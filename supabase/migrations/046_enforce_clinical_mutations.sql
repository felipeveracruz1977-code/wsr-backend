-- ═════════════════════════════════════════════════════════════════════════
-- 046_enforce_clinical_mutations.sql
--
-- Ley III (Frontera Clínica) del ecosistema: la Web mutaba health_alerts,
-- training_sessions y anamnesis directamente vía .from().update()/.insert()/
-- .delete(). Las tres tablas solo otorgan RLS a admin/super_admin
-- (*_admin_all), así que hoy un coach sin ese rol falla en silencio contra
-- RLS y, peor, ninguna de las tres mutaciones queda trazada como "acción de
-- coach" vs "acción de admin" — ambas colapsan en el mismo camino directo.
--
-- Estas RPCs SECURITY DEFINER:
--   1. Verifican explícitamente fn_is_coach() OR fn_is_admin_or_super().
--   2. Ejecutan la mutación con privilegios elevados, de forma auditable.
--   3. Se declaran con SET search_path TO 'public'.
-- Reemplazan los .from(...).update/insert/delete directos en
-- CheckInsTab.tsx, PlanesPersonalesTab.tsx y AnamnesisTab.tsx.
-- ═════════════════════════════════════════════════════════════════════════

-- ── 1. fn_admin_resolve_health_alert ─────────────────────────────────────────
-- Reemplaza: CheckInsTab.tsx → supabase.from("health_alerts").update({status,
-- resolved_at, resolved_by}).eq("id", alertId).
CREATE OR REPLACE FUNCTION public.fn_admin_resolve_health_alert(
  p_alert_id uuid,
  p_status   text DEFAULT 'atendida'
)
RETURNS public.health_alerts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_alert public.health_alerts%ROWTYPE;
BEGIN
  IF NOT (public.fn_is_coach() OR public.fn_is_admin_or_super()) THEN
    RAISE EXCEPTION 'Solo coaches o administradoras pueden resolver alertas de salud'
      USING ERRCODE = '42501';
  END IF;

  IF p_status NOT IN ('atendida', 'descartada') THEN
    RAISE EXCEPTION 'Estado % inválido para resolución de alerta', p_status;
  END IF;

  UPDATE public.health_alerts
  SET status      = p_status,
      resolved_at = now(),
      resolved_by = auth.uid()
  WHERE id = p_alert_id
  RETURNING * INTO v_alert;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Alerta % no encontrada', p_alert_id;
  END IF;

  RETURN v_alert;
END;
$function$;

GRANT ALL ON FUNCTION public.fn_admin_resolve_health_alert(uuid, text) TO anon;
GRANT ALL ON FUNCTION public.fn_admin_resolve_health_alert(uuid, text) TO authenticated;
GRANT ALL ON FUNCTION public.fn_admin_resolve_health_alert(uuid, text) TO service_role;

