/**
 * delete-account — WSR
 * =====================
 * Supabase Edge Function · Deno Runtime
 *
 * Elimina definitivamente el registro auth.users de una usuaria que ya
 * llamó a request_account_deletion() (migración 038).
 *
 * Flujo:
 *   1. La app llama a request_account_deletion() RPC → anonimiza PII
 *      + marca deletion_requested_at en user_profiles.
 *   2. Esta función se ejecuta:
 *      a) Desde un cron diario (Supabase Scheduled Functions o pg_cron).
 *      b) Opcionalmente desde la app vía invoke() tras confirmar.
 *   3. Llama a auth.admin.deleteUser() con service_role para cada cuenta
 *      marcada hace > 24 horas (grace period antifraud).
 *
 * Guard: requiere Authorization: Bearer <service_role_key> (mismo patrón que
 * adherence-engine/emotional-reactivation/post-training-survey/send-training-reminder).
 * Sin el header correcto, la función responde 401 — no es invocable públicamente.
 *
 * Deploy:
 *   supabase functions deploy delete-account
 *
 * Invocar manualmente (admin, con service_role):
 *   curl -X POST https://<project>.supabase.co/functions/v1/delete-account \
 *     -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"
 *
 * Cron recomendado (Supabase Dashboard → Edge Functions → Schedules, o pg_cron
 * con net.http_post + Authorization Bearer service_role_key como en 045):
 *   0 3 * * *   (3 AM diariamente)
 */

import { serve }        from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const GRACE_HOURS = 24;

serve(async (req: Request) => {
  if (req.method !== 'POST' && req.method !== 'GET') {
    return json({ ok: false, error: 'method_not_allowed' }, 405);
  }

  // Guard: solo pg_cron / invocación admin (Authorization Bearer service_role) puede
  // ejecutar este borrado masivo. Fail-closed: sin la clave, la función se bloquea.
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!serviceRoleKey) return json({ ok: false, error: 'misconfigured' }, 500);
  const authHeader = req.headers.get('Authorization') ?? '';
  if (authHeader !== `Bearer ${serviceRoleKey}`) {
    return json({ ok: false, error: 'unauthorized' }, 401);
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    serviceRoleKey,
    { auth: { persistSession: false } },
  );

  // Obtener cuentas pendientes que superaron el grace period
  const { data: pending, error: fetchErr } = await supabase
    .from('user_profiles')
    .select('id, deletion_requested_at')
    .not('deletion_requested_at', 'is', null)
    .lt(
      'deletion_requested_at',
      new Date(Date.now() - GRACE_HOURS * 3600 * 1000).toISOString(),
    );

  if (fetchErr) {
    console.error('[delete-account] Error leyendo pending_deletions:', fetchErr.message);
    return json({ ok: false, error: fetchErr.message }, 500);
  }

  if (!pending?.length) {
    console.log('[delete-account] Sin cuentas pendientes de eliminar.');
    return json({ ok: true, deleted: 0 });
  }

  console.log(`[delete-account] Procesando ${pending.length} cuenta(s)...`);

  const results: { id: string; ok: boolean; error?: string }[] = [];

  for (const row of pending) {
    const { error: deleteErr } = await supabase.auth.admin.deleteUser(row.id);

    if (deleteErr) {
      console.error(`[delete-account] Error eliminando ${row.id}:`, deleteErr.message);
      results.push({ id: row.id, ok: false, error: deleteErr.message });
    } else {
      console.log(`[delete-account] ✅ Eliminada: ${row.id}`);
      results.push({ id: row.id, ok: true });
    }
  }

  const deleted = results.filter((r) => r.ok).length;
  const failed  = results.filter((r) => !r.ok).length;

  return json({ ok: true, deleted, failed, results });
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
