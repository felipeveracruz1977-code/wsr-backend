-- 091 — HOTFIX 003 Parte C: cierre de EXECUTE anon en funciones invisibles
-- al linter de Supabase (fn_dashboard_kpis, fn_dashboard_risk_scores:
-- SECURITY INVOKER; fn_set_actualizado_en: trigger).
--
-- Contexto (auditoría HOTFIX 003, 2026-08-13):
-- Verificado en vivo ANTES de aplicar (SET ROLE anon):
--   fn_dashboard_kpis()        -> {"active_runners":0,"adherencia_promedio":null,
--                                  "total_checkins":0,"alerts_amarilla":0,
--                                  "alerts_naranja":0,"alerts_roja":0}
--   fn_dashboard_risk_scores() -> [] (cero filas)
-- Ambas son SECURITY INVOKER (no DEFINER): corren con los privilegios del
-- rol llamante. Las políticas RLS de runners/plan_check_ins/health_alerts
-- (health_alerts_admin_all, health_alerts_coach_select/update,
-- plan_check_ins_admin_all/coach_read/runner_own, runners_admin_all/
-- coach_select/coach_update/runner_own) están TODAS restringidas a
-- roles={authenticated} -- anon no tiene ninguna política aplicable en
-- ninguna de las tres tablas (RLS habilitado, sin FORCE), así que el motor
-- deniega todo por defecto. No hay fuga de datos de salud: el EXECUTE de
-- anon era una brecha de higiene sin explotación real, no una fuga activa.
-- Búsqueda en pg_policies (las 3 tablas, schema public completo): ninguna
-- política invoca fn_dashboard_kpis/fn_dashboard_risk_scores en su
-- qual/with_check, por lo que revocar EXECUTE no puede romper ninguna
-- política de RLS existente.
--
-- fn_set_actualizado_en() es RETURNS trigger (dispara en updates de
-- marcas_patrocinadoras); el motor de triggers no requiere EXECUTE del rol
-- que dispara el UPDATE (mismo criterio verificado en 076). Se revoca de
-- los tres roles.
--
-- Ninguna de las tres funciones aparece en get_advisors(security): el
-- linter 0028/0029 de Supabase solo detecta funciones SECURITY DEFINER
-- invocables por anon/authenticated, y PostgREST no expone funciones
-- RETURNS trigger como RPC. Son un punto ciego real del linter (ver
-- propuesta de chequeo propio en CI, HOTFIX 003 Parte D).
--
-- Rollback: wsr-backend/supabase/hotfix_091_rollback.sql (fuera de
-- migrations/ a propósito).

GRANT EXECUTE ON FUNCTION public.fn_dashboard_kpis() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_dashboard_kpis() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.fn_dashboard_risk_scores() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_dashboard_risk_scores() FROM PUBLIC, anon;

REVOKE EXECUTE ON FUNCTION public.fn_set_actualizado_en() FROM PUBLIC, anon, authenticated;
