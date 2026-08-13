-- 090 — HOTFIX 002: cierre de fuga PII (fn_get_vip_invite_prefill) +
-- revocación de funciones sin llamadores conocidos (GRUPO 3).
--
-- Contexto (auditoría HOTFIX 002, 2026-08-13):
-- 1. fn_get_vip_invite_prefill(p_training_id, p_email) tenía EXECUTE otorgado
--    explícitamente a anon. Dado un training_id + email arbitrarios (ambos
--    adivinables/enumerables), devuelve nombre/teléfono de la corredora
--    asociada — fuga PII activa por enumeración de correos. Se revoca de
--    PUBLIC y anon; se preserva el GRANT explícito preexistente a
--    authenticated (no otorgado vía PUBLIC — fuera de alcance de este hotfix).
--    Verificado en Web/womansocialrun-main/src/pages/EventoVip.tsx: la
--    llamada (líneas ~40-49) ignora `error` por completo y sólo asigna
--    initialValues si `prefillRows` trae filas, así que un 42501 degrada a
--    formulario sin prefill (nombre/teléfono vacíos, resto de la página
--    intacta) — no hay pantalla en blanco ni excepción no capturada. El RPC
--    no existe en App/wsr-app (grep sin resultados).
-- 2. wsr_coach_email_for_runner(p_runner_id) y get_private_trainings_for_runner()
--    (GRUPO 3): EXECUTE heredado únicamente de PUBLIC (grant por defecto de
--    Postgres al crear la función), cero llamadores verificados por grep en
--    App/ y Web/. Se otorga GRANT explícito a authenticated antes de revocar
--    PUBLIC + anon (mismo patrón que 074, para no arrastrar la pérdida de
--    acceso de authenticated que dependía solo de la herencia de PUBLIC).
-- 3. wsr_enviar_bienvenida_runner, wsr_notify_coach_alert, wsr_notify_coach_checkin,
--    wsr_sync_runner_coach: RETURNS trigger. El motor de triggers las invoca
--    sin verificar EXECUTE, por lo que no necesitan grant de invocación para
--    ningún rol. Se revocan de PUBLIC, anon Y authenticated.
--
-- Fuera de alcance: ninguna función de GRUPO 2 fue tocada en esta migración.
--
-- Rollback: wsr-backend/supabase/hotfix_090_rollback.sql (deliberadamente
-- fuera de supabase/migrations/ — ver nota en ese archivo).

-- 1. Fuga PII activa
REVOKE EXECUTE ON FUNCTION public.fn_get_vip_invite_prefill(uuid, text) FROM PUBLIC, anon;

-- 2. GRUPO 3, cero llamadores — preservar authenticated antes de cerrar PUBLIC/anon
GRANT EXECUTE ON FUNCTION public.wsr_coach_email_for_runner(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.wsr_coach_email_for_runner(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_private_trainings_for_runner() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.get_private_trainings_for_runner() FROM PUBLIC, anon;

-- 3. Funciones trigger: ningún cliente ni rol necesita invocarlas como RPC
REVOKE EXECUTE ON FUNCTION public.wsr_enviar_bienvenida_runner() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.wsr_notify_coach_alert() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.wsr_notify_coach_checkin() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.wsr_sync_runner_coach() FROM PUBLIC, anon, authenticated;
