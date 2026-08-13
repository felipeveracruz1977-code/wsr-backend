-- 089 — HOTFIX: guard de autenticación + revocación anon en invite_to_training
-- y respond_training_invitation.
--
-- Hallazgo (auditoría 2026-08-13):
-- 1. Ambas funciones (creadas en 078_trainings_private_invitations.sql) fueron
--    otorgadas solo a `authenticated`, pero nunca se revocó el EXECUTE que
--    Postgres concede a PUBLIC por defecto al crear una función. Verificado
--    en vivo: `has_function_privilege('anon', ...)` = true para ambas.
-- 2. Bug de semántica NULL independiente del punto 1: ambas funciones comparan
--    `columna <> auth.uid()` para verificar propiedad. Con `auth.uid() IS NULL`
--    (anon, sin sesión), esa comparación evalúa a NULL (no TRUE), y en
--    PL/pgSQL `IF NULL THEN ... END IF` no ejecuta la rama — el RAISE
--    EXCEPTION de "no tienes permiso" nunca se dispara. Es decir, incluso si
--    solo se hubiera corregido el GRANT, el propio código de la función tiene
--    una fuga de autorización latente para cualquier llamador con auth.uid()
--    NULL. Por eso el guard explícito al inicio es necesario y no cosmético.
--
-- Cambios: agrega `IF auth.uid() IS NULL THEN RAISE EXCEPTION` al inicio de
-- cada función (antes de cualquier otra lógica) y revoca EXECUTE de PUBLIC y
-- anon, manteniendo el GRANT a authenticated.

-- ============================================================================
-- invite_to_training
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
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

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

REVOKE EXECUTE ON FUNCTION public.invite_to_training(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.invite_to_training(uuid, uuid) TO authenticated;

-- ============================================================================
-- respond_training_invitation
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
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

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

REVOKE EXECUTE ON FUNCTION public.respond_training_invitation(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.respond_training_invitation(uuid, text) TO authenticated;
