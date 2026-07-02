-- ═════════════════════════════════════════════════════════════════════════
-- 043_restore_missing_rpcs.sql
--
-- Restaura 3 RPCs que el frontend (App) consumía y que no sobrevivieron a
-- la consolidación del esquema en producción. La corrección NO es cosmética:
-- `fn_complete_session_from_app` mueve una mutación clínica (session_results
-- + training_sessions) detrás de SECURITY DEFINER porque las políticas RLS
-- de esas tablas solo otorgan SELECT a la corredora dueña — un INSERT/UPDATE
-- directo desde el cliente móvil falla silenciosamente en producción.
--
-- `get_my_active_plan` y `get_social_feed_following` son de solo lectura y
-- se dejan con derechos de invocador (sin SECURITY DEFINER): las políticas
-- RLS existentes (*_runner_own, *_coach_*, follows "Ver follows") ya bastan
-- para autorizar el acceso correcto — añadir SECURITY DEFINER ahí sería
-- elevar privilegios sin necesidad.
-- ═════════════════════════════════════════════════════════════════════════

-- ── 1. get_my_active_plan ───────────────────────────────────────────────────
-- Aplana plans → training_weeks → training_sessions → session_results en
-- filas listas para hidratar en el cliente (una fila por sesión). Invoker
-- rights: RLS (plans_runner_own / training_weeks_runner_own /
-- training_sessions_runner_own / session_results_runner_own, más las
-- variantes *_coach_own y *_admin_all) decide qué filas son visibles.
CREATE OR REPLACE FUNCTION public.get_my_active_plan(
  p_runner_id uuid DEFAULT public.fn_runner_id_for_user()
)
RETURNS TABLE (
  plan_id          uuid,
  plan_title       text,
  plan_goal        text,
  coach_message    text,
  version_tag      text,
  delivered_at     timestamptz,
  week_id          uuid,
  week_number      integer,
  week_type        text,
  week_focus       text,
  weekly_km_target numeric,
  session_id       uuid,
  day_of_week      integer,
  session_type     text,
  session_title    text,
  session_desc     text,
  duration_min     integer,
  distance_km      numeric,
  pace_target      text,
  intensity        text,
  rpe_target       integer,
  session_status   text,
  completed_at     timestamptz,
  result_id        uuid,
  actual_rpe       smallint,
  pain_score       smallint
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

GRANT ALL ON FUNCTION public.get_my_active_plan(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_my_active_plan(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_my_active_plan(uuid) TO service_role;


-- ── 2. fn_complete_session_from_app ─────────────────────────────────────────
-- SECURITY DEFINER: session_results y training_sessions solo exponen SELECT
-- a la corredora dueña (session_results_runner_own / training_sessions_
-- runner_own son FOR SELECT). Esta función encapsula la escritura clínica
-- detrás de una verificación explícita de propiedad, saltando el RLS de
-- forma controlada — exactamente el patrón ya usado en redeem_reward() y
-- remove_training_leader() para mutaciones que el cliente no puede hacer
-- directo.
--
-- p_notes se añade sobre la firma mínima solicitada porque
-- SessionCompleteSheet.tsx ya captura texto libre de la corredora
-- (notes.trim() || null) y persistirlo es responsabilidad de este RPC;
-- omitirlo habría descartado en silencio un dato real de adherencia.
-- p_distance_km queda fuera: la UI actual siempre envía null (no hay
-- captura de distancia real en el flujo de "completar sesión" todavía).
CREATE OR REPLACE FUNCTION public.fn_complete_session_from_app(
  p_session_id      uuid,
  p_runner_id       uuid    DEFAULT public.fn_runner_id_for_user(),
  p_actual_duration integer DEFAULT NULL,
  p_actual_rpe      integer DEFAULT NULL,
  p_pain_score      integer DEFAULT 0,
  p_notes           text    DEFAULT NULL
)
RETURNS public.session_results
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_plan_id uuid;
  v_result  public.session_results%ROWTYPE;
BEGIN
  IF p_runner_id IS DISTINCT FROM public.fn_runner_id_for_user() THEN
    RAISE EXCEPTION 'No autorizada para completar sesiones de otra corredora';
  END IF;

  -- La sesión debe pertenecer a un plan activo de ESTA corredora.
  SELECT tw.plan_id INTO v_plan_id
  FROM public.training_sessions ts
  JOIN public.training_weeks tw ON tw.id = ts.week_id
  JOIN public.plans p           ON p.id = tw.plan_id
  WHERE ts.id = p_session_id
    AND p.runner_id = p_runner_id;

  IF v_plan_id IS NULL THEN
    RAISE EXCEPTION 'Sesión % no encontrada o no pertenece a esta corredora', p_session_id;
  END IF;

  INSERT INTO public.session_results (
    training_session_id, runner_id, plan_id,
    actual_duration_min, actual_rpe, pain_score, notes, source
  ) VALUES (
    p_session_id, p_runner_id, v_plan_id,
    p_actual_duration, p_actual_rpe, COALESCE(p_pain_score, 0), p_notes, 'app'
  )
  ON CONFLICT (training_session_id) DO UPDATE
    SET actual_duration_min = EXCLUDED.actual_duration_min,
        actual_rpe          = EXCLUDED.actual_rpe,
        pain_score          = EXCLUDED.pain_score,
        notes               = EXCLUDED.notes,
        completed_at        = now()
  RETURNING * INTO v_result;

  UPDATE public.training_sessions
  SET status = 'completed', completed_at = now()
  WHERE id = p_session_id;

  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.fn_complete_session_from_app(uuid, uuid, integer, integer, integer, text) TO anon;
GRANT ALL ON FUNCTION public.fn_complete_session_from_app(uuid, uuid, integer, integer, integer, text) TO authenticated;
GRANT ALL ON FUNCTION public.fn_complete_session_from_app(uuid, uuid, integer, integer, integer, text) TO service_role;


-- ── 3. get_social_feed_following ────────────────────────────────────────────
-- Mismo shape que get_social_feed(), pero acotado a las autoras que
-- p_user_id sigue. vw_social_feed ya resuelve visibilidad y bloqueo vía
-- auth.uid() (security_invoker=false en la vista, RLS de las tablas base
-- debajo); esta función solo añade el filtro del grafo `follows`, que es
-- de lectura pública ("Ver follows": auth.role() = 'authenticated'). No
-- requiere SECURITY DEFINER.
--
-- p_offset es un cursor de keyset (created_at), no un OFFSET numérico de
-- SQL — se conserva el nombre pedido, pero se implementa igual que
-- get_social_feed(p_cursor, ...) para evitar los saltos/duplicados típicos
-- de OFFSET paginado sobre un feed que cambia en caliente.
CREATE OR REPLACE FUNCTION public.get_social_feed_following(
  p_user_id uuid DEFAULT auth.uid(),
  p_limit   integer DEFAULT 20,
  p_offset  timestamptz DEFAULT now()
)
RETURNS SETOF public.vw_social_feed
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $function$
  SELECT vsf.*
  FROM public.vw_social_feed vsf
  WHERE vsf.created_at < p_offset
    AND vsf.author_id IN (
      SELECT f.following_id
      FROM public.follows f
      WHERE f.follower_id = p_user_id
    )
  ORDER BY vsf.created_at DESC
  LIMIT LEAST(p_limit, 50);
$function$;

GRANT ALL ON FUNCTION public.get_social_feed_following(uuid, integer, timestamptz) TO anon;
GRANT ALL ON FUNCTION public.get_social_feed_following(uuid, integer, timestamptz) TO authenticated;
GRANT ALL ON FUNCTION public.get_social_feed_following(uuid, integer, timestamptz) TO service_role;
