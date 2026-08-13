
-- 056 — Fix: get_my_active_plan() tardaba 60-90s (timeout) por recursión de RLS.
--
-- Las políticas *_coach_own de training_weeks y training_sessions, y
-- session_results_coach_read, usan EXISTS/IN referenciando plans/training_weeks
-- /runners directamente. Como esas tablas tienen sus propias políticas RLS
-- (varias permissive OR'd), Postgres las vuelve a evaluar recursivamente en
-- cascada por cada nivel del join plans→weeks→sessions→results — confirmado
-- con EXPLAIN: Planning Time 62s, 3.6M buffer hits para 28 filas reales.
-- Bloqueaba por completo la vista "Mi Plan" en la app (get_my_active_plan
-- devolvía 500 por statement_timeout).
--
-- Remedio (Ley III, mismo patrón que 054/055): encapsular la verificación de
-- pertenencia coach→plan en funciones SECURITY DEFINER. Al ejecutar con el
-- dueño de la tabla, la lectura interna no vuelve a disparar RLS sobre
-- plans/training_weeks/runners, cortando la cascada recursiva. La semántica
-- de autorización no cambia: mismas reglas, sin recomputar RLS en cadena.

create or replace function public.fn_coach_owns_plan(p_plan_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.plans p
    where p.id = p_plan_id and p.coach_id = auth.uid()
  );
$$;

revoke all on function public.fn_coach_owns_plan(uuid) from public;
grant execute on function public.fn_coach_owns_plan(uuid) to authenticated;

create or replace function public.fn_coach_owns_week(p_week_id uuid)
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
    where tw.id = p_week_id and p.coach_id = auth.uid()
  );
$$;

revoke all on function public.fn_coach_owns_week(uuid) from public;
grant execute on function public.fn_coach_owns_week(uuid) to authenticated;

create or replace function public.fn_coach_owns_runner(p_runner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.runners r
    where r.id = p_runner_id and r.coach_id = auth.uid()
  );
$$;

revoke all on function public.fn_coach_owns_runner(uuid) from public;
grant execute on function public.fn_coach_owns_runner(uuid) to authenticated;

drop policy if exists training_weeks_coach_own on public.training_weeks;
create policy training_weeks_coach_own
  on public.training_weeks for all
  using (fn_is_coach() and public.fn_coach_owns_plan(plan_id));

drop policy if exists training_sessions_coach_own on public.training_sessions;
create policy training_sessions_coach_own
  on public.training_sessions for all
  using (fn_is_coach() and public.fn_coach_owns_week(week_id));

drop policy if exists session_results_coach_read on public.session_results;
create policy session_results_coach_read
  on public.session_results for select
  using (fn_is_coach() and public.fn_coach_owns_runner(runner_id));
