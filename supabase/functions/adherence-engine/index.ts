// ═══════════════════════════════════════════════════════════════════════════
// Engine 06 — WSR Behavioral Adherence Engine™
// Supabase Edge Function · supabase/functions/adherence-engine/index.ts
//
// Calcula diariamente el Abandonment Risk Score (ARS, 0-100) de cada corredora
// con plan activo y materializa el resultado en `adherence_scores`, generando
// `health_alerts` (alert_type='adherencia') cuando el riesgo entra en zona
// amarilla / naranja / roja.
//
// Invocada por pg_cron (05:00 UTC = 02:00 AM Chile) vía net.http_post.
// Autorización: header `x-cron-secret` == env CRON_SECRET.
// Persistencia: service_role key → bypassa RLS en el proceso batch.
//
// Modelo matemático: docs/ARCHITECTURE_ADHERENCE_ENGINE_v2.0.md (aprobado CTO).
//   ARS = clamp(min(100, A + B + C) - D, 0, 100)
//     A [0-40] Cumplimiento de sesiones (ventana 28d + tendencia + RPE drift)
//     B [0-35] Señales conductuales del check-in (motivación, vida, energía)
//     C [0-25] Inactividad silenciosa (días sin sesión / sin check-in)
//     D [0-10] Modificador protector: interacción comunitaria (puntos,
//       logros y asistencia a entrenamientos grupales de los últimos 30 días,
//       vía RPC de solo lectura fn_get_community_score). Una corredora
//       comunitariamente activa reduce su riesgo de abandono estimado.
//
// FAIL-SAFE: el cálculo de cada corredora está aislado en try/catch. Si una
// falla, se registra el error y el loop continúa con el resto.
// ═══════════════════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
// SSOT: tipos generados desde el esquema real de Supabase (@wsr/contracts).
// Tipar el cliente contra `Database` convierte un .from('tabla_muerta') en un
// error de compilación en vez de un 404 silencioso en producción a las 5am.
import type { Database } from "../../../contracts/database.types.ts";
import { withObservability } from "../_shared/withObservability.ts";

type Db = SupabaseClient<Database>;

// ── Config / Entorno ────────────────────────────────────────────────────────
// SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY son inyectadas por el runtime.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";

// Función invocada exclusivamente server-to-server por pg_cron (x-cron-secret);
// los navegadores no tienen por qué alcanzarla: CORS restringido al origen WSR.
const CORS = {
  "Access-Control-Allow-Origin": "https://www.womansocialrun.cl",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
  Vary: "Origin",
};

// ── Constantes del modelo (ventanas y techos por componente) ────────────────
const WINDOW_DAYS = 28; // ventana deslizante de análisis de sesiones
const CHECKIN_LIMIT = 4; // últimos N check-ins a promediar
const CAP_A = 40;
const CAP_B = 35;
const CAP_C = 25;
const MAX_COMMUNITY_DISCOUNT = 10; // D: techo del descuento por interacción comunitaria
const MS_PER_DAY = 86_400_000;

// ═══════════════════════════════════════════════════════════════════════════
// Tipos
// ═══════════════════════════════════════════════════════════════════════════

type Nivel = "verde" | "amarilla" | "naranja" | "roja";

interface CheckInRow {
  motivation: number | null;
  energy: number | null;
  life_changes: boolean | null;
  week_start: string | null; // DATE
  created_at: string; // TIMESTAMPTZ
}

interface TrainingSessionRow {
  day_of_week: number;
  status: "planned" | "completed" | "skipped";
  session_type: string;
  completed_at: string | null;
  rpe_target: number | null;
  week_number: number; // inyectado desde training_weeks
}

interface SessionResultRow {
  completed_at: string;
  actual_rpe: number | null;
  rpe_target: number | null; // inyectado desde training_sessions embebido
}

interface ActivePlan {
  id: string;
  reference_date: string; // delivered_at ?? created_at (ancla de scheduled_date)
  sessions: TrainingSessionRow[];
}

