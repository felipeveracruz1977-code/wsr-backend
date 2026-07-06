
-- 059 — El linter de seguridad marcó fn_coach_owns_plan/_week/_runner,
-- fn_runner_owns_plan/_week y fn_runner_id_for_user como ejecutables por
-- `anon` (default privilege de Supabase que otorga EXECUTE a anon/authenticated
-- en funciones nuevas del schema public; REVOKE ALL FROM PUBLIC no alcanza
-- ese grant directo). No hay fuga de datos (solo booleano sobre auth.uid()),
-- pero se cierra explícitamente: estas son piezas internas de RLS, no API
-- pública, y anon no tiene auth.uid() de todas formas.

revoke execute on function public.fn_coach_owns_plan(uuid)   from anon;
revoke execute on function public.fn_coach_owns_week(uuid)   from anon;
revoke execute on function public.fn_coach_owns_runner(uuid) from anon;
revoke execute on function public.fn_runner_owns_plan(uuid)  from anon;
revoke execute on function public.fn_runner_owns_week(uuid)  from anon;
revoke execute on function public.fn_runner_id_for_user()    from anon;
