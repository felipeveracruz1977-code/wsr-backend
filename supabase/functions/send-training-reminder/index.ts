// Supabase Edge Function — Recordatorio 24h antes del entrenamiento
// Invocar via cron: "0 10 * * *" (10:00 UTC = 07:00 CLT / 06:00 CLST)
// O manualmente desde el dashboard de Supabase

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const EXPO_PUSH_URL = 'https://exp.host/--/api/v2/push/send';

Deno.serve(async (req) => {
  // Guard: solo pg_cron (Authorization Bearer service_role) puede invocar esta función.
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!serviceRoleKey) return new Response('misconfigured', { status: 500 });
  const authHeader = req.headers.get('Authorization') ?? '';
  if (authHeader !== `Bearer ${serviceRoleKey}`) return new Response('unauthorized', { status: 401 });

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    serviceRoleKey,
  );

  // Entrenamientos publicados entre 23h y 25h desde ahora
  const from = new Date(Date.now() + 23 * 60 * 60 * 1000).toISOString();
  const to   = new Date(Date.now() + 25 * 60 * 60 * 1000).toISOString();

  const { data: trainings, error: tErr } = await supabase
    .from('trainings')
    .select('id, title, scheduled_at, location_name')
    .eq('status', 'published')
    .gte('scheduled_at', from)
    .lte('scheduled_at', to);

  if (tErr) return new Response(tErr.message, { status: 500 });
  if (!trainings?.length) return new Response('No trainings in window', { status: 200 });

  const messages: object[] = [];

  for (const training of trainings) {
    const { data: registrations } = await supabase
      .from('registrations')
      .select('user_id, user_profiles(push_token)')
      .eq('training_id', training.id)
      .eq('status', 'confirmed');

    for (const reg of registrations ?? []) {
      const token = (reg as any).user_profiles?.push_token;
      if (!token) continue;

      const hour = new Date(training.scheduled_at).toLocaleTimeString('es-CL', {
        hour: '2-digit',
        minute: '2-digit',
        timeZone: 'America/Santiago',
      });

      messages.push({
        to: token,
        title: '¡Mañana corres! 👟',
        body: `${training.title} — ${hour} hrs en ${training.location_name}`,
        data: { trainingId: training.id },
        sound: 'default',
      });
    }
  }

  if (!messages.length) return new Response('No tokens to notify', { status: 200 });

  // Expo acepta lotes de hasta 100 mensajes
  const chunks = [];
  for (let i = 0; i < messages.length; i += 100) {
    chunks.push(messages.slice(i, i + 100));
  }

  for (const chunk of chunks) {
    await fetch(EXPO_PUSH_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(chunk),
    });
  }

  return new Response(JSON.stringify({ sent: messages.length }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
