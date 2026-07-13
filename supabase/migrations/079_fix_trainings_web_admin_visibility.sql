-- 079 — Fix: admin no veía sus propios entrenamientos privados
--
-- Bug (reportado 2026-07-13): la vista trainings_web (migración 078) solo
-- dejaba pasar entrenamientos privados a authenticated cuando:
--   - coach_id = auth.uid(), o
--   - existe una invitación para esa corredora
-- Un admin que crea un entrenamiento privado sin asignarse como coach_id
-- (caso normal: coach_id queda NULL) nunca aparecía en su propia lista del
-- panel Admin, porque la vista nunca consultaba fn_is_admin_or_super().
--
-- Fix: agregar `OR public.fn_is_admin_or_super()` a la condición de la vista,
-- y exponer la columna is_private para que el Admin la pueda leer y mostrar
-- el badge correspondiente.

DROP VIEW IF EXISTS public.trainings_web CASCADE;

CREATE VIEW public.trainings_web AS
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
  t.pacer_nombre,
  t.is_private
FROM public.trainings t
WHERE t.is_private = false
  OR public.fn_is_admin_or_super()
  OR (auth.role() != 'anon' AND auth.role() != 'authenticated')
  OR (auth.role() = 'authenticated' AND (
    t.coach_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM training_invitations ti
      WHERE ti.training_id = t.id AND ti.runner_id = auth.uid()
    )
  ));

ALTER VIEW public.trainings_web SET (security_invoker = true);

GRANT ALL ON public.trainings_web TO anon;
GRANT ALL ON public.trainings_web TO authenticated;
GRANT ALL ON public.trainings_web TO service_role;
