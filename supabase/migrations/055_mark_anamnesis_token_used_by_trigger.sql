-- 055 — Marcar anamnesis_tokens.used_at server-side (trigger), no desde el cliente.
--
-- Regresión detectada 2026-07-05 durante la revisión post-053: el cliente Web
-- marcaba el token como usado con un UPDATE directo como anon, pero un UPDATE
-- con WHERE también exige políticas SELECT sobre las filas afectadas y anon no
-- tiene ninguna en anamnesis_tokens → el UPDATE afecta 0 filas en silencio y
-- los tokens quedan reutilizables indefinidamente (funcionaba antes de la
-- auditoría: las 5 fichas históricas tienen used_at poblado).
--
-- Remedio (Ley III): el marcado pasa a ser responsabilidad del servidor — un
-- trigger AFTER INSERT sobre anamnesis, con función SECURITY DEFINER y
-- search_path fijo, sella el token en la misma transacción del INSERT. El
-- UPDATE del cliente queda como no-op inofensivo (su política USING exige
-- used_at IS NULL, que ya no se cumple).

create or replace function public.fn_marcar_anamnesis_token_usado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.token_id is not null then
    update anamnesis_tokens
       set used_at = coalesce(used_at, now())
     where id = new.token_id;
  end if;
  return new;
end;
$$;

revoke all on function public.fn_marcar_anamnesis_token_usado() from public, anon, authenticated;

drop trigger if exists trg_anamnesis_mark_token_used on public.anamnesis;

create trigger trg_anamnesis_mark_token_used
  after insert on public.anamnesis
  for each row execute function public.fn_marcar_anamnesis_token_usado();
