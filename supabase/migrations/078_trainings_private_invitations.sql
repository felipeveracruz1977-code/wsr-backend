-- 078 — Entrenamientos privados por invitación
--
-- Permite crear entrenamientos que no aparecen en la lista pública pero se envían
-- a corredoras específicas vía invitación por email.
--
-- Cambios:
-- 1. Agregar columna `is_private` a tabla `trainings`
-- 2. Crear tabla `training_invitations` para gestionar invitaciones
-- 3. Crear RPC para invitar corredoras a entrenamientos privados
-- 4. Crear RPC para obtener entrenamientos privados con invitaciones de una corredora
-- 5. Actualizar vista `trainings_web` para excluir entrenamientos privados a anon
-- 6. Crear políticas RLS para `training_invitations`

-- ============================================================================
-- 1. Agregar columna `is_private` a trainings
-- ============================================================================

ALTER TABLE public.trainings ADD COLUMN is_private boolean DEFAULT false NOT NULL;
CREATE INDEX idx_trainings_is_private ON public.trainings (is_private) WHERE is_private = true;

-- ============================================================================
-- 2. Crear tabla de invitaciones a entrenamientos privados
-- ============================================================================

CREATE TABLE public.training_invitations (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  training_id uuid NOT NULL REFERENCES public.trainings(id) ON DELETE CASCADE,
  runner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invited_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  invited_at timestamp with time zone DEFAULT now() NOT NULL,
  status text DEFAULT 'pending' NOT NULL CHECK (status IN ('pending', 'accepted', 'declined')),
  responded_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  UNIQUE(training_id, runner_id)
);

CREATE INDEX idx_training_invitations_runner ON public.training_invitations(runner_id);
CREATE INDEX idx_training_invitations_training ON public.training_invitations(training_id);
CREATE INDEX idx_training_invitations_status ON public.training_invitations(status);

-- ============================================================================
-- 3. Políticas RLS para training_invitations
-- ============================================================================

ALTER TABLE public.training_invitations ENABLE ROW LEVEL SECURITY;

-- Admin y super_admin ven todas las invitaciones de sus entrenamientos
CREATE POLICY "Admin ve invitaciones de sus entrenamientos" ON public.training_invitations
FOR SELECT USING (
  fn_is_admin_or_super()
  OR training_id IN (
    SELECT id FROM trainings WHERE coach_id = auth.uid()
  )
);

-- Corredora ve sus propias invitaciones
CREATE POLICY "Corredora ve sus invitaciones" ON public.training_invitations
FOR SELECT USING (runner_id = auth.uid());

-- Admin puede insertar invitaciones
CREATE POLICY "Admin puede invitar" ON public.training_invitations
FOR INSERT WITH CHECK (
  fn_is_admin_or_super()
  OR training_id IN (
    SELECT id FROM trainings WHERE coach_id = auth.uid()
  )
);

-- Admin puede actualizar el status de invitaciones
CREATE POLICY "Admin puede actualizar invitaciones" ON public.training_invitations
FOR UPDATE USING (
  fn_is_admin_or_super()
  OR training_id IN (
    SELECT id FROM trainings WHERE coach_id = auth.uid()
  )
);

-- Corredora puede actualizar su propio status de invitación (accept/decline)
CREATE POLICY "Corredora puede responder invitación" ON public.training_invitations
FOR UPDATE USING (runner_id = auth.uid())
WITH CHECK (runner_id = auth.uid());

-- ============================================================================
-- 4. RPC: Invitar corredora a entrenamiento privado
-- ============================================================================