interface ComponentBreakdown {
  a: number;
  b: number;
  c: number;
  communityScore: number;
  communityDiscount: number;
  sessionsAnalyzed: number;
  checkinsAnalyzed: number;
  diasSinSesion: number | null;
  diasSinCheckin: number | null;
  compliancePct: number | null;
  completed: number;
  eligible: number;
  trendDown: boolean;
  avgMotivation: number | null;
}

interface ARSResult extends ComponentBreakdown {
  runnerId: string;
  score: number;
  nivel: Nivel;
  reason: string;
}

// ═══════════════════════════════════════════════════════════════════════════
// Handler principal
// ═══════════════════════════════════════════════════════════════════════════

serve(withObservability("adherence-engine", async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  // ── Autorización: secreto compartido con pg_cron ──────────────────────────
  // Si CRON_SECRET no está configurado, rechazamos por defecto (fail-closed).
  const provided = req.headers.get("x-cron-secret") ?? "";
  if (!CRON_SECRET || provided !== CRON_SECRET) {
    return json({ error: "unauthorized" }, 401);
  }

  if (!SUPABASE_URL || !SERVICE_KEY) {
    return json({ error: "missing service configuration" }, 503);
  }

  const triggeredBy = await readTrigger(req);
  const db = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false },
  });

  const startedAt = Date.now();
  const summary = { scope: 0, scored: 0, alerts: 0, failed: 0, errors: [] as string[] };

  try {
    const runnerIds = await fetchScope(db);
    summary.scope = runnerIds.length;

    // FAIL-SAFE: cada corredora se procesa de forma independiente.
    for (const runnerId of runnerIds) {
      try {
        const result = await scoreRunner(db, runnerId);
        await persistScore(db, result, triggeredBy);
        summary.scored++;

        if (result.nivel !== "verde") {
          const created = await maybeCreateAlert(db, result);
          if (created) summary.alerts++;
        }
      } catch (err) {
        summary.failed++;
        const msg = err instanceof Error ? err.message : String(err);
        summary.errors.push(`${runnerId}: ${msg}`);
        console.error(`[adherence-engine] runner ${runnerId} falló:`, msg);
      }
    }
  } catch (err) {
    // Falla a nivel de scope (no de una corredora puntual): error fatal.
    const msg = err instanceof Error ? err.message : String(err);
    console.error("[adherence-engine] fallo fatal:", msg);
    return json({ ok: false, error: msg, summary }, 500);
  }

  const durationMs = Date.now() - startedAt;
  console.log(`[adherence-engine] OK en ${durationMs}ms`, summary);
  return json({ ok: true, durationMs, ...summary });
}));

// ═══════════════════════════════════════════════════════════════════════════
// Scope — corredoras con plan activo (ver H#2 de la migración 039)
// runners.status NO contiene 'active'; el "scope activo" se define por la
// existencia de un plan con status='active'.
// ═══════════════════════════════════════════════════════════════════════════

async function fetchScope(db: Db): Promise<string[]> {
  const { data, error } = await db
    .from("plans")
    .select("runner_id")
    .eq("status", "active");

  if (error) throw new Error(`fetchScope: ${error.message}`);

  // Deduplicar: una corredora puede tener más de un plan activo.
  const unique = new Set<string>();
  for (const row of data ?? []) {
    if (row.runner_id) unique.add(row.runner_id as string);
  }
  return [...unique];
}

// ═══════════════════════════════════════════════════════════════════════════
// Cálculo del ARS de una corredora
// ═══════════════════════════════════════════════════════════════════════════

