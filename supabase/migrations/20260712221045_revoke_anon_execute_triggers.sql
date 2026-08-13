-- 076 — Zero-Trust anon: cerrar también las funciones trigger
--
-- El barrido 074 excluyó las funciones de tipo trigger. Aunque NO son un vector
-- real (invocarlas directamente falla sin contexto de trigger: TG_OP/NEW/OLD),
-- el linter las marca (anon_security_definer_function_executable) y el criterio
-- zero-trust del repo pide que anon no tenga EXECUTE sobre nada que no sea un
-- endpoint público deliberado. Revocar EXECUTE de una función trigger NO afecta
-- el disparo del trigger (el motor las invoca sin verificar EXECUTE).
--
-- Ninguna de estas se invoca como RPC desde el cliente (verificado por grep).
-- Reversible: GRANT EXECUTE ... TO anon por función.

DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prorettype = 'trigger'::regtype
      AND has_function_privilege('anon', p.oid, 'EXECUTE')
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION public.%I(%s) FROM PUBLIC, anon;', r.proname, r.args);
  END LOOP;
END $$;
