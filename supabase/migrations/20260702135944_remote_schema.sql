SET check_function_bodies = false;
DROP EXTENSION pg_net;
CREATE EXTENSION pg_cron WITH SCHEMA pg_catalog;
CREATE SCHEMA private AUTHORIZATION postgres;
CREATE TABLE private.config (key text NOT NULL, value text NOT NULL);
ALTER TABLE private.config ADD CONSTRAINT config_pkey PRIMARY KEY (key);
CREATE EXTENSION pg_net WITH SCHEMA public;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO service_role;
CREATE TYPE public.activity_feeling AS ENUM ('genial', 'bien', 'normal', 'cansada', 'dificil');
CREATE TYPE public.app_role AS ENUM ('runner', 'coach', 'moderator', 'admin', 'super_admin', 'pacer');
CREATE TYPE public.channel_type AS ENUM ('direct', 'group', 'community');
CREATE TYPE public.loyalty_tier AS ENUM ('starter', 'runner', 'elite', 'champion');
CREATE TYPE public.message_kind AS ENUM ('text', 'image', 'system');
CREATE TYPE public.notification_kind AS ENUM ('new_message', 'new_training', 'support_reaction', 'anti_abandonment', 'general');
CREATE TYPE public.participant_role AS ENUM ('owner', 'admin', 'member');
CREATE TYPE public.personal_training_status AS ENUM ('assigned', 'completed', 'skipped');
CREATE TYPE public.post_type AS ENUM ('free_run', 'training_completed', 'achievement', 'milestone', 'streak', 'text', 'photo', 'new_runner', 'personal_training_completed');
CREATE TYPE public.post_visibility AS ENUM ('public', 'followers', 'private');
CREATE TYPE public.reaction_kind AS ENUM ('apoyo', 'fuerza', 'celebro', 'orgullo');
CREATE TYPE public.redemption_status AS ENUM ('pending', 'approved', 'delivered', 'rejected', 'cancelled');
CREATE TYPE public.referral_status AS ENUM ('pending', 'registered', 'qualified');
CREATE TYPE public.registration_status AS ENUM ('confirmed', 'cancelled', 'waitlist');
CREATE TYPE public.report_reason AS ENUM ('acoso', 'spam', 'contenido_inapropiado', 'discurso_odio', 'suplantacion', 'otro');
CREATE TYPE public.report_status AS ENUM ('pendiente', 'en_revision', 'resuelto', 'descartado');
CREATE TYPE public.report_target AS ENUM ('post', 'message', 'profile');
CREATE TYPE public.running_level AS ENUM ('principiante', 'intermedio', 'avanzada');
CREATE TYPE public.training_feeling AS ENUM ('genial', 'bien', 'normal', 'cansada', 'dificil');
CREATE TYPE public.training_status AS ENUM ('draft', 'published', 'cancelled', 'completed');
CREATE TYPE public.training_type AS ENUM ('rodaje', 'intervalos', 'fondo', 'fuerza', 'movilidad', 'recuperacion');
CREATE SEQUENCE public.ai_request_log_id_seq;
CREATE FUNCTION public.add_training_leader(p_training_id uuid, p_user_id uuid, p_role text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO training_leaders (training_id, user_id, role)
  VALUES (p_training_id, p_user_id, p_role)
  ON CONFLICT (training_id, user_id) DO UPDATE SET role = p_role;
END;
$function$;
GRANT ALL ON FUNCTION public.add_training_leader(uuid, uuid, text) TO anon;
GRANT ALL ON FUNCTION public.add_training_leader(uuid, uuid, text) TO authenticated;
GRANT ALL ON FUNCTION public.add_training_leader(uuid, uuid, text) TO service_role;
CREATE FUNCTION public.assign_super_admin_on_signup()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF EXISTS (
    SELECT 1 FROM super_admin_emails
    WHERE lower(email) = lower(NEW.email)
  ) THEN
    INSERT INTO user_roles (user_id, role)
    VALUES (NEW.id, 'super_admin')
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$function$;
CREATE TRIGGER trg_assign_super_admin AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.assign_super_admin_on_signup();
GRANT ALL ON FUNCTION public.assign_super_admin_on_signup() TO anon;
GRANT ALL ON FUNCTION public.assign_super_admin_on_signup() TO authenticated;
GRANT ALL ON FUNCTION public.assign_super_admin_on_signup() TO service_role;
CREATE FUNCTION public.assign_training_coach(p_training_id uuid, p_coach_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF p_coach_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = p_coach_id AND role IN ('coach','admin','super_admin')
    ) THEN
      RAISE EXCEPTION 'El usuario no tiene rol de coach o administradora';
    END IF;
  END IF;
  UPDATE trainings SET coach_id = p_coach_id WHERE id = p_training_id;
END;
$function$;
GRANT ALL ON FUNCTION public.assign_training_coach(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.assign_training_coach(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.assign_training_coach(uuid, uuid) TO service_role;
CREATE FUNCTION public.assign_training_pacer(p_training_id uuid, p_pacer_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF p_pacer_user_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = p_pacer_user_id AND role IN ('admin','super_admin')
    ) AND NOT EXISTS (
      SELECT 1 FROM registrations
      WHERE training_id = p_training_id
        AND user_id = p_pacer_user_id AND status = 'confirmed'
    ) THEN
      RAISE EXCEPTION 'Debe ser administradora o estar inscrita en el entrenamiento';
    END IF;
  END IF;
  UPDATE trainings SET pacer_user_id = p_pacer_user_id WHERE id = p_training_id;
END;
$function$;
GRANT ALL ON FUNCTION public.assign_training_pacer(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.assign_training_pacer(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.assign_training_pacer(uuid, uuid) TO service_role;
CREATE FUNCTION public.assign_winner_code(p_winner_id uuid, p_event_id uuid, p_distancia text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_codigo TEXT;
BEGIN
  IF NOT public.fn_is_admin_or_super() THEN
    RAISE EXCEPTION 'assign_winner_code: acceso denegado';
  END IF;

  WITH selected AS (
    SELECT id, codigo FROM public.event_code_pool
    WHERE  sponsor_event_id = p_event_id
      AND  tipo_beneficio   = 'entrada'
      AND  usado            = false
      AND  (p_distancia IS NULL OR distancia = p_distancia OR distancia IS NULL)
    ORDER BY CASE WHEN distancia = p_distancia THEN 0 ELSE 1 END, created_at ASC
    LIMIT 1 FOR UPDATE SKIP LOCKED
  ),
  marked AS (
    UPDATE public.event_code_pool SET usado = true
    FROM   selected WHERE event_code_pool.id = selected.id
    RETURNING event_code_pool.codigo
  )
  SELECT codigo INTO v_codigo FROM marked;

  IF v_codigo IS NULL THEN RETURN NULL; END IF;

  UPDATE public.event_winners SET codigo = v_codigo WHERE id = p_winner_id;
  RETURN v_codigo;
END;
$function$;
GRANT ALL ON FUNCTION public.assign_winner_code(uuid, uuid, text) TO anon;
GRANT ALL ON FUNCTION public.assign_winner_code(uuid, uuid, text) TO authenticated;
GRANT ALL ON FUNCTION public.assign_winner_code(uuid, uuid, text) TO service_role;
CREATE FUNCTION public.auto_enroll_community()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO channel_participants (channel_id, user_id, role, joined_at, last_read_at)
  VALUES (
    'c0ffee00-0000-4000-a000-000000000001',
    NEW.id,
    'member',
    NOW(),
    NOW()
  )
  ON CONFLICT (channel_id, user_id) DO NOTHING;
  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.auto_enroll_community() TO anon;
GRANT ALL ON FUNCTION public.auto_enroll_community() TO authenticated;
GRANT ALL ON FUNCTION public.auto_enroll_community() TO service_role;
CREATE FUNCTION public.award_points_by_rule(p_user_id uuid, p_event_type text, p_reference uuid DEFAULT NULL::uuid, p_custom_desc text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_rule  point_rules%ROWTYPE;
  v_pts   INT;
  v_mult  NUMERIC := 1.0;
  v_bonus INT := 0;
BEGIN
  IF NOT can_earn_points(p_user_id, p_event_type, p_reference) THEN
    RETURN FALSE;
  END IF;

  SELECT * INTO v_rule FROM point_rules WHERE event_type = p_event_type;

  SELECT COALESCE(MAX(multiplier),1.0), COALESCE(SUM(bonus_points),0)
    INTO v_mult, v_bonus
    FROM point_campaigns
   WHERE is_active
     AND NOW() BETWEEN starts_at AND ends_at
     AND (applies_to_event IS NULL OR applies_to_event = p_event_type);

  v_pts := ROUND(v_rule.points * v_mult)::INT + v_bonus;
  IF v_pts = 0 THEN RETURN FALSE; END IF;

  PERFORM award_points(p_user_id, v_pts, p_event_type, p_reference,
                       COALESCE(p_custom_desc, v_rule.description));
  RETURN TRUE;
END;
$function$;
GRANT ALL ON FUNCTION public.award_points_by_rule(uuid, text, uuid, text) TO anon;
GRANT ALL ON FUNCTION public.award_points_by_rule(uuid, text, uuid, text) TO authenticated;
GRANT ALL ON FUNCTION public.award_points_by_rule(uuid, text, uuid, text) TO service_role;
CREATE FUNCTION public.award_points(p_user_id uuid, p_points integer, p_event_type text, p_reference uuid, p_description text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO point_transactions (user_id, points, event_type, reference_id, description)
  VALUES (p_user_id, p_points, p_event_type, p_reference, p_description);

  UPDATE user_profiles
  SET total_points       = total_points + p_points,
      points_updated_at  = NOW()
  WHERE id = p_user_id;
END;
$function$;
GRANT ALL ON FUNCTION public.award_points(uuid, integer, text, uuid, text) TO anon;
GRANT ALL ON FUNCTION public.award_points(uuid, integer, text, uuid, text) TO authenticated;
GRANT ALL ON FUNCTION public.award_points(uuid, integer, text, uuid, text) TO service_role;
CREATE FUNCTION public.award_streak_bonus_if_needed(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_streak INT;
BEGIN
  v_streak := get_current_streak(p_user_id);

  IF v_streak >= 4 AND NOT EXISTS (
    SELECT 1 FROM point_transactions
    WHERE user_id = p_user_id AND event_type = 'streak_bonus_4'
  ) THEN
    PERFORM award_points(p_user_id, 200, 'streak_bonus_4', NULL, '¡Racha de 4 semanas! 🔥');
  END IF;

  IF v_streak >= 8 AND NOT EXISTS (
    SELECT 1 FROM point_transactions
    WHERE user_id = p_user_id AND event_type = 'streak_bonus_8'
  ) THEN
    PERFORM award_points(p_user_id, 400, 'streak_bonus_8', NULL, '¡Racha de 8 semanas! 🔥🔥');
  END IF;

  IF v_streak >= 12 AND NOT EXISTS (
    SELECT 1 FROM point_transactions
    WHERE user_id = p_user_id AND event_type = 'streak_bonus_12'
  ) THEN
    PERFORM award_points(p_user_id, 800, 'streak_bonus_12', NULL, '¡12 semanas consecutivas — Leyenda WSR! 👑');
  END IF;
END;
$function$;
GRANT ALL ON FUNCTION public.award_streak_bonus_if_needed(uuid) TO anon;
GRANT ALL ON FUNCTION public.award_streak_bonus_if_needed(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.award_streak_bonus_if_needed(uuid) TO service_role;
CREATE FUNCTION public.block_user(p_target uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No autenticada';
  END IF;
  IF p_target IS NULL OR p_target = v_uid THEN
    RAISE EXCEPTION 'Usuaria inválida';
  END IF;

  INSERT INTO blocked_users (blocker_id, blocked_id)
  VALUES (v_uid, p_target)
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;
END;
$function$;
GRANT ALL ON FUNCTION public.block_user(uuid) TO anon;
GRANT ALL ON FUNCTION public.block_user(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.block_user(uuid) TO service_role;
CREATE FUNCTION public.bump_channel_on_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE channels SET last_message_at = NEW.created_at, updated_at = NOW() WHERE id = NEW.channel_id;
  RETURN NEW;
END; $function$;
GRANT ALL ON FUNCTION public.bump_channel_on_message() TO anon;
GRANT ALL ON FUNCTION public.bump_channel_on_message() TO authenticated;
GRANT ALL ON FUNCTION public.bump_channel_on_message() TO service_role;
CREATE FUNCTION public.calculate_tier(p_points integer)
 RETURNS public.loyalty_tier
 LANGUAGE sql
 STABLE
AS $function$
  SELECT tier FROM loyalty_tiers
  WHERE p_points >= min_points AND (max_points IS NULL OR p_points <= max_points)
  ORDER BY sort_order DESC
  LIMIT 1;
$function$;
GRANT ALL ON FUNCTION public.calculate_tier(integer) TO anon;
GRANT ALL ON FUNCTION public.calculate_tier(integer) TO authenticated;
GRANT ALL ON FUNCTION public.calculate_tier(integer) TO service_role;
CREATE FUNCTION public.can_earn_points(p_user_id uuid, p_event_type text, p_reference uuid DEFAULT NULL::uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_rule  point_rules%ROWTYPE;
  v_count INT;
  v_since TIMESTAMPTZ;
BEGIN
  SELECT * INTO v_rule FROM point_rules WHERE event_type = p_event_type AND is_active;
  IF NOT FOUND THEN RETURN FALSE; END IF;
  IF v_rule.max_per_period IS NULL THEN RETURN TRUE; END IF;

  IF v_rule.period IN ('race','product','use','survey') THEN
    RETURN NOT EXISTS (
      SELECT 1 FROM point_transactions
      WHERE user_id = p_user_id AND event_type = p_event_type
        AND (p_reference IS NULL OR reference_id = p_reference)
    );
  END IF;

  v_since := CASE v_rule.period
    WHEN 'week'  THEN date_trunc('week',  NOW())
    WHEN 'month' THEN date_trunc('month', NOW())
    WHEN 'year'  THEN date_trunc('year',  NOW())
    ELSE NULL
  END;

  SELECT COUNT(*) INTO v_count FROM point_transactions
  WHERE user_id = p_user_id AND event_type = p_event_type
    AND (v_since IS NULL OR created_at >= v_since);

  RETURN v_count < v_rule.max_per_period;
END;
$function$;
GRANT ALL ON FUNCTION public.can_earn_points(uuid, text, uuid) TO anon;
GRANT ALL ON FUNCTION public.can_earn_points(uuid, text, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.can_earn_points(uuid, text, uuid) TO service_role;
CREATE FUNCTION public.channel_has_block(p_channel_id uuid, p_me uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM channel_participants cp
    JOIN channels c ON c.id = cp.channel_id
    WHERE cp.channel_id = p_channel_id
      AND c.type = 'direct'                 -- solo DMs; grupos/comunidad nunca se gatean
      AND cp.user_id <> p_me
      AND is_blocked_between(cp.user_id, p_me)
  );
$function$;
GRANT ALL ON FUNCTION public.channel_has_block(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.channel_has_block(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.channel_has_block(uuid, uuid) TO service_role;
CREATE FUNCTION public.check_ai_rate_limit(p_user_id uuid, p_limit integer DEFAULT 20, p_window_minutes integer DEFAULT 60)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_count       INTEGER;
  v_window_start TIMESTAMPTZ;
BEGIN
  v_window_start := NOW() - (p_window_minutes || ' minutes')::INTERVAL;

  SELECT COUNT(*) INTO v_count
  FROM public.ai_request_log
  WHERE user_id      = p_user_id
    AND requested_at >= v_window_start;

  IF v_count >= p_limit THEN
    RETURN FALSE;
  END IF;

  INSERT INTO public.ai_request_log (user_id) VALUES (p_user_id);
  RETURN TRUE;
END;
$function$;
GRANT ALL ON FUNCTION public.check_ai_rate_limit(uuid, integer, integer) TO anon;
GRANT ALL ON FUNCTION public.check_ai_rate_limit(uuid, integer, integer) TO authenticated;
GRANT ALL ON FUNCTION public.check_ai_rate_limit(uuid, integer, integer) TO service_role;
CREATE FUNCTION public.create_direct_channel(p_other_user uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid     UUID := auth.uid();
  v_channel UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No autenticada';
  END IF;
  IF p_other_user IS NULL OR p_other_user = v_uid THEN
    RAISE EXCEPTION 'Destinataria inválida';
  END IF;

  -- Seguridad: no se permite abrir un DM si hay bloqueo en cualquier dirección.
  IF is_blocked_between(p_other_user, v_uid) THEN
    RAISE EXCEPTION 'No es posible iniciar una conversación con esta usuaria';
  END IF;

  -- ¿Ya existe un DM exacto entre las dos?
  SELECT c.id INTO v_channel
  FROM channels c
  WHERE c.type = 'direct'
    AND EXISTS (SELECT 1 FROM channel_participants p WHERE p.channel_id = c.id AND p.user_id = v_uid)
    AND EXISTS (SELECT 1 FROM channel_participants p WHERE p.channel_id = c.id AND p.user_id = p_other_user)
    AND (SELECT COUNT(*) FROM channel_participants p WHERE p.channel_id = c.id) = 2
  LIMIT 1;

  IF v_channel IS NOT NULL THEN
    RETURN v_channel;
  END IF;

  INSERT INTO channels (type, created_by)
  VALUES ('direct', v_uid)
  RETURNING id INTO v_channel;

  INSERT INTO channel_participants (channel_id, user_id, role) VALUES
    (v_channel, v_uid,        'owner'),
    (v_channel, p_other_user, 'member');

  RETURN v_channel;
END;
$function$;
GRANT ALL ON FUNCTION public.create_direct_channel(uuid) TO anon;
GRANT ALL ON FUNCTION public.create_direct_channel(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.create_direct_channel(uuid) TO service_role;
CREATE FUNCTION public.create_group_channel(p_name text, p_description text DEFAULT NULL::text, p_members uuid[] DEFAULT '{}'::uuid[])
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid UUID := auth.uid(); v_channel UUID; v_member UUID;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'No autenticada'; END IF;
  IF p_name IS NULL OR length(trim(p_name)) = 0 THEN RAISE EXCEPTION 'El grupo necesita un nombre'; END IF;

  INSERT INTO channels (type, name, description, created_by)
  VALUES ('group', trim(p_name), p_description, v_uid) RETURNING id INTO v_channel;
  INSERT INTO channel_participants (channel_id, user_id, role) VALUES (v_channel, v_uid, 'owner');

  FOREACH v_member IN ARRAY p_members LOOP
    IF v_member <> v_uid THEN
      INSERT INTO channel_participants (channel_id, user_id, role)
      VALUES (v_channel, v_member, 'member') ON CONFLICT (channel_id, user_id) DO NOTHING;
    END IF;
  END LOOP;
  RETURN v_channel;
END; $function$;
GRANT ALL ON FUNCTION public.create_group_channel(text, text, uuid[]) TO anon;
GRANT ALL ON FUNCTION public.create_group_channel(text, text, uuid[]) TO authenticated;
GRANT ALL ON FUNCTION public.create_group_channel(text, text, uuid[]) TO service_role;
CREATE FUNCTION public.evaluate_achievements(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_sessions INT;
  v_streak   INT;
  v_ach      RECORD;
BEGIN
  v_sessions := get_completed_sessions(p_user_id);
  v_streak   := get_current_streak(p_user_id);

  FOR v_ach IN
    SELECT * FROM achievements
    WHERE id NOT IN (
      SELECT achievement_id FROM user_achievements WHERE user_id = p_user_id
    )
  LOOP
    IF (v_ach.required_sessions IS NOT NULL AND v_sessions >= v_ach.required_sessions)
    OR (v_ach.required_streak IS NOT NULL AND v_streak >= v_ach.required_streak)
    THEN
      INSERT INTO user_achievements (user_id, achievement_id)
      VALUES (p_user_id, v_ach.id)
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
END;
$function$;
GRANT ALL ON FUNCTION public.evaluate_achievements(uuid) TO anon;
GRANT ALL ON FUNCTION public.evaluate_achievements(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.evaluate_achievements(uuid) TO service_role;
CREATE FUNCTION public.find_app_user_by_email(p_email text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_uid UUID;
BEGIN
  IF NOT (has_role(auth.uid(), 'admin') OR has_role(auth.uid(), 'coach')) THEN
    RETURN NULL;
  END IF;
  SELECT id INTO v_uid FROM auth.users
  WHERE lower(email) = lower(p_email)
  LIMIT 1;
  RETURN v_uid;
END;
$function$;
GRANT ALL ON FUNCTION public.find_app_user_by_email(text) TO anon;
GRANT ALL ON FUNCTION public.find_app_user_by_email(text) TO authenticated;
GRANT ALL ON FUNCTION public.find_app_user_by_email(text) TO service_role;
CREATE FUNCTION public.finish_activity(p_distance_m integer, p_duration_s integer, p_started_at timestamp with time zone, p_ended_at timestamp with time zone, p_polyline text DEFAULT NULL::text, p_feeling public.activity_feeling DEFAULT NULL::public.activity_feeling, p_title text DEFAULT 'Salí a correr'::text, p_notes text DEFAULT NULL::text, p_is_shared boolean DEFAULT false, p_visibility text DEFAULT 'followers'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid      UUID := auth.uid();
  v_activity UUID;
  v_pace     INT;
  v_vis      TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No autenticada';
  END IF;

  v_vis := CASE
    WHEN p_visibility IN ('public', 'followers', 'private') THEN p_visibility
    ELSE 'followers'
  END;

  v_pace := CASE
    WHEN p_distance_m > 0
      THEN ROUND(p_duration_s::NUMERIC / (p_distance_m::NUMERIC / 1000))::INT
    ELSE NULL
  END;

  INSERT INTO activities (
    user_id, started_at, ended_at,
    distance_m, duration_s, avg_pace_s_per_km,
    route_polyline, feeling, title, notes,
    is_shared, visibility
  ) VALUES (
    v_uid, p_started_at, p_ended_at,
    p_distance_m, p_duration_s, v_pace,
    p_polyline, p_feeling, p_title, p_notes,
    p_is_shared, v_vis
  )
  RETURNING id INTO v_activity;

  -- NO se otorgan puntos por salidas libres (decisión de producto, ver 012).
  -- Los puntos son exclusivos de training_registrations (entrenamientos WSR).

  PERFORM evaluate_achievements(v_uid);

  IF p_is_shared THEN
    INSERT INTO feed_posts (author_id, post_type, ref_id, body, visibility)
    VALUES (v_uid, 'free_run', v_activity, p_notes, v_vis::post_visibility);
  END IF;

  RETURN v_activity;
END;
$function$;
GRANT ALL ON FUNCTION public.finish_activity(integer, integer, timestamp with time zone, timestamp with time zone, text, public.activity_feeling, text, text, boolean, text) TO anon;
GRANT ALL ON FUNCTION public.finish_activity(integer, integer, timestamp with time zone, timestamp with time zone, text, public.activity_feeling, text, text, boolean, text) TO authenticated;
GRANT ALL ON FUNCTION public.finish_activity(integer, integer, timestamp with time zone, timestamp with time zone, text, public.activity_feeling, text, text, boolean, text) TO service_role;
CREATE FUNCTION public.fn_check_in_adaptation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_compliance NUMERIC;
BEGIN
  v_compliance := (NEW.sessions_completed::numeric / NEW.sessions_planned::numeric) * 100;

  IF NEW.pain >= 6 THEN
    INSERT INTO public.health_alerts (runner_id, check_in_id, alert_type, severity, reason)
    VALUES (
      NEW.runner_id, NEW.id, 'dolor',
      CASE WHEN NEW.pain >= 8 THEN 'roja' ELSE 'naranja' END,
      'Dolor reportado: ' || NEW.pain || '/10'
        || COALESCE(' — ' || NULLIF(TRIM(NEW.pain_location), ''), '')
    );
  END IF;

  IF v_compliance < 50 THEN
    INSERT INTO public.health_alerts (runner_id, check_in_id, alert_type, severity, reason)
    VALUES (
      NEW.runner_id, NEW.id, 'cumplimiento',
      CASE WHEN v_compliance < 25 THEN 'roja' ELSE 'naranja' END,
      'Cumplimiento bajo: ' || NEW.sessions_completed || ' de ' || NEW.sessions_planned
        || ' sesiones (' || ROUND(v_compliance) || '%)'
    );
  END IF;

  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.fn_check_in_adaptation() TO anon;
GRANT ALL ON FUNCTION public.fn_check_in_adaptation() TO authenticated;
GRANT ALL ON FUNCTION public.fn_check_in_adaptation() TO service_role;
CREATE FUNCTION public.fn_forget_runner(p_runner_id uuid, p_reason text DEFAULT 'Solicitud de supresión Art. 4 Ley 21.719'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_email      TEXT;
  v_deleted_at TIMESTAMPTZ;
BEGIN
  IF NOT public.fn_is_admin_or_super() THEN
    RAISE EXCEPTION 'Acceso denegado: se requiere rol de administrador (Ley 21.719 Art. 4).'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT email
    INTO v_email
    FROM public.runners
   WHERE id = p_runner_id;

  IF v_email IS NULL THEN
    RETURN jsonb_build_object(
      'ok',        false,
      'error',     'runner_not_found',
      'runner_id', p_runner_id
    );
  END IF;

  -- 1. Purgar tokens (sin FK a runners, vinculados solo por email)
  DELETE FROM public.anamnesis_tokens
   WHERE runner_email = v_email;

  -- 2. Borrar anamnesis explícitamente para trazabilidad WAL pre-cascade
  DELETE FROM public.anamnesis
   WHERE runner_id    = p_runner_id
      OR runner_email = v_email;

  -- 3. Borrar runner → CASCADE elimina plans, check_ins, health_alerts,
  --    scores, adherence_scores, session_results y la cadena completa
  DELETE FROM public.runners
   WHERE id = p_runner_id;

  -- 4. Log de auditoría (sin PII — solo UUID)
  v_deleted_at := now();

  INSERT INTO public.gdpr_deletion_log (runner_id, deleted_at, requested_by, reason)
  VALUES (p_runner_id, v_deleted_at, auth.uid(), p_reason);

  RETURN jsonb_build_object(
    'ok',         true,
    'deleted_at', v_deleted_at,
    'runner_id',  p_runner_id
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'ok',        false,
      'error',     SQLERRM,
      'sqlstate',  SQLSTATE,
      'runner_id', p_runner_id
    );
END;
$function$;
COMMENT ON FUNCTION public.fn_forget_runner(uuid,text) IS 'Derecho al Olvido (Art. 4 Ley 21.719): borra atómicamente todos los datos personales de una titular. SECURITY DEFINER. Guard: fn_is_admin_or_super(). Retorna JSONB {ok, deleted_at, runner_id} o {ok:false, error, sqlstate}.';
GRANT ALL ON FUNCTION public.fn_forget_runner(uuid, text) TO anon;
GRANT ALL ON FUNCTION public.fn_forget_runner(uuid, text) TO authenticated;
GRANT ALL ON FUNCTION public.fn_forget_runner(uuid, text) TO service_role;
CREATE FUNCTION public.fn_is_admin_or_super()
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid()
      AND role IN ('admin', 'super_admin')
  );
$function$;
GRANT ALL ON FUNCTION public.fn_is_admin_or_super() TO anon;
GRANT ALL ON FUNCTION public.fn_is_admin_or_super() TO authenticated;
GRANT ALL ON FUNCTION public.fn_is_admin_or_super() TO service_role;
CREATE FUNCTION public.fn_is_coach()
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid()
      AND role = 'coach'
  );
$function$;
GRANT ALL ON FUNCTION public.fn_is_coach() TO anon;
GRANT ALL ON FUNCTION public.fn_is_coach() TO authenticated;
GRANT ALL ON FUNCTION public.fn_is_coach() TO service_role;
CREATE FUNCTION public.fn_runner_id_for_user()
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT id FROM public.runners
  WHERE user_id = auth.uid()
  LIMIT 1;
$function$;
GRANT ALL ON FUNCTION public.fn_runner_id_for_user() TO anon;
GRANT ALL ON FUNCTION public.fn_runner_id_for_user() TO authenticated;
GRANT ALL ON FUNCTION public.fn_runner_id_for_user() TO service_role;
CREATE FUNCTION public.fn_set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.fn_set_updated_at() TO anon;
GRANT ALL ON FUNCTION public.fn_set_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.fn_set_updated_at() TO service_role;
CREATE FUNCTION public.fn_submit_check_in(p_email text, p_sessions_planned integer, p_sessions_completed integer, p_energy integer, p_sleep_quality integer, p_motivation integer, p_pain integer, p_pain_location text DEFAULT NULL::text, p_life_changes boolean DEFAULT false, p_life_changes_detail text DEFAULT NULL::text, p_comments text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_runner_id   UUID;
  v_nombre      TEXT;
  v_plan_id     UUID;
  v_check_in_id UUID;
  v_week_start  DATE := (date_trunc('week', (now() AT TIME ZONE 'America/Santiago')))::date;
BEGIN
  SELECT id, nombre_apellido INTO v_runner_id, v_nombre
  FROM public.runners
  WHERE lower(email) = lower(trim(p_email))
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_runner_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'runner_not_found');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.plan_check_ins
    WHERE runner_id = v_runner_id AND week_start = v_week_start
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'already_submitted', 'nombre', v_nombre);
  END IF;

  SELECT id INTO v_plan_id
  FROM public.plans
  WHERE runner_id = v_runner_id AND status = 'active'
  ORDER BY created_at DESC
  LIMIT 1;

  INSERT INTO public.plan_check_ins (
    runner_id, plan_id, week_start,
    sessions_planned, sessions_completed,
    energy, sleep_quality, motivation,
    pain, pain_location,
    life_changes, life_changes_detail, comments
  ) VALUES (
    v_runner_id, v_plan_id, v_week_start,
    p_sessions_planned, p_sessions_completed,
    p_energy, p_sleep_quality, p_motivation,
    p_pain, NULLIF(TRIM(COALESCE(p_pain_location, '')), ''),
    COALESCE(p_life_changes, false),
    NULLIF(TRIM(COALESCE(p_life_changes_detail, '')), ''),
    NULLIF(TRIM(COALESCE(p_comments, '')), '')
  )
  RETURNING id INTO v_check_in_id;

  RETURN jsonb_build_object(
    'ok', true,
    'check_in_id', v_check_in_id,
    'nombre', v_nombre,
    'alert', EXISTS (SELECT 1 FROM public.health_alerts WHERE check_in_id = v_check_in_id)
  );
END;
$function$;
GRANT ALL ON FUNCTION public.fn_submit_check_in(text, integer, integer, integer, integer, integer, integer, text, boolean, text, text) TO anon;
GRANT ALL ON FUNCTION public.fn_submit_check_in(text, integer, integer, integer, integer, integer, integer, text, boolean, text, text) TO authenticated;
GRANT ALL ON FUNCTION public.fn_submit_check_in(text, integer, integer, integer, integer, integer, integer, text, boolean, text, text) TO service_role;
CREATE FUNCTION public.fn_validate_anamnesis_token(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id            UUID;
  v_runner_email  TEXT;
  v_runner_nombre TEXT;
  v_expires_at    TIMESTAMPTZ;
  v_used_at       TIMESTAMPTZ;
BEGIN
  SELECT id, runner_email, runner_nombre, expires_at, used_at
    INTO v_id, v_runner_email, v_runner_nombre, v_expires_at, v_used_at
    FROM public.anamnesis_tokens
   WHERE token = p_token
   LIMIT 1;

  IF v_id IS NULL THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'not_found');
  END IF;

  IF v_used_at IS NOT NULL THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'already_used');
  END IF;

  IF v_expires_at < now() THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'expired');
  END IF;

  RETURN jsonb_build_object(
    'valid',         true,
    'id',            v_id,
    'runner_nombre', v_runner_nombre,
    'runner_email',  v_runner_email
  );
END;
$function$;
GRANT ALL ON FUNCTION public.fn_validate_anamnesis_token(text) TO anon;
GRANT ALL ON FUNCTION public.fn_validate_anamnesis_token(text) TO authenticated;
GRANT ALL ON FUNCTION public.fn_validate_anamnesis_token(text) TO service_role;
CREATE FUNCTION public.get_active_checkins(p_training_id uuid)
 RETURNS TABLE(user_id uuid, full_name text, avatar_url text, checked_in_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    tc.user_id,
    pp.full_name,
    pp.avatar_url,
    tc.checked_in_at
  FROM training_checkins tc
  JOIN public_profiles pp ON pp.id = tc.user_id
  WHERE tc.training_id = p_training_id
    AND tc.checked_out_at IS NULL
    AND has_role(auth.uid(), 'admin')
  ORDER BY tc.checked_in_at;
$function$;
GRANT ALL ON FUNCTION public.get_active_checkins(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_active_checkins(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_active_checkins(uuid) TO service_role;
CREATE FUNCTION public.get_coach_options()
 RETURNS TABLE(user_id uuid, full_name text, label text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT DISTINCT ON (u.id)
    u.id,
    COALESCE(NULLIF(TRIM(u.raw_user_meta_data->>'full_name'), ''), initcap(split_part(u.email,'@',1))) AS full_name,
    CASE WHEN ur.role = 'coach' THEN 'Coach' ELSE 'Admin' END AS label
  FROM auth.users u
  JOIN public.user_roles ur ON ur.user_id = u.id
  WHERE ur.role IN ('admin','super_admin','coach')
  ORDER BY u.id,
    CASE ur.role WHEN 'coach' THEN 0 WHEN 'super_admin' THEN 1 ELSE 2 END;
$function$;
GRANT ALL ON FUNCTION public.get_coach_options() TO anon;
GRANT ALL ON FUNCTION public.get_coach_options() TO authenticated;
GRANT ALL ON FUNCTION public.get_coach_options() TO service_role;
CREATE FUNCTION public.get_comeback_info()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_user_id        UUID := auth.uid();
  v_profile        RECORD;
  v_current_streak SMALLINT;
  v_days_absent    NUMERIC;
BEGIN
  SELECT last_activity_at, max_streak_weeks, last_streak_weeks
  INTO v_profile
  FROM user_profiles
  WHERE id = v_user_id;

  SELECT get_current_streak(v_user_id) INTO v_current_streak;
  v_days_absent := EXTRACT(EPOCH FROM (NOW() - v_profile.last_activity_at)) / 86400.0;

  RETURN json_build_object(
    'days_absent',        FLOOR(v_days_absent)::INT,
    'current_streak',     v_current_streak,
    'last_streak_weeks',  COALESCE(v_profile.last_streak_weeks, 0),
    'max_streak_weeks',   COALESCE(v_profile.max_streak_weeks, 0)
  );
END;
$function$;
GRANT ALL ON FUNCTION public.get_comeback_info() TO anon;
GRANT ALL ON FUNCTION public.get_comeback_info() TO authenticated;
GRANT ALL ON FUNCTION public.get_comeback_info() TO service_role;
CREATE FUNCTION public.get_completed_sessions(p_user_id uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COUNT(*)::INT
  FROM registrations
  WHERE user_id = p_user_id
    AND status = 'confirmed';
$function$;
GRANT ALL ON FUNCTION public.get_completed_sessions(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_completed_sessions(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_completed_sessions(uuid) TO service_role;
CREATE FUNCTION public.get_conversation_messages(p_conversation_id uuid, p_limit integer DEFAULT 30, p_before timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS TABLE(id uuid, conversation_id uuid, sender_id uuid, body text, kind text, created_at timestamp with time zone, edited_at timestamp with time zone, deleted_at timestamp with time zone)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT
    m.id,
    m.channel_id   AS conversation_id,
    m.sender_id,
    m.body,
    m.kind::TEXT,
    m.created_at,
    m.edited_at,
    m.deleted_at
  FROM messages m
  WHERE m.channel_id = p_conversation_id
    AND (p_before IS NULL OR m.created_at < p_before)
  ORDER BY m.created_at DESC
  LIMIT LEAST(p_limit, 50);
$function$;
GRANT ALL ON FUNCTION public.get_conversation_messages(uuid, integer, timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.get_conversation_messages(uuid, integer, timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.get_conversation_messages(uuid, integer, timestamp with time zone) TO service_role;
CREATE FUNCTION public.get_conversation_messages(p_channel_id uuid, p_cursor timestamp with time zone DEFAULT now(), p_limit integer DEFAULT 50)
 RETURNS TABLE(id uuid, channel_id uuid, sender_id uuid, body text, kind text, created_at timestamp with time zone, edited_at timestamp with time zone, deleted_at timestamp with time zone, sender_name text, sender_avatar text, sender_tier text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT is_channel_participant(p_channel_id, auth.uid()) THEN
    RAISE EXCEPTION 'No eres participante de este canal';
  END IF;

  RETURN QUERY
  SELECT
    m.id,
    m.channel_id,
    m.sender_id,
    m.body,
    m.kind::TEXT,
    m.created_at,
    m.edited_at,
    m.deleted_at,
    pp.full_name          AS sender_name,
    pp.avatar_url         AS sender_avatar,
    pp.current_tier::TEXT AS sender_tier
  FROM   messages m
  LEFT   JOIN public_profiles pp ON pp.id = m.sender_id
  WHERE  m.channel_id = p_channel_id
    AND  m.created_at < p_cursor
  ORDER  BY m.created_at DESC
  LIMIT  LEAST(p_limit, 100);
END;
$function$;
GRANT ALL ON FUNCTION public.get_conversation_messages(uuid, timestamp with time zone, integer) TO anon;
GRANT ALL ON FUNCTION public.get_conversation_messages(uuid, timestamp with time zone, integer) TO authenticated;
GRANT ALL ON FUNCTION public.get_conversation_messages(uuid, timestamp with time zone, integer) TO service_role;
CREATE FUNCTION public.get_current_streak(p_user_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_streak INT := 0;
  v_week   TEXT;
  v_prev   TEXT := NULL;
BEGIN
  FOR v_week IN
    SELECT DISTINCT TO_CHAR(DATE_TRUNC('week', t.scheduled_at), 'IYYY-IW') AS iso_week
    FROM registrations r
    JOIN trainings t ON t.id = r.training_id
    WHERE r.user_id = p_user_id
      AND r.status = 'confirmed'
      AND t.scheduled_at <= NOW()
    ORDER BY iso_week DESC
  LOOP
    IF v_prev IS NULL THEN
      -- Primera semana: solo cuenta si es la semana actual o la anterior
      IF v_week >= TO_CHAR(DATE_TRUNC('week', NOW()) - INTERVAL '7 days', 'IYYY-IW') THEN
        v_streak := 1;
        v_prev   := v_week;
      ELSE
        EXIT; -- La última sesión fue hace más de 2 semanas, racha = 0
      END IF;
    ELSE
      -- Verificar que sea la semana inmediatamente anterior
      IF TO_CHAR(
           TO_DATE(v_prev, 'IYYY-IW') - INTERVAL '7 days',
           'IYYY-IW'
         ) = v_week THEN
        v_streak := v_streak + 1;
        v_prev   := v_week;
      ELSE
        EXIT;
      END IF;
    END IF;
  END LOOP;

  RETURN v_streak;
END;
$function$;
GRANT ALL ON FUNCTION public.get_current_streak(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_current_streak(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_current_streak(uuid) TO service_role;
CREATE FUNCTION public.get_followup_recipients(p_training_id uuid, p_secret text)
 RETURNS TABLE(nombre text, email text, asistio boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private'
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM private.config c
     WHERE c.key = 'followup_secret' AND c.value = p_secret
  ) THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  RETURN QUERY
  SELECT wr.nombre, wr.email, wr.asistio
    FROM public.web_registrations wr
   WHERE wr.training_id = p_training_id
     AND wr.estado_reserva <> 'cancelada';
END;
$function$;
GRANT ALL ON FUNCTION public.get_followup_recipients(uuid, text) TO anon;
GRANT ALL ON FUNCTION public.get_followup_recipients(uuid, text) TO authenticated;
GRANT ALL ON FUNCTION public.get_followup_recipients(uuid, text) TO service_role;
CREATE FUNCTION public.get_moderation_queue(p_status text DEFAULT 'pendiente'::text, p_limit integer DEFAULT 50)
 RETURNS TABLE(report_id uuid, reporter_id uuid, reporter_name text, reported_id uuid, reported_name text, content_type text, content_id uuid, reason text, status text, details text, reviewed_by uuid, reviewed_at timestamp with time zone, resolution_note text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Guard primario: falla rápido antes de tocar datos.
  IF NOT has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Acceso denegado: se requiere rol admin';
  END IF;

  RETURN QUERY
  SELECT
    rc.id                   AS report_id,
    rc.reporter_id,
    rtr.full_name           AS reporter_name,
    rc.reported_user_id     AS reported_id,
    rtd.full_name           AS reported_name,
    rc.content_type::TEXT,
    rc.content_id,
    rc.reason::TEXT,
    rc.status::TEXT,
    rc.details,
    rc.reviewed_by,
    rc.reviewed_at,
    rc.resolution_note,
    rc.created_at
  FROM reported_content rc
  LEFT JOIN user_profiles rtr ON rtr.id = rc.reporter_id
  LEFT JOIN user_profiles rtd ON rtd.id = rc.reported_user_id
  WHERE rc.status::TEXT = p_status
  ORDER BY rc.created_at ASC   -- cola FIFO: más antiguo = más urgente
  LIMIT LEAST(p_limit, 200);
END;
$function$;
GRANT ALL ON FUNCTION public.get_moderation_queue(text, integer) TO anon;
GRANT ALL ON FUNCTION public.get_moderation_queue(text, integer) TO authenticated;
GRANT ALL ON FUNCTION public.get_moderation_queue(text, integer) TO service_role;
CREATE FUNCTION public.get_my_blocked_profiles()
 RETURNS TABLE(blocked_id uuid, full_name text, avatar_url text, current_tier text, city text, reason text, blocked_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    bu.blocked_id,
    up.full_name,
    up.avatar_url,
    up.current_tier::TEXT,
    up.city,
    bu.reason,
    bu.created_at AS blocked_at
  FROM blocked_users bu
  JOIN user_profiles up ON up.id = bu.blocked_id
  WHERE bu.blocker_id = auth.uid()
  ORDER BY bu.created_at DESC;
$function$;
GRANT ALL ON FUNCTION public.get_my_blocked_profiles() TO anon;
GRANT ALL ON FUNCTION public.get_my_blocked_profiles() TO authenticated;
GRANT ALL ON FUNCTION public.get_my_blocked_profiles() TO service_role;
CREATE FUNCTION public.get_my_followers(p_user_id uuid)
 RETURNS TABLE(id uuid, full_name text, avatar_url text, current_tier text, city text, running_level text, followed_at timestamp with time zone)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT p.id, p.full_name, p.avatar_url, p.current_tier::TEXT,
         p.city, p.running_level::TEXT, f.created_at
  FROM follows f JOIN public_profiles p ON p.id = f.follower_id
  WHERE f.following_id = p_user_id
    AND (auth.uid() = p_user_id OR has_role(auth.uid(), 'admin'))
  ORDER BY f.created_at DESC;
$function$;
GRANT ALL ON FUNCTION public.get_my_followers(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_my_followers(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_my_followers(uuid) TO service_role;
CREATE FUNCTION public.get_my_following(p_user_id uuid)
 RETURNS TABLE(id uuid, full_name text, avatar_url text, current_tier text, city text, running_level text, followed_at timestamp with time zone, follows_back boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT p.id, p.full_name, p.avatar_url, p.current_tier::TEXT,
         p.city, p.running_level::TEXT, f.created_at,
         EXISTS (SELECT 1 FROM follows b
                 WHERE b.follower_id = f.following_id AND b.following_id = p_user_id)
  FROM follows f JOIN public_profiles p ON p.id = f.following_id
  WHERE f.follower_id = p_user_id
    AND (auth.uid() = p_user_id OR has_role(auth.uid(), 'admin'))
  ORDER BY f.created_at DESC;
$function$;
GRANT ALL ON FUNCTION public.get_my_following(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_my_following(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_my_following(uuid) TO service_role;
CREATE FUNCTION public.get_pacer_options(p_training_id uuid)
 RETURNS TABLE(user_id uuid, full_name text, label text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

  -- Admins/super_admins (con label correcto: Coach si tiene rol coach)
  SELECT DISTINCT ON (ur.user_id) ur.user_id, COALESCE(pp.full_name,'—'),
    CASE WHEN EXISTS (
      SELECT 1 FROM user_roles ur2
      WHERE ur2.user_id = ur.user_id AND ur2.role = 'coach'
    ) THEN 'Coach' ELSE 'Admin' END
  FROM user_roles ur
  JOIN public_profiles pp ON pp.id = ur.user_id
  WHERE ur.role IN ('admin','super_admin')

  UNION

  -- Inscritas via app (tabla registrations)
  SELECT DISTINCT r.user_id, COALESCE(pp.full_name,'—'), 'Inscrita'::TEXT
  FROM registrations r
  JOIN public_profiles pp ON pp.id = r.user_id
  WHERE r.training_id = p_training_id
    AND r.status = 'confirmed'
    AND NOT EXISTS (
      SELECT 1 FROM user_roles ur3
      WHERE ur3.user_id = r.user_id
        AND ur3.role IN ('admin','super_admin')
    )

  UNION

  -- Inscritas via web form (tabla web_registrations, solo las que tienen cuenta en app)
  SELECT DISTINCT wr.user_id, COALESCE(pp.full_name,'—'), 'Inscrita (web)'::TEXT
  FROM web_registrations wr
  JOIN public_profiles pp ON pp.id = wr.user_id
  WHERE wr.training_id = p_training_id
    AND wr.estado_reserva = 'confirmada'
    AND wr.user_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM user_roles ur4
      WHERE ur4.user_id = wr.user_id
        AND ur4.role IN ('admin','super_admin')
    )

  ORDER BY 3, 2;
$function$;
GRANT ALL ON FUNCTION public.get_pacer_options(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_pacer_options(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_pacer_options(uuid) TO service_role;
CREATE FUNCTION public.get_reports_for_moderation(p_status public.report_status DEFAULT NULL::public.report_status)
 RETURNS TABLE(id uuid, content_type public.report_target, content_id uuid, reason public.report_reason, details text, status public.report_status, created_at timestamp with time zone, reviewed_at timestamp with time zone, resolution_note text, reporter_id uuid, reporter_name text, reported_user_id uuid, reported_name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    rc.id,
    rc.content_type,
    rc.content_id,
    rc.reason,
    rc.details,
    rc.status,
    rc.created_at,
    rc.reviewed_at,
    rc.resolution_note,
    rc.reporter_id,
    rr.full_name AS reporter_name,
    rc.reported_user_id,
    ru.full_name AS reported_name
  FROM reported_content rc
  LEFT JOIN user_profiles rr ON rr.id = rc.reporter_id
  LEFT JOIN user_profiles ru ON ru.id = rc.reported_user_id
  WHERE
    (has_role(auth.uid(), 'moderator') OR has_role(auth.uid(), 'admin'))
    AND (p_status IS NULL OR rc.status = p_status)
  ORDER BY
    CASE rc.status
      WHEN 'pendiente'   THEN 1
      WHEN 'en_revision' THEN 2
      WHEN 'resuelto'    THEN 3
      WHEN 'descartado'  THEN 4
    END,
    rc.created_at DESC;
$function$;
GRANT ALL ON FUNCTION public.get_reports_for_moderation(public.report_status) TO anon;
GRANT ALL ON FUNCTION public.get_reports_for_moderation(public.report_status) TO authenticated;
GRANT ALL ON FUNCTION public.get_reports_for_moderation(public.report_status) TO service_role;
CREATE FUNCTION public.get_training_leaders(p_training_id uuid)
 RETURNS TABLE(user_id uuid, full_name text, label text, role text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT tl.user_id, COALESCE(pp.full_name,'—'),
    CASE 
      WHEN tl.role = 'pacer' THEN 'Pacer'
      WHEN EXISTS (SELECT 1 FROM user_roles ur WHERE ur.user_id = tl.user_id AND ur.role = 'coach')
      THEN 'Coach' ELSE 'Admin'
    END,
    tl.role
  FROM training_leaders tl
  JOIN public_profiles pp ON pp.id = tl.user_id
  WHERE tl.training_id = p_training_id
  ORDER BY tl.role, pp.full_name;
$function$;
GRANT ALL ON FUNCTION public.get_training_leaders(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_training_leaders(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_training_leaders(uuid) TO service_role;
CREATE FUNCTION public.get_training_participants(p_training_id uuid)
 RETURNS TABLE(user_id uuid, full_name text, avatar_url text, current_tier text, running_level text, city text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    pp.id          AS user_id,
    pp.full_name,
    pp.avatar_url,
    pp.current_tier::TEXT,
    pp.running_level::TEXT,
    pp.city
  FROM registrations r
  JOIN public_profiles pp ON pp.id = r.user_id
  WHERE r.training_id = p_training_id
    AND r.status = 'confirmed'
    AND (
      EXISTS (
        SELECT 1 FROM trainings t
        WHERE t.id = p_training_id AND t.coach_id = auth.uid()
      )
      OR has_role(auth.uid(), 'admin')
      OR EXISTS (
        SELECT 1 FROM registrations my_r
        WHERE my_r.training_id = p_training_id
          AND my_r.user_id = auth.uid()
          AND my_r.status = 'confirmed'
      )
    )
  ORDER BY pp.full_name;
$function$;
GRANT ALL ON FUNCTION public.get_training_participants(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_training_participants(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_training_participants(uuid) TO service_role;
CREATE FUNCTION public.get_user_group_ids(p_user_id uuid DEFAULT auth.uid())
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT group_id
  FROM   training_group_members
  WHERE  user_id = p_user_id;
$function$;
GRANT ALL ON FUNCTION public.get_user_group_ids(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_user_group_ids(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_user_group_ids(uuid) TO service_role;
CREATE FUNCTION public.handle_anamnesis_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $function$;
GRANT ALL ON FUNCTION public.handle_anamnesis_updated_at() TO anon;
GRANT ALL ON FUNCTION public.handle_anamnesis_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.handle_anamnesis_updated_at() TO service_role;
CREATE FUNCTION public.handle_event_winners_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $function$;
GRANT ALL ON FUNCTION public.handle_event_winners_updated_at() TO anon;
GRANT ALL ON FUNCTION public.handle_event_winners_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.handle_event_winners_updated_at() TO service_role;
CREATE FUNCTION public.handle_registration_cancelled()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF OLD.status = 'confirmed' AND NEW.status = 'cancelled' THEN
    PERFORM promote_from_waitlist(NEW.training_id);
  END IF;
  RETURN NULL;
END;
$function$;
GRANT ALL ON FUNCTION public.handle_registration_cancelled() TO anon;
GRANT ALL ON FUNCTION public.handle_registration_cancelled() TO authenticated;
GRANT ALL ON FUNCTION public.handle_registration_cancelled() TO service_role;
CREATE FUNCTION public.handle_sponsor_events_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $function$;
GRANT ALL ON FUNCTION public.handle_sponsor_events_updated_at() TO anon;
GRANT ALL ON FUNCTION public.handle_sponsor_events_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.handle_sponsor_events_updated_at() TO service_role;
CREATE FUNCTION public.has_role(p_user_id uuid, p_role public.app_role)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM user_roles ur
    WHERE ur.user_id = p_user_id
      AND (
        ur.role = p_role
        OR (p_role <> 'super_admin' AND ur.role = 'super_admin')
      )
  );
$function$;
GRANT ALL ON FUNCTION public.has_role(uuid, public.app_role) TO anon;
GRANT ALL ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated;
GRANT ALL ON FUNCTION public.has_role(uuid, public.app_role) TO service_role;
CREATE FUNCTION public.inscribir_en_entrenamiento(p_nombre text, p_email text, p_training_id uuid, p_contacto_emergencia text, p_condicion_medica text, p_telefono text DEFAULT NULL::text, p_respuestas_extra jsonb DEFAULT NULL::jsonb, p_tiene_condicion_medica boolean DEFAULT false, p_condiciones_declaradas text[] DEFAULT NULL::text[], p_anexo_a_requerido boolean DEFAULT false, p_anexo_a_aceptado_en timestamp with time zone DEFAULT NULL::timestamp with time zone, p_anexo_a_vigencia date DEFAULT NULL::date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_max_capacity   INTEGER;
  v_cupos_ocupados INTEGER;
  v_user_id        UUID;
BEGIN
  SELECT max_capacity INTO v_max_capacity
  FROM trainings WHERE id = p_training_id AND status = 'published';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Entrenamiento no encontrado o no disponible.';
  END IF;

  SELECT
    (SELECT COUNT(*) FROM web_registrations
       WHERE training_id = p_training_id AND estado_reserva = 'confirmada')
    + (SELECT COUNT(*) FROM registrations
       WHERE training_id = p_training_id AND status = 'confirmed')
  INTO v_cupos_ocupados;

  IF v_max_capacity IS NOT NULL AND v_cupos_ocupados >= v_max_capacity THEN
    RAISE EXCEPTION 'Entrenamiento lleno. Ya no hay cupos disponibles.';
  END IF;

  SELECT id INTO v_user_id FROM auth.users
  WHERE email = lower(p_email) LIMIT 1;

  INSERT INTO web_registrations (
    training_id, nombre, email, telefono, contacto_emergencia,
    condicion_medica, respuestas_extra, user_id,
    tiene_condicion_medica, condiciones_declaradas,
    anexo_a_requerido, anexo_a_aceptado_en, anexo_a_vigencia, created_via
  ) VALUES (
    p_training_id, p_nombre, lower(p_email), p_telefono, p_contacto_emergencia,
    p_condicion_medica, p_respuestas_extra, v_user_id,
    p_tiene_condicion_medica, p_condiciones_declaradas,
    p_anexo_a_requerido, p_anexo_a_aceptado_en, p_anexo_a_vigencia, 'web_form'
  );
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Ya estás inscrita en este entrenamiento.';
END;
$function$;
GRANT ALL ON FUNCTION public.inscribir_en_entrenamiento(text, text, uuid, text, text, text, jsonb, boolean, text[], boolean, timestamp with time zone, date) TO anon;
GRANT ALL ON FUNCTION public.inscribir_en_entrenamiento(text, text, uuid, text, text, text, jsonb, boolean, text[], boolean, timestamp with time zone, date) TO authenticated;
GRANT ALL ON FUNCTION public.inscribir_en_entrenamiento(text, text, uuid, text, text, text, jsonb, boolean, text[], boolean, timestamp with time zone, date) TO service_role;
CREATE FUNCTION public.is_blocked_between(p_other uuid, p_me uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE (blocker_id = p_me    AND blocked_id = p_other)
       OR (blocker_id = p_other AND blocked_id = p_me)
  );
$function$;
GRANT ALL ON FUNCTION public.is_blocked_between(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.is_blocked_between(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.is_blocked_between(uuid, uuid) TO service_role;
CREATE FUNCTION public.is_channel_admin(p_channel_id uuid, p_user_id uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (SELECT 1 FROM channel_participants
    WHERE channel_id = p_channel_id AND user_id = p_user_id AND role IN ('owner','admin'));
$function$;
GRANT ALL ON FUNCTION public.is_channel_admin(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.is_channel_admin(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.is_channel_admin(uuid, uuid) TO service_role;
CREATE FUNCTION public.is_channel_participant(p_channel_id uuid, p_user_id uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (SELECT 1 FROM channel_participants WHERE channel_id = p_channel_id AND user_id = p_user_id);
$function$;
GRANT ALL ON FUNCTION public.is_channel_participant(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.is_channel_participant(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.is_channel_participant(uuid, uuid) TO service_role;
CREATE FUNCTION public.join_community_space(p_channel_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid       UUID := auth.uid();
  v_chan_type channel_type;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No autenticada';
  END IF;
  SELECT type INTO v_chan_type FROM channels WHERE id = p_channel_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Canal no encontrado';
  END IF;
  IF v_chan_type <> 'community' THEN
    RAISE EXCEPTION 'Solo se pueden unir a espacios comunitarios';
  END IF;
  INSERT INTO channel_participants (channel_id, user_id, role, joined_at, last_read_at)
  VALUES (p_channel_id, v_uid, 'member', NOW(), NOW())
  ON CONFLICT (channel_id, user_id) DO NOTHING;
  RETURN p_channel_id;
END;
$function$;
GRANT ALL ON FUNCTION public.join_community_space(uuid) TO anon;
GRANT ALL ON FUNCTION public.join_community_space(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.join_community_space(uuid) TO service_role;
CREATE FUNCTION public.leave_channel(p_channel_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid          UUID := auth.uid();
  v_community_id UUID := 'c0ffee00-0000-4000-a000-000000000001';
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No autenticada';
  END IF;
  IF p_channel_id = v_community_id THEN
    RAISE EXCEPTION 'No puedes salir del canal principal de la comunidad';
  END IF;
  DELETE FROM channel_participants
  WHERE channel_id = p_channel_id AND user_id = v_uid;
END;
$function$;
GRANT ALL ON FUNCTION public.leave_channel(uuid) TO anon;
GRANT ALL ON FUNCTION public.leave_channel(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.leave_channel(uuid) TO service_role;
CREATE FUNCTION public.notify_on_new_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.kind NOT IN ('text', 'image') THEN
    RETURN NEW;
  END IF;

  INSERT INTO notifications (user_id, kind, title, body, ref_id, ref_type)
  SELECT
    cp.user_id,
    'new_message',
    'Nuevo mensaje',
    LEFT(NEW.body, 120),
    NEW.id,
    'message'
  FROM channel_participants cp
  WHERE cp.channel_id = NEW.channel_id
    AND cp.user_id    != NEW.sender_id
    AND cp.is_muted   = false;

  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.notify_on_new_message() TO anon;
GRANT ALL ON FUNCTION public.notify_on_new_message() TO authenticated;
GRANT ALL ON FUNCTION public.notify_on_new_message() TO service_role;
CREATE FUNCTION public.notify_on_post_reaction()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_post_author  UUID;
  v_reactor_name TEXT;
  v_reaction_label TEXT;
BEGIN
  SELECT author_id INTO v_post_author
  FROM feed_posts
  WHERE id = NEW.post_id;

  IF v_post_author IS NULL OR v_post_author = NEW.user_id THEN
    RETURN NEW;
  END IF;

  SELECT full_name INTO v_reactor_name
  FROM user_profiles
  WHERE id = NEW.user_id;

  v_reaction_label := CASE NEW.reaction
    WHEN 'apoyo'   THEN '🤍 Apoyo'
    WHEN 'fuerza'  THEN '💪 Fuerza'
    WHEN 'celebro' THEN '🎉 Celebración'
    WHEN 'orgullo' THEN '⭐ Orgullo'
    ELSE '💜 Reacción'
  END;

  INSERT INTO notifications (user_id, kind, title, body, ref_id, ref_type)
  VALUES (
    v_post_author,
    'support_reaction',
    v_reaction_label,
    COALESCE(v_reactor_name, 'Alguien') || ' te envió apoyo',
    NEW.post_id,
    'post'
  );

  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.notify_on_post_reaction() TO anon;
GRANT ALL ON FUNCTION public.notify_on_post_reaction() TO authenticated;
GRANT ALL ON FUNCTION public.notify_on_post_reaction() TO service_role;
CREATE FUNCTION public.notify_on_training_published()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.status != 'published' THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = 'published' THEN
    RETURN NEW;
  END IF;

  INSERT INTO notifications (user_id, kind, title, body, ref_id, ref_type)
  SELECT
    up.id,
    'new_training',
    '🏃‍♀️ Nuevo entrenamiento',
    NEW.title,
    NEW.id,
    'training'
  FROM user_profiles up;

  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.notify_on_training_published() TO anon;
GRANT ALL ON FUNCTION public.notify_on_training_published() TO authenticated;
GRANT ALL ON FUNCTION public.notify_on_training_published() TO service_role;
CREATE FUNCTION public.promote_from_waitlist(p_training_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id        UUID;
  v_training_title TEXT;
  v_training_hour  TEXT;
BEGIN
  SELECT user_id INTO v_user_id
  FROM registrations
  WHERE training_id = p_training_id AND status = 'waitlist'
  ORDER BY registered_at ASC LIMIT 1;

  IF v_user_id IS NULL THEN RETURN; END IF;

  UPDATE registrations
  SET status = 'confirmed'
  WHERE training_id = p_training_id AND user_id = v_user_id AND status = 'waitlist';

  SELECT title, to_char(scheduled_at AT TIME ZONE 'America/Santiago', 'HH24:MI')
  INTO v_training_title, v_training_hour
  FROM trainings WHERE id = p_training_id;

  INSERT INTO notifications (user_id, kind, title, body, ref_id, ref_type)
  VALUES (
    v_user_id, 'general', '¡Tienes un cupo! 🎉',
    format('Se liberó un lugar en "%s" (%s hrs). Ya estás confirmada 💜', v_training_title, v_training_hour),
    p_training_id, 'training'
  );
END;
$function$;
GRANT ALL ON FUNCTION public.promote_from_waitlist(uuid) TO anon;
GRANT ALL ON FUNCTION public.promote_from_waitlist(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.promote_from_waitlist(uuid) TO service_role;
CREATE FUNCTION public.purge_follows_on_block()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  DELETE FROM follows
  WHERE (follower_id = NEW.blocker_id AND following_id = NEW.blocked_id)
     OR (follower_id = NEW.blocked_id AND following_id = NEW.blocker_id);
  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.purge_follows_on_block() TO anon;
GRANT ALL ON FUNCTION public.purge_follows_on_block() TO authenticated;
GRANT ALL ON FUNCTION public.purge_follows_on_block() TO service_role;
CREATE FUNCTION public.qualify_referral_if_needed(p_referred_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_ref referrals%ROWTYPE;
BEGIN
  SELECT * INTO v_ref FROM referrals
   WHERE referred_id = p_referred_id AND status <> 'qualified'
   LIMIT 1;

  IF FOUND THEN
    UPDATE referrals SET status = 'qualified', qualified_at = NOW() WHERE id = v_ref.id;
    PERFORM award_points_by_rule(v_ref.referrer_id, 'referral_completed', v_ref.id, NULL);
  END IF;
END;
$function$;
GRANT ALL ON FUNCTION public.qualify_referral_if_needed(uuid) TO anon;
GRANT ALL ON FUNCTION public.qualify_referral_if_needed(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.qualify_referral_if_needed(uuid) TO service_role;
CREATE FUNCTION public.record_user_activity(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_days_absent    NUMERIC;
  v_current_streak SMALLINT;
BEGIN
  SELECT EXTRACT(EPOCH FROM (NOW() - last_activity_at)) / 86400.0
  INTO v_days_absent
  FROM user_profiles
  WHERE id = p_user_id;

  -- Calcular racha ANTES de registrar la nueva actividad
  SELECT get_current_streak(p_user_id) INTO v_current_streak;

  -- Regreso tras ausencia: limpiar escalones de reactivación
  -- para que la próxima ausencia reinicie el ciclo de mensajes
  IF v_days_absent > 2 THEN
    DELETE FROM reactivation_log WHERE user_id = p_user_id;
  END IF;

  UPDATE user_profiles SET
    last_activity_at  = NOW(),
    max_streak_weeks  = GREATEST(max_streak_weeks, v_current_streak),
    -- Si la racha actual es > 0, actualizar last_streak_weeks.
    -- Si es 0 (período sin entrenamiento), preservar el último valor conocido.
    last_streak_weeks = CASE
                          WHEN v_current_streak > 0 THEN v_current_streak
                          ELSE last_streak_weeks
                        END
  WHERE id = p_user_id;
END;
$function$;
GRANT ALL ON FUNCTION public.record_user_activity(uuid) TO anon;
GRANT ALL ON FUNCTION public.record_user_activity(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.record_user_activity(uuid) TO service_role;
CREATE FUNCTION public.redeem_reward(p_user_id uuid, p_reward_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_reward        rewards_catalog%ROWTYPE;
  v_profile       user_profiles%ROWTYPE;
  v_redemption_id UUID;
  v_tier_order    SMALLINT;
  v_req_order     SMALLINT;
BEGIN
  SELECT * INTO v_reward FROM rewards_catalog WHERE id = p_reward_id AND is_active FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Recompensa no disponible'; END IF;

  SELECT * INTO v_profile FROM user_profiles WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Usuaria no encontrada'; END IF;

  IF v_profile.total_points < v_reward.points_cost THEN
    RAISE EXCEPTION 'Puntos insuficientes (tienes %, necesitas %)', v_profile.total_points, v_reward.points_cost;
  END IF;

  IF v_reward.required_tier IS NOT NULL THEN
    SELECT sort_order INTO v_tier_order FROM loyalty_tiers WHERE tier = v_profile.current_tier;
    SELECT sort_order INTO v_req_order  FROM loyalty_tiers WHERE tier = v_reward.required_tier;
    IF v_tier_order < v_req_order THEN
      RAISE EXCEPTION 'Nivel insuficiente: requiere %', v_reward.required_tier;
    END IF;
  END IF;

  IF v_reward.stock IS NOT NULL AND v_reward.stock <= 0 THEN
    RAISE EXCEPTION 'Sin stock disponible';
  END IF;

  PERFORM award_points(p_user_id, -v_reward.points_cost, 'redemption', p_reward_id,
                       'Canje: ' || v_reward.name);

  INSERT INTO reward_redemptions (user_id, reward_id, points_spent)
  VALUES (p_user_id, p_reward_id, v_reward.points_cost)
  RETURNING id INTO v_redemption_id;

  IF v_reward.stock IS NOT NULL THEN
    UPDATE rewards_catalog SET stock = stock - 1 WHERE id = p_reward_id;
  END IF;

  RETURN v_redemption_id;
END;
$function$;
GRANT ALL ON FUNCTION public.redeem_reward(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.redeem_reward(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.redeem_reward(uuid, uuid) TO service_role;
CREATE FUNCTION public.remove_training_leader(p_training_id uuid, p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  DELETE FROM training_leaders
  WHERE training_id = p_training_id AND user_id = p_user_id;
END;
$function$;
GRANT ALL ON FUNCTION public.remove_training_leader(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.remove_training_leader(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.remove_training_leader(uuid, uuid) TO service_role;
CREATE FUNCTION public.report_user(p_reported_user uuid, p_content_type text DEFAULT 'profile'::text, p_content_id uuid DEFAULT NULL::uuid, p_reason text DEFAULT 'otro'::text, p_details text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid       UUID := auth.uid();
  v_report_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No autenticada';
  END IF;
  IF p_reported_user IS NULL OR p_reported_user = v_uid THEN
    RAISE EXCEPTION 'Usuaria reportada inválida';
  END IF;

  INSERT INTO reported_content (
    reporter_id,
    reported_user_id,
    content_type,
    content_id,
    reason,
    details
  )
  VALUES (
    v_uid,
    p_reported_user,
    p_content_type::report_target,    -- cast valida el ENUM
    p_content_id,
    p_reason::report_reason,          -- cast valida el ENUM
    p_details
  )
  RETURNING id INTO v_report_id;

  RETURN v_report_id;
END;
$function$;
GRANT ALL ON FUNCTION public.report_user(uuid, text, uuid, text, text) TO anon;
GRANT ALL ON FUNCTION public.report_user(uuid, text, uuid, text, text) TO authenticated;
GRANT ALL ON FUNCTION public.report_user(uuid, text, uuid, text, text) TO service_role;
CREATE FUNCTION public.resolve_sos_alert(p_alert_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT (has_role(auth.uid(), 'coach') OR has_role(auth.uid(), 'admin')) THEN
    RAISE EXCEPTION 'Solo coaches y administradoras pueden resolver alertas SOS'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  UPDATE public.training_sos_alerts
  SET resolved_at  = NOW(),
      resolved_by  = auth.uid()
  WHERE id          = p_alert_id
    AND resolved_at IS NULL;
END;
$function$;
GRANT ALL ON FUNCTION public.resolve_sos_alert(uuid) TO anon;
GRANT ALL ON FUNCTION public.resolve_sos_alert(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.resolve_sos_alert(uuid) TO service_role;
CREATE FUNCTION public.send_message(p_conversation_id uuid, p_body text, p_kind public.message_kind DEFAULT 'text'::public.message_kind)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid    UUID := auth.uid();
  v_msg_id UUID;
BEGIN

  -- §A  Sesión activa
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No autenticada';
  END IF;

  -- §B  Validación del cuerpo
  IF p_body IS NULL OR char_length(trim(p_body)) = 0 THEN
    RAISE EXCEPTION 'El mensaje no puede estar vacío';
  END IF;
  IF char_length(p_body) > 4000 THEN
    RAISE EXCEPTION 'Mensaje demasiado largo (máx. 4000 caracteres)';
  END IF;

  -- §C  Participación en el canal (SECURITY DEFINER, sin recursión)
  IF NOT is_channel_participant(p_conversation_id, v_uid) THEN
    RAISE EXCEPTION 'No perteneces a esta conversación';
  END IF;

  -- §D  Guard de bloqueo — solo gatea canales 'direct'
  IF channel_has_block(p_conversation_id, v_uid) THEN
    RAISE EXCEPTION 'No es posible enviar mensajes en esta conversación';
  END IF;

  -- §E  INSERT atómico — RLS RESTRICTIVE actúa como tercera capa
  INSERT INTO messages (channel_id, sender_id, body, kind)
  VALUES (p_conversation_id, v_uid, trim(p_body), p_kind)
  RETURNING id INTO v_msg_id;

  RETURN v_msg_id;

END;
$function$;
GRANT ALL ON FUNCTION public.send_message(uuid, text, public.message_kind) TO anon;
GRANT ALL ON FUNCTION public.send_message(uuid, text, public.message_kind) TO authenticated;
GRANT ALL ON FUNCTION public.send_message(uuid, text, public.message_kind) TO service_role;
CREATE FUNCTION public.send_message(p_channel_id uuid, p_body text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid       UUID := auth.uid();
  v_chan_type channel_type;
  v_other_uid UUID;
  v_msg_id    UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No autenticada';
  END IF;

  IF NOT is_channel_participant(p_channel_id, v_uid) THEN
    RAISE EXCEPTION 'No eres participante de este canal';
  END IF;

  IF p_body IS NULL OR length(trim(p_body)) = 0 THEN
    RAISE EXCEPTION 'El mensaje no puede estar vacío';
  END IF;

  IF length(p_body) > 4000 THEN
    RAISE EXCEPTION 'El mensaje supera los 4000 caracteres';
  END IF;

  SELECT type INTO v_chan_type FROM channels WHERE id = p_channel_id;

  IF v_chan_type = 'direct' THEN
    SELECT user_id INTO v_other_uid
    FROM   channel_participants
    WHERE  channel_id = p_channel_id
      AND  user_id   <> v_uid
    LIMIT  1;

    IF v_other_uid IS NOT NULL AND is_blocked_between(v_other_uid) THEN
      RAISE EXCEPTION 'No puedes enviar mensajes a esta conversación';
    END IF;
  END IF;

  INSERT INTO messages (channel_id, sender_id, body, kind)
  VALUES (p_channel_id, v_uid, trim(p_body), 'text')
  RETURNING id INTO v_msg_id;

  RETURN v_msg_id;
END;
$function$;
GRANT ALL ON FUNCTION public.send_message(uuid, text) TO anon;
GRANT ALL ON FUNCTION public.send_message(uuid, text) TO authenticated;
GRANT ALL ON FUNCTION public.send_message(uuid, text) TO service_role;
CREATE FUNCTION public.send_sos_alert(p_training_id uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid     UUID := auth.uid();
  v_sos_id  UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No autenticada';
  END IF;

  -- Validar inscripción confirmada
  IF NOT EXISTS (
    SELECT 1 FROM public.registrations r
    WHERE r.training_id = p_training_id
      AND r.user_id     = v_uid
      AND r.status      = 'confirmed'
  ) THEN
    RAISE EXCEPTION 'No tienes inscripción confirmada en este entrenamiento';
  END IF;

  INSERT INTO public.training_sos_alerts (training_id, runner_id, lat, lng)
  VALUES (p_training_id, v_uid, p_lat, p_lng)
  RETURNING id INTO v_sos_id;

  RETURN v_sos_id;
END;
$function$;
GRANT ALL ON FUNCTION public.send_sos_alert(uuid, double precision, double precision) TO anon;
GRANT ALL ON FUNCTION public.send_sos_alert(uuid, double precision, double precision) TO authenticated;
GRANT ALL ON FUNCTION public.send_sos_alert(uuid, double precision, double precision) TO service_role;
CREATE FUNCTION public.set_legacy_web_regs_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.set_legacy_web_regs_updated_at() TO anon;
GRANT ALL ON FUNCTION public.set_legacy_web_regs_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.set_legacy_web_regs_updated_at() TO service_role;
CREATE FUNCTION public.set_legacy_web_trainings_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.set_legacy_web_trainings_updated_at() TO anon;
GRANT ALL ON FUNCTION public.set_legacy_web_trainings_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.set_legacy_web_trainings_updated_at() TO service_role;
CREATE FUNCTION public.set_runners_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.set_runners_updated_at() TO anon;
GRANT ALL ON FUNCTION public.set_runners_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.set_runners_updated_at() TO service_role;
CREATE FUNCTION public.set_updated_at_timestamp()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.set_updated_at_timestamp() TO anon;
GRANT ALL ON FUNCTION public.set_updated_at_timestamp() TO authenticated;
GRANT ALL ON FUNCTION public.set_updated_at_timestamp() TO service_role;
CREATE FUNCTION public.start_gps_broadcast(p_training_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid        UUID := auth.uid();
  v_scheduled  TIMESTAMPTZ;
  v_checkin_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No autenticada';
  END IF;

  SELECT t.scheduled_at INTO v_scheduled
  FROM trainings t
  JOIN registrations r ON r.training_id = t.id
  WHERE t.id = p_training_id
    AND r.user_id = v_uid
    AND r.status = 'confirmed'
    AND t.status = 'published';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No tienes inscripción confirmada en este entrenamiento';
  END IF;

  IF NOW() < v_scheduled - INTERVAL '2 hours'
  OR NOW() > v_scheduled + INTERVAL '2 hours' THEN
    RAISE EXCEPTION 'El entrenamiento no está activo en este momento';
  END IF;

  INSERT INTO training_checkins (training_id, user_id)
  VALUES (p_training_id, v_uid)
  ON CONFLICT (training_id, user_id)
  DO UPDATE SET checked_in_at = NOW(), checked_out_at = NULL
  RETURNING id INTO v_checkin_id;

  RETURN v_checkin_id;
END;
$function$;
GRANT ALL ON FUNCTION public.start_gps_broadcast(uuid) TO anon;
GRANT ALL ON FUNCTION public.start_gps_broadcast(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.start_gps_broadcast(uuid) TO service_role;
CREATE FUNCTION public.stop_gps_broadcast(p_training_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE training_checkins
  SET checked_out_at = NOW()
  WHERE training_id = p_training_id
    AND user_id = auth.uid()
    AND checked_out_at IS NULL;
END;
$function$;
GRANT ALL ON FUNCTION public.stop_gps_broadcast(uuid) TO anon;
GRANT ALL ON FUNCTION public.stop_gps_broadcast(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.stop_gps_broadcast(uuid) TO service_role;
CREATE FUNCTION public.sync_post_likes_count()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE feed_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE feed_posts SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$function$;
GRANT ALL ON FUNCTION public.sync_post_likes_count() TO anon;
GRANT ALL ON FUNCTION public.sync_post_likes_count() TO authenticated;
GRANT ALL ON FUNCTION public.sync_post_likes_count() TO service_role;
CREATE FUNCTION public.toggle_reaction(p_post_id uuid, p_reaction public.reaction_kind DEFAULT 'apoyo'::public.reaction_kind)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid      UUID := auth.uid();
  v_existing reaction_kind;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'No autenticada'; END IF;
  SELECT reaction INTO v_existing FROM post_likes
  WHERE post_id = p_post_id AND user_id = v_uid;

  IF NOT FOUND THEN
    INSERT INTO post_likes (post_id, user_id, reaction) VALUES (p_post_id, v_uid, p_reaction);
    RETURN p_reaction::TEXT;
  ELSIF v_existing = p_reaction THEN
    DELETE FROM post_likes WHERE post_id = p_post_id AND user_id = v_uid;
    RETURN NULL;
  ELSE
    UPDATE post_likes SET reaction = p_reaction, created_at = NOW()
    WHERE post_id = p_post_id AND user_id = v_uid;
    RETURN p_reaction::TEXT;
  END IF;
END; $function$;
GRANT ALL ON FUNCTION public.toggle_reaction(uuid, public.reaction_kind) TO anon;
GRANT ALL ON FUNCTION public.toggle_reaction(uuid, public.reaction_kind) TO authenticated;
GRANT ALL ON FUNCTION public.toggle_reaction(uuid, public.reaction_kind) TO service_role;
CREATE FUNCTION public.trg_post_achievement_unlocked()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_name TEXT;
BEGIN
  SELECT name INTO v_name FROM achievements WHERE id = NEW.achievement_id;
  INSERT INTO feed_posts (author_id, post_type, ref_id, body, visibility)
  VALUES (NEW.user_id, 'achievement', NEW.id,
          '¡Logré el hito "' || COALESCE(v_name, '') || '"! 💜', 'followers');
  RETURN NEW;
END; $function$;
GRANT ALL ON FUNCTION public.trg_post_achievement_unlocked() TO anon;
GRANT ALL ON FUNCTION public.trg_post_achievement_unlocked() TO authenticated;
GRANT ALL ON FUNCTION public.trg_post_achievement_unlocked() TO service_role;
CREATE FUNCTION public.trg_post_training_completed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF OLD.checked_out_at IS NULL AND NEW.checked_out_at IS NOT NULL THEN
    INSERT INTO feed_posts (author_id, post_type, ref_id, body, visibility)
    VALUES (NEW.user_id, 'training_completed', NEW.training_id, NULL, 'followers');
  END IF;
  RETURN NEW;
END; $function$;
GRANT ALL ON FUNCTION public.trg_post_training_completed() TO anon;
GRANT ALL ON FUNCTION public.trg_post_training_completed() TO authenticated;
GRANT ALL ON FUNCTION public.trg_post_training_completed() TO service_role;
CREATE FUNCTION public.trg_record_activity_on_points()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  PERFORM record_user_activity(NEW.user_id);
  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.trg_record_activity_on_points() TO anon;
GRANT ALL ON FUNCTION public.trg_record_activity_on_points() TO authenticated;
GRANT ALL ON FUNCTION public.trg_record_activity_on_points() TO service_role;
CREATE FUNCTION public.trigger_award_survey_points()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM award_points_by_rule(NEW.user_id, 'survey_completed', NEW.training_id, NULL);
  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.trigger_award_survey_points() TO anon;
GRANT ALL ON FUNCTION public.trigger_award_survey_points() TO authenticated;
GRANT ALL ON FUNCTION public.trigger_award_survey_points() TO service_role;
CREATE FUNCTION public.trigger_evaluate_achievements()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.status = 'confirmed' THEN
    PERFORM evaluate_achievements(NEW.user_id);
  END IF;
  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.trigger_evaluate_achievements() TO anon;
GRANT ALL ON FUNCTION public.trigger_evaluate_achievements() TO authenticated;
GRANT ALL ON FUNCTION public.trigger_evaluate_achievements() TO service_role;
CREATE FUNCTION public.trigger_update_tier()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.current_tier := calculate_tier(NEW.total_points);
  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.trigger_update_tier() TO anon;
GRANT ALL ON FUNCTION public.trigger_update_tier() TO authenticated;
GRANT ALL ON FUNCTION public.trigger_update_tier() TO service_role;
CREATE FUNCTION public.unblock_user(p_target uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No autenticada';
  END IF;

  DELETE FROM blocked_users
  WHERE blocker_id = v_uid AND blocked_id = p_target;
END;
$function$;
GRANT ALL ON FUNCTION public.unblock_user(uuid) TO anon;
GRANT ALL ON FUNCTION public.unblock_user(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.unblock_user(uuid) TO service_role;
CREATE FUNCTION public.update_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.update_updated_at() TO anon;
GRANT ALL ON FUNCTION public.update_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.update_updated_at() TO service_role;
CREATE FUNCTION public.wsr_confirmar_inscripcion_web()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_key              text;
  v_primer_nombre    text;
  v_titulo           text;
  v_titulo_cap       text;
  v_fecha_hora       timestamptz;
  v_ubicacion        text;
  v_ubicacion_texto  text;
  v_latitud          float8;
  v_longitud         float8;
  v_dia_semana       text;
  v_dia_num          text;
  v_mes              text;
  v_anio             text;
  v_hora             text;
  v_fecha_txt        text;
  v_fila_ubicacion   text;
  v_cta_url          text;
  v_nota_encuentro   text;
  v_html             text;
  v_dow              int;
  v_mon              int;
BEGIN
  IF NEW.estado_reserva <> 'confirmada' THEN RETURN NEW; END IF;

  SELECT value INTO v_key FROM wsr_config WHERE key = 'resend_api_key';
  IF v_key IS NULL OR v_key = 'PEGA_TU_API_KEY_DE_RESEND_AQUI' THEN RETURN NEW; END IF;
  IF NEW.email IS NULL THEN RETURN NEW; END IF;

  SELECT title, scheduled_at, location_name, location_detail, latitude, longitude
  INTO v_titulo, v_fecha_hora, v_ubicacion, v_ubicacion_texto, v_latitud, v_longitud
  FROM trainings WHERE id = NEW.training_id;

  v_primer_nombre := split_part(trim(coalesce(NEW.nombre, 'Corredora')), ' ', 1);
  v_titulo_cap    := upper(left(v_titulo, 1)) || substring(v_titulo from 2);

  v_dow := extract(dow  FROM v_fecha_hora AT TIME ZONE 'America/Santiago');
  v_mon := extract(month FROM v_fecha_hora AT TIME ZONE 'America/Santiago');
  v_dia_num := to_char(v_fecha_hora AT TIME ZONE 'America/Santiago', 'DD');
  v_anio    := to_char(v_fecha_hora AT TIME ZONE 'America/Santiago', 'YYYY');
  v_hora    := to_char(v_fecha_hora AT TIME ZONE 'America/Santiago', 'HH24:MI');

  v_dia_semana := CASE v_dow
    WHEN 0 THEN 'Domingo'  WHEN 1 THEN 'Lunes'   WHEN 2 THEN 'Martes'
    WHEN 3 THEN 'Miércoles' WHEN 4 THEN 'Jueves'  WHEN 5 THEN 'Viernes'
    WHEN 6 THEN 'Sábado'
  END;
  v_mes := CASE v_mon
    WHEN 1  THEN 'enero'     WHEN 2  THEN 'febrero'   WHEN 3  THEN 'marzo'
    WHEN 4  THEN 'abril'     WHEN 5  THEN 'mayo'       WHEN 6  THEN 'junio'
    WHEN 7  THEN 'julio'     WHEN 8  THEN 'agosto'     WHEN 9  THEN 'septiembre'
    WHEN 10 THEN 'octubre'   WHEN 11 THEN 'noviembre'  WHEN 12 THEN 'diciembre'
  END;

  v_fecha_txt      := v_dia_semana || ' ' || v_dia_num || ' de ' || v_mes || ' de ' || v_anio;
  v_fila_ubicacion := CASE WHEN v_ubicacion IS NOT NULL
    THEN '<tr><td style="padding:5px 0;font-size:.875rem;color:#7B4F60;">📍 ' || v_ubicacion || '</td></tr>'
    ELSE ''
  END;

  IF v_latitud IS NOT NULL AND v_longitud IS NOT NULL THEN
    v_cta_url        := 'https://www.google.com/maps?q=' || v_latitud::text || ',' || v_longitud::text;
    v_nota_encuentro := coalesce(v_ubicacion_texto, v_ubicacion, 'Te esperamos en el punto marcado en el mapa.');
  ELSE
    v_cta_url        := 'https://www.instagram.com/woman_social_run/';
    v_nota_encuentro := 'El lugar exacto se confirma por Instagram antes del entrenamiento. Síguenos para no perderte nada.';
  END IF;

  v_html :=
    '<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"/></head>' ||
    '<body style="margin:0;padding:0;background:#FFF0F8;font-family:Helvetica Neue,Arial,sans-serif;">' ||
    '<div style="max-width:560px;margin:0 auto;padding:40px 16px 32px;">' ||
    '<p style="text-align:center;margin:0 0 28px;font-size:9px;letter-spacing:.35em;text-transform:uppercase;color:#D9488C;font-weight:500;">Woman Social Run</p>' ||
    '<div style="background:#fff;border:1px solid #FFD1F1;border-radius:4px;overflow:hidden;">' ||
    '<div style="height:3px;background:linear-gradient(90deg,#D9488C,#F08EC0,#C9A66B);"></div>' ||
    '<div style="padding:48px 40px 28px;text-align:center;">' ||
    '<p style="margin:0 0 14px;font-size:9px;letter-spacing:.32em;text-transform:uppercase;color:#D9488C;opacity:.8;">Inscripción confirmada</p>' ||
    '<h1 style="margin:0;font-family:Georgia,serif;font-size:2.1rem;font-weight:400;color:#3D1020;line-height:1.15;">¡Tu lugar está<br/>confirmado, ' || v_primer_nombre || '!</h1>' ||
    '</div>' ||
    '<div style="margin:0 40px;height:1px;background:linear-gradient(90deg,transparent,rgba(217,72,140,.2),transparent);"></div>' ||
    '<div style="padding:28px 40px 40px;">' ||
    '<p style="margin:0 0 22px;font-size:1rem;color:#5C3248;line-height:1.75;">Te esperamos en el siguiente entrenamiento:</p>' ||
    '<div style="background:#FFF5FB;border:1px solid #FFD1F1;border-left:3px solid #D9488C;border-radius:4px;padding:22px 22px 18px;">' ||
    '<p style="margin:0 0 12px;font-family:Georgia,serif;font-size:1.2rem;font-weight:400;color:#3D1020;line-height:1.3;">' || v_titulo_cap || '</p>' ||
    '<table style="border-collapse:collapse;width:100%;">' ||
    '<tr><td style="padding:5px 0;font-size:.875rem;color:#7B4F60;">📅 ' || v_fecha_txt || '</td></tr>' ||
    '<tr><td style="padding:5px 0;font-size:.875rem;color:#7B4F60;">🕐 ' || v_hora || ' hrs</td></tr>' ||
    v_fila_ubicacion ||
    '</table></div>' ||
    '<div style="margin:22px 0 0;padding:16px 18px;background:#FFF9FB;border:1px solid #FFE6F4;border-radius:4px;">' ||
    '<p style="margin:0;font-size:.875rem;color:#7B4F60;line-height:1.7;"><strong style="color:#5C3248;display:block;margin-bottom:3px;">📍 Punto de encuentro</strong>' || v_nota_encuentro || '</p>' ||
    '</div>' ||
    '<div style="text-align:center;margin:32px 0 8px;">' ||
    '<a href="' || v_cta_url || '" style="display:inline-block;padding:14px 34px;background:#D9488C;color:#fff;text-decoration:none;font-size:.72rem;letter-spacing:.16em;text-transform:uppercase;border-radius:999px;font-weight:500;">Ver punto de encuentro →</a>' ||
    '</div></div></div>' ||
    '<div style="text-align:center;padding:28px 16px 0;font-size:.68rem;color:#B07A90;letter-spacing:.06em;line-height:1.8;">' ||
    '<p style="margin:0;">Woman Social Run · Santiago, Chile</p>' ||
    '<p style="margin:4px 0 0;opacity:.65;">Recibiste este correo porque te inscribiste en un entrenamiento WSR.</p>' ||
    '</div></div></body></html>';

  PERFORM net.http_post(
    url     := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body := jsonb_build_object(
      'from',    'Woman Social Run <felipe@womansocialrun.cl>',
      'to',      ARRAY[NEW.email],
      'subject', '¡Estás inscrita! ' || v_titulo_cap,
      'html',    v_html
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'wsr_confirmar_inscripcion_web: % (training_id=%, email=%)', SQLERRM, NEW.training_id, NEW.email;
  RETURN NEW;
END;
$function$;
GRANT ALL ON FUNCTION public.wsr_confirmar_inscripcion_web() TO anon;
GRANT ALL ON FUNCTION public.wsr_confirmar_inscripcion_web() TO authenticated;
GRANT ALL ON FUNCTION public.wsr_confirmar_inscripcion_web() TO service_role;
CREATE TABLE public.achievements (id uuid DEFAULT gen_random_uuid() NOT NULL, key text NOT NULL, name text NOT NULL, description text NOT NULL, icon_url text DEFAULT ''::text NOT NULL, required_sessions integer, required_streak integer);
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievements ADD CONSTRAINT achievements_key_key UNIQUE (key);
ALTER TABLE public.achievements ADD CONSTRAINT achievements_pkey PRIMARY KEY (id);
GRANT ALL ON public.achievements TO anon;
GRANT ALL ON public.achievements TO authenticated;
GRANT ALL ON public.achievements TO service_role;
CREATE POLICY "Logros públicos" ON public.achievements FOR SELECT USING ((auth.role() = 'authenticated'::text));
CREATE TABLE public.activities (id uuid DEFAULT gen_random_uuid() NOT NULL, user_id uuid NOT NULL, started_at timestamp with time zone NOT NULL, ended_at timestamp with time zone NOT NULL, distance_m integer NOT NULL, duration_s integer NOT NULL, avg_pace_s_per_km integer, route_polyline text, route_storage_path text, feeling public.activity_feeling, title text DEFAULT 'Salí a correr'::text NOT NULL, notes text, is_shared boolean DEFAULT false NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL, visibility text DEFAULT 'followers'::text NOT NULL);
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ADD CONSTRAINT activities_distance_m_check CHECK (distance_m >= 0);
ALTER TABLE public.activities ADD CONSTRAINT activities_duration_s_check CHECK (duration_s >= 0);
ALTER TABLE public.activities ADD CONSTRAINT activities_pkey PRIMARY KEY (id);
ALTER TABLE public.activities ADD CONSTRAINT activities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.activities ADD CONSTRAINT activities_visibility_check CHECK (visibility = ANY (ARRAY['public'::text, 'followers'::text, 'private'::text]));
GRANT ALL ON public.activities TO anon;
GRANT ALL ON public.activities TO authenticated;
GRANT ALL ON public.activities TO service_role;
CREATE INDEX activities_user_idx ON public.activities (user_id, started_at DESC);
CREATE POLICY "Actividades propias" ON public.activities USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Bloqueo oculta actividades" ON public.activities AS RESTRICTIVE FOR SELECT USING ((NOT public.is_blocked_between(user_id)));
CREATE TABLE public.adherence_scores (id uuid DEFAULT gen_random_uuid() NOT NULL, runner_id uuid NOT NULL, scored_date date DEFAULT CURRENT_DATE NOT NULL, score smallint NOT NULL, nivel text NOT NULL, component_a smallint DEFAULT 0 NOT NULL, component_b smallint DEFAULT 0 NOT NULL, component_c smallint DEFAULT 0 NOT NULL, sessions_analyzed integer, checkins_analyzed integer, dias_sin_sesion integer, dias_sin_checkin integer, triggered_by text DEFAULT 'cron'::text NOT NULL, calculated_at timestamp with time zone DEFAULT now() NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.adherence_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.adherence_scores ADD CONSTRAINT adherence_scores_component_a_check CHECK (component_a >= 0 AND component_a <= 40);
ALTER TABLE public.adherence_scores ADD CONSTRAINT adherence_scores_component_b_check CHECK (component_b >= 0 AND component_b <= 35);
ALTER TABLE public.adherence_scores ADD CONSTRAINT adherence_scores_component_c_check CHECK (component_c >= 0 AND component_c <= 25);
ALTER TABLE public.adherence_scores ADD CONSTRAINT adherence_scores_nivel_check CHECK (nivel = ANY (ARRAY['verde'::text, 'amarilla'::text, 'naranja'::text, 'roja'::text]));
ALTER TABLE public.adherence_scores ADD CONSTRAINT adherence_scores_one_per_day UNIQUE (runner_id, scored_date);
ALTER TABLE public.adherence_scores ADD CONSTRAINT adherence_scores_pkey PRIMARY KEY (id);
ALTER TABLE public.adherence_scores ADD CONSTRAINT adherence_scores_score_check CHECK (score >= 0 AND score <= 100);
ALTER TABLE public.adherence_scores ADD CONSTRAINT adherence_scores_triggered_by_check CHECK (triggered_by = ANY (ARRAY['cron'::text, 'webhook'::text, 'manual'::text]));
GRANT ALL ON public.adherence_scores TO anon;
GRANT ALL ON public.adherence_scores TO authenticated;
GRANT ALL ON public.adherence_scores TO service_role;
CREATE INDEX adherence_scores_date_idx ON public.adherence_scores (scored_date DESC);
CREATE INDEX adherence_scores_runner_id_idx ON public.adherence_scores (runner_id);
CREATE INDEX adherence_scores_nivel_idx ON public.adherence_scores (nivel) WHERE nivel = ANY (ARRAY['naranja'::text, 'roja'::text]);
CREATE POLICY adherence_scores_admin_all ON public.adherence_scores TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE POLICY adherence_scores_runner_own ON public.adherence_scores FOR SELECT TO authenticated USING ((runner_id = public.fn_runner_id_for_user()));
CREATE TABLE public.ai_request_log (id bigint DEFAULT nextval('public.ai_request_log_id_seq'::regclass) NOT NULL, user_id uuid NOT NULL, requested_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER SEQUENCE public.ai_request_log_id_seq OWNED BY public.ai_request_log.id;
GRANT ALL ON SEQUENCE public.ai_request_log_id_seq TO anon;
GRANT ALL ON SEQUENCE public.ai_request_log_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.ai_request_log_id_seq TO service_role;
ALTER TABLE public.ai_request_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_request_log ADD CONSTRAINT ai_request_log_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_request_log ADD CONSTRAINT ai_request_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.ai_request_log TO anon;
GRANT ALL ON public.ai_request_log TO authenticated;
GRANT ALL ON public.ai_request_log TO service_role;
CREATE INDEX ai_request_log_user_window_idx ON public.ai_request_log (user_id, requested_at DESC);
CREATE TABLE public.alerts (id uuid DEFAULT gen_random_uuid() NOT NULL, user_id uuid NOT NULL, source text NOT NULL, severity text NOT NULL, payload jsonb DEFAULT '{}'::jsonb NOT NULL, resolved boolean DEFAULT false NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alerts ADD CONSTRAINT alerts_pkey PRIMARY KEY (id);
ALTER TABLE public.alerts ADD CONSTRAINT alerts_severity_check CHECK (severity = ANY (ARRAY['green'::text, 'yellow'::text, 'orange'::text, 'red'::text]));
ALTER TABLE public.alerts ADD CONSTRAINT alerts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.alerts TO anon;
GRANT ALL ON public.alerts TO authenticated;
GRANT ALL ON public.alerts TO service_role;
CREATE INDEX idx_alerts_user_date ON public.alerts (user_id, created_at DESC);
CREATE INDEX idx_alerts_severity ON public.alerts (severity) WHERE resolved = false;
CREATE POLICY "Alert propia (select)" ON public.alerts FOR SELECT USING ((auth.uid() = user_id));
CREATE TABLE public.ambassador_agreements (id uuid DEFAULT gen_random_uuid() NOT NULL, nombre_embajadora text NOT NULL, rut_embajadora text NOT NULL, domicilio_embajadora text NOT NULL, email_embajadora text NOT NULL, fecha_dia integer, fecha_mes text, nombre_carrera text NOT NULL, distancia_carrera text NOT NULL, fechas_proceso text NOT NULL, sponsor_event_id uuid, estado text DEFAULT 'pendiente'::text NOT NULL, token text DEFAULT (gen_random_uuid())::text NOT NULL, fecha_envio_email timestamp with time zone, fecha_aceptacion timestamp with time zone, ip_aceptacion text, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.ambassador_agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ambassador_agreements ADD CONSTRAINT ambassador_agreements_estado_check CHECK (estado = ANY (ARRAY['pendiente'::text, 'aceptado'::text]));
ALTER TABLE public.ambassador_agreements ADD CONSTRAINT ambassador_agreements_pkey PRIMARY KEY (id);
ALTER TABLE public.ambassador_agreements ADD CONSTRAINT ambassador_agreements_token_key UNIQUE (token);
GRANT ALL ON public.ambassador_agreements TO anon;
GRANT ALL ON public.ambassador_agreements TO authenticated;
GRANT ALL ON public.ambassador_agreements TO service_role;
CREATE INDEX ambassador_agreements_token_idx ON public.ambassador_agreements (token);
CREATE INDEX ambassador_agreements_estado_idx ON public.ambassador_agreements (estado);
CREATE INDEX ambassador_agreements_email_idx ON public.ambassador_agreements (email_embajadora);
CREATE POLICY ambassador_agreements_admin_all ON public.ambassador_agreements TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE TABLE public.anamnesis (id uuid DEFAULT gen_random_uuid() NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL, updated_at timestamp with time zone DEFAULT now() NOT NULL, nombre_apellido text NOT NULL, runner_email text, runner_id uuid, token_id uuid, realiza_actividad_fisica boolean DEFAULT false NOT NULL, deporte_actividad text, ritmo_10k text, ritmo_21k text, edad integer DEFAULT 0 NOT NULL, historial_familiar boolean DEFAULT false NOT NULL, historial_familiar_detalle text, patologias_medicas boolean DEFAULT false NOT NULL, patologias_diagnostico text, patologias_fecha_tratamiento text, fuma_cigarrillos boolean DEFAULT false NOT NULL, cigarrillos_por_dia text, hipertension boolean DEFAULT false NOT NULL, hipercolesterolemia boolean DEFAULT false NOT NULL, diabetes boolean DEFAULT false NOT NULL, resistencia_insulina boolean DEFAULT false NOT NULL, toma_alcohol boolean DEFAULT false NOT NULL, condiciones_previas text[] DEFAULT '{}'::text[] NOT NULL, condiciones_previas_otra text, lesiones_musculares boolean DEFAULT false NOT NULL, lesiones_musculares_detalle text, lesiones_articulares boolean DEFAULT false NOT NULL, lesiones_articulares_detalle text, lesiones_oseas boolean DEFAULT false NOT NULL, lesiones_oseas_detalle text, emergencia_nombre text, emergencia_contacto text, clinica_afiliada text, toma_medicamentos boolean DEFAULT false NOT NULL, medicamentos_detalle text, latidos_anormales boolean DEFAULT false NOT NULL, latidos_anormales_cuando text, presion_arterial text, presion_arterial_desconoce boolean DEFAULT false NOT NULL, comidas_por_dia text, descripcion_alimentacion text, suplementos text[] DEFAULT '{}'::text[] NOT NULL, suplementos_otro_detalle text, ultimo_examen_sangre text, nombre_rut_firma text DEFAULT ''::text NOT NULL, autoriza_datos boolean DEFAULT false NOT NULL, fecha_nacimiento date, telefono text, ciudad text, region text, pais text, profesion text, estado_civil text, tiene_hijos boolean, num_hijos smallint, edad_hijos text, nivel_estres smallint, carga_laboral smallint, carga_familiar smallint, horas_sueno text, calidad_sueno smallint, tiempo_para_ti smallint, ha_corrido boolean, tiempo_corriendo text, nivel_runner text, dias_semana_corre smallint, km_por_semana text, ha_trabajado_con_coach boolean, ha_seguido_planes boolean, otros_deportes text, entrenamiento_fuerza text, movilidad_elongacion boolean, objetivo_principal text, objetivo_12_meses text, exito_en_wsr text, dias_puede_entrenar smallint, tiempo_por_sesion text, dias_entrenamiento text[], dia_preferido_largo text, tiene_carrera_objetivo boolean, nombre_carrera text, fecha_carrera text, distancia_carrera text, lesiones_24_meses boolean, descripcion_lesion text, fecha_lesion text, lesion_genera_molestias boolean, dolor_actual smallint, donde_dolor text, operada_5_anos boolean, descripcion_operacion text, medico_restringio_ejercicio boolean, etapa_vital text, ciclo_regular text, sintomas_afectan_entrenamientos boolean, cuales_sintomas text, usa_anticonceptivos_hormonales boolean, tipo_terreno text, temperatura_entrenamiento text, seguridad_corriendo smallint, capacidad_lograr_objetivos smallint, preocupaciones_running text, motivaciones text, motivo_entrar_wsr text, expectativa_comunidad text, que_valoras text[], preferencia_acompanamiento text, semana_dificil_respuesta text, pierde_motivacion text, reflexion_final text, red_flags text[], isapre_afiliada text, consent_health_at timestamp with time zone, consent_ai_at timestamp with time zone, consent_retention_at timestamp with time zone);
COMMENT ON COLUMN public.anamnesis.consent_health_at IS 'Timestamp del consentimiento explícito para tratamiento de datos de salud (condiciones médicas, ciclo vital, lesiones). Art. 2.g Ley 21.719.';
COMMENT ON COLUMN public.anamnesis.consent_ai_at IS 'Timestamp del consentimiento para tratamiento automatizado y cálculo de red_flags por IA. Art. 8 bis Ley 21.719.';
COMMENT ON COLUMN public.anamnesis.consent_retention_at IS 'Timestamp del consentimiento para la política de retención de datos (vigencia de membresía + 2 años). Art. 4 Ley 21.719.';
ALTER TABLE public.anamnesis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_calidad_sueno_check CHECK (calidad_sueno >= 1 AND calidad_sueno <= 10);
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_capacidad_lograr_objetivos_check CHECK (capacidad_lograr_objetivos >= 1 AND capacidad_lograr_objetivos <= 10);
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_carga_familiar_check CHECK (carga_familiar >= 1 AND carga_familiar <= 10);
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_carga_laboral_check CHECK (carga_laboral >= 1 AND carga_laboral <= 10);
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_ciclo_regular_check CHECK (ciclo_regular = ANY (ARRAY['si'::text, 'no'::text, 'no_aplica'::text]));
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_dias_puede_entrenar_check CHECK (dias_puede_entrenar >= 1 AND dias_puede_entrenar <= 7);
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_dias_semana_corre_check CHECK (dias_semana_corre >= 0 AND dias_semana_corre <= 7);
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_dolor_actual_check CHECK (dolor_actual >= 0 AND dolor_actual <= 10);
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_entrenamiento_fuerza_check CHECK (entrenamiento_fuerza = ANY (ARRAY['nunca'::text, 'ocasionalmente'::text, '1_semana'::text, '2_semana'::text, '3_mas_semana'::text]));
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_estado_civil_check CHECK (estado_civil = ANY (ARRAY['soltera'::text, 'casada'::text, 'conviviente'::text, 'separada'::text, 'divorciada'::text, 'viuda'::text, 'prefiero_no_responder'::text]));
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_etapa_vital_check CHECK (etapa_vital = ANY (ARRAY['reproductiva'::text, 'embarazo'::text, 'postparto'::text, 'perimenopausia'::text, 'menopausia'::text, 'prefiero_no_responder'::text]));
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_horas_sueno_check CHECK (horas_sueno = ANY (ARRAY['menos_5'::text, '5_6'::text, '6_7'::text, '7_8'::text, 'mas_8'::text]));
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_nivel_estres_check CHECK (nivel_estres >= 1 AND nivel_estres <= 10);
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_nivel_runner_check CHECK (nivel_runner = ANY (ARRAY['principiante_absoluta'::text, 'principiante'::text, 'intermedia'::text, 'avanzada_recreativa'::text, 'experimentada'::text]));
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_objetivo_principal_check CHECK (objetivo_principal = ANY (ARRAY['comenzar_correr'::text, 'crear_habito'::text, 'mejorar_salud'::text, 'bajar_peso'::text, 'sentirme_mejor'::text, '5k'::text, '10k'::text, '21k'::text, 'trail'::text, 'volver_correr'::text]));
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_pkey PRIMARY KEY (id);
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_preferencia_acompanamiento_check CHECK (preferencia_acompanamiento = ANY (ARRAY['muy_estructurado'::text, 'equilibrado'::text, 'flexible'::text]));
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_ritmo_10k_check CHECK (ritmo_10k = ANY (ARRAY['bajo_4_30'::text, 'entre_4_40_5_0'::text, 'entre_5_30_5_50'::text, 'sobre_6_0'::text]));
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_ritmo_21k_check CHECK (ritmo_21k = ANY (ARRAY['mismos_10k'::text, 'desconozco'::text]));
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_seguridad_corriendo_check CHECK (seguridad_corriendo >= 1 AND seguridad_corriendo <= 10);
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_semana_dificil_respuesta_check CHECK (semana_dificil_respuesta = ANY (ARRAY['mantengo_plan'::text, 'reduzco'::text, 'dejo_de_entrenar'::text, 'depende'::text]));
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_temperatura_entrenamiento_check CHECK (temperatura_entrenamiento = ANY (ARRAY['frio'::text, 'templado'::text, 'caluroso'::text, 'muy_variable'::text]));
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_tiempo_corriendo_check CHECK (tiempo_corriendo = ANY (ARRAY['nunca'::text, 'menos_6m'::text, '6_12m'::text, '1_2a'::text, '2_5a'::text, 'mas_5a'::text]));
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_tiempo_para_ti_check CHECK (tiempo_para_ti >= 1 AND tiempo_para_ti <= 10);
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_tiempo_por_sesion_check CHECK (tiempo_por_sesion = ANY (ARRAY['menos_30'::text, '30_45'::text, '45_60'::text, '60_90'::text, 'mas_90'::text]));
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_tipo_terreno_check CHECK (tipo_terreno = ANY (ARRAY['nivel_mar'::text, 'urbana'::text, 'cerros'::text, 'trail'::text, 'mixto'::text]));
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_ultimo_examen_sangre_check CHECK (ultimo_examen_sangre = ANY (ARRAY['menos_3_meses'::text, 'mas_6_meses'::text, 'mas_2_anos'::text]));
GRANT ALL ON public.anamnesis TO anon;
GRANT ALL ON public.anamnesis TO authenticated;
GRANT ALL ON public.anamnesis TO service_role;
CREATE INDEX anamnesis_red_flags_idx ON public.anamnesis USING gin (red_flags);
CREATE INDEX anamnesis_etapa_vital_idx ON public.anamnesis (etapa_vital);
CREATE INDEX anamnesis_objetivo_idx ON public.anamnesis (objetivo_principal);
CREATE INDEX anamnesis_nivel_runner_idx ON public.anamnesis (nivel_runner);
CREATE INDEX anamnesis_runner_id_idx ON public.anamnesis (runner_id);
CREATE INDEX anamnesis_runner_email_idx ON public.anamnesis (runner_email);
CREATE INDEX anamnesis_nombre_idx ON public.anamnesis (lower(nombre_apellido));
CREATE INDEX anamnesis_created_at_idx ON public.anamnesis (created_at DESC);
CREATE TRIGGER trg_anamnesis_updated_at BEFORE UPDATE ON public.anamnesis FOR EACH ROW EXECUTE FUNCTION public.handle_anamnesis_updated_at();
CREATE POLICY anamnesis_admin_all ON public.anamnesis TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE POLICY anamnesis_public_submit ON public.anamnesis FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY anamnesis_runner_own ON public.anamnesis FOR SELECT TO authenticated USING ((runner_id = public.fn_runner_id_for_user()));
CREATE TABLE public.anamnesis_tokens (id uuid DEFAULT gen_random_uuid() NOT NULL, token text DEFAULT (gen_random_uuid())::text NOT NULL, runner_email text NOT NULL, runner_nombre text, expires_at timestamp with time zone DEFAULT (now() + '30 days'::interval) NOT NULL, used_at timestamp with time zone, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.anamnesis_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.anamnesis_tokens ADD CONSTRAINT anamnesis_tokens_pkey PRIMARY KEY (id);
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_token_id_fkey FOREIGN KEY (token_id) REFERENCES public.anamnesis_tokens(id) ON DELETE SET NULL;
ALTER TABLE public.anamnesis_tokens ADD CONSTRAINT anamnesis_tokens_token_key UNIQUE (token);
GRANT ALL ON public.anamnesis_tokens TO anon;
GRANT ALL ON public.anamnesis_tokens TO authenticated;
GRANT ALL ON public.anamnesis_tokens TO service_role;
CREATE INDEX anamnesis_tokens_created_idx ON public.anamnesis_tokens (created_at DESC);
CREATE INDEX anamnesis_tokens_token_idx ON public.anamnesis_tokens (token);
CREATE INDEX anamnesis_tokens_email_idx ON public.anamnesis_tokens (runner_email);
CREATE POLICY anamnesis_tokens_admin_all ON public.anamnesis_tokens TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE POLICY anamnesis_tokens_anon_mark_used ON public.anamnesis_tokens FOR UPDATE TO anon USING (((used_at IS NULL) AND (expires_at > now()))) WITH CHECK ((used_at IS NOT NULL));
CREATE TABLE public.assessments (id uuid DEFAULT gen_random_uuid() NOT NULL, runner_id uuid NOT NULL, coach_id uuid, assessment_date date DEFAULT CURRENT_DATE NOT NULL, assessment_type text DEFAULT 'initial'::text NOT NULL, resting_hr integer, max_hr_estimated integer, vo2max_estimate numeric(5,2), pace_5k text, pace_10k text, pace_21k text, weight_kg numeric(5,2), height_cm numeric(5,2), lactate_threshold_pace text, anaerobic_threshold_hr integer, endurance_score numeric(5,1), strength_score numeric(5,1), mobility_score numeric(5,1), overall_score numeric(5,1), observations text, created_at timestamp with time zone DEFAULT now() NOT NULL, updated_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assessments ADD CONSTRAINT assessments_anaerobic_threshold_hr_check CHECK (anaerobic_threshold_hr IS NULL OR anaerobic_threshold_hr >= 100 AND anaerobic_threshold_hr <= 220);
ALTER TABLE public.assessments ADD CONSTRAINT assessments_assessment_type_check CHECK (assessment_type = ANY (ARRAY['initial'::text, 'periodic'::text, 'post_injury'::text, 'pre_competition'::text]));
ALTER TABLE public.assessments ADD CONSTRAINT assessments_coach_id_fkey FOREIGN KEY (coach_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.assessments ADD CONSTRAINT assessments_endurance_score_check CHECK (endurance_score IS NULL OR endurance_score >= 0::numeric AND endurance_score <= 100::numeric);
ALTER TABLE public.assessments ADD CONSTRAINT assessments_height_cm_check CHECK (height_cm IS NULL OR height_cm >= 100::numeric AND height_cm <= 250::numeric);
ALTER TABLE public.assessments ADD CONSTRAINT assessments_max_hr_estimated_check CHECK (max_hr_estimated >= 100 AND max_hr_estimated <= 220);
ALTER TABLE public.assessments ADD CONSTRAINT assessments_mobility_score_check CHECK (mobility_score IS NULL OR mobility_score >= 0::numeric AND mobility_score <= 100::numeric);
ALTER TABLE public.assessments ADD CONSTRAINT assessments_overall_score_check CHECK (overall_score IS NULL OR overall_score >= 0::numeric AND overall_score <= 100::numeric);
ALTER TABLE public.assessments ADD CONSTRAINT assessments_pkey PRIMARY KEY (id);
ALTER TABLE public.assessments ADD CONSTRAINT assessments_resting_hr_check CHECK (resting_hr >= 30 AND resting_hr <= 120);
ALTER TABLE public.assessments ADD CONSTRAINT assessments_strength_score_check CHECK (strength_score IS NULL OR strength_score >= 0::numeric AND strength_score <= 100::numeric);
ALTER TABLE public.assessments ADD CONSTRAINT assessments_vo2max_estimate_check CHECK (vo2max_estimate >= 10::numeric AND vo2max_estimate <= 90::numeric);
ALTER TABLE public.assessments ADD CONSTRAINT assessments_weight_kg_check CHECK (weight_kg IS NULL OR weight_kg >= 30::numeric AND weight_kg <= 200::numeric);
GRANT ALL ON public.assessments TO anon;
GRANT ALL ON public.assessments TO authenticated;
GRANT ALL ON public.assessments TO service_role;
CREATE INDEX assessments_runner_id_idx ON public.assessments (runner_id);
CREATE INDEX assessments_type_idx ON public.assessments (assessment_type);
CREATE INDEX assessments_date_idx ON public.assessments (assessment_date DESC);
CREATE TRIGGER trg_assessments_updated_at BEFORE UPDATE ON public.assessments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_timestamp();
CREATE POLICY assessments_admin_all ON public.assessments TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE POLICY assessments_runner_own ON public.assessments FOR SELECT TO authenticated USING ((runner_id = public.fn_runner_id_for_user()));
CREATE TABLE public.blocked_users (blocker_id uuid NOT NULL, blocked_id uuid NOT NULL, reason text, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ADD CONSTRAINT blocked_users_blocked_id_fkey FOREIGN KEY (blocked_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.blocked_users ADD CONSTRAINT blocked_users_blocker_id_fkey FOREIGN KEY (blocker_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.blocked_users ADD CONSTRAINT blocked_users_check CHECK (blocker_id <> blocked_id);
ALTER TABLE public.blocked_users ADD CONSTRAINT blocked_users_pkey PRIMARY KEY (blocker_id, blocked_id);
GRANT ALL ON public.blocked_users TO anon;
GRANT ALL ON public.blocked_users TO authenticated;
GRANT ALL ON public.blocked_users TO service_role;
CREATE INDEX blocked_users_blocked_idx ON public.blocked_users (blocked_id);
CREATE TRIGGER trg_purge_follows_on_block AFTER INSERT ON public.blocked_users FOR EACH ROW EXECUTE FUNCTION public.purge_follows_on_block();
CREATE POLICY "Bloquear" ON public.blocked_users FOR INSERT WITH CHECK ((blocker_id = auth.uid()));
CREATE POLICY "Desbloquear" ON public.blocked_users FOR DELETE USING ((blocker_id = auth.uid()));
CREATE POLICY "Ver mis bloqueos" ON public.blocked_users FOR SELECT USING ((blocker_id = auth.uid()));
CREATE TABLE public.channel_participants (id uuid DEFAULT gen_random_uuid() NOT NULL, channel_id uuid NOT NULL, user_id uuid NOT NULL, role public.participant_role DEFAULT 'member'::public.participant_role NOT NULL, joined_at timestamp with time zone DEFAULT now() NOT NULL, last_read_at timestamp with time zone DEFAULT now() NOT NULL, is_muted boolean DEFAULT false NOT NULL);
ALTER TABLE public.channel_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channel_participants ADD CONSTRAINT channel_participants_channel_id_user_id_key UNIQUE (channel_id, user_id);
ALTER TABLE public.channel_participants ADD CONSTRAINT channel_participants_pkey PRIMARY KEY (id);
ALTER TABLE public.channel_participants ADD CONSTRAINT channel_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.channel_participants TO anon;
GRANT ALL ON public.channel_participants TO authenticated;
GRANT ALL ON public.channel_participants TO service_role;
CREATE INDEX channel_participants_channel_idx ON public.channel_participants (channel_id);
CREATE INDEX channel_participants_user_idx ON public.channel_participants (user_id);
CREATE POLICY "Actualizar membresía propia o admin" ON public.channel_participants FOR UPDATE USING (((user_id = auth.uid()) OR public.is_channel_admin(channel_id))) WITH CHECK (((user_id = auth.uid()) OR public.is_channel_admin(channel_id)));
CREATE POLICY "Salir del canal o admin remueve" ON public.channel_participants FOR DELETE USING (((user_id = auth.uid()) OR public.is_channel_admin(channel_id)));
CREATE POLICY "Ver participantes de mis canales" ON public.channel_participants FOR SELECT USING (public.is_channel_participant(channel_id));
CREATE TABLE public.channels (id uuid DEFAULT gen_random_uuid() NOT NULL, type public.channel_type NOT NULL, name text, description text, avatar_url text, created_by uuid, last_message_at timestamp with time zone, is_archived boolean DEFAULT false NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL, updated_at timestamp with time zone DEFAULT now() NOT NULL, topic text);
CREATE POLICY "Unirse a community o admin agrega" ON public.channel_participants FOR INSERT WITH CHECK ((((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM public.channels c
  WHERE ((c.id = channel_participants.channel_id) AND (c.type = 'community'::public.channel_type))))) OR public.is_channel_admin(channel_id)));
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels ADD CONSTRAINT channels_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.channels ADD CONSTRAINT channels_name_required CHECK (type = 'direct'::public.channel_type OR name IS NOT NULL AND length(TRIM(BOTH FROM name)) > 0);
ALTER TABLE public.channels ADD CONSTRAINT channels_pkey PRIMARY KEY (id);
ALTER TABLE public.channel_participants ADD CONSTRAINT channel_participants_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES public.channels(id) ON DELETE CASCADE;
GRANT ALL ON public.channels TO anon;
GRANT ALL ON public.channels TO authenticated;
GRANT ALL ON public.channels TO service_role;
CREATE INDEX channels_dm_activity_idx ON public.channels (last_message_at DESC NULLS LAST) WHERE type = ANY (ARRAY['direct'::public.channel_type, 'group'::public.channel_type]);
CREATE POLICY "Admin edita el canal" ON public.channels FOR UPDATE USING (public.is_channel_admin(id)) WITH CHECK (public.is_channel_admin(id));
CREATE POLICY "Crear canal propio" ON public.channels FOR INSERT WITH CHECK ((created_by = auth.uid()));
CREATE POLICY "Ver canales propios o community" ON public.channels FOR SELECT USING ((public.is_channel_participant(id) OR (type = 'community'::public.channel_type)));
CREATE TABLE public.checkins (id uuid DEFAULT gen_random_uuid() NOT NULL, user_id uuid NOT NULL, energy smallint NOT NULL, sleep smallint NOT NULL, motivation smallint NOT NULL, pain smallint NOT NULL, trainings_completed smallint DEFAULT 0 NOT NULL, note text, week_start date DEFAULT (date_trunc('week'::text, now()))::date NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL);
CREATE FUNCTION public.get_my_week_checkin()
 RETURNS public.checkins
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row        checkins;
  v_week_start DATE := date_trunc('week', NOW())::DATE;
BEGIN
  SELECT * INTO v_row
  FROM checkins
  WHERE user_id   = auth.uid()
    AND week_start = v_week_start
  LIMIT 1;

  RETURN v_row;
END;
$function$;
GRANT ALL ON FUNCTION public.get_my_week_checkin() TO anon;
GRANT ALL ON FUNCTION public.get_my_week_checkin() TO authenticated;
GRANT ALL ON FUNCTION public.get_my_week_checkin() TO service_role;
CREATE FUNCTION public.submit_weekly_checkin(p_energy smallint, p_sleep smallint, p_motivation smallint, p_pain smallint, p_trainings_completed smallint, p_note text DEFAULT NULL::text)
 RETURNS public.checkins
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row        checkins;
  v_week_start DATE := date_trunc('week', NOW())::DATE;
BEGIN
  INSERT INTO checkins (
    user_id, energy, sleep, motivation, pain,
    trainings_completed, note, week_start
  ) VALUES (
    auth.uid(), p_energy, p_sleep, p_motivation, p_pain,
    p_trainings_completed, p_note, v_week_start
  )
  ON CONFLICT (user_id, week_start) DO UPDATE SET
    energy              = EXCLUDED.energy,
    sleep               = EXCLUDED.sleep,
    motivation          = EXCLUDED.motivation,
    pain                = EXCLUDED.pain,
    trainings_completed = EXCLUDED.trainings_completed,
    note                = EXCLUDED.note
  RETURNING * INTO v_row;

  IF p_pain >= 6 THEN
    INSERT INTO alerts (user_id, source, severity, payload)
    VALUES (
      auth.uid(), 'checkin_pain', 'orange',
      jsonb_build_object('pain', p_pain, 'checkin_id', v_row.id, 'week_start', v_week_start)
    )
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN v_row;
END;
$function$;
GRANT ALL ON FUNCTION public.submit_weekly_checkin(smallint, smallint, smallint, smallint, smallint, text) TO anon;
GRANT ALL ON FUNCTION public.submit_weekly_checkin(smallint, smallint, smallint, smallint, smallint, text) TO authenticated;
GRANT ALL ON FUNCTION public.submit_weekly_checkin(smallint, smallint, smallint, smallint, smallint, text) TO service_role;
ALTER TABLE public.checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checkins ADD CONSTRAINT checkins_energy_check CHECK (energy >= 1 AND energy <= 10);
ALTER TABLE public.checkins ADD CONSTRAINT checkins_motivation_check CHECK (motivation >= 1 AND motivation <= 10);
ALTER TABLE public.checkins ADD CONSTRAINT checkins_pain_check CHECK (pain >= 0 AND pain <= 10);
ALTER TABLE public.checkins ADD CONSTRAINT checkins_pkey PRIMARY KEY (id);
ALTER TABLE public.checkins ADD CONSTRAINT checkins_sleep_check CHECK (sleep >= 1 AND sleep <= 10);
ALTER TABLE public.checkins ADD CONSTRAINT checkins_trainings_completed_check CHECK (trainings_completed >= 0 AND trainings_completed <= 100);
ALTER TABLE public.checkins ADD CONSTRAINT checkins_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.checkins ADD CONSTRAINT checkins_user_week_unique UNIQUE (user_id, week_start);
GRANT ALL ON public.checkins TO anon;
GRANT ALL ON public.checkins TO authenticated;
GRANT ALL ON public.checkins TO service_role;
CREATE INDEX idx_checkins_user_week ON public.checkins (user_id, week_start DESC);
CREATE POLICY "Checkin propio" ON public.checkins USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));
CREATE TABLE public.emotional_checkins (id uuid DEFAULT gen_random_uuid() NOT NULL, user_id uuid NOT NULL, energy smallint NOT NULL, mood text NOT NULL, note text, created_at timestamp with time zone DEFAULT now() NOT NULL);
CREATE FUNCTION public.get_recent_checkins(p_limit integer DEFAULT 7)
 RETURNS SETOF public.emotional_checkins
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT *
  FROM emotional_checkins
  WHERE user_id = auth.uid()
  ORDER BY created_at DESC
  LIMIT p_limit;
END;
$function$;
GRANT ALL ON FUNCTION public.get_recent_checkins(integer) TO anon;
GRANT ALL ON FUNCTION public.get_recent_checkins(integer) TO authenticated;
GRANT ALL ON FUNCTION public.get_recent_checkins(integer) TO service_role;
CREATE FUNCTION public.submit_emotional_checkin(p_energy smallint, p_mood text, p_note text DEFAULT NULL::text)
 RETURNS public.emotional_checkins
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row emotional_checkins;
BEGIN
  INSERT INTO emotional_checkins (user_id, energy, mood, note)
  VALUES (auth.uid(), p_energy, p_mood, p_note)
  RETURNING * INTO v_row;

  PERFORM record_user_activity(auth.uid());

  RETURN v_row;
END;
$function$;
GRANT ALL ON FUNCTION public.submit_emotional_checkin(smallint, text, text) TO anon;
GRANT ALL ON FUNCTION public.submit_emotional_checkin(smallint, text, text) TO authenticated;
GRANT ALL ON FUNCTION public.submit_emotional_checkin(smallint, text, text) TO service_role;
ALTER TABLE public.emotional_checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emotional_checkins ADD CONSTRAINT emotional_checkins_energy_check CHECK (energy >= 1 AND energy <= 5);
ALTER TABLE public.emotional_checkins ADD CONSTRAINT emotional_checkins_mood_check CHECK (mood = ANY (ARRAY['agotada'::text, 'tranquila'::text, 'bien'::text, 'fuerte'::text, 'radiante'::text]));
ALTER TABLE public.emotional_checkins ADD CONSTRAINT emotional_checkins_pkey PRIMARY KEY (id);
ALTER TABLE public.emotional_checkins ADD CONSTRAINT emotional_checkins_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.emotional_checkins TO anon;
GRANT ALL ON public.emotional_checkins TO authenticated;
GRANT ALL ON public.emotional_checkins TO service_role;
CREATE INDEX idx_emotional_checkins_user_date ON public.emotional_checkins (user_id, created_at DESC);
CREATE POLICY "Check-ins propios" ON public.emotional_checkins USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));
CREATE TABLE public.event_code_pool (id uuid DEFAULT gen_random_uuid() NOT NULL, sponsor_event_id uuid NOT NULL, codigo text NOT NULL, tipo_beneficio text NOT NULL, usado boolean DEFAULT false NOT NULL, distancia text, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.event_code_pool ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_code_pool ADD CONSTRAINT event_code_pool_pkey PRIMARY KEY (id);
ALTER TABLE public.event_code_pool ADD CONSTRAINT event_code_pool_sponsor_event_id_codigo_key UNIQUE (sponsor_event_id, codigo);
ALTER TABLE public.event_code_pool ADD CONSTRAINT event_code_pool_tipo_beneficio_check CHECK (tipo_beneficio = ANY (ARRAY['entrada'::text, 'descuento'::text]));
GRANT ALL ON public.event_code_pool TO anon;
GRANT ALL ON public.event_code_pool TO authenticated;
GRANT ALL ON public.event_code_pool TO service_role;
CREATE INDEX event_code_pool_available_idx ON public.event_code_pool (sponsor_event_id, tipo_beneficio, usado);
CREATE POLICY event_code_pool_admin_all ON public.event_code_pool TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE TABLE public.event_winners (id uuid DEFAULT gen_random_uuid() NOT NULL, sponsor_event_id uuid NOT NULL, runner_id uuid, nombre_externo text, email_externo text, tipo_beneficio text NOT NULL, fecha_asignacion timestamp with time zone DEFAULT now() NOT NULL, origen_entrada text, distancia text, codigo text, created_at timestamp with time zone DEFAULT now() NOT NULL, updated_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.event_winners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_winners ADD CONSTRAINT event_winners_identidad_chk CHECK (runner_id IS NOT NULL OR nombre_externo IS NOT NULL);
ALTER TABLE public.event_winners ADD CONSTRAINT event_winners_origen_entrada_chk CHECK (tipo_beneficio = 'entrada'::text AND (origen_entrada = ANY (ARRAY['sorteo'::text, 'acuerdo'::text])) OR tipo_beneficio = 'descuento'::text AND origen_entrada IS NULL);
ALTER TABLE public.event_winners ADD CONSTRAINT event_winners_pkey PRIMARY KEY (id);
ALTER TABLE public.event_winners ADD CONSTRAINT event_winners_tipo_beneficio_check CHECK (tipo_beneficio = ANY (ARRAY['entrada'::text, 'descuento'::text]));
GRANT ALL ON public.event_winners TO anon;
GRANT ALL ON public.event_winners TO authenticated;
GRANT ALL ON public.event_winners TO service_role;
CREATE INDEX event_winners_sponsor_event_idx ON public.event_winners (sponsor_event_id);
CREATE INDEX event_winners_runner_idx ON public.event_winners (runner_id);
CREATE INDEX event_winners_origen_idx ON public.event_winners (origen_entrada) WHERE origen_entrada IS NOT NULL;
CREATE INDEX event_winners_tipo_idx ON public.event_winners (tipo_beneficio);
CREATE TRIGGER trg_event_winners_updated_at BEFORE UPDATE ON public.event_winners FOR EACH ROW EXECUTE FUNCTION public.handle_event_winners_updated_at();
CREATE POLICY event_winners_admin_all ON public.event_winners TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE TABLE public.feed_posts (id uuid DEFAULT gen_random_uuid() NOT NULL, author_id uuid NOT NULL, post_type public.post_type NOT NULL, ref_id uuid, body text, media_urls text[] DEFAULT '{}'::text[] NOT NULL, visibility public.post_visibility DEFAULT 'followers'::public.post_visibility NOT NULL, likes_count integer DEFAULT 0 NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.feed_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feed_posts ADD CONSTRAINT feed_posts_author_id_fkey FOREIGN KEY (author_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.feed_posts ADD CONSTRAINT feed_posts_pkey PRIMARY KEY (id);
GRANT ALL ON public.feed_posts TO anon;
GRANT ALL ON public.feed_posts TO authenticated;
GRANT ALL ON public.feed_posts TO service_role;
CREATE INDEX feed_posts_author_idx ON public.feed_posts (author_id, created_at DESC);
CREATE INDEX feed_posts_created_idx ON public.feed_posts (created_at DESC);
CREATE POLICY "Bloqueo oculta posts" ON public.feed_posts AS RESTRICTIVE FOR SELECT USING ((NOT public.is_blocked_between(author_id)));
CREATE POLICY "Borrar lo propio" ON public.feed_posts FOR DELETE USING ((auth.uid() = author_id));
CREATE POLICY "Editar lo propio" ON public.feed_posts FOR UPDATE USING ((auth.uid() = author_id));
CREATE POLICY "Publicar lo propio" ON public.feed_posts FOR INSERT WITH CHECK ((auth.uid() = author_id));
CREATE TABLE public.follows (follower_id uuid NOT NULL, following_id uuid NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL);
CREATE POLICY "Ver actividades compartidas de seguidas" ON public.activities FOR SELECT USING ((is_shared AND (EXISTS ( SELECT 1
   FROM public.follows f
  WHERE ((f.follower_id = auth.uid()) AND (f.following_id = activities.user_id))))));
CREATE POLICY "Ver feed" ON public.feed_posts FOR SELECT USING (((author_id = auth.uid()) OR (visibility = 'public'::public.post_visibility) OR ((visibility = 'followers'::public.post_visibility) AND (EXISTS ( SELECT 1
   FROM public.follows f
  WHERE ((f.follower_id = auth.uid()) AND (f.following_id = feed_posts.author_id)))))));
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ADD CONSTRAINT follows_check CHECK (follower_id <> following_id);
ALTER TABLE public.follows ADD CONSTRAINT follows_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.follows ADD CONSTRAINT follows_following_id_fkey FOREIGN KEY (following_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.follows ADD CONSTRAINT follows_pkey PRIMARY KEY (follower_id, following_id);
GRANT ALL ON public.follows TO anon;
GRANT ALL ON public.follows TO authenticated;
GRANT ALL ON public.follows TO service_role;
CREATE INDEX follows_following_idx ON public.follows (following_id);
CREATE POLICY "Dejar de seguir" ON public.follows FOR DELETE USING ((auth.uid() = follower_id));
CREATE POLICY "Seguir" ON public.follows FOR INSERT WITH CHECK ((auth.uid() = follower_id));
CREATE POLICY "Ver follows" ON public.follows FOR SELECT USING ((auth.role() = 'authenticated'::text));
CREATE TABLE public.gdpr_deletion_log (id uuid DEFAULT gen_random_uuid() NOT NULL, runner_id uuid NOT NULL, deleted_at timestamp with time zone DEFAULT now() NOT NULL, requested_by uuid, reason text DEFAULT 'Solicitud de supresión Art. 4 Ley 21.719'::text NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL);
COMMENT ON TABLE public.gdpr_deletion_log IS 'Log de auditoría de supresiones por Derecho al Olvido (Art. 4 Ley 21.719). Inmutable. Sin FK a runners — la titular ya no existe al momento del registro.';
COMMENT ON COLUMN public.gdpr_deletion_log.runner_id IS 'UUID de la runner eliminada. Deliberadamente sin FK (la runner fue borrada).';
COMMENT ON COLUMN public.gdpr_deletion_log.requested_by IS 'auth.uid() del administrador que ejecutó la supresión.';
ALTER TABLE public.gdpr_deletion_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gdpr_deletion_log ADD CONSTRAINT gdpr_deletion_log_pkey PRIMARY KEY (id);
GRANT ALL ON public.gdpr_deletion_log TO anon;
GRANT ALL ON public.gdpr_deletion_log TO authenticated;
GRANT ALL ON public.gdpr_deletion_log TO service_role;
CREATE INDEX gdpr_deletion_log_runner_idx ON public.gdpr_deletion_log (runner_id);
CREATE INDEX gdpr_deletion_log_deleted_at_idx ON public.gdpr_deletion_log (deleted_at DESC);
CREATE POLICY gdpr_log_admin_all ON public.gdpr_deletion_log TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE TABLE public.health_alerts (id uuid DEFAULT gen_random_uuid() NOT NULL, runner_id uuid NOT NULL, check_in_id uuid, session_id uuid, alert_type text NOT NULL, severity text DEFAULT 'naranja'::text NOT NULL, reason text NOT NULL, status text DEFAULT 'pendiente'::text NOT NULL, resolved_at timestamp with time zone, resolved_by uuid, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.health_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_alerts ADD CONSTRAINT health_alerts_alert_type_check CHECK (alert_type = ANY (ARRAY['dolor'::text, 'cumplimiento'::text, 'adherencia'::text]));
ALTER TABLE public.health_alerts ADD CONSTRAINT health_alerts_pkey PRIMARY KEY (id);
ALTER TABLE public.health_alerts ADD CONSTRAINT health_alerts_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.health_alerts ADD CONSTRAINT health_alerts_severity_check CHECK (severity = ANY (ARRAY['amarilla'::text, 'naranja'::text, 'roja'::text]));
ALTER TABLE public.health_alerts ADD CONSTRAINT health_alerts_status_check CHECK (status = ANY (ARRAY['pendiente'::text, 'atendida'::text, 'descartada'::text]));
GRANT ALL ON public.health_alerts TO anon;
GRANT ALL ON public.health_alerts TO authenticated;
GRANT ALL ON public.health_alerts TO service_role;
CREATE INDEX health_alerts_adherencia_day_idx ON public.health_alerts (runner_id, created_at) WHERE alert_type = 'adherencia'::text;
CREATE INDEX health_alerts_status_idx ON public.health_alerts (status) WHERE status = 'pendiente'::text;
CREATE INDEX health_alerts_check_in_idx ON public.health_alerts (check_in_id) WHERE check_in_id IS NOT NULL;
CREATE INDEX health_alerts_session_idx ON public.health_alerts (session_id) WHERE session_id IS NOT NULL;
CREATE INDEX health_alerts_runner_id_idx ON public.health_alerts (runner_id);
CREATE POLICY health_alerts_admin_all ON public.health_alerts TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE TABLE public.health_profiles (id uuid DEFAULT gen_random_uuid() NOT NULL, runner_id uuid NOT NULL, has_hypertension boolean DEFAULT false NOT NULL, has_diabetes boolean DEFAULT false NOT NULL, has_heart_history boolean DEFAULT false NOT NULL, has_cholesterol boolean DEFAULT false NOT NULL, has_insulin_resistance boolean DEFAULT false NOT NULL, is_smoker boolean DEFAULT false NOT NULL, has_active_injury boolean DEFAULT false NOT NULL, injury_detail text, has_joint_condition boolean DEFAULT false NOT NULL, has_bone_condition boolean DEFAULT false NOT NULL, takes_medication boolean DEFAULT false NOT NULL, medication_detail text, emergency_name text, emergency_phone text, clinic_affiliation text, last_updated_by uuid, source_anamnesis_id uuid, profile_complete boolean DEFAULT false NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL, updated_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.health_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_profiles ADD CONSTRAINT health_profiles_last_updated_by_fkey FOREIGN KEY (last_updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.health_profiles ADD CONSTRAINT health_profiles_pkey PRIMARY KEY (id);
ALTER TABLE public.health_profiles ADD CONSTRAINT health_profiles_runner_id_key UNIQUE (runner_id);
GRANT ALL ON public.health_profiles TO anon;
GRANT ALL ON public.health_profiles TO authenticated;
GRANT ALL ON public.health_profiles TO service_role;
CREATE INDEX health_profiles_risk_idx ON public.health_profiles (runner_id) WHERE has_hypertension OR has_diabetes OR has_heart_history OR has_active_injury;
CREATE INDEX health_profiles_runner_id_idx ON public.health_profiles (runner_id);
CREATE TRIGGER trg_health_profiles_updated_at BEFORE UPDATE ON public.health_profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_timestamp();
CREATE POLICY health_profiles_admin_all ON public.health_profiles TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE POLICY health_profiles_runner_own ON public.health_profiles FOR SELECT TO authenticated USING ((runner_id = public.fn_runner_id_for_user()));
CREATE TABLE public.legacy_web_registrations (id uuid DEFAULT gen_random_uuid() NOT NULL, runner_id uuid, training_ref_id uuid, fecha_inscripcion timestamp with time zone DEFAULT now() NOT NULL, estado_reserva text DEFAULT 'confirmada'::text NOT NULL, contacto_emergencia text DEFAULT ''::text NOT NULL, condicion_medica text, respuestas_extra jsonb, asistio boolean DEFAULT false NOT NULL, web_id uuid, migrated_at timestamp with time zone DEFAULT now() NOT NULL, reconciled boolean DEFAULT false NOT NULL, app_registration_id uuid, created_at timestamp with time zone DEFAULT now() NOT NULL, updated_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.legacy_web_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.legacy_web_registrations ADD CONSTRAINT legacy_web_registrations_estado_reserva_check CHECK (estado_reserva = ANY (ARRAY['confirmada'::text, 'cancelada'::text]));
ALTER TABLE public.legacy_web_registrations ADD CONSTRAINT legacy_web_registrations_pkey PRIMARY KEY (id);
ALTER TABLE public.legacy_web_registrations ADD CONSTRAINT legacy_web_registrations_web_id_key UNIQUE (web_id);
GRANT ALL ON public.legacy_web_registrations TO anon;
GRANT ALL ON public.legacy_web_registrations TO authenticated;
GRANT ALL ON public.legacy_web_registrations TO service_role;
CREATE INDEX legacy_web_regs_runner_idx ON public.legacy_web_registrations (runner_id);
CREATE INDEX legacy_web_regs_reconciled_idx ON public.legacy_web_registrations (reconciled) WHERE reconciled = false;
CREATE INDEX legacy_web_regs_training_ref_idx ON public.legacy_web_registrations (training_ref_id);
CREATE TRIGGER trg_legacy_web_regs_updated_at BEFORE UPDATE ON public.legacy_web_registrations FOR EACH ROW EXECUTE FUNCTION public.set_legacy_web_regs_updated_at();
CREATE POLICY legacy_web_regs_admin_all ON public.legacy_web_registrations TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE TABLE public.legacy_web_trainings (id uuid DEFAULT gen_random_uuid() NOT NULL, titulo_entrenamiento text NOT NULL, fecha_hora timestamp with time zone NOT NULL, ubicacion text, cupos_totales integer, estado text DEFAULT 'activo'::text NOT NULL, preguntas_extra jsonb, web_id uuid, migrated_at timestamp with time zone DEFAULT now() NOT NULL, reconciled boolean DEFAULT false NOT NULL, app_training_id uuid, created_at timestamp with time zone DEFAULT now() NOT NULL, updated_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.legacy_web_trainings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.legacy_web_trainings ADD CONSTRAINT legacy_web_trainings_estado_check CHECK (estado = ANY (ARRAY['activo'::text, 'cerrado'::text]));
ALTER TABLE public.legacy_web_trainings ADD CONSTRAINT legacy_web_trainings_pkey PRIMARY KEY (id);
ALTER TABLE public.legacy_web_trainings ADD CONSTRAINT legacy_web_trainings_web_id_key UNIQUE (web_id);
GRANT ALL ON public.legacy_web_trainings TO anon;
GRANT ALL ON public.legacy_web_trainings TO authenticated;
GRANT ALL ON public.legacy_web_trainings TO service_role;
CREATE INDEX legacy_web_trainings_reconciled_idx ON public.legacy_web_trainings (reconciled) WHERE reconciled = false;
CREATE INDEX legacy_web_trainings_fecha_idx ON public.legacy_web_trainings (fecha_hora);
CREATE TRIGGER trg_legacy_web_trainings_updated_at BEFORE UPDATE ON public.legacy_web_trainings FOR EACH ROW EXECUTE FUNCTION public.set_legacy_web_trainings_updated_at();
CREATE POLICY legacy_web_trainings_admin_all ON public.legacy_web_trainings TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE TABLE public.loyalty_tiers (tier public.loyalty_tier NOT NULL, display_name text NOT NULL, emoji text NOT NULL, color_hex text NOT NULL, min_points integer NOT NULL, max_points integer, perks jsonb DEFAULT '[]'::jsonb NOT NULL, sort_order smallint NOT NULL);
ALTER TABLE public.loyalty_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_tiers ADD CONSTRAINT loyalty_tiers_pkey PRIMARY KEY (tier);
GRANT ALL ON public.loyalty_tiers TO anon;
GRANT ALL ON public.loyalty_tiers TO authenticated;
GRANT ALL ON public.loyalty_tiers TO service_role;
CREATE POLICY "Niveles públicos" ON public.loyalty_tiers FOR SELECT USING (true);
CREATE TABLE public.messages (id uuid DEFAULT gen_random_uuid() NOT NULL, channel_id uuid NOT NULL, sender_id uuid NOT NULL, body text NOT NULL, kind public.message_kind DEFAULT 'text'::public.message_kind NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL, edited_at timestamp with time zone, deleted_at timestamp with time zone);
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages REPLICA IDENTITY FULL;
ALTER TABLE public.messages ADD CONSTRAINT messages_body_check CHECK (char_length(body) >= 1 AND char_length(body) <= 4000);
ALTER TABLE public.messages ADD CONSTRAINT messages_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES public.channels(id) ON DELETE CASCADE;
ALTER TABLE public.messages ADD CONSTRAINT messages_pkey PRIMARY KEY (id);
ALTER TABLE public.messages ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.messages TO anon;
GRANT ALL ON public.messages TO authenticated;
GRANT ALL ON public.messages TO service_role;
CREATE INDEX messages_channel_idx ON public.messages (channel_id, created_at DESC);
CREATE TRIGGER trg_bump_channel_on_message AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.bump_channel_on_message();
CREATE TRIGGER trg_notify_new_message AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_message();
CREATE POLICY "Bloqueo impide enviar DM" ON public.messages AS RESTRICTIVE FOR INSERT WITH CHECK ((NOT public.channel_has_block(channel_id)));
CREATE POLICY "Bloqueo oculta mensajes" ON public.messages AS RESTRICTIVE FOR SELECT USING ((NOT public.is_blocked_between(sender_id)));
CREATE POLICY "Editar mis propios mensajes" ON public.messages FOR UPDATE USING ((sender_id = auth.uid())) WITH CHECK ((sender_id = auth.uid()));
CREATE POLICY "Enviar mensajes a mis canales" ON public.messages FOR INSERT WITH CHECK (((sender_id = auth.uid()) AND public.is_channel_participant(channel_id)));
CREATE POLICY "Leer mensajes de mis canales" ON public.messages FOR SELECT USING (public.is_channel_participant(channel_id));
CREATE TABLE public.notifications (id uuid DEFAULT gen_random_uuid() NOT NULL, user_id uuid NOT NULL, kind public.notification_kind DEFAULT 'general'::public.notification_kind NOT NULL, title text NOT NULL, body text DEFAULT ''::text NOT NULL, ref_id uuid, ref_type text, is_read boolean DEFAULT false NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);
ALTER TABLE public.notifications ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.notifications TO anon;
GRANT ALL ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;
CREATE INDEX idx_notifications_user_created ON public.notifications (user_id, created_at DESC);
CREATE INDEX idx_notifications_user_unread ON public.notifications (user_id) WHERE is_read = false;
CREATE TRIGGER on_notification_insert AFTER INSERT ON public.notifications FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request('https://thirekzbfbwchstvcqxw.supabase.co/functions/v1/send-push-notification', 'POST', '{"Content-type":"application/json","Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoaXJla3piZmJ3Y2hzdHZjcXh3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTQ3NzY3NCwiZXhwIjoyMDk1MDUzNjc0fQ.Ac5CwAbjsLC-GwTqH4Cuqn3ma8OizREBYm0AfWdOo1Y","x-webhook-secret":"WEBHOOK_SECRET"}', '{}', '8000');
CREATE POLICY notifications_insert_blocked ON public.notifications FOR INSERT WITH CHECK (false);
CREATE POLICY notifications_select_own ON public.notifications FOR SELECT USING ((auth.uid() = user_id));
CREATE POLICY notifications_update_own ON public.notifications FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));
CREATE TABLE public.pacers (id uuid DEFAULT gen_random_uuid() NOT NULL, name text NOT NULL, bio text DEFAULT ''::text NOT NULL, avatar_url text DEFAULT ''::text NOT NULL, specialty text DEFAULT ''::text NOT NULL, is_active boolean DEFAULT true NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL, user_id uuid);
ALTER TABLE public.pacers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pacers ADD CONSTRAINT pacers_pkey PRIMARY KEY (id);
ALTER TABLE public.pacers ADD CONSTRAINT pacers_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
GRANT ALL ON public.pacers TO anon;
GRANT ALL ON public.pacers TO authenticated;
GRANT ALL ON public.pacers TO service_role;
CREATE UNIQUE INDEX pacers_user_idx ON public.pacers (user_id) WHERE user_id IS NOT NULL;
CREATE POLICY "Pacers públicos" ON public.pacers FOR SELECT USING ((auth.role() = 'authenticated'::text));
CREATE TABLE public.personal_trainings (id uuid DEFAULT gen_random_uuid() NOT NULL, runner_id uuid NOT NULL, coach_id uuid NOT NULL, title text NOT NULL, description text, scheduled_date date NOT NULL, training_type text, target_distance_km numeric(5,2), target_notes text, status public.personal_training_status DEFAULT 'assigned'::public.personal_training_status NOT NULL, completed_at timestamp with time zone, runner_feeling public.training_feeling, runner_notes text, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.personal_trainings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personal_trainings ADD CONSTRAINT personal_trainings_coach_id_fkey FOREIGN KEY (coach_id) REFERENCES auth.users(id);
ALTER TABLE public.personal_trainings ADD CONSTRAINT personal_trainings_pkey PRIMARY KEY (id);
ALTER TABLE public.personal_trainings ADD CONSTRAINT personal_trainings_runner_id_fkey FOREIGN KEY (runner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.personal_trainings TO anon;
GRANT ALL ON public.personal_trainings TO authenticated;
GRANT ALL ON public.personal_trainings TO service_role;
CREATE INDEX personal_trainings_coach_idx ON public.personal_trainings (coach_id, scheduled_date);
CREATE INDEX personal_trainings_runner_idx ON public.personal_trainings (runner_id, scheduled_date);
CREATE POLICY "Coach asigna entrenamientos" ON public.personal_trainings FOR INSERT WITH CHECK ((public.has_role(auth.uid(), 'coach'::public.app_role) OR public.has_role(auth.uid(), 'admin'::public.app_role)));
CREATE POLICY "Coach borra lo asignado" ON public.personal_trainings FOR DELETE USING (((auth.uid() = coach_id) OR public.has_role(auth.uid(), 'admin'::public.app_role)));
CREATE POLICY "Coach edita lo asignado" ON public.personal_trainings FOR UPDATE USING (((auth.uid() = coach_id) OR public.has_role(auth.uid(), 'admin'::public.app_role)));
CREATE POLICY "Runner completa lo suyo" ON public.personal_trainings FOR UPDATE USING ((auth.uid() = runner_id)) WITH CHECK ((auth.uid() = runner_id));
CREATE POLICY "Ver entrenamientos personales propios" ON public.personal_trainings FOR SELECT USING (((auth.uid() = runner_id) OR (auth.uid() = coach_id) OR public.has_role(auth.uid(), 'admin'::public.app_role)));
CREATE TABLE public.plan_check_ins (id uuid DEFAULT gen_random_uuid() NOT NULL, runner_id uuid NOT NULL, plan_id uuid, week_start date DEFAULT (date_trunc('week'::text, (now() AT TIME ZONE 'America/Santiago'::text)))::date NOT NULL, sessions_planned integer NOT NULL, sessions_completed integer NOT NULL, compliance_pct numeric(5,1) GENERATED ALWAYS AS (round((((sessions_completed)::numeric / (sessions_planned)::numeric) * (100)::numeric), 1)) STORED, energy smallint NOT NULL, sleep_quality smallint NOT NULL, motivation smallint NOT NULL, pain smallint NOT NULL, pain_location text, life_changes boolean DEFAULT false NOT NULL, life_changes_detail text, comments text, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.plan_check_ins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plan_check_ins ADD CONSTRAINT plan_check_ins_completed_lte_planned CHECK (sessions_completed <= sessions_planned);
ALTER TABLE public.plan_check_ins ADD CONSTRAINT plan_check_ins_energy_check CHECK (energy >= 1 AND energy <= 10);
ALTER TABLE public.plan_check_ins ADD CONSTRAINT plan_check_ins_motivation_check CHECK (motivation >= 1 AND motivation <= 10);
ALTER TABLE public.plan_check_ins ADD CONSTRAINT plan_check_ins_one_per_week UNIQUE (runner_id, week_start);
ALTER TABLE public.plan_check_ins ADD CONSTRAINT plan_check_ins_pain_check CHECK (pain >= 0 AND pain <= 10);
ALTER TABLE public.plan_check_ins ADD CONSTRAINT plan_check_ins_pkey PRIMARY KEY (id);
ALTER TABLE public.health_alerts ADD CONSTRAINT health_alerts_check_in_id_fkey FOREIGN KEY (check_in_id) REFERENCES public.plan_check_ins(id) ON DELETE SET NULL;
ALTER TABLE public.plan_check_ins ADD CONSTRAINT plan_check_ins_sessions_completed_check CHECK (sessions_completed >= 0);
ALTER TABLE public.plan_check_ins ADD CONSTRAINT plan_check_ins_sessions_planned_check CHECK (sessions_planned >= 1 AND sessions_planned <= 14);
ALTER TABLE public.plan_check_ins ADD CONSTRAINT plan_check_ins_sleep_quality_check CHECK (sleep_quality >= 1 AND sleep_quality <= 10);
GRANT ALL ON public.plan_check_ins TO anon;
GRANT ALL ON public.plan_check_ins TO authenticated;
GRANT ALL ON public.plan_check_ins TO service_role;
CREATE INDEX plan_check_ins_plan_id_idx ON public.plan_check_ins (plan_id) WHERE plan_id IS NOT NULL;
CREATE INDEX plan_check_ins_week_start_idx ON public.plan_check_ins (week_start DESC);
CREATE INDEX plan_check_ins_runner_id_idx ON public.plan_check_ins (runner_id);
CREATE TRIGGER plan_check_ins_adaptation_trigger AFTER INSERT ON public.plan_check_ins FOR EACH ROW EXECUTE FUNCTION public.fn_check_in_adaptation();
CREATE POLICY plan_check_ins_admin_all ON public.plan_check_ins TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE POLICY plan_check_ins_runner_own ON public.plan_check_ins FOR SELECT TO authenticated USING ((runner_id = public.fn_runner_id_for_user()));
CREATE TABLE public.plans (id uuid DEFAULT gen_random_uuid() NOT NULL, runner_id uuid NOT NULL, coach_id uuid, title text NOT NULL, goal text, current_level text DEFAULT 'beginner'::text NOT NULL, weekly_km_base numeric(6,2), days_per_week integer DEFAULT 3 NOT NULL, notes text, coach_message text, status text DEFAULT 'draft'::text NOT NULL, generated_at timestamp with time zone, approved_at timestamp with time zone, delivered_at timestamp with time zone, delivered_to text, version integer DEFAULT 0 NOT NULL, version_tag text DEFAULT '1.0'::text NOT NULL, parent_plan_id uuid, pdf_url text, pdf_version integer DEFAULT 0 NOT NULL, pdf_generated_at timestamp with time zone, created_at timestamp with time zone DEFAULT now() NOT NULL, updated_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plans ADD CONSTRAINT plans_coach_id_fkey FOREIGN KEY (coach_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.plans ADD CONSTRAINT plans_current_level_check CHECK (current_level = ANY (ARRAY['beginner'::text, 'intermediate'::text, 'advanced'::text]));
ALTER TABLE public.plans ADD CONSTRAINT plans_days_per_week_check CHECK (days_per_week >= 1 AND days_per_week <= 7);
ALTER TABLE public.plans ADD CONSTRAINT plans_pkey PRIMARY KEY (id);
ALTER TABLE public.plan_check_ins ADD CONSTRAINT plan_check_ins_plan_id_fk FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE SET NULL;
ALTER TABLE public.plans ADD CONSTRAINT plans_parent_plan_id_fkey FOREIGN KEY (parent_plan_id) REFERENCES public.plans(id) ON DELETE SET NULL;
ALTER TABLE public.plans ADD CONSTRAINT plans_status_check CHECK (status = ANY (ARRAY['draft'::text, 'review'::text, 'approved'::text, 'active'::text, 'completed'::text, 'archived'::text]));
GRANT ALL ON public.plans TO anon;
GRANT ALL ON public.plans TO authenticated;
GRANT ALL ON public.plans TO service_role;
CREATE INDEX plans_status_idx ON public.plans (status);
CREATE INDEX plans_parent_id_idx ON public.plans (parent_plan_id) WHERE parent_plan_id IS NOT NULL;
CREATE INDEX plans_active_runner_idx ON public.plans (runner_id) WHERE status = 'active'::text;
CREATE INDEX plans_runner_id_idx ON public.plans (runner_id);
CREATE INDEX plans_coach_id_idx ON public.plans (coach_id);
CREATE TRIGGER trg_plans_updated_at BEFORE UPDATE ON public.plans FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_timestamp();
CREATE POLICY plans_admin_all ON public.plans TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE POLICY plans_coach_own ON public.plans TO authenticated USING ((public.fn_is_coach() AND (coach_id = auth.uid()))) WITH CHECK ((public.fn_is_coach() AND (coach_id = auth.uid())));
CREATE POLICY plans_runner_own ON public.plans FOR SELECT TO authenticated USING ((runner_id = public.fn_runner_id_for_user()));
CREATE TABLE public.point_campaigns (id uuid DEFAULT gen_random_uuid() NOT NULL, name text NOT NULL, description text, multiplier numeric(3,1) DEFAULT 1.0 NOT NULL, applies_to_event text, bonus_points integer DEFAULT 0 NOT NULL, starts_at timestamp with time zone NOT NULL, ends_at timestamp with time zone NOT NULL, is_active boolean DEFAULT true NOT NULL);
ALTER TABLE public.point_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.point_campaigns ADD CONSTRAINT point_campaigns_check CHECK (ends_at > starts_at);
ALTER TABLE public.point_campaigns ADD CONSTRAINT point_campaigns_pkey PRIMARY KEY (id);
GRANT ALL ON public.point_campaigns TO anon;
GRANT ALL ON public.point_campaigns TO authenticated;
GRANT ALL ON public.point_campaigns TO service_role;
CREATE POLICY "Campañas públicas" ON public.point_campaigns FOR SELECT USING (is_active);
CREATE TABLE public.point_rules (event_type text NOT NULL, display_name text NOT NULL, category text NOT NULL, points integer NOT NULL, max_per_period integer, period text, is_active boolean DEFAULT true NOT NULL, description text NOT NULL);
ALTER TABLE public.point_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.point_rules ADD CONSTRAINT point_rules_pkey PRIMARY KEY (event_type);
GRANT ALL ON public.point_rules TO anon;
GRANT ALL ON public.point_rules TO authenticated;
GRANT ALL ON public.point_rules TO service_role;
CREATE POLICY "Reglas públicas" ON public.point_rules FOR SELECT USING (is_active);
CREATE TABLE public.point_transactions (id uuid DEFAULT gen_random_uuid() NOT NULL, user_id uuid NOT NULL, points integer NOT NULL, event_type text NOT NULL, reference_id uuid, description text NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.point_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.point_transactions ADD CONSTRAINT point_transactions_pkey PRIMARY KEY (id);
ALTER TABLE public.point_transactions ADD CONSTRAINT point_transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.point_transactions TO anon;
GRANT ALL ON public.point_transactions TO authenticated;
GRANT ALL ON public.point_transactions TO service_role;
CREATE TRIGGER record_activity_on_points AFTER INSERT ON public.point_transactions FOR EACH ROW EXECUTE FUNCTION public.trg_record_activity_on_points();
CREATE POLICY "Usuarias ven sus propios puntos" ON public.point_transactions FOR SELECT USING ((auth.uid() = user_id));
CREATE TABLE public.post_likes (post_id uuid NOT NULL, user_id uuid NOT NULL, reaction public.reaction_kind DEFAULT 'apoyo'::public.reaction_kind NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ADD CONSTRAINT post_likes_pkey PRIMARY KEY (post_id, user_id);
ALTER TABLE public.post_likes ADD CONSTRAINT post_likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.feed_posts(id) ON DELETE CASCADE;
ALTER TABLE public.post_likes ADD CONSTRAINT post_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.post_likes TO anon;
GRANT ALL ON public.post_likes TO authenticated;
GRANT ALL ON public.post_likes TO service_role;
CREATE TRIGGER post_likes_count_sync AFTER INSERT OR DELETE ON public.post_likes FOR EACH ROW EXECUTE FUNCTION public.sync_post_likes_count();
CREATE TRIGGER trg_notify_post_reaction AFTER INSERT ON public.post_likes FOR EACH ROW EXECUTE FUNCTION public.notify_on_post_reaction();
CREATE POLICY "Quitar reacción" ON public.post_likes FOR DELETE USING ((auth.uid() = user_id));
CREATE POLICY "Reaccionar" ON public.post_likes FOR INSERT WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Ver reacciones" ON public.post_likes FOR SELECT USING ((auth.role() = 'authenticated'::text));
CREATE TABLE public.reactivation_log (id uuid DEFAULT gen_random_uuid() NOT NULL, user_id uuid NOT NULL, stage smallint NOT NULL, sent_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.reactivation_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reactivation_log ADD CONSTRAINT reactivation_log_pkey PRIMARY KEY (id);
ALTER TABLE public.reactivation_log ADD CONSTRAINT reactivation_log_stage_check CHECK (stage = ANY (ARRAY[3, 10, 21]));
ALTER TABLE public.reactivation_log ADD CONSTRAINT reactivation_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.reactivation_log ADD CONSTRAINT reactivation_log_user_id_stage_key UNIQUE (user_id, stage);
GRANT ALL ON public.reactivation_log TO anon;
GRANT ALL ON public.reactivation_log TO authenticated;
GRANT ALL ON public.reactivation_log TO service_role;
CREATE POLICY "Reactivación propia (lectura)" ON public.reactivation_log FOR SELECT USING ((auth.uid() = user_id));
CREATE TABLE public.referrals (id uuid DEFAULT gen_random_uuid() NOT NULL, referrer_id uuid NOT NULL, referred_id uuid, referred_email text, referral_code text DEFAULT substr(md5(((random())::text || (clock_timestamp())::text)), 1, 8) NOT NULL, status public.referral_status DEFAULT 'pending'::public.referral_status NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL, qualified_at timestamp with time zone);
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ADD CONSTRAINT referrals_pkey PRIMARY KEY (id);
ALTER TABLE public.referrals ADD CONSTRAINT referrals_referral_code_key UNIQUE (referral_code);
ALTER TABLE public.referrals ADD CONSTRAINT referrals_referred_id_fkey FOREIGN KEY (referred_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.referrals ADD CONSTRAINT referrals_referrer_id_fkey FOREIGN KEY (referrer_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.referrals TO anon;
GRANT ALL ON public.referrals TO authenticated;
GRANT ALL ON public.referrals TO service_role;
CREATE INDEX idx_referrals_code ON public.referrals (referral_code);
CREATE INDEX idx_referrals_referrer ON public.referrals (referrer_id);
CREATE POLICY "Crear mi referido" ON public.referrals FOR INSERT WITH CHECK ((auth.uid() = referrer_id));
CREATE POLICY "Mis referidos" ON public.referrals FOR SELECT USING ((auth.uid() = referrer_id));
CREATE TABLE public.registrations (id uuid DEFAULT gen_random_uuid() NOT NULL, training_id uuid NOT NULL, user_id uuid NOT NULL, status public.registration_status DEFAULT 'confirmed'::public.registration_status NOT NULL, registered_at timestamp with time zone DEFAULT now() NOT NULL, cancelled_at timestamp with time zone, tiene_condicion_medica boolean DEFAULT false NOT NULL, condiciones_declaradas text[], anexo_a_requerido boolean DEFAULT false NOT NULL, anexo_a_aceptado_en timestamp with time zone, anexo_a_vigencia date);
ALTER TABLE public.registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registrations ADD CONSTRAINT registrations_pkey PRIMARY KEY (id);
ALTER TABLE public.registrations ADD CONSTRAINT registrations_training_id_user_id_key UNIQUE (training_id, user_id);
ALTER TABLE public.registrations ADD CONSTRAINT registrations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.registrations TO anon;
GRANT ALL ON public.registrations TO authenticated;
GRANT ALL ON public.registrations TO service_role;
CREATE TRIGGER on_registration_confirmed AFTER INSERT OR UPDATE OF status ON public.registrations FOR EACH ROW EXECUTE FUNCTION public.trigger_evaluate_achievements();
CREATE TRIGGER trigger_promote_on_cancel AFTER UPDATE ON public.registrations FOR EACH ROW EXECUTE FUNCTION public.handle_registration_cancelled();
CREATE POLICY "Cancelar inscripción propia" ON public.registrations FOR UPDATE USING ((auth.uid() = user_id));
CREATE POLICY "Crear inscripción propia" ON public.registrations FOR INSERT WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Ver inscripción propia" ON public.registrations FOR SELECT USING ((auth.uid() = user_id));
CREATE TABLE public.reported_content (id uuid DEFAULT gen_random_uuid() NOT NULL, reporter_id uuid NOT NULL, reported_user_id uuid NOT NULL, content_type public.report_target NOT NULL, content_id uuid, reason public.report_reason NOT NULL, details text, status public.report_status DEFAULT 'pendiente'::public.report_status NOT NULL, reviewed_by uuid, reviewed_at timestamp with time zone, resolution_note text, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.reported_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reported_content ADD CONSTRAINT reported_content_check CHECK (reporter_id <> reported_user_id);
ALTER TABLE public.reported_content ADD CONSTRAINT reported_content_pkey PRIMARY KEY (id);
ALTER TABLE public.reported_content ADD CONSTRAINT reported_content_reported_user_id_fkey FOREIGN KEY (reported_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.reported_content ADD CONSTRAINT reported_content_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.reported_content ADD CONSTRAINT reported_content_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES auth.users(id) ON DELETE SET NULL;
GRANT ALL ON public.reported_content TO anon;
GRANT ALL ON public.reported_content TO authenticated;
GRANT ALL ON public.reported_content TO service_role;
CREATE INDEX reported_content_reporter_idx ON public.reported_content (reporter_id);
CREATE INDEX reported_content_status_idx ON public.reported_content (status, created_at);
CREATE POLICY "Moderación resuelve reportes" ON public.reported_content FOR UPDATE USING ((public.has_role(auth.uid(), 'moderator'::public.app_role) OR public.has_role(auth.uid(), 'admin'::public.app_role))) WITH CHECK ((public.has_role(auth.uid(), 'moderator'::public.app_role) OR public.has_role(auth.uid(), 'admin'::public.app_role)));
CREATE POLICY "Reportar contenido" ON public.reported_content FOR INSERT WITH CHECK (((reporter_id = auth.uid()) AND (reporter_id <> reported_user_id)));
CREATE POLICY "Ver reportes: autora o admin" ON public.reported_content FOR SELECT USING (((reporter_id = auth.uid()) OR public.has_role(auth.uid(), 'admin'::public.app_role)));
CREATE TABLE public.reward_redemptions (id uuid DEFAULT gen_random_uuid() NOT NULL, user_id uuid NOT NULL, reward_id uuid NOT NULL, points_spent integer NOT NULL, status public.redemption_status DEFAULT 'pending'::public.redemption_status NOT NULL, redemption_code text, admin_notes text, requested_at timestamp with time zone DEFAULT now() NOT NULL, approved_at timestamp with time zone, delivered_at timestamp with time zone);
ALTER TABLE public.reward_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_redemptions ADD CONSTRAINT reward_redemptions_pkey PRIMARY KEY (id);
ALTER TABLE public.reward_redemptions ADD CONSTRAINT reward_redemptions_points_spent_check CHECK (points_spent > 0);
ALTER TABLE public.reward_redemptions ADD CONSTRAINT reward_redemptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.reward_redemptions TO anon;
GRANT ALL ON public.reward_redemptions TO authenticated;
GRANT ALL ON public.reward_redemptions TO service_role;
CREATE INDEX idx_redemptions_status ON public.reward_redemptions (status);
CREATE INDEX idx_redemptions_user ON public.reward_redemptions (user_id);
CREATE POLICY "Mis canjes" ON public.reward_redemptions FOR SELECT USING ((auth.uid() = user_id));
CREATE TABLE public.rewards_catalog (id uuid DEFAULT gen_random_uuid() NOT NULL, name text NOT NULL, description text NOT NULL, category text NOT NULL, emoji text DEFAULT '🎁'::text NOT NULL, image_url text, points_cost integer NOT NULL, required_tier public.loyalty_tier, sponsor_id uuid, stock integer, redemption_instructions text NOT NULL, is_active boolean DEFAULT true NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.rewards_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rewards_catalog ADD CONSTRAINT rewards_catalog_pkey PRIMARY KEY (id);
ALTER TABLE public.reward_redemptions ADD CONSTRAINT reward_redemptions_reward_id_fkey FOREIGN KEY (reward_id) REFERENCES public.rewards_catalog(id);
ALTER TABLE public.rewards_catalog ADD CONSTRAINT rewards_catalog_points_cost_check CHECK (points_cost > 0);
GRANT ALL ON public.rewards_catalog TO anon;
GRANT ALL ON public.rewards_catalog TO authenticated;
GRANT ALL ON public.rewards_catalog TO service_role;
CREATE POLICY "Catálogo público" ON public.rewards_catalog FOR SELECT USING (is_active);
CREATE TABLE public.runner_profiles (id uuid DEFAULT gen_random_uuid() NOT NULL, runner_id uuid NOT NULL, user_profile_id uuid, linked_at timestamp with time zone DEFAULT now() NOT NULL, linked_by uuid, is_verified boolean DEFAULT false NOT NULL, verification_note text, created_at timestamp with time zone DEFAULT now() NOT NULL, updated_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.runner_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.runner_profiles ADD CONSTRAINT runner_profiles_linked_by_fkey FOREIGN KEY (linked_by) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.runner_profiles ADD CONSTRAINT runner_profiles_pkey PRIMARY KEY (id);
ALTER TABLE public.runner_profiles ADD CONSTRAINT runner_profiles_runner_id_key UNIQUE (runner_id);
ALTER TABLE public.runner_profiles ADD CONSTRAINT runner_profiles_user_profile_id_key UNIQUE (user_profile_id);
GRANT ALL ON public.runner_profiles TO anon;
GRANT ALL ON public.runner_profiles TO authenticated;
GRANT ALL ON public.runner_profiles TO service_role;
CREATE INDEX runner_profiles_user_profile_id_idx ON public.runner_profiles (user_profile_id) WHERE user_profile_id IS NOT NULL;
CREATE INDEX runner_profiles_runner_id_idx ON public.runner_profiles (runner_id);
CREATE TRIGGER trg_runner_profiles_updated_at BEFORE UPDATE ON public.runner_profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_timestamp();
CREATE POLICY runner_profiles_admin_all ON public.runner_profiles TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE POLICY runner_profiles_runner_own ON public.runner_profiles FOR SELECT TO authenticated USING ((runner_id = public.fn_runner_id_for_user()));
CREATE TABLE public.runners (id uuid DEFAULT gen_random_uuid() NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL, updated_at timestamp with time zone DEFAULT now() NOT NULL, nombre_apellido text NOT NULL, email text NOT NULL, comuna text, instagram_usuario text, telefono text, fecha_nacimiento date, estado_civil text, tiene_hijos text, nivel_educativo text, ocupacion text, talla_polera text, frecuencia_deporte text, participa_carreras text, intereses_hobbies text, productos_interes text, sigue_marcas text, redes_sociales text, interaccion_marcas text, formato_contenido text, autoriza_datos boolean DEFAULT false, control_envio text DEFAULT 'pendiente'::text, status text DEFAULT 'activa'::text, coach_id uuid, user_id uuid);
CREATE POLICY adherence_scores_coach_read ON public.adherence_scores FOR SELECT TO authenticated USING ((public.fn_is_coach() AND (runner_id IN ( SELECT runners.id
   FROM public.runners
  WHERE (runners.coach_id = auth.uid())))));
CREATE POLICY anamnesis_coach_read ON public.anamnesis FOR SELECT TO authenticated USING ((public.fn_is_coach() AND (runner_id IN ( SELECT runners.id
   FROM public.runners
  WHERE (runners.coach_id = auth.uid())))));
CREATE POLICY assessments_coach_all ON public.assessments TO authenticated USING ((public.fn_is_coach() AND (runner_id IN ( SELECT runners.id
   FROM public.runners
  WHERE (runners.coach_id = auth.uid()))))) WITH CHECK ((public.fn_is_coach() AND (runner_id IN ( SELECT runners.id
   FROM public.runners
  WHERE (runners.coach_id = auth.uid())))));
CREATE POLICY health_alerts_coach_select ON public.health_alerts FOR SELECT TO authenticated USING ((public.fn_is_coach() AND (runner_id IN ( SELECT runners.id
   FROM public.runners
  WHERE (runners.coach_id = auth.uid())))));
CREATE POLICY health_alerts_coach_update ON public.health_alerts FOR UPDATE TO authenticated USING ((public.fn_is_coach() AND (runner_id IN ( SELECT runners.id
   FROM public.runners
  WHERE (runners.coach_id = auth.uid()))))) WITH CHECK ((public.fn_is_coach() AND (runner_id IN ( SELECT runners.id
   FROM public.runners
  WHERE (runners.coach_id = auth.uid())))));
CREATE POLICY health_profiles_coach_select ON public.health_profiles FOR SELECT TO authenticated USING ((public.fn_is_coach() AND (runner_id IN ( SELECT runners.id
   FROM public.runners
  WHERE (runners.coach_id = auth.uid())))));
CREATE POLICY health_profiles_coach_update ON public.health_profiles FOR UPDATE TO authenticated USING ((public.fn_is_coach() AND (runner_id IN ( SELECT runners.id
   FROM public.runners
  WHERE (runners.coach_id = auth.uid()))))) WITH CHECK ((public.fn_is_coach() AND (runner_id IN ( SELECT runners.id
   FROM public.runners
  WHERE (runners.coach_id = auth.uid())))));
CREATE POLICY legacy_web_regs_coach_read ON public.legacy_web_registrations FOR SELECT TO authenticated USING ((public.fn_is_coach() AND (runner_id IN ( SELECT runners.id
   FROM public.runners
  WHERE (runners.coach_id = auth.uid())))));
CREATE POLICY plan_check_ins_coach_read ON public.plan_check_ins FOR SELECT TO authenticated USING ((public.fn_is_coach() AND (runner_id IN ( SELECT runners.id
   FROM public.runners
  WHERE (runners.coach_id = auth.uid())))));
CREATE POLICY runner_profiles_coach_read ON public.runner_profiles FOR SELECT TO authenticated USING ((public.fn_is_coach() AND (runner_id IN ( SELECT runners.id
   FROM public.runners
  WHERE (runners.coach_id = auth.uid())))));
ALTER TABLE public.runners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.runners ADD CONSTRAINT runners_coach_id_fkey FOREIGN KEY (coach_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.runners ADD CONSTRAINT runners_pkey PRIMARY KEY (id);
ALTER TABLE public.adherence_scores ADD CONSTRAINT adherence_scores_runner_id_fkey FOREIGN KEY (runner_id) REFERENCES public.runners(id) ON DELETE CASCADE;
ALTER TABLE public.anamnesis ADD CONSTRAINT anamnesis_runner_id_fkey FOREIGN KEY (runner_id) REFERENCES public.runners(id) ON DELETE CASCADE;
ALTER TABLE public.assessments ADD CONSTRAINT assessments_runner_id_fkey FOREIGN KEY (runner_id) REFERENCES public.runners(id) ON DELETE CASCADE;
ALTER TABLE public.event_winners ADD CONSTRAINT event_winners_runner_id_fkey FOREIGN KEY (runner_id) REFERENCES public.runners(id) ON DELETE SET NULL;
ALTER TABLE public.health_alerts ADD CONSTRAINT health_alerts_runner_id_fkey FOREIGN KEY (runner_id) REFERENCES public.runners(id) ON DELETE CASCADE;
ALTER TABLE public.health_profiles ADD CONSTRAINT health_profiles_runner_id_fkey FOREIGN KEY (runner_id) REFERENCES public.runners(id) ON DELETE CASCADE;
ALTER TABLE public.legacy_web_registrations ADD CONSTRAINT legacy_web_registrations_runner_id_fkey FOREIGN KEY (runner_id) REFERENCES public.runners(id) ON DELETE SET NULL;
ALTER TABLE public.plan_check_ins ADD CONSTRAINT plan_check_ins_runner_id_fkey FOREIGN KEY (runner_id) REFERENCES public.runners(id) ON DELETE CASCADE;
ALTER TABLE public.plans ADD CONSTRAINT plans_runner_id_fkey FOREIGN KEY (runner_id) REFERENCES public.runners(id) ON DELETE CASCADE;
ALTER TABLE public.runner_profiles ADD CONSTRAINT runner_profiles_runner_id_fkey FOREIGN KEY (runner_id) REFERENCES public.runners(id) ON DELETE CASCADE;
ALTER TABLE public.runners ADD CONSTRAINT runners_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
GRANT ALL ON public.runners TO anon;
GRANT ALL ON public.runners TO authenticated;
GRANT ALL ON public.runners TO service_role;
CREATE UNIQUE INDEX runners_email_unique_idx ON public.runners (lower(email));
CREATE INDEX runners_coach_id_idx ON public.runners (coach_id);
CREATE INDEX runners_user_id_idx ON public.runners (user_id);
CREATE INDEX runners_created_at_idx ON public.runners (created_at DESC);
CREATE INDEX runners_email_idx ON public.runners (email);
CREATE TRIGGER trg_runners_updated_at BEFORE UPDATE ON public.runners FOR EACH ROW EXECUTE FUNCTION public.set_runners_updated_at();
CREATE POLICY runners_admin_all ON public.runners TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE POLICY runners_anon_insert ON public.runners FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY runners_coach_select ON public.runners FOR SELECT TO authenticated USING ((public.fn_is_coach() AND (coach_id = auth.uid())));
CREATE POLICY runners_coach_update ON public.runners FOR UPDATE TO authenticated USING ((public.fn_is_coach() AND (coach_id = auth.uid()))) WITH CHECK ((public.fn_is_coach() AND (coach_id = auth.uid())));
CREATE POLICY runners_runner_own ON public.runners FOR SELECT TO authenticated USING ((user_id = auth.uid()));
CREATE TABLE public.scores (id uuid DEFAULT gen_random_uuid() NOT NULL, runner_id uuid NOT NULL, plan_id uuid, assessment_date date DEFAULT CURRENT_DATE NOT NULL, vo2max_estimate numeric(5,2), lactate_threshold_pace text, endurance_score numeric(5,1), strength_score numeric(5,1), mobility_score numeric(5,1), overall_score numeric(5,1), notes text, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scores ADD CONSTRAINT scores_pkey PRIMARY KEY (id);
ALTER TABLE public.scores ADD CONSTRAINT scores_plan_id_fk FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE SET NULL;
ALTER TABLE public.scores ADD CONSTRAINT scores_runner_id_fkey FOREIGN KEY (runner_id) REFERENCES public.runners(id) ON DELETE CASCADE;
GRANT ALL ON public.scores TO anon;
GRANT ALL ON public.scores TO authenticated;
GRANT ALL ON public.scores TO service_role;
CREATE INDEX scores_runner_id_idx ON public.scores (runner_id);
CREATE INDEX scores_plan_id_idx ON public.scores (plan_id) WHERE plan_id IS NOT NULL;
CREATE INDEX scores_date_idx ON public.scores (assessment_date DESC);
CREATE POLICY scores_admin_all ON public.scores TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE POLICY scores_coach_all ON public.scores TO authenticated USING ((public.fn_is_coach() AND (runner_id IN ( SELECT runners.id
   FROM public.runners
  WHERE (runners.coach_id = auth.uid()))))) WITH CHECK ((public.fn_is_coach() AND (runner_id IN ( SELECT runners.id
   FROM public.runners
  WHERE (runners.coach_id = auth.uid())))));
CREATE POLICY scores_runner_own ON public.scores FOR SELECT TO authenticated USING ((runner_id = public.fn_runner_id_for_user()));
CREATE TABLE public.session_results (id uuid DEFAULT gen_random_uuid() NOT NULL, training_session_id uuid NOT NULL, runner_id uuid NOT NULL, plan_id uuid, actual_duration_min integer, actual_distance_km numeric(5,2), actual_rpe smallint, pain_score smallint DEFAULT 0 NOT NULL, pain_location text, notes text, source text DEFAULT 'app'::text NOT NULL, completed_at timestamp with time zone DEFAULT now() NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER PUBLICATION supabase_realtime ADD TABLE public.channel_participants, TABLE public.health_alerts, TABLE public.messages, TABLE public.notifications, TABLE public.session_results;
ALTER TABLE public.session_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_results ADD CONSTRAINT session_results_actual_distance_km_check CHECK (actual_distance_km IS NULL OR actual_distance_km >= 0::numeric);
ALTER TABLE public.session_results ADD CONSTRAINT session_results_actual_duration_min_check CHECK (actual_duration_min IS NULL OR actual_duration_min >= 0 AND actual_duration_min <= 600);
ALTER TABLE public.session_results ADD CONSTRAINT session_results_actual_rpe_check CHECK (actual_rpe IS NULL OR actual_rpe >= 0 AND actual_rpe <= 10);
ALTER TABLE public.session_results ADD CONSTRAINT session_results_pain_score_check CHECK (pain_score >= 0 AND pain_score <= 10);
ALTER TABLE public.session_results ADD CONSTRAINT session_results_pkey PRIMARY KEY (id);
ALTER TABLE public.health_alerts ADD CONSTRAINT health_alerts_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.session_results(id) ON DELETE SET NULL;
ALTER TABLE public.session_results ADD CONSTRAINT session_results_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE SET NULL;
ALTER TABLE public.session_results ADD CONSTRAINT session_results_runner_id_fkey FOREIGN KEY (runner_id) REFERENCES public.runners(id) ON DELETE CASCADE;
ALTER TABLE public.session_results ADD CONSTRAINT session_results_source_check CHECK (source = ANY (ARRAY['app'::text, 'web'::text, 'clone'::text]));
ALTER TABLE public.session_results ADD CONSTRAINT session_results_training_session_id_key UNIQUE (training_session_id);
GRANT ALL ON public.session_results TO anon;
GRANT ALL ON public.session_results TO authenticated;
GRANT ALL ON public.session_results TO service_role;
CREATE INDEX session_results_pain_idx ON public.session_results (pain_score) WHERE pain_score >= 6;
CREATE INDEX session_results_runner_id_idx ON public.session_results (runner_id);
CREATE INDEX session_results_plan_id_idx ON public.session_results (plan_id) WHERE plan_id IS NOT NULL;
CREATE POLICY session_results_admin_all ON public.session_results TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE POLICY session_results_coach_read ON public.session_results FOR SELECT TO authenticated USING ((public.fn_is_coach() AND (runner_id IN ( SELECT runners.id
   FROM public.runners
  WHERE (runners.coach_id = auth.uid())))));
CREATE POLICY session_results_runner_own ON public.session_results FOR SELECT TO authenticated USING ((runner_id = public.fn_runner_id_for_user()));
CREATE TABLE public.sponsor_events (id uuid DEFAULT gen_random_uuid() NOT NULL, nombre_carrera text NOT NULL, cupos_entradas integer DEFAULT 0 NOT NULL, cupos_descuentos integer DEFAULT 0 NOT NULL, estado text DEFAULT 'activo'::text NOT NULL, fecha_carrera date, created_at timestamp with time zone DEFAULT now() NOT NULL, updated_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.sponsor_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sponsor_events ADD CONSTRAINT sponsor_events_cupos_descuentos_check CHECK (cupos_descuentos >= 0);
ALTER TABLE public.sponsor_events ADD CONSTRAINT sponsor_events_cupos_entradas_check CHECK (cupos_entradas >= 0);
ALTER TABLE public.sponsor_events ADD CONSTRAINT sponsor_events_estado_check CHECK (estado = ANY (ARRAY['activo'::text, 'inactivo'::text]));
ALTER TABLE public.sponsor_events ADD CONSTRAINT sponsor_events_pkey PRIMARY KEY (id);
ALTER TABLE public.ambassador_agreements ADD CONSTRAINT ambassador_agreements_sponsor_event_id_fkey FOREIGN KEY (sponsor_event_id) REFERENCES public.sponsor_events(id) ON DELETE SET NULL;
ALTER TABLE public.event_code_pool ADD CONSTRAINT event_code_pool_sponsor_event_id_fkey FOREIGN KEY (sponsor_event_id) REFERENCES public.sponsor_events(id) ON DELETE CASCADE;
ALTER TABLE public.event_winners ADD CONSTRAINT event_winners_sponsor_event_id_fkey FOREIGN KEY (sponsor_event_id) REFERENCES public.sponsor_events(id) ON DELETE CASCADE;
GRANT ALL ON public.sponsor_events TO anon;
GRANT ALL ON public.sponsor_events TO authenticated;
GRANT ALL ON public.sponsor_events TO service_role;
CREATE INDEX sponsor_events_estado_idx ON public.sponsor_events (estado);
CREATE TRIGGER trg_sponsor_events_updated_at BEFORE UPDATE ON public.sponsor_events FOR EACH ROW EXECUTE FUNCTION public.handle_sponsor_events_updated_at();
CREATE POLICY sponsor_events_admin_write ON public.sponsor_events TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE POLICY sponsor_events_public_read ON public.sponsor_events FOR SELECT TO anon, authenticated USING (true);
CREATE TABLE public.sponsors (id uuid DEFAULT gen_random_uuid() NOT NULL, name text NOT NULL, logo_url text DEFAULT ''::text NOT NULL, banner_url text, website_url text, is_active boolean DEFAULT true NOT NULL);
ALTER TABLE public.sponsors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sponsors ADD CONSTRAINT sponsors_pkey PRIMARY KEY (id);
ALTER TABLE public.rewards_catalog ADD CONSTRAINT rewards_catalog_sponsor_id_fkey FOREIGN KEY (sponsor_id) REFERENCES public.sponsors(id) ON DELETE SET NULL;
GRANT ALL ON public.sponsors TO anon;
GRANT ALL ON public.sponsors TO authenticated;
GRANT ALL ON public.sponsors TO service_role;
CREATE POLICY "Sponsors públicos" ON public.sponsors FOR SELECT USING ((auth.role() = 'authenticated'::text));
CREATE TABLE public.super_admin_emails (email text NOT NULL, granted_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.super_admin_emails ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.super_admin_emails ADD CONSTRAINT super_admin_emails_pkey PRIMARY KEY (email);
GRANT ALL ON public.super_admin_emails TO anon;
GRANT ALL ON public.super_admin_emails TO authenticated;
GRANT ALL ON public.super_admin_emails TO service_role;
CREATE POLICY "Solo super_admin gestiona emails" ON public.super_admin_emails USING (public.has_role(auth.uid(), 'super_admin'::public.app_role));
CREATE TABLE public.training_checkins (id uuid DEFAULT gen_random_uuid() NOT NULL, training_id uuid NOT NULL, user_id uuid NOT NULL, checked_in_at timestamp with time zone DEFAULT now() NOT NULL, checked_out_at timestamp with time zone);
ALTER TABLE public.training_checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_checkins ADD CONSTRAINT training_checkins_pkey PRIMARY KEY (id);
ALTER TABLE public.training_checkins ADD CONSTRAINT training_checkins_training_id_user_id_key UNIQUE (training_id, user_id);
ALTER TABLE public.training_checkins ADD CONSTRAINT training_checkins_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.training_checkins TO anon;
GRANT ALL ON public.training_checkins TO authenticated;
GRANT ALL ON public.training_checkins TO service_role;
CREATE INDEX training_checkins_user_idx ON public.training_checkins (user_id);
CREATE INDEX training_checkins_training_idx ON public.training_checkins (training_id, checked_in_at DESC);
CREATE TRIGGER on_training_checkout AFTER UPDATE OF checked_out_at ON public.training_checkins FOR EACH ROW EXECUTE FUNCTION public.trg_post_training_completed();
CREATE POLICY "Participante actualiza su checkin" ON public.training_checkins FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Participante check-in propio" ON public.training_checkins FOR INSERT WITH CHECK (((auth.uid() = user_id) AND (EXISTS ( SELECT 1
   FROM public.registrations r
  WHERE ((r.training_id = training_checkins.training_id) AND (r.user_id = auth.uid()) AND (r.status = 'confirmed'::public.registration_status))))));
CREATE POLICY "Ver checkins propios o admin" ON public.training_checkins FOR SELECT USING (((auth.uid() = user_id) OR public.has_role(auth.uid(), 'admin'::public.app_role)));
CREATE TABLE public.training_group_members (id uuid DEFAULT gen_random_uuid() NOT NULL, group_id uuid NOT NULL, user_id uuid NOT NULL, rol text DEFAULT 'participante'::text NOT NULL, joined_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.training_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_group_members ADD CONSTRAINT training_group_members_group_id_user_id_key UNIQUE (group_id, user_id);
ALTER TABLE public.training_group_members ADD CONSTRAINT training_group_members_pkey PRIMARY KEY (id);
ALTER TABLE public.training_group_members ADD CONSTRAINT training_group_members_rol_check CHECK (rol = ANY (ARRAY['participante'::text, 'pacer'::text, 'coach'::text]));
ALTER TABLE public.training_group_members ADD CONSTRAINT training_group_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.training_group_members TO anon;
GRANT ALL ON public.training_group_members TO authenticated;
GRANT ALL ON public.training_group_members TO service_role;
CREATE INDEX tgm_user_idx ON public.training_group_members (user_id);
CREATE INDEX tgm_group_idx ON public.training_group_members (group_id);
CREATE POLICY tgm_admin_all ON public.training_group_members USING (public.has_role(auth.uid(), 'admin'::public.app_role)) WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));
CREATE POLICY tgm_participante_select ON public.training_group_members FOR SELECT USING ((group_id IN ( SELECT public.get_user_group_ids() AS get_user_group_ids)));
CREATE TABLE public.training_groups (id uuid DEFAULT gen_random_uuid() NOT NULL, training_id uuid NOT NULL, nombre text DEFAULT 'Grupo A'::text NOT NULL, color text DEFAULT '#E91E8C'::text NOT NULL, orden integer DEFAULT 1 NOT NULL, coach_id uuid, pacer_id uuid, capacidad_max integer DEFAULT 15 NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.training_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_groups ADD CONSTRAINT training_groups_coach_id_fkey FOREIGN KEY (coach_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.training_groups ADD CONSTRAINT training_groups_pacer_id_fkey FOREIGN KEY (pacer_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.training_groups ADD CONSTRAINT training_groups_pkey PRIMARY KEY (id);
ALTER TABLE public.training_group_members ADD CONSTRAINT training_group_members_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.training_groups(id) ON DELETE CASCADE;
ALTER TABLE public.training_groups ADD CONSTRAINT training_groups_training_id_nombre_key UNIQUE (training_id, nombre);
GRANT ALL ON public.training_groups TO anon;
GRANT ALL ON public.training_groups TO authenticated;
GRANT ALL ON public.training_groups TO service_role;
CREATE INDEX training_groups_pacer_idx ON public.training_groups (pacer_id) WHERE pacer_id IS NOT NULL;
CREATE INDEX training_groups_coach_idx ON public.training_groups (coach_id) WHERE coach_id IS NOT NULL;
CREATE INDEX training_groups_training_idx ON public.training_groups (training_id);
CREATE POLICY tg_admin_all ON public.training_groups USING (public.has_role(auth.uid(), 'admin'::public.app_role)) WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));
CREATE POLICY tg_participante_select ON public.training_groups FOR SELECT USING ((id IN ( SELECT public.get_user_group_ids() AS get_user_group_ids)));
CREATE TABLE public.training_leaders (id uuid DEFAULT gen_random_uuid() NOT NULL, training_id uuid NOT NULL, user_id uuid NOT NULL, role text NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.training_leaders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_leaders ADD CONSTRAINT training_leaders_pkey PRIMARY KEY (id);
ALTER TABLE public.training_leaders ADD CONSTRAINT training_leaders_role_check CHECK (role = ANY (ARRAY['coach'::text, 'pacer'::text]));
ALTER TABLE public.training_leaders ADD CONSTRAINT training_leaders_training_id_user_id_key UNIQUE (training_id, user_id);
ALTER TABLE public.training_leaders ADD CONSTRAINT training_leaders_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.training_leaders TO anon;
GRANT ALL ON public.training_leaders TO authenticated;
GRANT ALL ON public.training_leaders TO service_role;
CREATE POLICY "Lectura pública de líderes" ON public.training_leaders FOR SELECT USING (true);
CREATE TABLE public.training_pacers (training_id uuid NOT NULL, pacer_id uuid NOT NULL, rol text DEFAULT 'pacer'::text NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.training_pacers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_pacers ADD CONSTRAINT training_pacers_pkey PRIMARY KEY (training_id, pacer_id);
ALTER TABLE public.training_pacers ADD CONSTRAINT training_pacers_rol_check CHECK (rol = ANY (ARRAY['pacer'::text, 'lead_pacer'::text, 'coach'::text]));
GRANT ALL ON public.training_pacers TO anon;
GRANT ALL ON public.training_pacers TO authenticated;
GRANT ALL ON public.training_pacers TO service_role;
CREATE INDEX idx_training_pacers_training_id ON public.training_pacers (training_id);
CREATE INDEX idx_training_pacers_pacer_id ON public.training_pacers (pacer_id);
CREATE POLICY training_pacers_select_public ON public.training_pacers FOR SELECT TO anon, authenticated USING (true);
CREATE TABLE public.training_sessions (id uuid DEFAULT gen_random_uuid() NOT NULL, week_id uuid NOT NULL, day_of_week integer NOT NULL, session_type text DEFAULT 'rest'::text NOT NULL, title text, description text, coach_notes text, duration_min integer, distance_km numeric(5,2), pace_target text, intensity text DEFAULT 'low'::text NOT NULL, rpe_target integer, status text DEFAULT 'planned'::text NOT NULL, completed_at timestamp with time zone, created_at timestamp with time zone DEFAULT now() NOT NULL, updated_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.training_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_sessions ADD CONSTRAINT training_sessions_day_of_week_check CHECK (day_of_week >= 1 AND day_of_week <= 7);
ALTER TABLE public.training_sessions ADD CONSTRAINT training_sessions_distance_km_check CHECK (distance_km IS NULL OR distance_km >= 0::numeric AND distance_km <= 100::numeric);
ALTER TABLE public.training_sessions ADD CONSTRAINT training_sessions_duration_min_check CHECK (duration_min IS NULL OR duration_min >= 5 AND duration_min <= 600);
ALTER TABLE public.training_sessions ADD CONSTRAINT training_sessions_intensity_check CHECK (intensity = ANY (ARRAY['low'::text, 'moderate'::text, 'high'::text, 'max'::text]));
ALTER TABLE public.training_sessions ADD CONSTRAINT training_sessions_pkey PRIMARY KEY (id);
ALTER TABLE public.session_results ADD CONSTRAINT session_results_training_session_id_fkey FOREIGN KEY (training_session_id) REFERENCES public.training_sessions(id) ON DELETE CASCADE;
ALTER TABLE public.training_sessions ADD CONSTRAINT training_sessions_rpe_target_check CHECK (rpe_target IS NULL OR rpe_target >= 1 AND rpe_target <= 10);
ALTER TABLE public.training_sessions ADD CONSTRAINT training_sessions_session_type_check CHECK (session_type = ANY (ARRAY['easy_run'::text, 'intervals'::text, 'tempo'::text, 'long_run'::text, 'recovery'::text, 'strength'::text, 'mobility'::text, 'cross_training'::text, 'rest'::text]));
ALTER TABLE public.training_sessions ADD CONSTRAINT training_sessions_status_check CHECK (status = ANY (ARRAY['planned'::text, 'completed'::text, 'skipped'::text]));
GRANT ALL ON public.training_sessions TO anon;
GRANT ALL ON public.training_sessions TO authenticated;
GRANT ALL ON public.training_sessions TO service_role;
CREATE INDEX training_sessions_status_idx ON public.training_sessions (status);
CREATE INDEX training_sessions_week_id_idx ON public.training_sessions (week_id);
CREATE INDEX training_sessions_day_idx ON public.training_sessions (day_of_week);
CREATE INDEX training_sessions_completed_idx ON public.training_sessions (week_id) WHERE status = 'completed'::text;
CREATE TRIGGER trg_training_sessions_updated_at BEFORE UPDATE ON public.training_sessions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_timestamp();
CREATE POLICY training_sessions_admin_all ON public.training_sessions TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE TABLE public.training_sos_alerts (id uuid DEFAULT gen_random_uuid() NOT NULL, training_id uuid NOT NULL, runner_id uuid NOT NULL, sent_at timestamp with time zone DEFAULT now() NOT NULL, lat double precision, lng double precision, resolved_at timestamp with time zone, resolved_by uuid);
COMMENT ON TABLE public.training_sos_alerts IS 'Alertas de seguridad enviadas por corredoras durante un entrenamiento en vivo. El coach recibe notificación inmediata vía Realtime postgres_changes.';
ALTER TABLE public.training_sos_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_sos_alerts ADD CONSTRAINT training_sos_alerts_pkey PRIMARY KEY (id);
ALTER TABLE public.training_sos_alerts ADD CONSTRAINT training_sos_alerts_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.training_sos_alerts ADD CONSTRAINT training_sos_alerts_runner_id_fkey FOREIGN KEY (runner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.training_sos_alerts TO anon;
GRANT ALL ON public.training_sos_alerts TO authenticated;
GRANT ALL ON public.training_sos_alerts TO service_role;
CREATE INDEX training_sos_runner_idx ON public.training_sos_alerts (runner_id);
CREATE INDEX training_sos_training_idx ON public.training_sos_alerts (training_id, sent_at DESC);
CREATE INDEX training_sos_open_idx ON public.training_sos_alerts (training_id) WHERE resolved_at IS NULL;
CREATE POLICY coach_admin_all_sos ON public.training_sos_alerts USING ((public.has_role(auth.uid(), 'coach'::public.app_role) OR public.has_role(auth.uid(), 'admin'::public.app_role))) WITH CHECK ((public.has_role(auth.uid(), 'coach'::public.app_role) OR public.has_role(auth.uid(), 'admin'::public.app_role)));
CREATE POLICY runner_insert_own_sos ON public.training_sos_alerts FOR INSERT WITH CHECK (((auth.uid() = runner_id) AND (EXISTS ( SELECT 1
   FROM public.registrations r
  WHERE ((r.training_id = training_sos_alerts.training_id) AND (r.user_id = auth.uid()) AND (r.status = 'confirmed'::public.registration_status))))));
CREATE POLICY runner_select_own_sos ON public.training_sos_alerts FOR SELECT USING ((auth.uid() = runner_id));
CREATE TABLE public.training_surveys (id uuid DEFAULT gen_random_uuid() NOT NULL, training_id uuid NOT NULL, user_id uuid NOT NULL, satisfaction_score smallint NOT NULL, would_recommend boolean DEFAULT true NOT NULL, free_text text, submitted_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.training_surveys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_surveys ADD CONSTRAINT training_surveys_pkey PRIMARY KEY (id);
ALTER TABLE public.training_surveys ADD CONSTRAINT training_surveys_satisfaction_score_check CHECK (satisfaction_score >= 1 AND satisfaction_score <= 5);
ALTER TABLE public.training_surveys ADD CONSTRAINT training_surveys_training_id_user_id_key UNIQUE (training_id, user_id);
ALTER TABLE public.training_surveys ADD CONSTRAINT training_surveys_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.training_surveys TO anon;
GRANT ALL ON public.training_surveys TO authenticated;
GRANT ALL ON public.training_surveys TO service_role;
CREATE TRIGGER on_survey_submitted AFTER INSERT ON public.training_surveys FOR EACH ROW EXECUTE FUNCTION public.trigger_award_survey_points();
CREATE POLICY "Encuesta propia" ON public.training_surveys USING ((auth.uid() = user_id));
CREATE TABLE public.training_weeks (id uuid DEFAULT gen_random_uuid() NOT NULL, plan_id uuid NOT NULL, week_number integer NOT NULL, week_type text DEFAULT 'build'::text NOT NULL, focus text, weekly_km_target numeric(6,2), notes text, created_at timestamp with time zone DEFAULT now() NOT NULL, updated_at timestamp with time zone DEFAULT now() NOT NULL);
CREATE POLICY training_sessions_coach_own ON public.training_sessions TO authenticated USING ((public.fn_is_coach() AND (EXISTS ( SELECT 1
   FROM (public.training_weeks tw
     JOIN public.plans p ON ((p.id = tw.plan_id)))
  WHERE ((tw.id = training_sessions.week_id) AND (p.coach_id = auth.uid())))))) WITH CHECK ((public.fn_is_coach() AND (EXISTS ( SELECT 1
   FROM (public.training_weeks tw
     JOIN public.plans p ON ((p.id = tw.plan_id)))
  WHERE ((tw.id = training_sessions.week_id) AND (p.coach_id = auth.uid()))))));
CREATE POLICY training_sessions_runner_own ON public.training_sessions FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.training_weeks tw
     JOIN public.plans p ON ((p.id = tw.plan_id)))
  WHERE ((tw.id = training_sessions.week_id) AND (p.runner_id = public.fn_runner_id_for_user())))));
ALTER TABLE public.training_weeks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_weeks ADD CONSTRAINT training_weeks_pkey PRIMARY KEY (id);
ALTER TABLE public.training_sessions ADD CONSTRAINT training_sessions_week_id_fkey FOREIGN KEY (week_id) REFERENCES public.training_weeks(id) ON DELETE CASCADE;
ALTER TABLE public.training_weeks ADD CONSTRAINT training_weeks_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE CASCADE;
ALTER TABLE public.training_weeks ADD CONSTRAINT training_weeks_plan_id_week_number_key UNIQUE (plan_id, week_number);
ALTER TABLE public.training_weeks ADD CONSTRAINT training_weeks_week_number_check CHECK (week_number > 0);
ALTER TABLE public.training_weeks ADD CONSTRAINT training_weeks_week_type_check CHECK (week_type = ANY (ARRAY['build'::text, 'deload'::text, 'peak'::text, 'recovery'::text, 'assessment'::text]));
GRANT ALL ON public.training_weeks TO anon;
GRANT ALL ON public.training_weeks TO authenticated;
GRANT ALL ON public.training_weeks TO service_role;
CREATE INDEX training_weeks_plan_id_idx ON public.training_weeks (plan_id);
CREATE INDEX training_weeks_type_idx ON public.training_weeks (week_type);
CREATE TRIGGER trg_training_weeks_updated_at BEFORE UPDATE ON public.training_weeks FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_timestamp();
CREATE POLICY training_weeks_admin_all ON public.training_weeks TO authenticated USING (public.fn_is_admin_or_super()) WITH CHECK (public.fn_is_admin_or_super());
CREATE POLICY training_weeks_coach_own ON public.training_weeks TO authenticated USING ((public.fn_is_coach() AND (EXISTS ( SELECT 1
   FROM public.plans p
  WHERE ((p.id = training_weeks.plan_id) AND (p.coach_id = auth.uid())))))) WITH CHECK ((public.fn_is_coach() AND (EXISTS ( SELECT 1
   FROM public.plans p
  WHERE ((p.id = training_weeks.plan_id) AND (p.coach_id = auth.uid()))))));
CREATE POLICY training_weeks_runner_own ON public.training_weeks FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.plans p
  WHERE ((p.id = training_weeks.plan_id) AND (p.runner_id = public.fn_runner_id_for_user())))));
CREATE TABLE public.trainings (id uuid DEFAULT gen_random_uuid() NOT NULL, title text NOT NULL, description text, scheduled_at timestamp with time zone NOT NULL, location_name text NOT NULL, location_maps_url text, distance_km numeric(5,2), recommended_level text DEFAULT 'todas'::text NOT NULL, max_capacity integer DEFAULT 30 NOT NULL, pacer_id uuid, sponsor_id uuid, cover_image_url text, status public.training_status DEFAULT 'published'::public.training_status NOT NULL, created_at timestamp with time zone DEFAULT now() NOT NULL, training_type public.training_type DEFAULT 'rodaje'::public.training_type NOT NULL, location_detail text, latitude numeric(10,7), longitude numeric(10,7), coach_id uuid, pacer_user_id uuid, preguntas_extra jsonb, training_kind text DEFAULT 'community'::text NOT NULL, descripcion text, tipo_entrenamiento text, nivel_objetivo text, imagen_url text, puntos_asistencia integer DEFAULT 10 NOT NULL, sponsor_event_id uuid, pacer_nombre text);
CREATE FUNCTION public.get_my_assigned_trainings()
 RETURNS SETOF public.trainings
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT t.*
  FROM trainings t
  WHERE t.coach_id = auth.uid()
    AND t.status IN ('published', 'completed')
  ORDER BY t.scheduled_at DESC;
$function$;
GRANT ALL ON FUNCTION public.get_my_assigned_trainings() TO anon;
GRANT ALL ON FUNCTION public.get_my_assigned_trainings() TO authenticated;
GRANT ALL ON FUNCTION public.get_my_assigned_trainings() TO service_role;
CREATE POLICY "Coach ve inscripciones de su entrenamiento" ON public.registrations FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.trainings t
  WHERE ((t.id = registrations.training_id) AND (t.coach_id = auth.uid())))));
CREATE POLICY tgm_coach_select ON public.training_group_members FOR SELECT USING ((group_id IN ( SELECT tg.id
   FROM public.training_groups tg
  WHERE ((tg.coach_id = auth.uid()) OR (tg.pacer_id = auth.uid()) OR (tg.training_id IN ( SELECT trainings.id
           FROM public.trainings
          WHERE (trainings.coach_id = auth.uid())))))));
CREATE POLICY tg_coach_select ON public.training_groups FOR SELECT USING (((coach_id = auth.uid()) OR (pacer_id = auth.uid()) OR (training_id IN ( SELECT trainings.id
   FROM public.trainings
  WHERE (trainings.coach_id = auth.uid())))));
ALTER TABLE public.trainings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trainings ADD CONSTRAINT trainings_coach_id_fkey FOREIGN KEY (coach_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.trainings ADD CONSTRAINT trainings_kind_check CHECK (training_kind = ANY (ARRAY['community'::text, 'internal'::text]));
ALTER TABLE public.trainings ADD CONSTRAINT trainings_pacer_id_fkey FOREIGN KEY (pacer_id) REFERENCES public.pacers(id);
ALTER TABLE public.trainings ADD CONSTRAINT trainings_pacer_user_id_fkey FOREIGN KEY (pacer_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.trainings ADD CONSTRAINT trainings_pkey PRIMARY KEY (id);
ALTER TABLE public.legacy_web_trainings ADD CONSTRAINT legacy_web_trainings_app_training_id_fkey FOREIGN KEY (app_training_id) REFERENCES public.trainings(id) ON DELETE SET NULL;
ALTER TABLE public.registrations ADD CONSTRAINT registrations_training_id_fkey FOREIGN KEY (training_id) REFERENCES public.trainings(id) ON DELETE CASCADE;
ALTER TABLE public.training_checkins ADD CONSTRAINT training_checkins_training_id_fkey FOREIGN KEY (training_id) REFERENCES public.trainings(id) ON DELETE CASCADE;
ALTER TABLE public.training_groups ADD CONSTRAINT training_groups_training_id_fkey FOREIGN KEY (training_id) REFERENCES public.trainings(id) ON DELETE CASCADE;
ALTER TABLE public.training_leaders ADD CONSTRAINT training_leaders_training_id_fkey FOREIGN KEY (training_id) REFERENCES public.trainings(id) ON DELETE CASCADE;
ALTER TABLE public.training_pacers ADD CONSTRAINT training_pacers_training_id_fkey FOREIGN KEY (training_id) REFERENCES public.trainings(id) ON DELETE CASCADE;
ALTER TABLE public.training_sos_alerts ADD CONSTRAINT training_sos_alerts_training_id_fkey FOREIGN KEY (training_id) REFERENCES public.trainings(id) ON DELETE CASCADE;
ALTER TABLE public.training_surveys ADD CONSTRAINT training_surveys_training_id_fkey FOREIGN KEY (training_id) REFERENCES public.trainings(id);
ALTER TABLE public.trainings ADD CONSTRAINT trainings_sponsor_id_fkey FOREIGN KEY (sponsor_id) REFERENCES public.sponsors(id);
GRANT ALL ON public.trainings TO anon;
GRANT ALL ON public.trainings TO authenticated;
GRANT ALL ON public.trainings TO service_role;
CREATE INDEX idx_trainings_status_kind ON public.trainings (status, training_kind);
CREATE INDEX trainings_pacer_user_idx ON public.trainings (pacer_user_id) WHERE pacer_user_id IS NOT NULL;
CREATE INDEX trainings_coach_idx ON public.trainings (coach_id) WHERE coach_id IS NOT NULL;
CREATE INDEX idx_trainings_kind_scheduled ON public.trainings (training_kind, scheduled_at DESC);
CREATE INDEX idx_trainings_sponsor_event_id ON public.trainings (sponsor_event_id) WHERE sponsor_event_id IS NOT NULL;
CREATE TRIGGER trg_notify_training_published AFTER INSERT OR UPDATE OF status ON public.trainings FOR EACH ROW EXECUTE FUNCTION public.notify_on_training_published();
CREATE POLICY "Admin autenticado puede crear entrenamientos" ON public.trainings FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Admin autenticado puede editar entrenamientos" ON public.trainings FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Admin autenticado puede eliminar entrenamientos" ON public.trainings FOR DELETE TO authenticated USING (true);
CREATE POLICY "Entrenamientos públicos" ON public.trainings FOR SELECT USING (((auth.role() = 'authenticated'::text) AND (status = 'published'::public.training_status)));
CREATE POLICY "Entrenamientos visibles al público" ON public.trainings FOR SELECT TO anon USING ((status = 'published'::public.training_status));
CREATE POLICY "Web lee entrenamientos publicados" ON public.trainings FOR SELECT TO anon USING ((status = 'published'::public.training_status));
CREATE TABLE public.user_achievements (id uuid DEFAULT gen_random_uuid() NOT NULL, user_id uuid NOT NULL, achievement_id uuid NOT NULL, unlocked_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ADD CONSTRAINT user_achievements_achievement_id_fkey FOREIGN KEY (achievement_id) REFERENCES public.achievements(id);
ALTER TABLE public.user_achievements ADD CONSTRAINT user_achievements_pkey PRIMARY KEY (id);
ALTER TABLE public.user_achievements ADD CONSTRAINT user_achievements_user_id_achievement_id_key UNIQUE (user_id, achievement_id);
ALTER TABLE public.user_achievements ADD CONSTRAINT user_achievements_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.user_achievements TO anon;
GRANT ALL ON public.user_achievements TO authenticated;
GRANT ALL ON public.user_achievements TO service_role;
CREATE TRIGGER on_achievement_unlocked AFTER INSERT ON public.user_achievements FOR EACH ROW EXECUTE FUNCTION public.trg_post_achievement_unlocked();
CREATE POLICY "Ver logros propios" ON public.user_achievements FOR SELECT USING ((auth.uid() = user_id));
CREATE TABLE public.user_onboarding (user_id uuid NOT NULL, running_relationship text, motivations text[] DEFAULT '{}'::text[] NOT NULL, energy_baseline smallint, barriers text[] DEFAULT '{}'::text[] NOT NULL, cycle_opt_in boolean DEFAULT false NOT NULL, support_style text, completed_at timestamp with time zone, updated_at timestamp with time zone DEFAULT now() NOT NULL);
CREATE FUNCTION public.upsert_user_onboarding(p_running_relationship text, p_motivations text[], p_energy_baseline smallint, p_barriers text[], p_cycle_opt_in boolean, p_support_style text)
 RETURNS public.user_onboarding
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row user_onboarding;
BEGIN
  INSERT INTO user_onboarding (
    user_id, running_relationship, motivations, energy_baseline,
    barriers, cycle_opt_in, support_style, completed_at, updated_at
  ) VALUES (
    auth.uid(), p_running_relationship, COALESCE(p_motivations, '{}'),
    p_energy_baseline, COALESCE(p_barriers, '{}'), COALESCE(p_cycle_opt_in, FALSE),
    p_support_style, NOW(), NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    running_relationship = EXCLUDED.running_relationship,
    motivations          = EXCLUDED.motivations,
    energy_baseline      = EXCLUDED.energy_baseline,
    barriers             = EXCLUDED.barriers,
    cycle_opt_in         = EXCLUDED.cycle_opt_in,
    support_style        = EXCLUDED.support_style,
    completed_at         = COALESCE(user_onboarding.completed_at, NOW()),
    updated_at           = NOW()
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$function$;
GRANT ALL ON FUNCTION public.upsert_user_onboarding(text, text[], smallint, text[], boolean, text) TO anon;
GRANT ALL ON FUNCTION public.upsert_user_onboarding(text, text[], smallint, text[], boolean, text) TO authenticated;
GRANT ALL ON FUNCTION public.upsert_user_onboarding(text, text[], smallint, text[], boolean, text) TO service_role;
ALTER TABLE public.user_onboarding ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_onboarding ADD CONSTRAINT user_onboarding_energy_baseline_check CHECK (energy_baseline >= 1 AND energy_baseline <= 5);
ALTER TABLE public.user_onboarding ADD CONSTRAINT user_onboarding_pkey PRIMARY KEY (user_id);
ALTER TABLE public.user_onboarding ADD CONSTRAINT user_onboarding_running_relationship_check CHECK (running_relationship = ANY (ARRAY['empezando'::text, 'voy_y_vengo'::text, 'retomar'::text, 'hace_tiempo'::text]));
ALTER TABLE public.user_onboarding ADD CONSTRAINT user_onboarding_support_style_check CHECK (support_style = ANY (ARRAY['suave'::text, 'empuje'::text, 'a_demanda'::text, 'comunidad'::text]));
ALTER TABLE public.user_onboarding ADD CONSTRAINT user_onboarding_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.user_onboarding TO anon;
GRANT ALL ON public.user_onboarding TO authenticated;
GRANT ALL ON public.user_onboarding TO service_role;
CREATE POLICY "Onboarding propio" ON public.user_onboarding USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));
CREATE TABLE public.user_profiles (id uuid NOT NULL, full_name text NOT NULL, email text NOT NULL, avatar_url text, birth_date date, running_level public.running_level DEFAULT 'principiante'::public.running_level NOT NULL, city text DEFAULT 'Santiago'::text NOT NULL, push_token text, created_at timestamp with time zone DEFAULT now() NOT NULL, updated_at timestamp with time zone DEFAULT now() NOT NULL, total_points integer DEFAULT 0 NOT NULL, points_updated_at timestamp with time zone, current_tier public.loyalty_tier DEFAULT 'starter'::public.loyalty_tier NOT NULL, last_activity_at timestamp with time zone DEFAULT now(), max_streak_weeks smallint DEFAULT 0 NOT NULL, last_streak_weeks smallint DEFAULT 0 NOT NULL, bio text, why_i_run text, running_since date, favorite_distance text, profile_photo_urls text[] DEFAULT '{}'::text[]);
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ADD CONSTRAINT bio_length CHECK (bio IS NULL OR char_length(bio) <= 300);
ALTER TABLE public.user_profiles ADD CONSTRAINT favorite_distance_valid CHECK (favorite_distance IS NULL OR (favorite_distance = ANY (ARRAY['5k'::text, '10k'::text, '21k'::text, '42k'::text, 'trail'::text, 'cualquier distancia'::text])));
ALTER TABLE public.user_profiles ADD CONSTRAINT user_profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.user_profiles ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (id);
ALTER TABLE public.runner_profiles ADD CONSTRAINT runner_profiles_user_profile_id_fkey FOREIGN KEY (user_profile_id) REFERENCES public.user_profiles(id) ON DELETE SET NULL;
ALTER TABLE public.user_profiles ADD CONSTRAINT why_i_run_length CHECK (why_i_run IS NULL OR char_length(why_i_run) <= 200);
GRANT ALL ON public.user_profiles TO anon;
GRANT ALL ON public.user_profiles TO authenticated;
GRANT ALL ON public.user_profiles TO service_role;
CREATE TRIGGER trg_auto_enroll_community AFTER INSERT ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION public.auto_enroll_community();
CREATE TRIGGER user_profiles_tier_sync BEFORE UPDATE OF total_points ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION public.trigger_update_tier();
CREATE TRIGGER user_profiles_updated_at BEFORE UPDATE ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE POLICY "Bloqueo oculta perfil" ON public.user_profiles AS RESTRICTIVE FOR SELECT USING ((NOT public.is_blocked_between(id)));
CREATE POLICY "Perfil propio" ON public.user_profiles USING ((auth.uid() = id));
CREATE TABLE public.user_roles (user_id uuid NOT NULL, role public.app_role NOT NULL, granted_at timestamp with time zone DEFAULT now() NOT NULL);
CREATE POLICY "Coach/admin lee alertas" ON public.alerts FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.user_roles
  WHERE ((user_roles.user_id = auth.uid()) AND (user_roles.role = ANY (ARRAY['coach'::public.app_role, 'admin'::public.app_role, 'super_admin'::public.app_role]))))));
CREATE POLICY "Admin gestiona entrenamientos" ON public.trainings TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.user_roles
  WHERE ((user_roles.user_id = auth.uid()) AND ((user_roles.role)::text = 'admin'::text))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.user_roles
  WHERE ((user_roles.user_id = auth.uid()) AND ((user_roles.role)::text = 'admin'::text)))));
CREATE POLICY "Admin ve todos los entrenamientos" ON public.trainings FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.user_roles
  WHERE ((user_roles.user_id = auth.uid()) AND ((user_roles.role)::text = 'admin'::text)))));
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role);
ALTER TABLE public.user_roles ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
GRANT ALL ON public.user_roles TO anon;
GRANT ALL ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
CREATE POLICY "Roles admin son visibles para selector pacer" ON public.user_roles FOR SELECT USING ((role = ANY (ARRAY['admin'::public.app_role, 'super_admin'::public.app_role])));
CREATE POLICY "Roles coach y pacer son visibles" ON public.user_roles FOR SELECT USING ((role = ANY (ARRAY['coach'::public.app_role, 'pacer'::public.app_role])));
CREATE POLICY "Solo admin gestiona roles" ON public.user_roles USING (public.has_role(auth.uid(), 'admin'::public.app_role)) WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));
CREATE POLICY "Ver roles propios" ON public.user_roles FOR SELECT USING (((auth.uid() = user_id) OR public.has_role(auth.uid(), 'admin'::public.app_role)));
CREATE TABLE public.web_registrations (id uuid DEFAULT gen_random_uuid() NOT NULL, training_id uuid NOT NULL, nombre text NOT NULL, email text NOT NULL, telefono text, contacto_emergencia text NOT NULL, condicion_medica text, respuestas_extra jsonb, estado_reserva text DEFAULT 'confirmada'::text NOT NULL, asistio boolean DEFAULT false NOT NULL, fecha_inscripcion timestamp with time zone DEFAULT now() NOT NULL, user_id uuid, created_via text DEFAULT 'web_form'::text NOT NULL, tiene_condicion_medica boolean DEFAULT false NOT NULL, condiciones_declaradas text[], anexo_a_requerido boolean DEFAULT false NOT NULL, anexo_a_aceptado_en timestamp with time zone, anexo_a_vigencia date);
ALTER TABLE public.web_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.web_registrations ADD CONSTRAINT web_registrations_created_via_check CHECK (created_via = ANY (ARRAY['web_form'::text, 'app'::text, 'admin'::text]));
ALTER TABLE public.web_registrations ADD CONSTRAINT web_registrations_estado_reserva_check CHECK (estado_reserva = ANY (ARRAY['confirmada'::text, 'cancelada'::text]));
ALTER TABLE public.web_registrations ADD CONSTRAINT web_registrations_pkey PRIMARY KEY (id);
ALTER TABLE public.legacy_web_registrations ADD CONSTRAINT legacy_web_registrations_app_registration_id_fkey FOREIGN KEY (app_registration_id) REFERENCES public.web_registrations(id) ON DELETE SET NULL;
ALTER TABLE public.web_registrations ADD CONSTRAINT web_registrations_training_id_email_key UNIQUE (training_id, email);
ALTER TABLE public.web_registrations ADD CONSTRAINT web_registrations_training_id_fkey FOREIGN KEY (training_id) REFERENCES public.trainings(id) ON DELETE CASCADE;
ALTER TABLE public.web_registrations ADD CONSTRAINT web_registrations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
GRANT ALL ON public.web_registrations TO anon;
GRANT ALL ON public.web_registrations TO authenticated;
GRANT ALL ON public.web_registrations TO service_role;
CREATE TRIGGER wsr_on_web_registration_insert AFTER INSERT ON public.web_registrations FOR EACH ROW EXECUTE FUNCTION public.wsr_confirmar_inscripcion_web();
CREATE POLICY "Admin actualiza web_registrations" ON public.web_registrations FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Admin autenticado puede eliminar registraciones" ON public.web_registrations FOR DELETE TO authenticated USING (true);
CREATE POLICY "Admin gestiona web_registrations" ON public.web_registrations FOR SELECT TO authenticated USING (true);
CREATE TABLE public.wsr_config (key text NOT NULL, value text NOT NULL);
ALTER TABLE public.wsr_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wsr_config ADD CONSTRAINT wsr_config_pkey PRIMARY KEY (key);
GRANT ALL ON public.wsr_config TO anon;
GRANT ALL ON public.wsr_config TO authenticated;
GRANT ALL ON public.wsr_config TO service_role;
CREATE TABLE public.wsr_pacers (id uuid DEFAULT gen_random_uuid() NOT NULL, user_id uuid, nombre text NOT NULL, activo boolean DEFAULT true NOT NULL, bio text, instagram text, avatar_url text, created_at timestamp with time zone DEFAULT now() NOT NULL, updated_at timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE public.wsr_pacers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wsr_pacers ADD CONSTRAINT wsr_pacers_pkey PRIMARY KEY (id);
ALTER TABLE public.training_pacers ADD CONSTRAINT training_pacers_pacer_id_fkey FOREIGN KEY (pacer_id) REFERENCES public.wsr_pacers(id) ON DELETE CASCADE;
ALTER TABLE public.wsr_pacers ADD CONSTRAINT wsr_pacers_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.wsr_pacers ADD CONSTRAINT wsr_pacers_user_unique UNIQUE (user_id);
GRANT ALL ON public.wsr_pacers TO anon;
GRANT ALL ON public.wsr_pacers TO authenticated;
GRANT ALL ON public.wsr_pacers TO service_role;
CREATE INDEX idx_wsr_pacers_user_id ON public.wsr_pacers (user_id) WHERE user_id IS NOT NULL;
CREATE TRIGGER trg_wsr_pacers_updated_at BEFORE UPDATE ON public.wsr_pacers FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();
CREATE POLICY wsr_pacers_select_public ON public.wsr_pacers FOR SELECT TO anon, authenticated USING ((activo = true));
CREATE VIEW public.feed_activities AS SELECT r.id,
    'registration_confirmed'::text AS activity_type,
    up.full_name AS actor_name,
    up.avatar_url AS actor_avatar_url,
    jsonb_build_object('training_title', t.title, 'training_location', t.location_name) AS metadata,
    r.registered_at AS occurred_at
   FROM ((public.registrations r
     JOIN public.user_profiles up ON ((up.id = r.user_id)))
     JOIN public.trainings t ON ((t.id = r.training_id)))
  WHERE (r.status = 'confirmed'::public.registration_status)
UNION ALL
 SELECT ua.id,
    'achievement_unlocked'::text AS activity_type,
    up.full_name AS actor_name,
    up.avatar_url AS actor_avatar_url,
    jsonb_build_object('achievement_name', a.name, 'achievement_desc', a.description) AS metadata,
    ua.unlocked_at AS occurred_at
   FROM ((public.user_achievements ua
     JOIN public.user_profiles up ON ((up.id = ua.user_id)))
     JOIN public.achievements a ON ((a.id = ua.achievement_id)))
  ORDER BY 6 DESC;
GRANT ALL ON public.feed_activities TO anon;
GRANT ALL ON public.feed_activities TO authenticated;
GRANT ALL ON public.feed_activities TO service_role;
CREATE VIEW public.loyalty_leaderboard AS SELECT up.id,
    up.full_name,
    up.avatar_url,
    up.total_points,
    up.current_tier,
    t.display_name AS tier_name,
    t.emoji AS tier_emoji,
    t.color_hex AS tier_color,
    rank() OVER (ORDER BY up.total_points DESC) AS rank
   FROM (public.user_profiles up
     JOIN public.loyalty_tiers t ON ((t.tier = up.current_tier)));
GRANT ALL ON public.loyalty_leaderboard TO anon;
GRANT ALL ON public.loyalty_leaderboard TO authenticated;
GRANT ALL ON public.loyalty_leaderboard TO service_role;
CREATE VIEW public.public_profiles WITH (security_invoker=false) AS SELECT id,
    full_name,
    avatar_url,
    current_tier,
    city,
    running_level,
    bio,
    why_i_run,
    running_since,
    favorite_distance,
    profile_photo_urls,
    last_activity_at,
    max_streak_weeks,
    last_streak_weeks
   FROM public.user_profiles p
  WHERE (NOT public.is_blocked_between(id));
GRANT SELECT ON public.public_profiles TO anon;
GRANT ALL ON public.public_profiles TO authenticated;
GRANT ALL ON public.public_profiles TO service_role;
CREATE VIEW public.training_with_counts AS SELECT t.id,
    t.title,
    t.description,
    t.scheduled_at,
    t.location_name,
    t.location_maps_url,
    t.distance_km,
    t.recommended_level,
    t.max_capacity,
    t.pacer_id,
    t.sponsor_id,
    t.cover_image_url,
    t.status,
    t.created_at,
    count(r.id) FILTER (WHERE (r.status = 'confirmed'::public.registration_status)) AS registration_count
   FROM (public.trainings t
     LEFT JOIN public.registrations r ON ((r.training_id = t.id)))
  GROUP BY t.id;
GRANT ALL ON public.training_with_counts TO anon;
GRANT ALL ON public.training_with_counts TO authenticated;
GRANT ALL ON public.training_with_counts TO service_role;
CREATE VIEW public.trainings_web AS SELECT id,
    title AS titulo_entrenamiento,
    scheduled_at AS fecha_hora,
    location_name AS ubicacion,
    location_detail AS ubicacion_texto,
    latitude AS latitud,
    longitude AS longitud,
    max_capacity AS cupos_totales,
        CASE (status)::text
            WHEN 'published'::text THEN 'activo'::text
            WHEN 'cancelled'::text THEN 'cerrado'::text
            ELSE (status)::text
        END AS estado,
    NULL::jsonb AS preguntas_extra,
    pacer_nombre
   FROM public.trainings;
GRANT ALL ON public.trainings_web TO anon;
GRANT ALL ON public.trainings_web TO authenticated;
GRANT ALL ON public.trainings_web TO service_role;
CREATE VIEW public.user_tier_progress AS SELECT up.id AS user_id,
    up.total_points,
    up.current_tier,
    curr.display_name AS current_tier_name,
    curr.emoji AS current_tier_emoji,
    curr.color_hex AS current_tier_color,
    nxt.tier AS next_tier,
    nxt.display_name AS next_tier_name,
    nxt.min_points AS next_tier_min_points,
    GREATEST((nxt.min_points - up.total_points), 0) AS points_to_next_tier
   FROM ((public.user_profiles up
     JOIN public.loyalty_tiers curr ON ((curr.tier = up.current_tier)))
     LEFT JOIN public.loyalty_tiers nxt ON ((nxt.sort_order = (curr.sort_order + 1))));
GRANT ALL ON public.user_tier_progress TO anon;
GRANT ALL ON public.user_tier_progress TO authenticated;
GRANT ALL ON public.user_tier_progress TO service_role;
CREATE VIEW public.vw_social_feed WITH (security_invoker=false) AS SELECT fp.id AS event_id,
    fp.post_type AS event_type,
    fp.ref_id,
    fp.body AS description,
    fp.media_urls,
    fp.visibility,
    fp.likes_count,
    fp.created_at,
    fp.author_id,
    pp.full_name AS runner_name,
    pp.avatar_url AS avatar,
    pp.current_tier AS runner_tier,
    pp.city AS runner_city,
    ( SELECT (pl.reaction)::text AS reaction
           FROM public.post_likes pl
          WHERE ((pl.post_id = fp.id) AND (pl.user_id = auth.uid()))
         LIMIT 1) AS my_reaction,
        CASE fp.post_type
            WHEN 'free_run'::public.post_type THEN jsonb_build_object('title', COALESCE(act.title, 'Salí a correr'::text), 'distance_m', act.distance_m, 'duration_s', act.duration_s, 'pace_s_km', act.avg_pace_s_per_km, 'feeling', (act.feeling)::text, 'has_route', (act.route_polyline IS NOT NULL))
            WHEN 'training_completed'::public.post_type THEN jsonb_build_object('training_title', tr.title, 'location_name', tr.location_name, 'distance_km', tr.distance_km, 'training_kind', tr.training_kind)
            WHEN 'achievement'::public.post_type THEN jsonb_build_object('name', ach.name, 'description', ach.description, 'icon', ach.icon_url)
            WHEN 'streak'::public.post_type THEN jsonb_build_object('weeks', fp.body)
            ELSE jsonb_build_object()
        END AS event_data
   FROM (((((public.feed_posts fp
     JOIN public.public_profiles pp ON ((pp.id = fp.author_id)))
     LEFT JOIN public.activities act ON (((fp.post_type = 'free_run'::public.post_type) AND (act.id = fp.ref_id))))
     LEFT JOIN public.trainings tr ON (((fp.post_type = 'training_completed'::public.post_type) AND (tr.id = fp.ref_id))))
     LEFT JOIN public.user_achievements ua ON (((fp.post_type = 'achievement'::public.post_type) AND (ua.id = fp.ref_id))))
     LEFT JOIN public.achievements ach ON ((ach.id = ua.achievement_id)))
  WHERE (((fp.author_id = auth.uid()) OR (fp.visibility = 'public'::public.post_visibility) OR ((fp.visibility = 'followers'::public.post_visibility) AND (EXISTS ( SELECT 1
           FROM public.follows f
          WHERE ((f.follower_id = auth.uid()) AND (f.following_id = fp.author_id)))))) AND (NOT public.is_blocked_between(fp.author_id)));
CREATE FUNCTION public.get_social_feed(p_cursor timestamp with time zone DEFAULT now(), p_limit integer DEFAULT 20)
 RETURNS SETOF public.vw_social_feed
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT * FROM vw_social_feed
  WHERE  created_at < p_cursor
  ORDER  BY created_at DESC
  LIMIT  LEAST(p_limit, 50);
$function$;
GRANT ALL ON FUNCTION public.get_social_feed(timestamp with time zone, integer) TO anon;
GRANT ALL ON FUNCTION public.get_social_feed(timestamp with time zone, integer) TO authenticated;
GRANT ALL ON FUNCTION public.get_social_feed(timestamp with time zone, integer) TO service_role;
GRANT ALL ON public.vw_social_feed TO authenticated;
GRANT ALL ON public.vw_social_feed TO service_role;
CREATE VIEW public.vw_wsr_conversations WITH (security_invoker=true) AS SELECT c.id AS channel_id,
    c.type,
    c.name,
    c.last_message_at,
    c.is_archived,
    cp.last_read_at,
    cp.is_muted,
    cp.role AS my_role,
    ((c.last_message_at IS NOT NULL) AND (c.last_message_at > cp.last_read_at)) AS has_unread,
    lm.id AS last_msg_id,
    lm.body AS last_msg_body,
    lm.sender_id AS last_msg_sender_id,
    (lm.kind)::text AS last_msg_kind,
    lm.deleted_at AS last_msg_deleted_at,
    lm.created_at AS last_msg_created_at,
    cp_other.user_id AS counterpart_id,
    pp.full_name AS counterpart_name,
    pp.avatar_url AS counterpart_avatar,
    (pp.current_tier)::text AS counterpart_tier
   FROM ((((public.channels c
     JOIN public.channel_participants cp ON (((cp.channel_id = c.id) AND (cp.user_id = auth.uid()))))
     LEFT JOIN LATERAL ( SELECT messages.id,
            messages.body,
            messages.sender_id,
            messages.kind,
            messages.deleted_at,
            messages.created_at
           FROM public.messages
          WHERE (messages.channel_id = c.id)
          ORDER BY messages.created_at DESC
         LIMIT 1) lm ON (true))
     LEFT JOIN LATERAL ( SELECT channel_participants.user_id
           FROM public.channel_participants
          WHERE ((channel_participants.channel_id = c.id) AND (channel_participants.user_id <> auth.uid()))
         LIMIT 1) cp_other ON ((c.type = 'direct'::public.channel_type)))
     LEFT JOIN public.public_profiles pp ON (((c.type = 'direct'::public.channel_type) AND (pp.id = cp_other.user_id))))
  WHERE (c.is_archived = false)
  ORDER BY c.last_message_at DESC NULLS LAST;
GRANT ALL ON public.vw_wsr_conversations TO authenticated;
GRANT ALL ON public.vw_wsr_conversations TO service_role;
CREATE VIEW public.wsr_blocks WITH (security_invoker=true) AS SELECT blocker_id,
    blocked_id,
    created_at
   FROM public.blocked_users;
GRANT ALL ON public.wsr_blocks TO authenticated;
GRANT ALL ON public.wsr_blocks TO service_role;
CREATE VIEW public.wsr_conversations WITH (security_invoker=true) AS SELECT id,
    (type)::text AS type,
    name,
    description,
    avatar_url,
    created_by,
    last_message_at,
    is_archived,
    created_at
   FROM public.channels
  WHERE (type = ANY (ARRAY['direct'::public.channel_type, 'group'::public.channel_type]));
GRANT ALL ON public.wsr_conversations TO authenticated;
GRANT ALL ON public.wsr_conversations TO service_role;
CREATE VIEW public.wsr_messages WITH (security_invoker=true) AS SELECT m.id,
    m.channel_id AS conversation_id,
    m.sender_id,
    m.body,
    (m.kind)::text AS kind,
    m.created_at,
    m.edited_at,
    m.deleted_at
   FROM (public.messages m
     JOIN public.channels c ON ((c.id = m.channel_id)))
  WHERE (c.type = ANY (ARRAY['direct'::public.channel_type, 'group'::public.channel_type]));
GRANT ALL ON public.wsr_messages TO authenticated;
GRANT ALL ON public.wsr_messages TO service_role;
CREATE VIEW public.wsr_reports WITH (security_invoker=true) AS SELECT id,
    reporter_id,
    reported_user_id AS reported_id,
    (content_type)::text AS content_type,
    content_id,
    (reason)::text AS reason,
    (status)::text AS status,
    details,
    created_at
   FROM public.reported_content;
GRANT ALL ON public.wsr_reports TO authenticated;
GRANT ALL ON public.wsr_reports TO service_role;