async function scoreRunner(db: Db, runnerId: string): Promise<ARSResult> {
  const since = isoDaysAgo(WINDOW_DAYS);

  // Las cuatro consultas son independientes → en paralelo.
  const [checkIns, activePlan, sessionResults, communityScore] = await Promise.all([
    fetchCheckIns(db, runnerId),
    fetchActivePlan(db, runnerId),
    fetchSessionResults(db, runnerId, since),
    fetchCommunityScore(db, runnerId),
  ]);

  const a = computeComponentA(activePlan, sessionResults);
  const c = computeComponentC(sessionResults, checkIns, activePlan);
  const b = computeComponentB(checkIns);
  const d = computeComponentD(communityScore);

  const score = clamp(a.points + b.points + c.points - d.discount, 0, 100);
  const nivel = classify(score);

  const reason = buildReason({ score, a, b, c, d });

  return {
    runnerId,
    score,
    nivel,
    reason,
    a: a.points,
    b: b.points,
    c: c.points,
    communityScore: d.communityScore,
    communityDiscount: d.discount,
    sessionsAnalyzed: a.eligible,
    checkinsAnalyzed: c.checkinsAnalyzed,
    diasSinSesion: c.diasSinSesion,
    diasSinCheckin: c.diasSinCheckin,
    compliancePct: a.compliancePct,
    completed: a.completed,
    eligible: a.eligible,
    trendDown: a.trendDown,
    avgMotivation: b.avgMotivation,
  };
}

// ─── Data fetchers ──────────────────────────────────────────────────────────

async function fetchCheckIns(db: Db, runnerId: string): Promise<CheckInRow[]> {
  // Tabla real: plan_check_ins (la tabla `check_ins` no existe en el esquema
  // clínico — ver migración 049 / auditoría SSOT). Columnas sin cambios.
  const { data, error } = await db
    .from("plan_check_ins")
    .select("motivation, energy, life_changes, week_start, created_at")
    .eq("runner_id", runnerId)
    .order("week_start", { ascending: false })
    .limit(CHECKIN_LIMIT);

  if (error) throw new Error(`plan_check_ins: ${error.message}`);
  return (data ?? []) as CheckInRow[];
}

async function fetchActivePlan(db: Db, runnerId: string): Promise<ActivePlan | null> {
  // Embebemos training_weeks → training_sessions en una sola consulta.
  // (La tabla `plan_sessions` no existe en el esquema clínico; la tabla real
  // de sesiones individuales es `training_sessions`, FK training_sessions.week_id
  // → training_weeks.id — ver migración 049 / auditoría SSOT.)
  const { data, error } = await db
    .from("plans")
    .select(
      "id, delivered_at, created_at, training_weeks(week_number, training_sessions(day_of_week, status, session_type, completed_at, rpe_target))",
    )
    .eq("runner_id", runnerId)
    .eq("status", "active")
    .order("created_at", { ascending: false })
    .limit(1);

  if (error) throw new Error(`plans: ${error.message}`);
  const plan = (data ?? [])[0] as
    | {
        id: string;
        delivered_at: string | null;
        created_at: string;
        training_weeks: Array<{
          week_number: number;
          training_sessions: Array<Omit<TrainingSessionRow, "week_number">>;
        }> | null;
      }
    | undefined;

  if (!plan) return null;

  const sessions: TrainingSessionRow[] = [];
  for (const week of plan.training_weeks ?? []) {
    for (const s of week.training_sessions ?? []) {
      sessions.push({ ...s, week_number: week.week_number });
    }
  }

  return {
    id: plan.id,
    reference_date: plan.delivered_at ?? plan.created_at,
    sessions,
  };
}

async function fetchSessionResults(
  db: Db,
  runnerId: string,
  since: string,
): Promise<SessionResultRow[]> {
  // source != 'clone' → excluye telemetría duplicada por versionado de planes.
  // Embed real: session_results.training_session_id → training_sessions.id
  // (no existe `plan_sessions` — ver migración 049 / auditoría SSOT).
  const { data, error } = await db
    .from("session_results")
    .select("completed_at, actual_rpe, source, training_sessions(rpe_target)")
    .eq("runner_id", runnerId)
    .neq("source", "clone")
    .gte("completed_at", since)
    .order("completed_at", { ascending: false });

  if (error) throw new Error(`session_results: ${error.message}`);

  return (data ?? []).map((r: Record<string, unknown>) => ({
    completed_at: r.completed_at as string,
    actual_rpe: (r.actual_rpe as number | null) ?? null,
    rpe_target: extractRpeTarget(r.training_sessions),
  }));
}

