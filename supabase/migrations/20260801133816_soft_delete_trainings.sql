-- 082 — Soft-delete para trainings: evitar pérdida permanente de entrenamientos
--
-- Motivo (2026-08-01): el botón "Eliminar" del panel Admin ejecutaba un DELETE
-- físico sobre `trainings`, que hace cascade sobre web_registrations,
-- training_checkins, training_invitations, training_leaders, training_pacers,
-- training_groups, training_sos_alerts y vip_event_invitations — destruyendo
-- permanentemente el entrenamiento y todo su historial de asistencia con solo
-- 2 clics, sin posibilidad de recuperación.
--
-- Fix: agregar `deleted_at`; el cliente ahora hace UPDATE en vez de DELETE.
-- Las vistas públicas y de admin ocultan los registros archivados. El dato
-- físico queda intacto y recuperable (SET deleted_at = NULL) si algún día
-- se necesita.

ALTER TABLE public.trainings
  ADD COLUMN deleted_at timestamptz NULL;

-- ============================================================================
-- Recrear trainings_web (pública) ocultando archivados
-- ============================================================================

DROP VIEW IF EXISTS public.trainings_web CASCADE;

CREATE VIEW public.trainings_web
WITH (security_invoker = true) AS
SELECT
  t.id,
  t.title AS titulo_entrenamiento,
  t.scheduled_at AS fecha_hora,
  t.location_name AS ubicacion,
  t.location_detail AS ubicacion_texto,
  t.latitude AS latitud,
  t.longitude AS longitud,
  t.max_capacity AS cupos_totales,
  CASE (t.status)::text
    WHEN 'published'::text THEN 'activo'::text
    WHEN 'cancelled'::text THEN 'cerrado'::text
    ELSE (t.status)::text
  END AS estado,
  NULL::jsonb AS preguntas_extra,
  t.pacer_nombre
FROM public.trainings t
WHERE t.is_private = false AND t.deleted_at IS NULL;

GRANT SELECT ON public.trainings_web TO anon;
GRANT SELECT ON public.trainings_web TO authenticated;
GRANT SELECT ON public.trainings_web TO service_role;

-- ============================================================================
-- Recrear admin_trainings_view ocultando archivados
-- ============================================================================

DROP VIEW IF EXISTS public.admin_trainings_view;

CREATE VIEW public.admin_trainings_view AS
SELECT
  t.id,
  t.title AS titulo_entrenamiento,
  t.scheduled_at AS fecha_hora,
  t.location_name AS ubicacion,
  t.location_detail AS ubicacion_texto,
  t.latitude AS latitud,
  t.longitude AS longitud,
  t.max_capacity AS cupos_totales,
  CASE (t.status)::text
    WHEN 'published'::text THEN 'activo'::text
    WHEN 'cancelled'::text THEN 'cerrado'::text
    ELSE (t.status)::text
  END AS estado,
  t.is_private,
  t.pacer_nombre
FROM public.trainings t
WHERE (public.fn_is_admin_or_super() OR t.coach_id = auth.uid())
  AND t.deleted_at IS NULL;

REVOKE ALL ON public.admin_trainings_view FROM anon;
REVOKE ALL ON public.admin_trainings_view FROM PUBLIC;
GRANT SELECT ON public.admin_trainings_view TO authenticated;
