-- 049_community_score_rpc.sql
-- Read-only aggregator: consolidates community participation into a single
-- 0-100 score, consumed by the Adherence Engine (Engine 06) as a protective
-- signal in the Abandonment Risk Score (ARS) calculation.
--
-- Sources of "interacción comunitaria" (WSR philosophy: points, achievements,
-- and group-training attendance are the three ledgers that actually capture
-- a runner showing up for the community, as opposed to just following her
-- individual plan):
--   * public.point_transactions (user_id, points, created_at)
--   * public.user_achievements  (user_id, unlocked_at)
--   * public.training_checkins  (user_id, checked_in_at) — group training attendance
--
-- All three tables key on auth.users.id ("user_id"), not on runners.id, so
-- the function resolves p_runner_id -> runners.user_id internally.
--
-- Security: per Ley III (WSR_ECOSYSTEM_GOVERNANCE.md), read-only aggregates
-- do NOT need SECURITY DEFINER when existing RLS already authorizes the
-- access. point_transactions/user_achievements/training_checkins all carry
-- "own rows only" SELECT policies (auth.uid() = user_id), so under INVOKER
-- rights a non-admin caller passing someone else's p_runner_id simply gets 0
-- (RLS filters the joined rows) — no re-implementation of authorization by
-- hand. The Adherence Engine invokes this with the service_role client,
-- which bypasses RLS entirely and sees the real aggregates for every runner.

CREATE OR REPLACE FUNCTION public.fn_get_community_score(p_runner_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $$
  -- Score = sum of three capped sub-scores over a 30-day window, each
  -- normalized to its own ceiling so no single ledger can dominate:
  --   points        [0-50] : 10 recent points = 1 score point (cap at 500 pts)
  --   achievements  [0-25] : 12 pts per unlock in the window (cap at ~2 unlocks)
  --   attendance    [0-25] : 5 pts per group-training check-in (cap at 5 sessions)
  -- Final LEAST(100, ...) guards the contract even though the sub-caps
  -- already sum to exactly 100.
  SELECT LEAST(
    100,
    LEAST(COALESCE((
      SELECT SUM(pt.points)
      FROM public.point_transactions pt
      JOIN public.runners r ON r.user_id = pt.user_id
      WHERE r.id = p_runner_id
        AND pt.created_at >= now() - interval '30 days'
    ), 0) / 10, 50)
    +
    LEAST(COALESCE((
      SELECT COUNT(*)
      FROM public.user_achievements ua
      JOIN public.runners r ON r.user_id = ua.user_id
      WHERE r.id = p_runner_id
        AND ua.unlocked_at >= now() - interval '30 days'
    ), 0) * 12, 25)
    +
    LEAST(COALESCE((
      SELECT COUNT(*)
      FROM public.training_checkins tc
      JOIN public.runners r ON r.user_id = tc.user_id
      WHERE r.id = p_runner_id
        AND tc.checked_in_at >= now() - interval '30 days'
    ), 0) * 5, 25)
  )::integer;
$$;

COMMENT ON FUNCTION public.fn_get_community_score(uuid) IS
  'Read-only 0-100 community engagement score (30-day window: recent points + achievements unlocked + group-training check-ins). Invoker rights — relies on existing "own rows" RLS on point_transactions/user_achievements/training_checkins. Consumed by Engine 06 (adherence-engine) via service_role as a protective modifier on the ARS.';

GRANT EXECUTE ON FUNCTION public.fn_get_community_score(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_get_community_score(uuid) TO service_role;