// El embed de PostgREST para un FK to-one suele venir como objeto, pero según
// cómo infiera la relación puede llegar como array. Soportamos ambos.
function extractRpeTarget(embed: unknown): number | null {
  const obj = Array.isArray(embed) ? embed[0] : embed;
  const v = (obj as { rpe_target?: number | null } | null)?.rpe_target;
  return typeof v === "number" ? v : null;
}

// fn_get_community_score (migración 049) — RPC de solo lectura que agrega
// puntos/logros/asistencia comunitaria de los últimos 30 días en un 0-100.
// Invocada con el cliente service_role → bypassa RLS, ve el dato real de
// cada corredora sin importar de quién sea la sesión.
async function fetchCommunityScore(db: Db, runnerId: string): Promise<number> {
  const { data, error } = await db.rpc("fn_get_community_score", { p_runner_id: runnerId });
  if (error) throw new Error(`fn_get_community_score: ${error.message}`);
  return typeof data === "number" ? data : 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// COMPONENTE A — Cumplimiento de sesiones [0-40]
// ═══════════════════════════════════════════════════════════════════════════

function computeComponentA(
  plan: ActivePlan | null,
  sessionResults: SessionResultRow[],
): {
  points: number;
  compliancePct: number | null;
  completed: number;
  eligible: number;
  trendDown: boolean;
} {
  if (!plan || plan.sessions.length === 0) {
    // Sin plan o sin sesiones: no hay nada que penalizar en A.
    // La inactividad la captura el Componente C.
    return { points: 0, compliancePct: null, completed: 0, eligible: 0, trendDown: false };
  }

  const now = Date.now();
  const windowStart = now - WINDOW_DAYS * MS_PER_DAY;

  let completed = 0;
  let eligible = 0;
  // Buckets para la tendencia: semana 1 (0-7d) vs semana 2 (8-14d).
  let w1Completed = 0, w1Eligible = 0;
  let w2Completed = 0, w2Eligible = 0;

  for (const s of plan.sessions) {
    if (s.session_type === "rest") continue;

    const scheduled = scheduledDate(plan.reference_date, s.week_number, s.day_of_week);
    const scheduledMs = scheduled.getTime();

    // Elegible = vencida (fecha pasada) dentro de la ventana de 28 días, o ya
    // resuelta (completed/skipped). Las futuras no cuentan en el denominador.
    const isDue = scheduledMs <= now;
    const isResolved = s.status === "completed" || s.status === "skipped";
    const inWindow = scheduledMs >= windowStart;
    if (!inWindow || !(isDue || isResolved)) continue;

    eligible++;
    const isCompleted = s.status === "completed";
    if (isCompleted) completed++;

    const ageDays = (now - scheduledMs) / MS_PER_DAY;
    if (ageDays <= 7) {
      w1Eligible++;
      if (isCompleted) w1Completed++;
    } else if (ageDays <= 14) {
      w2Eligible++;
      if (isCompleted) w2Completed++;
    }
  }

  if (eligible === 0) {
    return { points: 0, compliancePct: null, completed: 0, eligible: 0, trendDown: false };
  }

  const compliance = completed / eligible;

  // Paso 2 — escala de riesgo base.
  let points = scaleCompliance(compliance);

  // Paso 3 — penalización por tendencia decreciente (+5).
  const w1 = w1Eligible > 0 ? w1Completed / w1Eligible : null;
  const w2 = w2Eligible > 0 ? w2Completed / w2Eligible : null;
  const trendDown = w1 !== null && w2 !== null && w1 < w2 && w1 < 0.7;
  if (trendDown) points += 5;

  // Paso 4 — RPE drift (+3 / +5) si hay telemetría suficiente.
  points += rpeDriftPenalty(sessionResults);

  return {
    points: clamp(points, 0, CAP_A),
    compliancePct: Math.round(compliance * 100),
    completed,
    eligible,
    trendDown,
  };
}

function scaleCompliance(c: number): number {
  if (c >= 0.8) return 0;
  if (c >= 0.6) return 10;
  if (c >= 0.4) return 20;
  if (c >= 0.2) return 30;
  return 40;
}

function rpeDriftPenalty(results: SessionResultRow[]): number {
  // Promedio de (actual_rpe - rpe_target) sobre las últimas 4 sesiones con
  // ambos datos. results ya viene ordenado por completed_at DESC.
  const deltas: number[] = [];
  for (const r of results) {
    if (r.actual_rpe == null || r.rpe_target == null) continue;
    deltas.push(r.actual_rpe - r.rpe_target);
    if (deltas.length === 4) break;
  }
  if (deltas.length === 0) return 0;

  const avg = deltas.reduce((sum, d) => sum + d, 0) / deltas.length;
  if (avg > 2.0) return 3; // forzando demasiado → riesgo lesión/abandono
  if (avg < -2.5) return 5; // evitando el esfuerzo → desenganche conductual
  return 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// COMPONENTE B — Señales conductuales del check-in [0-35]
// ═══════════════════════════════════════════════════════════════════════════

function computeComponentB(
  checkIns: CheckInRow[],
): { points: number; avgMotivation: number | null } {
  // Sin check-ins: B=0. La inactividad de canal la captura el Componente C.2,
  // por lo que no se castiga dos veces (ver doc §2.3, caso de borde).
  if (checkIns.length === 0) {
    return { points: 0, avgMotivation: null };
  }

  // B.1 — Motivación (0-15) + bonus por caída brusca (+3).
  const motivations = numbers(checkIns.map((c) => c.motivation));
  const avgMotivation = average(motivations);
  let bMot = scaleMotivation(avgMotivation);
  // checkIns[0] es el más reciente (order week_start DESC).
  const latestMot = checkIns[0]?.motivation;
  if (avgMotivation !== null && latestMot != null && latestMot < avgMotivation - 1.5) {
    bMot += 3;
  }

  // B.2 — Carga vital disruptiva en las últimas 4 semanas (0-10).
  const since = isoDaysAgo(28);
  const lifeEvents = checkIns.filter(
    (c) => c.life_changes === true && (c.week_start ?? "") >= since.slice(0, 10),
  ).length;
  const bLife = lifeEvents >= 2 ? 10 : lifeEvents === 1 ? 5 : 0;

  // B.3 — Déficit energético crónico (0-10).
  const energies = numbers(checkIns.map((c) => c.energy));
  const bEnergy = scaleEnergy(average(energies));

  return { points: clamp(bMot + bLife + bEnergy, 0, CAP_B), avgMotivation };
}

function scaleMotivation(avg: number | null): number {
  if (avg === null) return 0;
  if (avg >= 7.0) return 0;
  if (avg >= 5.0) return 5;
  if (avg >= 3.0) return 10;
  return 15;
}

function scaleEnergy(avg: number | null): number {
  if (avg === null) return 0;
  if (avg >= 6.0) return 0;
  if (avg >= 4.0) return 5;
  return 10;
}

// ═══════════════════════════════════════════════════════════════════════════
// COMPONENTE C — Inactividad silenciosa [0-25]   ◀── BLOQUE AUDITADO POR EL CTO
//
// La señal más crítica del ARS: detecta dropouts que NO generan ningún INSERT
// (sin sesión fallada, sin check-in) y que por tanto ningún trigger de BD puede
// capturar. Se toma el PEOR de los dos indicadores de silencio (no la suma)
// para no castigar dos veces la misma inactividad.
// ═══════════════════════════════════════════════════════════════════════════

function computeComponentC(
  sessionResults: SessionResultRow[],
  checkIns: CheckInRow[],
  plan: ActivePlan | null,
): { points: number; diasSinSesion: number | null; diasSinCheckin: number | null; checkinsAnalyzed: number } {
  // Ancla para corredoras nuevas: si nunca registraron actividad, medimos el
  // silencio desde la entrega del plan (no desde el epoch) para no marcar en
  // rojo a quien acaba de empezar.
  const anchor = plan?.reference_date ?? null;

  // C.1 — Días sin sesión registrada (fuente: session_results, source!='clone').
  const lastSession = mostRecent(sessionResults.map((r) => r.completed_at));
  const diasSinSesion = daysSince(lastSession ?? anchor);
  const c1 = scaleSessionGap(diasSinSesion);

  // C.2 — Días sin check-in (fuente: check_ins.created_at).
  const lastCheckin = mostRecent(checkIns.map((c) => c.created_at));
  const diasSinCheckin = daysSince(lastCheckin ?? anchor);
  const c2 = scaleCheckinGap(diasSinCheckin);

  // C = max(C.1, C.2) → el peor de los dos silencios.
  const points = clamp(Math.max(c1, c2), 0, CAP_C);

  return {
    points,
    diasSinSesion,
    diasSinCheckin,
    checkinsAnalyzed: checkIns.length,
  };
}

function scaleSessionGap(dias: number | null): number {
  if (dias === null) return CAP_C; // sin ancla ni actividad → riesgo máximo
  if (dias <= 7) return 0;
  if (dias <= 14) return 10;
  if (dias <= 21) return 17;
  if (dias <= 28) return 22;
  return 25;
}

function scaleCheckinGap(dias: number | null): number {
  if (dias === null) return 18;
  if (dias <= 8) return 0; // gap normal semanal
  if (dias <= 15) return 5; // saltó 1 semana
  if (dias <= 22) return 12; // saltó 2 semanas
  return 18; // abandono de canal
}

// ═══════════════════════════════════════════════════════════════════════════
// COMPONENTE D — Modificador protector: interacción comunitaria [0-10]
//
// A diferencia de A/B/C (que suman riesgo), D resta: una corredora activa en
// la comunidad (puntos, logros, entrenamientos grupales de los últimos 30d)
// tiene un ARS más bajo a igualdad de A+B+C. Escala linealmente el score
// 0-100 de fn_get_community_score a un descuento 0-10 sobre el ARS.
// ═══════════════════════════════════════════════════════════════════════════

function computeComponentD(communityScore: number): { discount: number; communityScore: number } {
  const clamped = clamp(communityScore, 0, 100);
  const discount = Math.round((clamped / 100) * MAX_COMMUNITY_DISCOUNT);
  return { discount, communityScore: clamped };
}

// ═══════════════════════════════════════════════════════════════════════════
// Clasificación y narrativa
// ═══════════════════════════════════════════════════════════════════════════

function classify(score: number): Nivel {
  if (score < 40) return "verde";
  if (score < 60) return "amarilla";
  if (score < 80) return "naranja";
  return "roja";
}

function buildReason(args: {
  score: number;
  a: ReturnType<typeof computeComponentA>;
  b: ReturnType<typeof computeComponentB>;
  c: ReturnType<typeof computeComponentC>;
  d: ReturnType<typeof computeComponentD>;
}): string {
  const { score, a, b, c, d } = args;
  const parts: string[] = [`ARS ${score}/100`];

  if (a.compliancePct !== null) {
    const trend = a.trendDown ? ", ↓ vs semana anterior" : "";
    parts.push(`Cumplimiento ${a.compliancePct}% (${a.completed}/${a.eligible} sesiones${trend})`);
  } else {
    parts.push("sin sesiones vencidas en la ventana");
  }

  if (b.avgMotivation !== null) {
    parts.push(`motivación media ${b.avgMotivation.toFixed(1)}/10`);
  }

  if (c.diasSinSesion !== null) {
    parts.push(`${c.diasSinSesion} días sin completar sesión registrada`);
  }

  if (d.discount > 0) {
    parts.push(`-${d.discount} por interacción comunitaria (score ${d.communityScore}/100)`);
  }

  return parts.join(" — ") + ".";
}

// ═══════════════════════════════════════════════════════════════════════════
// Persistencia
// ═══════════════════════════════════════════════════════════════════════════

async function persistScore(
  db: Db,
  r: ARSResult,
  triggeredBy: string,
): Promise<void> {
  // UPSERT idempotente: 1 fila por corredora por día (UNIQUE runner_id+scored_date).
  const { error } = await db.from("adherence_scores").upsert(
    {
      runner_id: r.runnerId,
      scored_date: todayISO(),
      score: r.score,
      nivel: r.nivel,
      component_a: r.a,
      component_b: r.b,
      component_c: r.c,
      sessions_analyzed: r.sessionsAnalyzed,
      checkins_analyzed: r.checkinsAnalyzed,
      dias_sin_sesion: r.diasSinSesion,
      dias_sin_checkin: r.diasSinCheckin,
      triggered_by: triggeredBy,
      calculated_at: new Date().toISOString(),
    },
    { onConflict: "runner_id,scored_date" },
  );

  if (error) throw new Error(`upsert adherence_scores: ${error.message}`);
}

async function maybeCreateAlert(db: Db, r: ARSResult): Promise<boolean> {
  // No duplicar: una sola alerta de adherencia por corredora por día.
  const { data: existing, error: selErr } = await db
    .from("health_alerts")
    .select("id")
    .eq("runner_id", r.runnerId)
    .eq("alert_type", "adherencia")
    .gte("created_at", `${todayISO()}T00:00:00Z`)
    .limit(1);

  if (selErr) throw new Error(`select health_alerts: ${selErr.message}`);
  if (existing && existing.length > 0) return false;

  const { error: insErr } = await db.from("health_alerts").insert({
    runner_id: r.runnerId,
    check_in_id: null,
    alert_type: "adherencia",
    severity: r.nivel, // 'amarilla' | 'naranja' | 'roja' (verde nunca llega aquí)
    reason: r.reason,
    status: "pendiente",
  });

  if (insErr) throw new Error(`insert health_alerts: ${insErr.message}`);
  return true;
}

// ═══════════════════════════════════════════════════════════════════════════
// Utilidades puras
// ═══════════════════════════════════════════════════════════════════════════

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

async function readTrigger(req: Request): Promise<string> {
  try {
    const body = await req.json();
    const t = (body as { trigger?: string })?.trigger;
    return t === "manual" || t === "webhook" ? t : "cron";
  } catch {
    return "cron"; // sin body válido → asumimos invocación programada
  }
}

function clamp(n: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, Math.round(n)));
}