-- ── 2. fn_admin_update_training_session ──────────────────────────────────────
-- Reemplaza: PlanesPersonalesTab.tsx → supabase.from("training_sessions")
-- .update({...rest, updated_at}).eq("id", id) — únicamente para el camino de
-- "planes no-activos" (edición directa); el camino de plan ACTIVO ya usaba
-- fn_adapt_plan (clona el plan, Ley de Inmutabilidad). Esta función reafirma
-- esa misma regla del lado del servidor: si el plan está activo, rechaza la
-- edición directa en vez de confiar en que el cliente eligió el camino
-- correcto.
CREATE OR REPLACE FUNCTION public.fn_admin_update_training_session(
  p_session_id   uuid,
  p_session_type text,
  p_title        text,
  p_distance_km  numeric,
  p_duration_min integer,
  p_pace_target  text,
  p_intensity    text,
  p_rpe_target   integer,
  p_description  text,
  p_coach_notes  text
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
  SET session_type = p_session_type,
      title        = p_title,
      distance_km  = p_distance_km,
      duration_min = p_duration_min,
      pace_target  = p_pace_target,
      intensity    = p_intensity,
      rpe_target   = p_rpe_target,
      description  = p_description,
      coach_notes  = p_coach_notes,
      updated_at   = now()
  WHERE id = p_session_id
  RETURNING * INTO v_session;

  RETURN v_session;
END;
$function$;

GRANT ALL ON FUNCTION public.fn_admin_update_training_session(
  uuid, text, text, numeric, integer, text, text, integer, text, text
) TO anon;
GRANT ALL ON FUNCTION public.fn_admin_update_training_session(
  uuid, text, text, numeric, integer, text, text, integer, text, text
) TO authenticated;
GRANT ALL ON FUNCTION public.fn_admin_update_training_session(
  uuid, text, text, numeric, integer, text, text, integer, text, text
) TO service_role;

-- ── 3. fn_admin_upsert_anamnesis ─────────────────────────────────────────────
-- Reemplaza: AnamnesisTab.tsx → supabase.from("anamnesis").update(payload)
-- / .insert(payload). p_payload es el mismo objeto ya construido por
-- AnamnesisFormView.submit() (campos v1 completos); se aplica vía
-- jsonb_populate_record contra la fila base (NULL para insert, la fila
-- actual para update) para no redeclarar ~40 columnas a mano en SQL.
CREATE OR REPLACE FUNCTION public.fn_admin_upsert_anamnesis(
  p_id      uuid,
  p_payload jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_current public.anamnesis%ROWTYPE;
  v_merged  public.anamnesis%ROWTYPE;
  v_id      uuid;
BEGIN
  IF NOT (public.fn_is_coach() OR public.fn_is_admin_or_super()) THEN
    RAISE EXCEPTION 'Solo coaches o administradoras pueden editar fichas de anamnesis'
      USING ERRCODE = '42501';
  END IF;

  IF p_id IS NULL THEN
    v_merged := jsonb_populate_record(
      NULL::public.anamnesis,
      p_payload || jsonb_build_object(
        'id', gen_random_uuid(),
        'created_at', now(),
        'updated_at', now()
      )
    );
    INSERT INTO public.anamnesis SELECT (v_merged).*
    RETURNING id INTO v_id;
  ELSE
    SELECT * INTO v_current FROM public.anamnesis WHERE id = p_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Anamnesis % no encontrada', p_id;
    END IF;

    v_merged := jsonb_populate_record(v_current, p_payload || jsonb_build_object('updated_at', now()));

    UPDATE public.anamnesis SET
      nombre_apellido              = v_merged.nombre_apellido,
      realiza_actividad_fisica     = v_merged.realiza_actividad_fisica,
      deporte_actividad            = v_merged.deporte_actividad,
      ritmo_10k                    = v_merged.ritmo_10k,
      ritmo_21k                    = v_merged.ritmo_21k,
      edad                         = v_merged.edad,
      historial_familiar           = v_merged.historial_familiar,
      historial_familiar_detalle   = v_merged.historial_familiar_detalle,
      patologias_medicas           = v_merged.patologias_medicas,
      patologias_diagnostico       = v_merged.patologias_diagnostico,
      patologias_fecha_tratamiento = v_merged.patologias_fecha_tratamiento,
      fuma_cigarrillos             = v_merged.fuma_cigarrillos,
      cigarrillos_por_dia          = v_merged.cigarrillos_por_dia,
      hipertension                 = v_merged.hipertension,
      hipercolesterolemia          = v_merged.hipercolesterolemia,
      diabetes                     = v_merged.diabetes,
      resistencia_insulina         = v_merged.resistencia_insulina,
      toma_alcohol                 = v_merged.toma_alcohol,
      condiciones_previas          = v_merged.condiciones_previas,
      condiciones_previas_otra     = v_merged.condiciones_previas_otra,
      lesiones_musculares          = v_merged.lesiones_musculares,
      lesiones_musculares_detalle  = v_merged.lesiones_musculares_detalle,
      lesiones_articulares         = v_merged.lesiones_articulares,
      lesiones_articulares_detalle = v_merged.lesiones_articulares_detalle,
      lesiones_oseas               = v_merged.lesiones_oseas,
      lesiones_oseas_detalle       = v_merged.lesiones_oseas_detalle,
      emergencia_nombre            = v_merged.emergencia_nombre,
      emergencia_contacto          = v_merged.emergencia_contacto,
      clinica_afiliada             = v_merged.clinica_afiliada,
      isapre_afiliada              = v_merged.isapre_afiliada,
      toma_medicamentos            = v_merged.toma_medicamentos,
      medicamentos_detalle         = v_merged.medicamentos_detalle,
      latidos_anormales            = v_merged.latidos_anormales,
      latidos_anormales_cuando     = v_merged.latidos_anormales_cuando,
      presion_arterial             = v_merged.presion_arterial,
      presion_arterial_desconoce   = v_merged.presion_arterial_desconoce,
      comidas_por_dia              = v_merged.comidas_por_dia,
      descripcion_alimentacion     = v_merged.descripcion_alimentacion,
      suplementos                  = v_merged.suplementos,
      suplementos_otro_detalle     = v_merged.suplementos_otro_detalle,
      ultimo_examen_sangre         = v_merged.ultimo_examen_sangre,
      nombre_rut_firma             = v_merged.nombre_rut_firma,
      autoriza_datos               = v_merged.autoriza_datos,
      updated_at                   = now()
    WHERE id = p_id;

    v_id := p_id;
  END IF;

  RETURN v_id;
END;
$function$;

GRANT ALL ON FUNCTION public.fn_admin_upsert_anamnesis(uuid, jsonb) TO anon;
GRANT ALL ON FUNCTION public.fn_admin_upsert_anamnesis(uuid, jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.fn_admin_upsert_anamnesis(uuid, jsonb) TO service_role;

-- ── 4. fn_admin_delete_anamnesis ─────────────────────────────────────────────
-- Reemplaza: AnamnesisTab.tsx → supabase.from("anamnesis").delete().eq("id", r.id).
CREATE OR REPLACE FUNCTION public.fn_admin_delete_anamnesis(
  p_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT (public.fn_is_coach() OR public.fn_is_admin_or_super()) THEN
    RAISE EXCEPTION 'Solo coaches o administradoras pueden eliminar fichas de anamnesis'
      USING ERRCODE = '42501';
  END IF;

  DELETE FROM public.anamnesis WHERE id = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Anamnesis % no encontrada', p_id;
  END IF;
END;
$function$;

GRANT ALL ON FUNCTION public.fn_admin_delete_anamnesis(uuid) TO anon;
GRANT ALL ON FUNCTION public.fn_admin_delete_anamnesis(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.fn_admin_delete_anamnesis(uuid) TO service_role;
