
-- 058 — Última capa de la cascada de 056/057: get_my_active_plan bajó de 66s
-- a 5.6s pero seguía con 372K buffer hits para 28 filas. fn_runner_id_for_user()
-- no era SECURITY DEFINER, así que cada invocación (se llama por fila, no se
-- memoiza) volvía a disparar las 3 políticas RLS de runners (admin_all,
-- coach_select, runner_own), cada una evaluando fn_is_coach()/
-- fn_is_admin_or_super() de nuevo. Es solo resolución de identidad — no hay
-- razón de negocio para pasar por RLS en cada llamada.
--
-- Remedio: SECURITY DEFINER (mismo patrón Ley III). Es un lookup de solo
-- lectura sobre auth.uid() propio — no expone datos de otras corredoras.

create or replace function public.fn_runner_id_for_user()
returns uuid
language sql
stable
security definer
set search_path = public
as $function$
  SELECT id FROM public.runners
  WHERE user_id = auth.uid()
  LIMIT 1;
$function$;

revoke all on function public.fn_runner_id_for_user() from public;
grant execute on function public.fn_runner_id_for_user() to authenticated;