function numbers(values: Array<number | null>): number[] {
  return values.filter((v): v is number => typeof v === "number" && !Number.isNaN(v));
}

function average(values: number[]): number | null {
  if (values.length === 0) return null;
  return values.reduce((sum, v) => sum + v, 0) / values.length;
}

function mostRecent(timestamps: string[]): string | null {
  let max: number | null = null;
  for (const ts of timestamps) {
    const t = Date.parse(ts);
    if (!Number.isNaN(t) && (max === null || t > max)) max = t;
  }
  return max === null ? null : new Date(max).toISOString();
}

// Días enteros transcurridos desde `iso` hasta ahora (null si no hay fecha).
function daysSince(iso: string | null): number | null {
  if (!iso) return null;
  const t = Date.parse(iso);
  if (Number.isNaN(t)) return null;
  return Math.max(0, Math.floor((Date.now() - t) / MS_PER_DAY));
}

// scheduled_date = reference_date + (week_number-1)*7 + (day_of_week-1) días.
// Deriva la fecha prevista de una sesión a partir del ancla del plan.
function scheduledDate(referenceDate: string, weekNumber: number, dayOfWeek: number): Date {
  const base = new Date(referenceDate);
  const offsetDays = (weekNumber - 1) * 7 + (dayOfWeek - 1);
  return new Date(base.getTime() + offsetDays * MS_PER_DAY);
}

function isoDaysAgo(days: number): string {
  return new Date(Date.now() - days * MS_PER_DAY).toISOString();
}

function todayISO(): string {
  return new Date().toISOString().slice(0, 10); // YYYY-MM-DD (UTC)
}
