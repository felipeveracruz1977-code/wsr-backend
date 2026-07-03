-- 048_coach_rbac_anamnesis_read.sql
-- Part of the admin-panel zero-trust RBAC rollout: the Web client now shows
-- the "Anamnesis" tab to coach-role users, but no RLS policy previously
-- granted coach SELECT access on public.anamnesis (only admin_all and
-- runner_own existed) — the tab would have rendered an empty list for
-- coaches. This mirrors the existing runners_coach_select /
-- plan_check_ins_coach_read pattern: coach can read anamnesis rows only for
-- runners assigned to them (runners.coach_id = auth.uid()).

CREATE POLICY anamnesis_coach_read ON public.anamnesis FOR SELECT TO authenticated USING (
  public.fn_is_coach() AND runner_id IN (
    SELECT runners.id FROM public.runners WHERE runners.coach_id = auth.uid()
  )
);
