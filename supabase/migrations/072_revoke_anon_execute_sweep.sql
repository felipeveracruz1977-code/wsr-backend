-- 072 — Zero-Trust anon: barrido integral de EXECUTE + corrección de raíz
--
-- Hallazgo (auditoría 2026-07-12): 76 funciones no-trigger del schema public
-- eran ejecutables por `anon`. La causa raíz es el default privilege de Supabase
-- (pg_default_acl, grantor postgres/supabase_admin) que otorga EXECUTE a anon a
-- CADA función nueva de public. Las revocaciones previas (059, 064) fueron
-- puntuales; cada migración posterior (066/067/069/070) volvió a exponer.
--
-- Estrategia: revocar EXECUTE de anon en TODA función de public EXCEPTO:
--   (A) Endpoints públicos legítimos que el cliente anónimo de la Web invoca:
--       - inscribir_en_entrenamiento  (formulario público /inscripcion)
--       - fn_validate_anamnesis_token, fn_submit... (no aplica), fn_anamnesis_token_valido
--         (fn_anamnesis_token_valido lo evalúa la política RLS anamnesis_public_submit)
--       - fn_validate_checkin_token, fn_submit_check_in_token  (/check-in/:token)
--       - get_training_leaders  (página pública /entrenamientos → TrainingCalendar)
--   (B) Helpers booleanos de RLS (retornan solo booleanos sobre auth.uid(), CERO
--       fuga de datos) que las políticas aplicables al rol public podrían evaluar
--       si anon lee esas tablas. Se conservan por seguridad de no romper lecturas
--       anónimas legítimas; su exposición es inocua (mismo criterio que 059).
--
-- Idempotente y reversible: para revertir, GRANT EXECUTE ... TO anon por función.

DO $$
DECLARE
  r record;
  allow text[] := ARRAY[
    -- (A) endpoints públicos
    'inscribir_en_entrenamiento',
    'fn_validate_anamnesis_token',
    'fn_anamnesis_token_valido',
    'fn_validate_checkin_token',
    'fn_submit_check_in_token',
    'get_training_leaders',
    -- (B) helpers booleanos de RLS (cero fuga de datos)
    'is_blocked_between',
    'is_channel_participant',
    'is_channel_admin',
    'channel_has_block',
    'has_role',
    'get_user_group_ids',
    'fn_is_coach',
    'fn_is_admin_or_super'
  ];
BEGIN
  FOR r IN
    SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND has_function_privilege('anon', p.oid, 'EXECUTE')
      AND NOT (p.proname = ANY(allow))
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION public.%I(%s) FROM anon;', r.proname, r.args);
  END LOOP;
END $$;

-- Corrección de raíz: las funciones futuras creadas por `postgres` (rol de las
-- migraciones) ya NO otorgarán EXECUTE a anon por defecto. authenticated se
-- mantiene (lo necesita para las RPC legítimas; su superficie la acota RLS +
-- verificación interna de identidad).
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon;
