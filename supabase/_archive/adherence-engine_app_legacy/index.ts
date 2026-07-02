/**
 * adherence-engine — WSR Adherence Risk Score (ARS) Calculator
 * =============================================================
 * Supabase Edge Function · Deno Runtime
 *
 * Invocada diariamente vía pg_cron (05:00 UTC) o manualmente.
 * Para cada runner con plan activo, calcula el ARS y lo upserta
 * en adherence_scores.
 *
 * ARS (0-100): mayor = más riesgo de abandono.
 *   Component A [0-40]: cumplimiento de sesiones del plan (últimas 2 sem)
 *   Component B [0-35]: señales del check-in semanal (última semana)
 *   Component C [0-25]: inactividad silenciosa (días sin ningún dato)
 *
 * Invoke:
 *   supabase functions invoke adherence-engine --body '{}'
 *   supabase functions deploy adherence-engine
 *
 * Secrets (auto-inyectados):
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 */

import { serve }        from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ── Tipos ─────────────────────────────────────────────────────────────────────

interface Runner {
  id:         string;
  user_id:    string | null;
}

interface SessionResult {
  training_session_id: string;
  completed_at:        string | null;
  actual_rpe:          number | null;
}

interface TrainingSession {
  id:         string;
  status:     string;
}

interface CheckIn {
  week_start:  string;
  mood_score:  number | null;
  energy_score: number | null;
  pain_score:  number | null;
}

type AdhNivel = 'verde' | 'amarilla' | 'naranja' | 'roja';

// ── ARS Calculator ─────────────────────────────────────────────────────────────

function calcComponentA(
  sessions: TrainingSession[],
  results:  SessionResult[],
  daysWindow: number = 14,
): { score: number; analyzed: number } {
  const cutoff = new Date(Date.now() - daysWindow * 86_400_000).toISOString();

  // Sessions from the plan that were due in the window (exclude rest)
  const dueSessions = sessions.filter((s) =>
    s.status === 'completed' || s.status === 'planned' || s.status === 'skipped',
  );
  if (dueSessions.length === 0) return { score: 0, analyzed: 0 };

  const completedIds = new Set(results.map((r) => r.training_session_id));
  const completed    = dueSessions.filter((s) => completedIds.has(s.id)).length;
  const total        = dueSessions.length;
  const adherenceRate = completed / total;

  // Lower adherence → higher risk (A component)
  const score = Math.round((1 - adherenceRate) * 40);
  return { score: Math.min(score, 40), analyzed: total };
}

function calcComponentB(checkins: CheckIn[]): { score: number; analyzed: number } {
  if (checkins.length === 0) return { score: 20, analyzed: 0 }; // sin datos = riesgo moderado

  const latest   = checkins[0];
  let   b        = 0;

  // Humor bajo → riesgo moderado
  if (latest.mood_score !== null   && latest.mood_score   <= 2) b += 12;
  else if (latest.mood_score !== null && latest.mood_score <= 3) b +=  6;

  // Energía baja
  if (latest.energy_score !== null && latest.energy_score <= 2) b += 12;
  else if (latest.energy_score !== null && latest.energy_score <= 3) b += 6;

  // Dolor alto — señal crítica
  if (latest.pain_score !== null   && latest.pain_score   >= 6) b += 11;
  else if (latest.pain_score !== null && latest.pain_score >= 4) b += 5;

  return { score: Math.min(b, 35), analyzed: checkins.length };
}

function calcComponentC(
  diasSinSesion:  number,
  diasSinCheckin: number,
): { score: number } {
  // Inactividad compuesta: el mayor de los dos define el riesgo
  const dias = Math.max(diasSinSesion, diasSinCheckin);
  if (dias >= 21) return { score: 25 };
  if (dias >= 14) return { score: 18 };
  if (dias >= 7)  return { score: 10 };
  if (dias >= 3)  return { score: 4 };
  return { score: 0 };
}

