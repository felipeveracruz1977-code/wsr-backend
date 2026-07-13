-- 080 — Fix: entrenamientos privados se filtraban a la sección pública
--
-- Bug (reportado 2026-07-13): la migración 079 agregó
-- `OR public.fn_is_admin_or_super()` a la vista COMPARTIDA trainings_web,
-- consultada tanto por la página pública /entrenamientos (TrainingCalendar.tsx)
-- como por el panel Admin. Como el admin mantiene la misma sesión autenticada
-- en todo el sitio, el entrenamiento privado empezó a aparecer también en la
-- página pública cuando el admin la visitaba logueado — la vista no puede
-- distinguir "quién pregunta" de "desde qué página se pregunta".
--
-- Además se detectó una brecha más profunda: las políticas RLS de la tabla
-- base `trainings` para anon/authenticated genérico ("Entrenamientos
-- públicos", "Entrenamientos visibles al público", "Web lee entrenamientos
-- publicados") solo verifican `status = 'published'` y NUNCA consideraron
-- `is_private`. Cualquier corredora autenticada (no solo el admin) que
-- consultara la tabla `trainings` directamente podía ver entrenamientos
-- privados-pero-publicados.
--
-- Fix:
-- 1. Revertir trainings_web a una vista SIEMPRE público-segura: jamás expone
--    is_private = true, sin importar el rol de quien consulta.
-- 2. Cerrar la brecha en las políticas RLS base de `trainings` agregando
--    `AND is_private = false` a las 3 políticas de solo-lectura pública.
-- 3. Crear admin_trainings_view: vista EXCLUSIVA del panel Admin, con su
--    propio chequeo de autorización (fn_is_admin_or_super() o
--    coach_id = auth.uid()) — no depende de las políticas RLS de la tabla
--    base (que solo reconocen role='admin', no 'super_admin').

-- ============================================================================
-- 1. trainings_web: SIEMPRE público-seguro
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
WHERE t.is_private = false;

GRANT SELECT ON public.trainings_web TO anon;
GRANT SELECT ON public.trainings_web TO authenticated;
GRANT SELECT ON public.trainings_web TO service_role;

-- ============================================================================
-- 2. Cerrar la brecha real en la tabla base `trainings`
-- ============================================================================

ALTER POLICY "Entrenamientos públicos" ON public.trainings
  USING ((auth.role() = 'authenticated'::text) AND (status = 'published'::public.training_status) AND (is_private = false));

ALTER POLICY "Entrenamientos visibles al público" ON public.trainings
  USING ((status = 'published'::public.training_status) AND (is_private = false));

ALTER POLICY "Web lee entrenamientos publicados" ON public.trainings
  USING ((status = 'published'::public.training_status) AND (is_private = false));

-- ============================================================================
-- 3. admin_trainings_view: exclusiva del panel Admin, nunca compartida
--    con la página pública
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
WHERE public.fn_is_admin_or_super() OR t.coach_id = auth.uid();

REVOKE ALL ON public.admin_trainings_view FROM anon;
REVOKE ALL ON public.admin_trainings_view FROM PUBLIC;
GRANT SELECT ON public.admin_trainings_view TO authenticated;
