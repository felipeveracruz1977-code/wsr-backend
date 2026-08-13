-- 082 — Invitaciones VIP para entrenamientos privados (indexado por email)
--
-- Contexto: se necesita invitar por correo a corredoras que pueden no tener
-- cuenta creada en la app (solo se registraron alguna vez vía el formulario
-- público). training_invitations no sirve para este caso porque su
-- runner_id referencia auth.users.id (requiere cuenta). Se crea una tabla
-- nueva indexada por email, y dos RPC SECURITY DEFINER para que una página
-- pública pueda: (a) leer un entrenamiento privado por id (link "secreto"
-- no adivinable, mismo criterio que /anamnesis/:token y /check-in/:token),
-- y (b) prellenar nombre/teléfono SOLO si el email fue efectivamente
-- invitado a ese entrenamiento puntual (evita enumeración de emails
-- arbitrarios contra la tabla runners).

-- ─────────────────────────────────────────────────────────────
-- 1 · Tabla de invitaciones VIP (por email)
-- ─────────────────────────────────────────────────────────────

create table public.vip_event_invitations (
  id          uuid primary key default gen_random_uuid(),
  training_id uuid not null references public.trainings(id) on delete cascade,
  email       text not null,
  nombre      text,
  motivo      text not null,
  invited_by  uuid not null references auth.users(id),
  invited_at  timestamptz not null default now(),
  unique (training_id, email)
);

create index vip_event_invitations_training_idx on public.vip_event_invitations (training_id);

alter table public.vip_event_invitations enable row level security;

-- Lección de 064/067: anon no recibe ningún privilegio de tabla; el acceso
-- público pasa exclusivamente por fn_get_vip_invite_prefill (abajo). El
-- endpoint admin (Vercel) usa service_role, que ignora RLS.
revoke all on table public.vip_event_invitations from anon;

create policy vip_event_invitations_admin_all on public.vip_event_invitations
  for all to authenticated
  using (public.fn_is_admin_or_super())
  with check (public.fn_is_admin_or_super());

-- ─────────────────────────────────────────────────────────────
-- 2 · Lectura pública de un entrenamiento privado por id
--     (mismo shape que trainings_web, pero sin filtrar is_private)
-- ─────────────────────────────────────────────────────────────

create function public.fn_get_vip_event_public(p_training_id uuid)
returns table (
  id uuid,
  titulo_entrenamiento text,
  fecha_hora timestamptz,
  ubicacion text,
  ubicacion_texto text,
  latitud numeric(10,7),
  longitud numeric(10,7),
  cupos_totales integer,
  estado text,
  preguntas_extra jsonb
)
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  return query
  select
    t.id,
    t.title,
    t.scheduled_at,
    t.location_name,
    t.location_detail,
    t.latitude,
    t.longitude,
    t.max_capacity,
    case (t.status)::text
      when 'published'::text then 'activo'::text
      when 'cancelled'::text then 'cerrado'::text
      else (t.status)::text
    end,
    null::jsonb
  from public.trainings t
  where t.id = p_training_id
    and t.status = 'published';
end;
$$;

revoke all on function public.fn_get_vip_event_public(uuid) from public;
grant execute on function public.fn_get_vip_event_public(uuid) to anon, authenticated, service_role;

-- ─────────────────────────────────────────────────────────────
-- 3 · Prellenado de nombre/teléfono — solo si el email fue invitado
--     a ESTE entrenamiento puntual (evita enumeración de emails)
-- ─────────────────────────────────────────────────────────────

create function public.fn_get_vip_invite_prefill(p_training_id uuid, p_email text)
returns table (
  nombre text,
  telefono text
)
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  return query
  select r.nombre_apellido, r.telefono
  from public.vip_event_invitations vi
  join public.runners r on lower(r.email) = lower(vi.email)
  where vi.training_id = p_training_id
    and lower(vi.email) = lower(p_email)
  limit 1;
end;
$$;

revoke all on function public.fn_get_vip_invite_prefill(uuid, text) from public;
grant execute on function public.fn_get_vip_invite_prefill(uuid, text) to anon, authenticated, service_role;
