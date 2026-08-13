-- ═════════════════════════════════════════════════════════════════════════
-- 062_fix_fn_adapt_plan.sql
--
-- Reparación de deuda técnica crítica (Engine 05 — Adaptation Engine™):
-- fn_adapt_plan NUNCA existió en el clúster APP. PlanesPersonalesTab.tsx ya
-- la invocaba para el "Camino B" (edición manual de sesiones en planes
-- ACTIVOS), asumiendo — correctamente, según la arquitectura de Inmutabilidad
-- — que un plan activo nunca se muta in-place; toda edición debe clonar el
-- plan, aplicar el delta a la copia y archivar el original. Sin la RPC, esa
-- ruta fallaba en producción con "function does not exist" (42883) cada vez
-- que una coach editaba una sesión de un plan activo.
--
-- Ley III: SECURITY DEFINER + search_path fijo + guard fn_is_coach()/
-- fn_is_admin_or_super(). Todo el clonado ocurre en una única transacción de
-- función plpgsql — si cualquier INSERT falla, Postgres revierte la función
-- completa (no hace falta ROLLBACK manual: una excepción no capturada aborta
-- la transacción implícita de la función).
-- ═════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_adapt_plan(
  p_plan_id     uuid,
  p_adaptations jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_old_plan    public.plans%ROWTYPE;
  v_new_plan_id uuid;
  v_current_tag text;
  v_next_tag    text;
  v_week        record;
  v_new_week_id uuid;
  v_session     record;
  v_adapt       jsonb;
BEGIN
  IF NOT (public.fn_is_coach() OR public.fn_is_admin_or_super()) THEN
    RAISE EXCEPTION 'Solo coaches o administradoras pueden adaptar planes'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_old_plan FROM public.plans WHERE id = p_plan_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Plan % no encontrado', p_plan_id;
  END IF;

  IF v_old_plan.status <> 'active' THEN
    RAISE EXCEPTION 'Solo planes activos pueden adaptarse vía fn_adapt_plan (estado actual: %). Planes no-activos usan fn_admin_update_training_session.', v_old_plan.status;
  END IF;

  -- Bump de version_tag (mismo esquema que Engine 05: "v1.0" → "v1.1")
  v_current_tag := coalesce(v_old_plan.version_tag, 'v1.0');
  v_next_tag := split_part(v_current_tag, '.', 1) || '.' ||
    (coalesce(nullif(split_part(v_current_tag, '.', 2), '')::int, 0) + 1)::text;

  -- ── 1. Clonar el plan maestro (Camino B: nace ya 'active' — es una edición
  --      manual ya revisada por la coach, no una sugerencia de IA pendiente
  --      de aprobación) ──
  INSERT INTO public.plans (
    runner_id, coach_id, title, goal, current_level, weekly_km_base, days_per_week,
    notes, coach_message, status, generated_at, parent_plan_id, version_tag
  ) VALUES (
    v_old_plan.runner_id, v_old_plan.coach_id, v_old_plan.title, v_old_plan.goal,
    v_old_plan.current_level, v_old_plan.weekly_km_base, v_old_plan.days_per_week,
    v_old_plan.notes, v_old_plan.coach_message, 'active', now(), p_plan_id, v_next_tag
  )
  RETURNING id INTO v_new_plan_id;

  -- ── 2. Clonar semanas + sesiones, aplicando el delta de p_adaptations por session_id ──
  FOR v_week IN
    SELECT * FROM public.training_weeks WHERE plan_id = p_plan_id ORDER BY week_number
  LOOP
    INSERT INTO public.training_weeks (plan_id, week_number, week_type, focus, weekly_km_target, notes)
    VALUES (v_new_plan_id, v_week.week_number, v_week.week_type, v_week.focus, v_week.weekly_km_target, v_week.notes)
    RETURNING id INTO v_new_week_id;

    FOR v_session IN
      SELECT * FROM public.training_sessions WHERE week_id = v_week.id ORDER BY day_of_week
    LOOP
      SELECT elem INTO v_adapt
      FROM jsonb_array_elements(coalesce(p_adaptations, '[]'::jsonb)) elem
      WHERE elem->>'session_id' = v_session.id::text
      LIMIT 1;

      INSERT INTO public.training_sessions (
        week_id, day_of_week, session_type, title, distance_km, duration_min,
        pace_target, intensity, rpe_target, warmup_desc, main_desc, cooldown_desc,
        description, coach_notes, status, completed_at
      ) VALUES (
        v_new_week_id,
        v_session.day_of_week,
        coalesce(v_adapt->>'session_type', v_session.session_type),
        CASE WHEN v_adapt ? 'title'         THEN v_adapt->>'title'         ELSE v_session.title         END,
        CASE WHEN v_adapt ? 'distance_km'   THEN (v_adapt->>'distance_km')::numeric ELSE v_session.distance_km END,
        CASE WHEN v_adapt ? 'duration_min'  THEN (v_adapt->>'duration_min')::integer ELSE v_session.duration_min END,
        CASE WHEN v_adapt ? 'pace_target'   THEN v_adapt->>'pace_target'   ELSE v_session.pace_target   END,
        coalesce(v_adapt->>'intensity', v_session.intensity),
        CASE WHEN v_adapt ? 'rpe_target'    THEN (v_adapt->>'rpe_target')::integer ELSE v_session.rpe_target END,
        CASE WHEN v_adapt ? 'warmup_desc'   THEN v_adapt->>'warmup_desc'   ELSE v_session.warmup_desc   END,
        CASE WHEN v_adapt ? 'main_desc'     THEN v_adapt->>'main_desc'     ELSE v_session.main_desc     END,
        CASE WHEN v_adapt ? 'cooldown_desc' THEN v_adapt->>'cooldown_desc' ELSE v_session.cooldown_desc END,
        CASE WHEN v_adapt ? 'description'   THEN v_adapt->>'description'   ELSE v_session.description   END,
        v_session.coach_notes,
        -- Ley de Inmutabilidad operativa: una sesión ya ejecutada nunca recibe delta
        v_session.status,
        v_session.completed_at
      );
    END LOOP;
  END LOOP;

  -- ── 3. Archivar el plan original — el clon activo lo reemplaza ──
  UPDATE public.plans SET status = 'archived', updated_at = now() WHERE id = p_plan_id;

  RETURN v_new_plan_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_adapt_plan(uuid, jsonb) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.fn_adapt_plan(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_adapt_plan(uuid, jsonb) TO service_role;
