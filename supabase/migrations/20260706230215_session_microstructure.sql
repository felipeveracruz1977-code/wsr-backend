-- ═════════════════════════════════════════════════════════════════════════
-- 060_session_microstructure.sql
--
-- Planning Engine™ / Coach Copilot™ v2.0 (Human-Augmented AI):
--   1. Microestructura de sesión: warmup_desc / main_desc / cooldown_desc.
--      `description` se conserva como fallback legado (sesiones pre-v2.0 y
--      cualquier consumidor que aún no lea los 3 bloques).
--   2. Ritmo (Pace): se REUTILIZA la columna `pace_target` ya existente
--      (creada junto con `distance_km`/`intensity`) en vez de duplicarla bajo
--      un nombre nuevo — v1.0 la dejaba siempre NULL por regla de seguridad
--      ("prohibición absoluta de paces"); v2.0 la reactiva como campo real.
--
-- fn_admin_update_training_session (046_enforce_clinical_mutations.sql) se
-- reemplaza para aceptar los 3 bloques nuevos — sigue siendo el único camino
-- de escritura desde el cliente (Ley III), ahora con 3 parámetros trailing
-- opcionales para no romper llamadas existentes.
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.training_sessions
  ADD COLUMN IF NOT EXISTS warmup_desc   text,
  ADD COLUMN IF NOT EXISTS main_desc     text,
  ADD COLUMN IF NOT EXISTS cooldown_desc text;

COMMENT ON COLUMN public.training_sessions.pace_target IS
  'Ritmo objetivo de la sesión (ej. "5:30 min/km" o "N/A" para Run-Walk). Planning Engine v2.0 lo genera obligatoriamente; la coach puede sobreescribirlo vía inline editing.';
COMMENT ON COLUMN public.training_sessions.description IS
  'Fallback legado pre-v2.0 (retrocompatibilidad). Sesiones v2.0 usan warmup_desc/main_desc/cooldown_desc.';
COMMENT ON COLUMN public.training_sessions.warmup_desc IS
  'Instrucciones del bloque de Calentamiento (microestructura v2.0).';
COMMENT ON COLUMN public.training_sessions.main_desc IS
  'Instrucciones del bloque Principal (microestructura v2.0).';
COMMENT ON COLUMN public.training_sessions.cooldown_desc IS
  'Instrucciones del bloque de Vuelta a la calma (microestructura v2.0).';

DROP FUNCTION IF EXISTS public.fn_admin_update_training_session(
  uuid, text, text, numeric, integer, text, text, integer, text, text
);

CREATE FUNCTION public.fn_admin_update_training_session(
  p_session_id    uuid,
  p_session_type  text,
  p_title         text,
  p_distance_km   numeric,
  p_duration_min  integer,
  p_pace_target   text,
  p_intensity     text,
  p_rpe_target    integer,
  p_description   text,
  p_coach_notes   text,
  p_warmup_desc   text DEFAULT NULL,
  p_main_desc     text DEFAULT NULL,
  p_cooldown_desc text DEFAULT NULL
)
RETURNS public.training_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_plan_status text;
  v_session     public.training_sessions%ROWTYPE;
BEGIN
  IF NOT (public.fn_is_coach() OR public.fn_is_admin_or_super()) THEN
    RAISE EXCEPTION 'Solo coaches o administradoras pueden editar sesiones de entrenamiento'
      USING ERRCODE = '42501';
  END IF;

  SELECT p.status INTO v_plan_status
  FROM public.training_sessions ts
  JOIN public.training_weeks tw ON tw.id = ts.week_id
  JOIN public.plans p           ON p.id = tw.plan_id
  WHERE ts.id = p_session_id;

  IF v_plan_status IS NULL THEN
    RAISE EXCEPTION 'Sesión % no encontrada', p_session_id;
  END IF;

  IF v_plan_status = 'active' THEN
    RAISE EXCEPTION 'Plan activo: usa fn_adapt_plan para preservar el historial clínico (Ley de Inmutabilidad)';
  END IF;

  UPDATE public.training_sessions
  SET session_type   = p_session_type,
      title          = p_title,
      distance_km    = p_distance_km,
      duration_min   = p_duration_min,
      pace_target    = p_pace_target,
      intensity      = p_intensity,
      rpe_target     = p_rpe_target,
      description    = p_description,
      coach_notes    = p_coach_notes,
      warmup_desc    = p_warmup_desc,
      main_desc      = p_main_desc,
      cooldown_desc  = p_cooldown_desc,
      updated_at     = now()
  WHERE id = p_session_id
  RETURNING * INTO v_session;

  RETURN v_session;
END;
$function$;

GRANT ALL ON FUNCTION public.fn_admin_update_training_session(
  uuid, text, text, numeric, integer, text, text, integer, text, text, text, text, text
) TO anon;
GRANT ALL ON FUNCTION public.fn_admin_update_training_session(
  uuid, text, text, numeric, integer, text, text, integer, text, text, text, text, text
) TO authenticated;
GRANT ALL ON FUNCTION public.fn_admin_update_training_session(
  uuid, text, text, numeric, integer, text, text, integer, text, text, text, text, text
) TO service_role;
