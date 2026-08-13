-- 067 — Check-in tokenizado + consentimientos versionados (Ley 21.719)
--
-- Contexto (auditoría de cumplimiento 2026-07-12):
--
-- H-1 · El check-in público identificaba a la corredora SOLO por su email:
--       fn_submit_check_in (EXECUTE para anon) permitía (a) enumerar qué
--       correos pertenecen a la comunidad, (b) enviar datos de salud a nombre
--       de terceras y (c) obtener el nombre de la titular a partir del correo.
--       Se reemplaza por un flujo de enlace tokenizado, espejo del patrón
--       anamnesis_tokens (054/055/064). La revocación del RPC por email vive
--       en la migración 068, que debe aplicarse JUNTO con el deploy de la web
--       que consume los RPC nuevos — aplicarla antes rompe el check-in vivo.
--
-- H-2 · runners no registraba la autorización de uso de imagen ni la versión
--       y fecha de los consentimientos aceptados. El art. 12 de la ley 19.628
--       (texto ley 21.719) pone la carga de la prueba del consentimiento en
--       el responsable: sin versión ni timestamp no hay prueba.

-- ─────────────────────────────────────────────────────────────
-- 1 · Consentimientos versionados en runners
-- ─────────────────────────────────────────────────────────────

alter table public.runners
  add column if not exists acepta_marketing    boolean not null default false,
  add column if not exists autoriza_imagen     boolean not null default false,
  add column if not exists consent_version     text,
  add column if not exists consents_updated_at timestamptz;

comment on column public.runners.acepta_marketing is
  'Consentimiento OPCIONAL para compartir intereses con marcas auspiciadoras (Ley 21.719 arts. 12/15). Separado del consentimiento base.';
comment on column public.runners.autoriza_imagen is
  'Autorización OPCIONAL de uso de imagen en web/RRSS (Ley 21.719 art. 12). Nunca condición de inscripción; revocable.';
comment on column public.runners.consent_version is
  'Versión del texto de consentimientos aceptado. La fija /api/save-profile server-side; el cliente no la envía.';
comment on column public.runners.consents_updated_at is
  'Momento en que la corredora aceptó/actualizó sus consentimientos por última vez.';

-- ─────────────────────────────────────────────────────────────
-- 2 · Tokens de check-in (espejo de anamnesis_tokens, endurecido según 064)
-- ─────────────────────────────────────────────────────────────

create table public.checkin_tokens (
  id         uuid primary key default gen_random_uuid(),
  token      text not null unique default gen_random_uuid()::text,
  runner_id  uuid not null references public.runners(id) on delete cascade,
  expires_at timestamptz not null default now() + interval '14 days',
  used_at    timestamptz,
  created_at timestamptz not null default now()
);

create index checkin_tokens_token_idx  on public.checkin_tokens (token);
create index checkin_tokens_runner_idx on public.checkin_tokens (runner_id, created_at desc);

alter table public.checkin_tokens enable row level security;

-- Lección de 064: anon no recibe NINGÚN privilegio de tabla; el acceso público
-- pasa exclusivamente por los RPC SECURITY DEFINER de abajo. Los endpoints
-- server-side (Vercel) usan service_role. Staff autenticado, solo vía RLS admin.
revoke all on table public.checkin_tokens from anon;

create policy checkin_tokens_admin_all on public.checkin_tokens
  for all to authenticated
  using (public.fn_is_admin_or_super())
  with check (public.fn_is_admin_or_super());

-- ─────────────────────────────────────────────────────────────
-- 3 · Validación pública del token (para pintar el formulario)
--     Devuelve solo el primer nombre: mínimo necesario para el saludo.
-- ─────────────────────────────────────────────────────────────

