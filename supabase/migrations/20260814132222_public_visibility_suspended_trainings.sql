-- Mostrar entrenamientos suspendidos (status='cancelled') en la web pública,
-- en vez de ocultarlos por completo.
--
-- Contexto (2026-08-14): al suspender un entrenamiento por mal tiempo, las
-- políticas RLS de lectura pública sobre `trainings` solo dejaban pasar
-- status='published' (migración 080_split_public_admin_trainings_views.sql),
-- así que TrainingCalendar.tsx (Web) dejaba de mostrar la fecha por completo.
-- El equipo prefiere que la corredora siga viendo la fecha en el calendario,
-- marcada como "Suspendido" — evita que pregunten si hay o no entrenamiento.
--
-- Esto NO reabre inscripciones: el RPC inscribir_en_entrenamiento exige
-- status = 'published' de forma independiente (WHERE ... AND status =
-- 'published' → RAISE EXCEPTION si no), y RegistrationFlow.tsx (Web) ya
-- bloquea el formulario en el cliente cuando estado='cerrado'. Solo se
-- amplía qué filas puede LEER anon/authenticated.
--
-- Se amplían las 3 políticas de solo-lectura pública de la migración 080
-- para incluir status='cancelled', sin tocar is_private (se mantiene
-- oculto) ni las políticas de admin/coach/staff.

ALTER POLICY "Entrenamientos públicos" ON public.trainings
  USING (
    (auth.role() = 'authenticated'::text)
    AND (status = ANY (ARRAY['published'::public.training_status, 'cancelled'::public.training_status]))
    AND (is_private = false)
  );

ALTER POLICY "Entrenamientos visibles al público" ON public.trainings
  USING (
    (status = ANY (ARRAY['published'::public.training_status, 'cancelled'::public.training_status]))
    AND (is_private = false)
  );

ALTER POLICY "Web lee entrenamientos publicados" ON public.trainings
  USING (
    (status = ANY (ARRAY['published'::public.training_status, 'cancelled'::public.training_status]))
    AND (is_private = false)
  );
