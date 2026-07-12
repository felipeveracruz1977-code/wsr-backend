-- 068 — Revocación del check-in identificado por email
--
-- ⚠️ SECUENCIA DE DESPLIEGUE: aplicar esta migración JUNTO con (o inmediatamente
--    después de) el deploy de la web que usa fn_submit_check_in_token (067).
--    Si se aplica antes, el check-in del sitio en producción deja de funcionar.
--
-- Cierra el hallazgo H-1 de la auditoría 2026-07-12: fn_submit_check_in
-- aceptaba cualquier correo como única "autenticación", permitiendo enumerar
-- socias y registrar datos de salud a nombre de terceras (Ley 21.719,
-- art. 14 quinquies — deber de seguridad; art. 34 ter j — infracción grave).
--
-- service_role conserva EXECUTE por si algún flujo interno lo necesita;
-- el RPC deja de ser invocable desde clientes públicos.

revoke execute on function public.fn_submit_check_in(text, integer, integer, integer, integer, integer, integer, text, boolean, text, text) from public, anon, authenticated;