create function public.fn_validate_checkin_token(p_token text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_id         uuid;
  v_runner_id  uuid;
  v_expires_at timestamptz;
  v_used_at    timestamptz;
  v_nombre     text;
  v_week_start date := (date_trunc('week', (now() at time zone 'America/Santiago')))::date;
begin
  select t.id, t.runner_id, t.expires_at, t.used_at, split_part(r.nombre_apellido, ' ', 1)
    into v_id, v_runner_id, v_expires_at, v_used_at, v_nombre
    from public.checkin_tokens t
    join public.runners r on r.id = t.runner_id
   where t.token = p_token
   limit 1;

  if v_id is null then
    return jsonb_build_object('valid', false, 'reason', 'not_found');
  end if;

  if v_used_at is not null then
    return jsonb_build_object('valid', false, 'reason', 'already_used');
  end if;

  if v_expires_at < now() then
    return jsonb_build_object('valid', false, 'reason', 'expired');
  end if;

  if exists (
    select 1 from public.plan_check_ins
    where runner_id = v_runner_id and week_start = v_week_start
  ) then
    return jsonb_build_object('valid', false, 'reason', 'already_submitted', 'nombre', v_nombre);
  end if;

  return jsonb_build_object('valid', true, 'nombre', v_nombre);
end;
$$;

revoke all on function public.fn_validate_checkin_token(text) from public;
grant execute on function public.fn_validate_checkin_token(text) to anon, authenticated, service_role;

-- ─────────────────────────────────────────────────────────────
-- 4 · Envío del check-in autenticado por token (reemplaza al RPC por email)
-- ─────────────────────────────────────────────────────────────

create function public.fn_submit_check_in_token(
  p_token               text,
  p_sessions_planned    integer,
  p_sessions_completed  integer,
  p_energy              integer,
  p_sleep_quality       integer,
  p_motivation          integer,
  p_pain                integer,
  p_pain_location       text default null,
  p_life_changes        boolean default false,
  p_life_changes_detail text default null,
  p_comments            text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_token_id    uuid;
  v_runner_id   uuid;
  v_expires_at  timestamptz;
  v_used_at     timestamptz;
  v_nombre      text;
  v_plan_id     uuid;
  v_check_in_id uuid;
  v_week_start  date := (date_trunc('week', (now() at time zone 'America/Santiago')))::date;
begin
  select t.id, t.runner_id, t.expires_at, t.used_at, split_part(r.nombre_apellido, ' ', 1)
    into v_token_id, v_runner_id, v_expires_at, v_used_at, v_nombre
    from public.checkin_tokens t
    join public.runners r on r.id = t.runner_id
   where t.token = p_token
   limit 1;

  if v_token_id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_token');
  end if;

  if v_used_at is not null then
    return jsonb_build_object('ok', false, 'code', 'already_used');
  end if;

  if v_expires_at < now() then
    return jsonb_build_object('ok', false, 'code', 'expired');
  end if;

  -- Rangos server-side: el RPC es la frontera de confianza, no el formulario.
  if p_sessions_planned is null or p_sessions_planned not between 1 and 14
     or p_sessions_completed is null or p_sessions_completed not between 0 and p_sessions_planned
     or p_energy is null or p_energy not between 1 and 10
     or p_sleep_quality is null or p_sleep_quality not between 1 and 10
     or p_motivation is null or p_motivation not between 1 and 10
     or p_pain is null or p_pain not between 0 and 10 then
    return jsonb_build_object('ok', false, 'code', 'invalid_values');
  end if;

  if exists (
    select 1 from public.plan_check_ins
    where runner_id = v_runner_id and week_start = v_week_start
  ) then
    return jsonb_build_object('ok', false, 'code', 'already_submitted', 'nombre', v_nombre);
  end if;

  select id into v_plan_id
  from public.plans
  where runner_id = v_runner_id and status = 'active'
  order by created_at desc
  limit 1;

  insert into public.plan_check_ins (
    runner_id, plan_id, week_start,
    sessions_planned, sessions_completed,
    energy, sleep_quality, motivation,
    pain, pain_location,
    life_changes, life_changes_detail, comments
  ) values (
    v_runner_id, v_plan_id, v_week_start,
    p_sessions_planned, p_sessions_completed,
    p_energy, p_sleep_quality, p_motivation,
    p_pain, nullif(trim(coalesce(p_pain_location, '')), ''),
    coalesce(p_life_changes, false),
    nullif(trim(coalesce(p_life_changes_detail, '')), ''),
    nullif(trim(coalesce(p_comments, '')), '')
  )
  returning id into v_check_in_id;

  update public.checkin_tokens set used_at = now() where id = v_token_id;

  return jsonb_build_object(
    'ok', true,
    'check_in_id', v_check_in_id,
    'nombre', v_nombre,
    'alert', exists (select 1 from public.health_alerts where check_in_id = v_check_in_id)
  );
end;
$$;

revoke all on function public.fn_submit_check_in_token(text, integer, integer, integer, integer, integer, integer, text, boolean, text, text) from public;
grant execute on function public.fn_submit_check_in_token(text, integer, integer, integer, integer, integer, integer, text, boolean, text, text) to anon, authenticated, service_role;
