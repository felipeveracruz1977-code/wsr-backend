-- 073 — Defensa en profundidad: mutadores internos no deben ser invocables por
-- ningún cliente (ni anon ni authenticated).
--
-- Hallazgo (auditoría 2026-07-12): award_points(p_user_id, p_points, ...) inserta
-- point_transactions y suma total_points de CUALQUIER usuaria sin verificar
-- identidad. Es un helper interno (lo invocan triggers, redeem_reward y
-- award_points_by_rule, todos SECURITY DEFINER que corren como owner, y edge
-- functions con service_role). Ningún cliente lo llama directamente (verificado
-- por grep en App/ y Web/). Exponerlo a authenticated permitía a cualquier
-- usuaria acreditarse puntos arbitrarios → fraude en el canje de recompensas.
--
-- Se revoca EXECUTE (anon + authenticated) de los mutadores internos. Los
-- llamantes legítimos (SECURITY DEFINER / triggers / service_role) NO dependen
-- del grant directo, por lo que el ecosistema no se rompe.
--
-- Reversible: GRANT EXECUTE ... TO authenticated por función.

REVOKE EXECUTE ON FUNCTION public.award_points(uuid, integer, text, uuid, text)          FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.award_points_by_rule(uuid, text, uuid, text)            FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.evaluate_achievements(uuid)                             FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.record_user_activity(uuid)                              FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.promote_from_waitlist(uuid)                             FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.qualify_referral_if_needed(uuid)                        FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.check_ai_rate_limit(uuid, integer, integer)             FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.assign_winner_code(uuid, uuid, text)                    FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.assign_training_coach(uuid, uuid)                       FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.assign_training_pacer(uuid, uuid)                       FROM anon, authenticated;
