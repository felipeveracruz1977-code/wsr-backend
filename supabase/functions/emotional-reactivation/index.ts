// Supabase Edge Function — Reactivación emocional (anti-abandono)
// Invocar via cron diario: "0 14 * * *" (14:00 UTC = 11:00 CLT)
//
// Filosofía (Sección 9 del Documento Maestro): acompañar, nunca presionar.
// Escalamiento SUAVE y DECRECIENTE según días de inactividad: 3 / 10 / 21.
// Nunca lenguaje de culpa. Si la usuaria declaró "culpa" como barrera, el
// tono es extra-suave. Cada escalón se envía una sola vez (reactivation_log).
//
// Señal de actividad: última fila en point_transactions (toda acción suma puntos).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const EXPO_PUSH_URL = 'https://exp.host/--/api/v2/push/send';
const STAGES = [21, 10, 3] as const; // de mayor a menor: aplica el escalón más alto alcanzado
type Stage = (typeof STAGES)[number];

// Espejo Deno del motor en utils/microcopy.ts (mantener ambos en sintonía).
function reactivationCopy(stage: Stage, firstName: string | null, guiltSensitive: boolean): string {
  const name = firstName ? `, ${firstName}` : '';
  if (stage === 21) {
    return `Te guardamos tu lugar${name}. Cuando quieras, aquí estamos. 🤍`;
  }
  if (stage === 10) {
    return 'La comunidad te extraña. Hay una corrida tranquila esperándote cuando puedas. 💛';
  }
  // stage 3
  return guiltSensitive
    ? `¿Una corrida suave esta semana${name}? Sin apuros, a tu ritmo. 🤍`
    : `¿Una corrida suave esta semana${name}? A tu ritmo, sin presión. 🌿`;
}

function daysSince(iso: string): number {
  return Math.floor((Date.now() - new Date(iso).getTime()) / 86_400_000);
}

Deno.serve(async (req) => {
  // Guard: solo pg_cron (que envía Authorization Bearer service_role) puede invocar esta función.
  // Fail-closed: si SUPABASE_SERVICE_ROLE_KEY no está disponible, rechaza.
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!serviceRoleKey) {
    return new Response('misconfigured', { status: 500 });
  }
  const authHeader = req.headers.get('Authorization') ?? '';
  if (authHeader !== `Bearer ${serviceRoleKey}`) {
    return new Response('unauthorized', { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    serviceRoleKey,
  );

  // Usuarias con push token y su nivel de barrera (culpa => extra-suave).
  const { data: users, error: uErr } = await supabase
    .from('user_profiles')
    .select('id, full_name, push_token, user_onboarding(barriers)');

  if (uErr) return new Response(uErr.message, { status: 500 });
  if (!users?.length) return new Response('No users', { status: 200 });

  const messages: { to: string; userId: string; stage: Stage; body: string }[] = [];

  for (const u of users as any[]) {
    if (!u.push_token) continue;

    // Última actividad = último movimiento de puntos.
    const { data: lastTx } = await supabase
      .from('point_transactions')
      .select('created_at')
      .eq('user_id', u.id)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!lastTx) continue; // nunca tuvo actividad: la maneja el onboarding, no esto.
    const days = daysSince(lastTx.created_at);

    // Escalón más alto alcanzado.
    const stage = STAGES.find((s) => days >= s);
    if (!stage) continue;

    // ¿Ya se le envió este escalón?
    const { data: already } = await supabase
      .from('reactivation_log')
      .select('id')
      .eq('user_id', u.id)
      .eq('stage', stage)
      .maybeSingle();
    if (already) continue;

    const barriers: string[] = u.user_onboarding?.barriers ?? [];
    const body = reactivationCopy(stage, u.full_name?.split(' ')[0] ?? null, barriers.includes('culpa'));

    messages.push({ to: u.push_token, userId: u.id, stage, body });
  }

  if (!messages.length) return new Response('Nadie por reactivar hoy', { status: 200 });

  // Enviar push en lotes de 100 y registrar el escalón.
  for (let i = 0; i < messages.length; i += 100) {
    const chunk = messages.slice(i, i + 100);
    await fetch(EXPO_PUSH_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(
        chunk.map((m) => ({ to: m.to, title: 'Woman Social Run', body: m.body, sound: 'default' })),
      ),
    });
    await supabase
      .from('reactivation_log')
      .insert(chunk.map((m) => ({ user_id: m.userId, stage: m.stage })));
  }

  return new Response(JSON.stringify({ sent: messages.length }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
