-- 054 — Fix: anamnesis_public_submit siempre rechazaba el INSERT anónimo.
--
-- La política creada en 053 (FASE 3d) valida el token con un EXISTS sobre
-- anamnesis_tokens, pero ese subquery se evalúa bajo el RLS del rol invocador
-- y anamnesis_tokens no tiene política SELECT para anon → el EXISTS siempre
-- es falso y todo envío público de ficha falla con 401 (regresión detectada
-- 2026-07-05, reportada por runner Maura Bellagamba).
--
-- Remedio (Ley III): la validación del token se encapsula en una función
-- SECURITY DEFINER con search_path fijo, que lee anamnesis_tokens con
-- privilegios elevados sin exponer la tabla al rol anon.

create or replace function public.fn_anamnesis_token_valido(p_token_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from anamnesis_tokens t
    where t.id = p_token_id
      and t.used_at is null
      and t.expires_at > now()
  );
$$;

revoke all on function public.fn_anamnesis_token_valido(uuid) from public;
grant execute on function public.fn_anamnesis_token_valido(uuid) to anon, authenticated;

drop policy if exists anamnesis_public_submit on public.anamnesis;

create policy anamnesis_public_submit
  on public.anamnesis for insert to anon, authenticated
  with check (
    token_id is not null
    and public.fn_anamnesis_token_valido(token_id)
  );
