-- ═════════════════════════════════════════════════════════════════════════
-- 057_get_my_active_plan_microstructure.sql
--
-- Planning Engine™ v2.0: la app móvil consume el plan activo vía la RPC
-- get_my_active_plan (solo lectura, RLS resuelve autorización — sin
-- SECURITY DEFINER). Se agrega warmup_desc/main_desc/cooldown_desc al
-- output para que mi-plan.tsx renderice la microestructura de sesión.
-- Requiere DROP + CREATE porque cambia la firma de RETURNS TABLE.
-- ═════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.get_my_active_plan(uuid);

CREATE FUNCTION public.get_my_active_plan(p_runner_id uuid DEFAULT fn_runner_id_for_user())
RETURNS TABLE(
  plan_id uuid, plan_title text, plan_goal text, coach_message text,
  version_tag text, delivered_at timestamp with time zone,
  week_id uuid, week_number integer, week_type text, week_focus text,
  weekly_km_target numeric,
  session_id uuid, day_of_week integer, session_type text, session_title text,
  session_desc text, duration_min integer, distance_km numeric,
  pace_target text, warmup_desc text, main_desc text, cooldown_desc text,
  intensity text, rpe_target integer,
  session_status text, completed_at timestamp with time zone,
  result_id uuid, actual_rpe smallint, pain_score smallint
)
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $function$
  SELECT
    p.id             AS plan_id,
    p.title          AS plan_title,
    p.goal           AS plan_goal,
    p.coach_message  AS coach_message,
    p.version_tag    AS version_tag,
    p.delivered_at   AS delivered_at,
    tw.id            AS week_id,
    tw.week_number   AS week_number,
    tw.week_type     AS week_type,
    tw.focus         AS week_focus,
    tw.weekly_km_target AS weekly_km_target,
    ts.id            AS session_id,
    ts.day_of_week   AS day_of_week,
    ts.session_type  AS session_type,
    ts.title         AS session_title,
    ts.description   AS session_desc,
    ts.duration_min  AS duration_min,
    ts.distance_km   AS distance_km,
    ts.pace_target   AS pace_target,
    ts.warmup_desc   AS warmup_desc,
    ts.main_desc     AS main_desc,
    ts.cooldown_desc AS cooldown_desc,
    ts.intensity     AS intensity,
    ts.rpe_target    AS rpe_target,
    ts.status        AS session_status,
    ts.completed_at  AS completed_at,
    sr.id            AS result_id,
    sr.actual_rpe    AS actual_rpe,
    sr.pain_score    AS pain_score
  FROM public.plans p
  JOIN public.training_weeks    tw ON tw.plan_id = p.id
  JOIN public.training_sessions ts ON ts.week_id = tw.id
  LEFT JOIN public.session_results sr ON sr.training_session_id = ts.id
  WHERE p.runner_id = p_runner_id
    AND p.status = 'active'
  ORDER BY tw.week_number, ts.day_of_week;
$function$;

GRANT EXECUTE ON FUNCTION public.get_my_active_plan(uuid) TO authenticated;