CREATE OR REPLACE FUNCTION public.invite_to_training(
  p_training_id uuid,
  p_runner_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_training trainings%ROWTYPE;
  v_is_coach boolean;
BEGIN
  -- Verificar que el entrenamiento existe y es privado
  SELECT * INTO v_training FROM trainings WHERE id = p_training_id;
  IF v_training.id IS NULL THEN
    RAISE EXCEPTION 'Entrenamiento no encontrado';
  END IF;

  IF NOT v_training.is_private THEN
    RAISE EXCEPTION 'Solo se pueden invitar corredoras a entrenamientos privados';
  END IF;

  -- Verificar que quien invita es admin o coach del entrenamiento
  IF NOT fn_is_admin_or_super() THEN
    IF v_training.coach_id IS NULL OR v_training.coach_id <> auth.uid() THEN
      RAISE EXCEPTION 'No tienes permiso para invitar a este entrenamiento';
    END IF;
  END IF;

  -- Insertar o actualizar invitación
  INSERT INTO training_invitations (training_id, runner_id, invited_by, status)
  VALUES (p_training_id, p_runner_id, auth.uid(), 'pending')
  ON CONFLICT (training_id, runner_id)
  DO UPDATE SET status = 'pending', invited_at = now();
END;
$function$;

GRANT ALL ON FUNCTION public.invite_to_training(uuid, uuid) TO authenticated;

-- ============================================================================
-- 5. RPC: Obtener entrenamientos privados para los que una corredora está invitada
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_private_trainings_for_runner()
RETURNS TABLE (
  id uuid,
  title text,
  description text,
  scheduled_at timestamp with time zone,
  location_name text,
  location_maps_url text,
  distance_km numeric,
  recommended_level text,
  max_capacity integer,
  cover_image_url text,
  status text,
  training_type text,
  location_detail text,
  latitude numeric,
  longitude numeric,
  coach_id uuid,
  pacer_user_id uuid,
  invitation_status text,
  invited_at timestamp with time zone
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT
    t.id,
    t.title,
    t.description,
    t.scheduled_at,
    t.location_name,
    t.location_maps_url,
    t.distance_km,
    t.recommended_level,
    t.max_capacity,
    t.cover_image_url,
    t.status,
    t.training_type,
    t.location_detail,
    t.latitude,
    t.longitude,
    t.coach_id,
    t.pacer_user_id,
    ti.status,
    ti.invited_at
  FROM trainings t
  INNER JOIN training_invitations ti ON t.id = ti.training_id
  WHERE ti.runner_id = auth.uid()
    AND t.is_private = true
  ORDER BY t.scheduled_at DESC;
$function$;

GRANT ALL ON FUNCTION public.get_private_trainings_for_runner() TO authenticated;

-- ============================================================================
-- 6. RPC: Responder invitación (aceptar/rechazar)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.respond_training_invitation(
  p_invitation_id uuid,
  p_response text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_invitation training_invitations%ROWTYPE;
BEGIN
  IF p_response NOT IN ('accepted', 'declined') THEN
    RAISE EXCEPTION 'Respuesta inválida. Use "accepted" o "declined"';
  END IF;

  SELECT * INTO v_invitation FROM training_invitations WHERE id = p_invitation_id;
  IF v_invitation.id IS NULL THEN
    RAISE EXCEPTION 'Invitación no encontrada';
  END IF;

  IF v_invitation.runner_id <> auth.uid() THEN
    RAISE EXCEPTION 'No tienes permiso para responder esta invitación';
  END IF;

  UPDATE training_invitations
  SET status = p_response, responded_at = now()
  WHERE id = p_invitation_id;

  -- Si acepta, crear registro en registrations
  IF p_response = 'accepted' THEN
    INSERT INTO registrations (training_id, user_id, status, created_at)
    VALUES (v_invitation.training_id, auth.uid(), 'confirmed', now())
    ON CONFLICT (training_id, user_id) DO NOTHING;
  END IF;
END;
$function$;

GRANT ALL ON FUNCTION public.respond_training_invitation(uuid, text) TO authenticated;

-- ============================================================================
-- 7. Actualizar vista trainings_web para excluir entrenamientos privados a anon
-- ============================================================================

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
  t.pacer_nombre
FROM public.trainings t
-- Filtrar: excluir entrenamientos privados a anon, pero admin/coach ven todos
WHERE t.is_private = false
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

-- ============================================================================
-- 8. Permitir a admin crear registros en training_invitations sin ser propietaria
-- ============================================================================

GRANT INSERT, UPDATE ON public.training_invitations TO authenticated;