function nivel(score: number): AdhNivel {
  if (score <= 20)  return 'verde';
  if (score <= 45)  return 'amarilla';
  if (score <= 70)  return 'naranja';
  return 'roja';
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function daysSince(isoDate: string | null): number {
  if (!isoDate) return 999;
  return Math.floor((Date.now() - new Date(isoDate).getTime()) / 86_400_000);
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// ── Main ──────────────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method !== 'POST' && req.method !== 'GET') {
    return json({ ok: false, error: 'method_not_allowed' }, 405);
  }

  // Guard: solo invocable con Bearer service_role (pg_cron migración 044 lo envía).
  // Procesa datos clínicos de todas las runners → nunca debe quedar abierto.
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!serviceRoleKey) return json({ ok: false, error: 'misconfigured' }, 500);
  const authHeader = req.headers.get('Authorization') ?? '';
  if (authHeader !== `Bearer ${serviceRoleKey}`) {
    return json({ ok: false, error: 'unauthorized' }, 401);
  }

  // Parse optional runner_id (manual trigger for single runner)
  let targetRunnerId: string | null = null;
  try {
    if (req.method === 'POST' && req.headers.get('content-type')?.includes('json')) {
      const body = await req.json();
      targetRunnerId = body.runner_id ?? null;
    }
  } catch { /* no body */ }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  // 1. Fetch active runners (with active plans)
  let runnersQuery = supabase
    .from('runners')
    .select('id, user_id')
    .limit(500);

  if (targetRunnerId) {
    runnersQuery = runnersQuery.eq('id', targetRunnerId);
  }

  const { data: runners, error: rErr } = await runnersQuery;
  if (rErr) return json({ ok: false, error: rErr.message }, 500);
  if (!runners?.length) return json({ ok: true, processed: 0 });

  const today       = new Date().toISOString().slice(0, 10);
  const window14    = new Date(Date.now() - 14 * 86_400_000).toISOString();
  const window28    = new Date(Date.now() - 28 * 86_400_000).toISOString();
  const triggeredBy = targetRunnerId ? 'manual' : 'cron';

  let processed = 0;
  let errors    = 0;

  for (const runner of runners as Runner[]) {
    try {
      // 2. Fetch active plan
      const { data: plan } = await supabase
        .from('plans')
        .select('id')
        .eq('runner_id', runner.id)
        .eq('status', 'active')
        .maybeSingle();

      if (!plan) continue; // sin plan activo: no hay ARS que calcular

      // 3. Sessions from the plan (last 28 days window)
      const { data: sessions } = await supabase
        .from('training_sessions')
        .select('id, status')
        .eq('plan_id', plan.id);

      // 4. Session results (last 28 days)
      const { data: results } = await supabase
        .from('session_results')
        .select('training_session_id, completed_at, actual_rpe')
        .eq('runner_id', runner.id)
        .gte('completed_at', window28);

      // 5. Check-ins (last 14 days, ordered desc)
      const { data: checkins } = await supabase
        .from('checkins')
        .select('week_start, mood_score, energy_score, pain_score')
        .eq('runner_id', runner.id)
        .gte('week_start', window14)
        .order('week_start', { ascending: false });

      // 6. Last session result date
      const lastResultAt = results?.length
        ? results.reduce((latest, r) =>
            r.completed_at && r.completed_at > latest ? r.completed_at : latest, '')
        : null;

      const lastCheckinAt = checkins?.length
        ? checkins[0].week_start
        : null;

      const diasSinSesion  = daysSince(lastResultAt);
      const diasSinCheckin = daysSince(lastCheckinAt);

      // 7. Compute components
      const A = calcComponentA(
        (sessions ?? []) as TrainingSession[],
        (results  ?? []) as SessionResult[],
      );
      const B = calcComponentB((checkins ?? []) as CheckIn[]);
      const C = calcComponentC(diasSinSesion, diasSinCheckin);

      const totalScore = Math.min(A.score + B.score + C.score, 100);

      // 8. Upsert
      const { error: uErr } = await supabase
        .from('adherence_scores')
        .upsert({
          runner_id:         runner.id,
          scored_date:       today,
          score:             totalScore,
          nivel:             nivel(totalScore),
          component_a:       A.score,
          component_b:       B.score,
          component_c:       C.score,
          sessions_analyzed: A.analyzed,
          checkins_analyzed: B.analyzed,
          dias_sin_sesion:   diasSinSesion === 999 ? null : diasSinSesion,
          dias_sin_checkin:  diasSinCheckin === 999 ? null : diasSinCheckin,
          triggered_by:      triggeredBy,
          calculated_at:     new Date().toISOString(),
        }, { onConflict: 'runner_id,scored_date' });

      if (uErr) {
        console.error(`[adherence] runner ${runner.id}: ${uErr.message}`);
        errors++;
      } else {
        processed++;
      }
    } catch (err) {
      console.error(`[adherence] runner ${runner.id} exception:`, err);
      errors++;
    }
  }

  return json({ ok: true, processed, errors, date: today });
});
