-- 074 — Corrección de raíz REAL del leak de EXECUTE a anon (supersede 072/073)
--
-- Diagnóstico (auditoría 2026-07-12): las migraciones 072/073 revocaron el grant
-- EXPLÍCITO a anon/authenticated, pero el ACL de las funciones es `{=X/postgres,...}`
-- donde `=X` es un grant a PUBLIC. PostgreSQL otorga EXECUTE a PUBLIC por defecto
-- al crear CUALQUIER función. anon y authenticated heredan EXECUTE vía PUBLIC, por
-- lo que revocar solo el grant explícito no cierra el acceso. Hay que revocar de
-- PUBLIC. Verificado: has_function_privilege('anon', ...) seguía en true tras 072/073.
--
-- Estrategia (idempotente, reversible):
--   allow_anon  → endpoints públicos legítimos del cliente anónimo Web + helpers
--                 booleanos de RLS: se dejan intactos (PUBLIC ⊇ anon = intencional).
--   lock_both   → mutadores internos que NINGÚN cliente invoca (verificado por grep
--                 en App/ y Web/). Se revoca de PUBLIC + anon + authenticated →
--                 quedan solo para postgres (dueño, usado por SECURITY DEFINER
--                 internos y triggers) y service_role (edge functions).
--   resto       → RPC legítimas de usuaria autenticada (redeem_reward, send_message,
--                 finish_activity, submit_weekly_checkin, get_social_feed_following,
--                 helpers INVOKER llamados por triggers de authenticated, etc.):
--                 se garantiza GRANT explícito a authenticated y se revoca PUBLIC+anon.
--
-- Nota SECURITY DEFINER: los mutadores bloqueados (award_points, etc.) los invoca
-- redeem_reward/triggers como SECURITY DEFINER propiedad de postgres → corren con
-- privilegios del dueño (postgres, que conserva EXECUTE). Bloquearlos a clientes NO
-- rompe las cadenas internas.

DO $$
DECLARE
  r record;
  allow_anon text[] := ARRAY[
    -- endpoints públicos (cliente anónimo Web)
    'inscribir_en_entrenamiento',
    'fn_validate_anamnesis_token',
    'fn_anamnesis_token_valido',
    'fn_validate_checkin_token',
    'fn_submit_check_in_token',
    'get_training_leaders',
    -- helpers booleanos de RLS (cero fuga de datos; evaluados por políticas)
    'is_blocked_between',
    'is_channel_participant',
    'is_channel_admin',
    'channel_has_block',
    'has_role',
    'get_user_group_ids',
    'fn_is_coach',
    'fn_is_admin_or_super'
  ];
  lock_both text[] := ARRAY[
    'award_points',
    'award_points_by_rule',
    'evaluate_achievements',
    'record_user_activity',
    'promote_from_waitlist',
    'qualify_referral_if_needed',
    'check_ai_rate_limit',
    'assign_winner_code',
    'assign_training_coach',
    'assign_training_pacer'
  ];
BEGIN
  FOR r IN
    SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) AS args,
           has_function_privilege('authenticated', p.oid, 'EXECUTE') AS auth_can
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prorettype <> 'trigger'::regtype
  LOOP
    IF r.proname = ANY(allow_anon) THEN
      CONTINUE;  -- endpoint público / helper RLS: se deja como está
    ELSIF r.proname = ANY(lock_both) THEN
      EXECUTE format('REVOKE EXECUTE ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated;', r.proname, r.args);
    ELSE
      -- Preservar acceso de authenticated si hoy lo tiene (via cualquier ruta),
      -- luego cerrar la fuga a anon quitando PUBLIC.
      IF r.auth_can THEN
        EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s) TO authenticated;', r.proname, r.args);
      END IF;
      EXECUTE format('REVOKE EXECUTE ON FUNCTION public.%I(%s) FROM PUBLIC, anon;', r.proname, r.args);
    END IF;
  END LOOP;
END $$;

-- Corrección de raíz definitiva: las funciones futuras creadas por postgres NO
-- otorgarán EXECUTE a PUBLIC por defecto. En adelante cada migración debe GRANT
-- explícito a authenticated / anon según corresponda (patrón Zero-Trust del repo).
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
