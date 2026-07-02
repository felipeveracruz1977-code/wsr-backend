// Supabase Edge Function — Encuesta post-entrenamiento
// Invocar via cron: "0 14 * * 0" (domingos 14:00 UTC = ~11:00 CLT)
// Envía la encuesta 2h después de la hora estimada de término

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

  // Entrenamientos completados en las últimas 4 horas (ventana holgada)
  const from = new Date(Date.now() - 4 * 60 * 60 * 1000).toISOString();
  const to   = new Date(Date.now() - 1 * 60 * 60 * 1000).toISOString();

  const { data: trainings, error } = await supabase
    .from('trainings')
    .select('id, title')
    .eq('status', 'published')
    .gte('scheduled_at', from)
    .lte('scheduled_at', to);

  if (error) return new Response(error.message, { status: 500 });
  if (!trainings?.length) return new Response('No trainings in window', { status: 200 });

  const messages: object[] = [];

  for (const training of trainings) {
    // Solo usuarias sin encuesta enviada para este entrenamiento
    const { data: registrations } = await supabase
      .from('registrations')
      .select(`
        user_id,
        user_profiles(push_token)
      `)
      .eq('training_id', training.id)
      .eq('status', 'confirmed');

    if (!registrations?.length) continue;

    // Excluir las que ya respondieron
    const { data: alreadyAnswered } = await supabase
      .from('training_surveys')
      .select('user_id')
      .eq('training_id', training.id);

    const answeredIds = new Set((alreadyAnswered ?? []).map((s: any) => s.user_id));

    for (const reg of registrations) {
      if (answeredIds.has(reg.user_id)) continue;
      const token = (reg as any).user_profiles?.push_token;
      if (!token) continue;

      messages.push({
        to: token,
        title: '¿Cómo te fue hoy? 💜',
        body: `Cuéntanos tu experiencia en "${training.title}"`,
        data: { trainingId: training.id, type: 'survey' },
        sound: 'default',
      });
    }
  }

  if (!messages.length) return new Response('No tokens to notify', { status: 200 });

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
