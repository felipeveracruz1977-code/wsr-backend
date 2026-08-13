-- Comunidad: permitir designar líder de entrenamiento (coach/admin) y pacers
-- entre las inscritas reales (web_registrations) en vez de un catálogo aparte.

-- 1. training_leaders.role: admitir 'admin' además de 'coach'/'pacer'.
ALTER TABLE public.training_leaders DROP CONSTRAINT training_leaders_role_check;
ALTER TABLE public.training_leaders
  ADD CONSTRAINT training_leaders_role_check
  CHECK (role = ANY (ARRAY['coach'::text, 'pacer'::text, 'admin'::text]));

-- 2. training_pacers.pacer_id: retarget de wsr_pacers (catálogo vacío, muerto)
--    a web_registrations (inscritas reales). Tabla vacía hoy, sin datos que migrar.
ALTER TABLE public.training_pacers DROP CONSTRAINT training_pacers_pacer_id_fkey;
ALTER TABLE public.training_pacers
  ADD CONSTRAINT training_pacers_pacer_id_fkey
  FOREIGN KEY (pacer_id) REFERENCES public.web_registrations(id) ON DELETE CASCADE;

-- 3. Trigger: el pacer_id referenciado debe pertenecer al mismo training_id
--    (evita asignar como pacer a alguien inscrita en OTRO entrenamiento).
CREATE OR REPLACE FUNCTION public.fn_validate_training_pacer()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.web_registrations wr
    WHERE wr.id = NEW.pacer_id AND wr.training_id = NEW.training_id
  ) THEN
    RAISE EXCEPTION 'pacer_id debe corresponder a una inscripcion (web_registrations) del mismo training_id';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_training_pacer ON public.training_pacers;
CREATE TRIGGER trg_validate_training_pacer
  BEFORE INSERT OR UPDATE ON public.training_pacers
  FOR EACH ROW EXECUTE FUNCTION public.fn_validate_training_pacer();

-- 4. Policies de escritura para staff (mismo patron que trainings_staff_manage).
CREATE POLICY "training_leaders_staff_manage" ON public.training_leaders
  FOR ALL TO authenticated
  USING (fn_is_admin_or_super() OR fn_is_coach())
  WITH CHECK (fn_is_admin_or_super() OR fn_is_coach());

CREATE POLICY "training_pacers_staff_manage" ON public.training_pacers
  FOR ALL TO authenticated
  USING (fn_is_admin_or_super() OR fn_is_coach())
  WITH CHECK (fn_is_admin_or_super() OR fn_is_coach());
