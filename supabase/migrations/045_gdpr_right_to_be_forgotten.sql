-- 045 — Derecho al Olvido / Derecho de Supresión (Ley 21.719 Art. 4)
--
-- CONTEXTO DE GOBERNANZA: fn_forget_runner v1 fue aplicada al clúster APP
-- fuera del repositorio (el número 045 quedó vacante entre 044 y 046). Este
-- archivo salda esa deuda documental y a la vez eleva la función a v2.
--
-- v1 purgaba: anamnesis_tokens (por email) → anamnesis (explícito, pre-cascade)
-- → runners (CASCADE: plans, check_ins, health_alerts, scores, adherence_scores,
-- session_results, health_profiles, runner_profiles, assessments…) → log GDPR.
--
-- v2 cierra las fugas detectadas en la auditoría DPO 2026-07-09 — tablas con
-- PII/N2 que NO cuelgan de runners por CASCADE y sobrevivían a la supresión:
--   · web_registrations         (nombre, email, teléfono, contacto_emergencia,
--                                condicion_medica N2) — sin FK a runners.
--   · legacy_web_registrations  (contacto_emergencia, condicion_medica N2) —
--                                FK ON DELETE SET NULL: la fila quedaba huérfana
--                                con los datos clínicos intactos.
--   · event_winners             (nombre_externo, email_externo) — FK SET NULL.
--                                Se anonimiza (se conserva el código de premio
--                                como registro de negocio, sin titular).

-- ── Log de auditoría de supresiones (sin PII: solo UUIDs) ────────────────────
create table if not exists public.gdpr_deletion_log (
  id           uuid primary key default gen_random_uuid(),
  runner_id    uuid not null,
  deleted_at   timestamptz not null default now(),
  requested_by uuid,
  reason       text,
  created_at   timestamptz not null default now()
);

alter table public.gdpr_deletion_log enable row level security;

drop policy if exists gdpr_deletion_log_admin_read on public.gdpr_deletion_log;
create policy gdpr_deletion_log_admin_read
  on public.gdpr_deletion_log
  for select to authenticated
  using (public.fn_is_admin_or_super());

revoke all on table public.gdpr_deletion_log from anon;

-- ── RPC atómica de supresión ─────────────────────────────────────────────────
create or replace function public.fn_forget_runner(
  p_runner_id uuid,
  p_reason    text default 'Solicitud de supresión Art. 4 Ley 21.719'
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_email      text;
  v_deleted_at timestamptz;
  n_tokens     int;
  n_anamnesis  int;
  n_webregs    int;
  n_legacy     int;
  n_winners    int;
begin
  if not public.fn_is_admin_or_super() then
    raise exception 'Acceso denegado: se requiere rol de administrador (Ley 21.719 Art. 4).'
      using errcode = 'insufficient_privilege';
  end if;

  select email
    into v_email
    from public.runners
   where id = p_runner_id;

  if v_email is null then
    return jsonb_build_object(
      'ok',        false,
      'error',     'runner_not_found',
      'runner_id', p_runner_id
    );
  end if;

  -- 1. Purgar tokens (sin FK a runners, vinculados solo por email)
  delete from public.anamnesis_tokens
   where lower(runner_email) = lower(v_email);
  get diagnostics n_tokens = row_count;

  -- 2. Borrar anamnesis explícitamente para trazabilidad WAL pre-cascade
  delete from public.anamnesis
   where runner_id = p_runner_id
      or lower(runner_email) = lower(v_email);
  get diagnostics n_anamnesis = row_count;

  -- 3. Inscripciones web actuales (PII + condicion_medica N2, sin FK a runners)
  delete from public.web_registrations
   where lower(email) = lower(v_email);
  get diagnostics n_webregs = row_count;

  -- 4. Inscripciones legadas (FK SET NULL dejaba huérfanos con N2)
  delete from public.legacy_web_registrations
   where runner_id = p_runner_id;
  get diagnostics n_legacy = row_count;

  -- 5. Premios: anonimizar titular, conservar el código como registro de negocio
  update public.event_winners
     set nombre_externo = null,
         email_externo  = null
   where runner_id = p_runner_id
      or lower(email_externo) = lower(v_email);
  get diagnostics n_winners = row_count;

  -- 6. Borrar runner → CASCADE elimina plans, check_ins, health_alerts,
  --    scores IA, adherence_scores, session_results y la cadena completa
  delete from public.runners
   where id = p_runner_id;

  -- 7. Log de auditoría (sin PII — solo UUID)
  v_deleted_at := now();

  insert into public.gdpr_deletion_log (runner_id, deleted_at, requested_by, reason)
  values (p_runner_id, v_deleted_at, auth.uid(), p_reason);

  return jsonb_build_object(
    'ok',                  true,
    'deleted_at',          v_deleted_at,
    'runner_id',           p_runner_id,
    'purged',              jsonb_build_object(
      'anamnesis_tokens',          n_tokens,
      'anamnesis',                 n_anamnesis,
      'web_registrations',         n_webregs,
      'legacy_web_registrations',  n_legacy,
      'event_winners_anonimizados', n_winners
    )
  );

exception
  when others then
    return jsonb_build_object(
      'ok',        false,
      'error',     sqlerrm,
      'sqlstate',  sqlstate,
      'runner_id', p_runner_id
    );
end;
$$;

-- La función verifica fn_is_admin_or_super() internamente; aún así, anon no
-- tiene ninguna razón legítima para poder invocarla.
revoke all on function public.fn_forget_runner(uuid, text) from public, anon;
grant execute on function public.fn_forget_runner(uuid, text) to authenticated, service_role;
