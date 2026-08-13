-- 050_fix_adherence_cron_auth_header.sql
-- Bug P0 encontrado durante la resurrección del Adherence Engine (Engine 06,
-- ver commit 2d0f90d): el job wsr-adherence-engine-daily invocaba la Edge
-- Function adherence-engine solo con `Authorization: Bearer service_role_key`,
-- pero el handler valida el header `x-cron-secret` (fail-closed si falta o
-- no coincide). El cron nunca envió ese header, así que el ARS nocturno
-- devolvía 401 antes de tocar una sola query — independiente del bug de
-- tablas muertas (check_ins/plan_sessions) ya corregido.
--
-- Fix: se agrega x-cron-secret al payload de net.http_post, leído desde
-- vault.decrypted_secrets ('adherence_engine_cron_secret'). El valor debe
-- coincidir con el env var CRON_SECRET configurado en la Edge Function
-- (acción manual del CTO vía `supabase secrets set`, no automatizable desde
-- una migración SQL).

SELECT cron.unschedule('wsr-adherence-engine-daily');

SELECT cron.schedule(
  'wsr-adherence-engine-daily',
  '0 5 * * *',
  $$
  SELECT net.http_post(
    url     := 'https://thirekzbfbwchstvcqxw.supabase.co/functions/v1/adherence-engine',
    headers := jsonb_build_object(
                 'Content-Type',  'application/json',
                 'Authorization', 'Bearer ' || (
                   SELECT decrypted_secret
                   FROM   vault.decrypted_secrets
                   WHERE  name = 'service_role_key'
                   LIMIT  1
                 ),
                 'x-cron-secret', (
                   SELECT decrypted_secret
                   FROM   vault.decrypted_secrets
                   WHERE  name = 'adherence_engine_cron_secret'
                   LIMIT  1
                 )
               ),
    body    := '{}'::jsonb
  ) AS request_id;
  $$
);
