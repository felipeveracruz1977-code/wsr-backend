-- 086 — Roster de marcas patrocinadoras para el Informe de Marca
--
-- Motivo (2026-08-11): el Informe de Marca (Web, InformeMarcaTab.tsx) pedía
-- nombre y @usuario de cada marca a mano en cada generación. Con auspicios
-- recurrentes (la misma marca vuelve evento tras evento, o acompaña
-- semana a semana) eso es retipear el mismo dato una y otra vez. Esta tabla
-- persiste el roster: se carga una marca una vez, después se selecciona.
--
-- No reutiliza `public.sponsors` (name, logo_url NOT NULL, banner_url,
-- website_url, is_active): esa tabla no la consulta ninguna vista del
-- proyecto hoy (queda huérfana, probablemente pensada para un showcase
-- público que nunca se conectó) y exige logo — friction que no tiene sentido
-- para simplemente guardar nombre + @usuario de Instagram para un reporte.
-- Son dos conceptos con el mismo nombre en español pero distinto propósito;
-- forzarlos a compartir tabla habría acoplado dos features que no se tocan.
--
-- Ley III: esta es data administrada directamente por el admin desde el
-- cliente (no un cron), así que SELECT/INSERT/UPDATE van a `authenticated`
-- con la misma condición fn_is_admin_or_super() que ya gatea el resto del
-- panel B2B -- no hace falta una función RPC SECURITY DEFINER porque no hay
-- lógica de negocio que verificar más allá de "es admin", que es exactamente
-- lo que RLS con derechos de invocador ya resuelve.

create table public.marcas_patrocinadoras (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  usuario_instagram text not null,
  -- Soft-delete: una marca que ya no auspicia deja de aparecer en el selector
  -- sin borrar el historial de informes que ya la mencionan (esos informes no
  -- se persisten, pero si alguna vez se guardan, no queremos una FK rota).
  activa boolean not null default true,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  constraint marcas_patrocinadoras_nombre_check check (btrim(nombre) <> ''),
  constraint marcas_patrocinadoras_usuario_check check (btrim(usuario_instagram) <> '')
);

comment on table public.marcas_patrocinadoras is
  'Roster de marcas patrocinadoras (nombre + @usuario de Instagram) para preseleccionar en el Informe de Marca, en vez de reingresarlas cada vez. Administrado directamente por el admin desde el cliente.';

-- Evita duplicados por typo de mayúsculas o espacios ("@GatoradeCL " vs
-- "@gatoradecl"): normaliza a minúsculas y sin espacios para la comparación,
-- sin forzar esa normalización en la columna visible.
create unique index marcas_patrocinadoras_usuario_unico
  on public.marcas_patrocinadoras (lower(btrim(usuario_instagram)));

create index marcas_patrocinadoras_activa_idx
  on public.marcas_patrocinadoras (activa) where activa;

-- fn_set_updated_at() ya existe pero codifica la columna `updated_at`
-- (inglés); el resto de este esquema usa `actualizado_en` (ver 085), así que
-- se agrega el equivalente en vez de renombrar la columna para calzar con
-- una función ajena a esta convención.
create or replace function public.fn_set_actualizado_en()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  new.actualizado_en = now();
  return new;
end;
$$;

create trigger marcas_patrocinadoras_actualizado_en
  before update on public.marcas_patrocinadoras
  for each row execute function public.fn_set_actualizado_en();

alter table public.marcas_patrocinadoras enable row level security;

create policy "Admin lee marcas patrocinadoras"
  on public.marcas_patrocinadoras for select to authenticated
  using (public.fn_is_admin_or_super());

create policy "Admin crea marcas patrocinadoras"
  on public.marcas_patrocinadoras for insert to authenticated
  with check (public.fn_is_admin_or_super());

create policy "Admin edita marcas patrocinadoras"
  on public.marcas_patrocinadoras for update to authenticated
  using (public.fn_is_admin_or_super())
  with check (public.fn_is_admin_or_super());

-- Sin policy de DELETE: se desactiva (activa = false), no se borra. Conserva
-- el registro de con qué marcas se ha trabajado alguna vez.

revoke all on public.marcas_patrocinadoras from anon, public;
grant select, insert, update on public.marcas_patrocinadoras to authenticated;
grant all on public.marcas_patrocinadoras to service_role;
