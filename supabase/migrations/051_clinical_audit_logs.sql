-- 051_clinical_audit_logs.sql
-- Sprint 8 (Hardening & Observabilidad): trazabilidad de mutaciones sobre datos clinicos sensibles.
-- Registra quien (auth.uid()), que fila, que operacion y el diff old/new para
-- anamnesis, health_alerts, plans y training_sessions.

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  entity text not null,
  entity_id uuid not null,
  action text not null check (action in ('UPDATE', 'DELETE')),
  old_value jsonb,
  new_value jsonb,
  created_at timestamptz not null default now()
);

comment on table public.audit_logs is 'Audit trail inmutable de mutaciones (UPDATE/DELETE) sobre entidades clinicas sensibles.';

-- Se consulta casi siempre por entidad+fila o por autor; created_at para orden/retencion.
create index if not exists audit_logs_entity_entity_id_idx on public.audit_logs (entity, entity_id);
create index if not exists audit_logs_user_id_idx on public.audit_logs (user_id);
create index if not exists audit_logs_created_at_idx on public.audit_logs (created_at desc);

alter table public.audit_logs enable row level security;

-- Nadie escribe audit_logs manualmente: solo lo hace el trigger (SECURITY DEFINER).
-- Lectura restringida a service_role (dashboards de compliance se sirven via Edge Function).
create policy audit_logs_service_role_select
  on public.audit_logs
  for select
  to service_role
  using (true);

-- ---------------------------------------------------------------------------
-- Funcion generica de trigger. SECURITY DEFINER para poder insertar en
-- audit_logs sin depender de que el rol que dispara el trigger tenga permiso
-- de escritura sobre esa tabla; STABLE-ish (en realidad VOLATILE por el INSERT)
-- pero sin locks adicionales: un solo INSERT de fila unica, sin FKs a validar,
-- por lo que el costo marginal por mutacion clinica es de un insert simple.
-- ---------------------------------------------------------------------------
create or replace function public.fn_capture_audit_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (tg_op = 'UPDATE') then
    insert into public.audit_logs (user_id, entity, entity_id, action, old_value, new_value)
    values (auth.uid(), tg_table_name, new.id, 'UPDATE', to_jsonb(old), to_jsonb(new));
    return new;
  elsif (tg_op = 'DELETE') then
    insert into public.audit_logs (user_id, entity, entity_id, action, old_value, new_value)
    values (auth.uid(), tg_table_name, old.id, 'DELETE', to_jsonb(old), null);
    return old;
  end if;
  return null;
end;
$$;

comment on function public.fn_capture_audit_log() is 'Trigger generico AFTER UPDATE/DELETE: escribe una fila en audit_logs con auth.uid() como autor.';

-- SECURITY DEFINER + funcion en el schema publico = ejecutable por anon via
-- /rest/v1/rpc/fn_capture_audit_log por defecto (GRANT EXECUTE a PUBLIC).
-- Debe dispararse solo como trigger, nunca invocarse directamente.
revoke execute on function public.fn_capture_audit_log() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Adjuntar el trigger a las tablas de maxima sensibilidad clinica.
-- AFTER (no BEFORE) para no bloquear la escritura original ni poder abortarla;
-- FOR EACH ROW porque el diff old/new es por fila.
-- ---------------------------------------------------------------------------
drop trigger if exists trg_audit_anamnesis on public.anamnesis;
create trigger trg_audit_anamnesis
  after update or delete on public.anamnesis
  for each row execute function public.fn_capture_audit_log();

drop trigger if exists trg_audit_health_alerts on public.health_alerts;
create trigger trg_audit_health_alerts
  after update or delete on public.health_alerts
  for each row execute function public.fn_capture_audit_log();

drop trigger if exists trg_audit_plans on public.plans;
create trigger trg_audit_plans
  after update or delete on public.plans
  for each row execute function public.fn_capture_audit_log();

drop trigger if exists trg_audit_training_sessions on public.training_sessions;
create trigger trg_audit_training_sessions
  after update or delete on public.training_sessions
  for each row execute function public.fn_capture_audit_log();
