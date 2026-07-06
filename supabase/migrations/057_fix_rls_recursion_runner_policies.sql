
-- 057 — Continuación de 056: el fix de las políticas *_coach_own bajó el
-- Planning Time de 62s a 0.08ms, pero la ejecución seguía en 40s / 2.7M
-- buffer hits — porque training_weeks_runner_own y training_sessions_runner_own
-- tienen el MISMO patrón: EXISTS referenciando plans/training_weeks, que
-- vuelve a disparar RLS recursivamente en cascada (esta vez en tiempo de
-- ejecución, no de planificación, porque el runner es quien está corriendo
-- la consulta real en get_my_active_plan()).
--
-- Remedio: mismo patrón SECURITY DEFINER (Ley III) para el lado runner.

create or replace function public.fn_runner_owns_plan(p_plan_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.plans p
    where p.id = p_plan_id and p.runner_id = public.fn_runner_id_for_user()
  );
$$;

revoke all on function public.fn_runner_owns_plan(uuid) from public;
grant execute on function public.fn_runner_owns_plan(uuid) to authenticated;

create or replace function public.fn_runner_owns_week(p_week_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.training_weeks tw
    join public.plans p on p.id = tw.plan_id
    where tw.id = p_week_id and p.runner_id = public.fn_runner_id_for_user()
  );
$$;

revoke all on function public.fn_runner_owns_week(uuid) from public;
grant execute on function public.fn_runner_owns_week(uuid) to authenticated;

drop policy if exists training_weeks_runner_own on public.training_weeks;
create policy training_weeks_runner_own
  on public.training_weeks for select
  using (public.fn_runner_owns_plan(plan_id));

drop policy if exists training_sessions_runner_own on public.training_sessions;
create policy training_sessions_runner_own
  on public.training_sessions for select
  using (public.fn_runner_owns_week(week_id));
