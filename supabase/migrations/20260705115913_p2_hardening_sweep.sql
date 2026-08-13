-- 053_p2_hardening_sweep.sql
-- Remediación P2 — auditoría de seguridad 2026-07-05 (Fases 1-3 del P2 Sweep).
--
-- FASE 1: search_path fijo en las 29 funciones SECURITY DEFINER/trigger
--          con search_path mutable (previene search_path hijacking).
-- FASE 2: bucket profile-photos: se elimina el SELECT bucket-wide para
--          authenticated; cada usuaria solo puede listar SU carpeta.
--          La lectura de fotos ajenas sigue funcionando vía URL pública
--          exacta (la App usa getPublicUrl, nunca .list()).
-- FASE 3: cierre de políticas RLS 'always true':
--   * trainings / web_registrations: cualquier authenticated podía
--     escribir/leer. Ahora solo staff (admin, super_admin, coach — las
--     coaches operan las tabs Entrenamientos/Comunidad del panel).
--   * runners_anon_insert: ELIMINADA. Ningún cliente inserta en runners
--     directamente (el formulario público usa /api/save-profile con
--     service_role, que bypassa RLS). Deny by default.
--   * anamnesis_public_submit: ya no es 'true' — cada INSERT anónimo debe
--     venir atado a un token vigente y no usado de anamnesis_tokens
--     (mata la inyección masiva de basura).
--   * ai_request_log / wsr_config: RLS ya estaba habilitado sin políticas
--     (deny implícito); se agregan políticas de denegación explícita.

-- ═══════════════════════════════════════════════════════════════════════
-- FASE 1 — search_path hardening (29 funciones detectadas por el advisor)
-- ═══════════════════════════════════════════════════════════════════════
do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'set_runners_updated_at','set_legacy_web_trainings_updated_at',
        'set_legacy_web_regs_updated_at','set_updated_at_timestamp',
        'update_updated_at','get_completed_sessions','get_current_streak',
        'award_points','award_streak_bonus_if_needed','calculate_tier',
        'can_earn_points','award_points_by_rule','trigger_update_tier',
        'trigger_award_survey_points','redeem_reward','qualify_referral_if_needed',
        'upsert_user_onboarding','sync_post_likes_count','submit_emotional_checkin',
        'handle_anamnesis_updated_at','record_user_activity','trg_record_activity_on_points',
        'get_comeback_info','get_recent_checkins','handle_sponsor_events_updated_at',
        'handle_event_winners_updated_at','fn_set_updated_at','submit_weekly_checkin',
        'get_my_week_checkin'
      )
      and not exists (
        select 1 from unnest(coalesce(p.proconfig, '{}')) cfg
        where cfg like 'search_path=%'
      )
  loop
    execute format('alter function %s set search_path = public', fn.sig);
  end loop;
end $$;

-- ═══════════════════════════════════════════════════════════════════════
-- FASE 2 — Storage: bloquear el listado del bucket profile-photos
-- ═══════════════════════════════════════════════════════════════════════
-- Antes: SELECT bucket-wide para authenticated ⇒ cualquier usuaria (o bot
-- con cuenta) podía listar TODAS las fotos. Ahora: solo su propia carpeta.
drop policy if exists "Read profile photos" on storage.objects;

create policy "Read own profile photos"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'profile-photos'
    and (auth.uid())::text = (storage.foldername(name))[1]
  );

-- ═══════════════════════════════════════════════════════════════════════
-- FASE 3a — trainings: erradicar políticas 'always true'
-- ═══════════════════════════════════════════════════════════════════════
drop policy if exists "Admin autenticado puede crear entrenamientos"    on public.trainings;
drop policy if exists "Admin autenticado puede editar entrenamientos"   on public.trainings;
drop policy if exists "Admin autenticado puede eliminar entrenamientos" on public.trainings;

-- Staff del panel (admin/super_admin/coach) gestiona entrenamientos.
-- Las políticas públicas de SELECT (status='published') no se tocan.
create policy trainings_staff_manage
  on public.trainings for all to authenticated
  using (fn_is_admin_or_super() or fn_is_coach())
  with check (fn_is_admin_or_super() or fn_is_coach());

-- ═══════════════════════════════════════════════════════════════════════
-- FASE 3b — web_registrations: erradicar políticas 'always true'
-- ═══════════════════════════════════════════════════════════════════════
drop policy if exists "Admin actualiza web_registrations"               on public.web_registrations;
drop policy if exists "Admin autenticado puede eliminar registraciones" on public.web_registrations;
drop policy if exists "Admin gestiona web_registrations"                on public.web_registrations;

-- Coaches necesitan leer y marcar asistencia (tab Entrenamientos del panel).
create policy web_registrations_staff_read
  on public.web_registrations for select to authenticated
  using (fn_is_admin_or_super() or fn_is_coach());

create policy web_registrations_staff_update
  on public.web_registrations for update to authenticated
  using (fn_is_admin_or_super() or fn_is_coach())
  with check (fn_is_admin_or_super() or fn_is_coach());

-- Borrar inscripciones queda reservado a admin/super_admin.
create policy web_registrations_admin_delete
  on public.web_registrations for delete to authenticated
  using (fn_is_admin_or_super());

-- ═══════════════════════════════════════════════════════════════════════
-- FASE 3c — runners: eliminar el INSERT anónimo 'always true' (sin uso)
-- ═══════════════════════════════════════════════════════════════════════
drop policy if exists runners_anon_insert on public.runners;

-- ═══════════════════════════════════════════════════════════════════════
-- FASE 3d — anamnesis: INSERT público atado a token vigente
-- ═══════════════════════════════════════════════════════════════════════
drop policy if exists anamnesis_public_submit on public.anamnesis;

create policy anamnesis_public_submit
  on public.anamnesis for insert to anon, authenticated
  with check (
    token_id is not null
    and exists (
      select 1 from public.anamnesis_tokens t
      where t.id = token_id
        and t.used_at is null
        and t.expires_at > now()
    )
  );

-- ═══════════════════════════════════════════════════════════════════════
-- FASE 3e — ai_request_log / wsr_config: denegación explícita
-- ═══════════════════════════════════════════════════════════════════════
-- Ya estaban en deny implícito (RLS on, cero políticas). Se deja constancia
-- explícita del deny-by-default; solo service_role (bypass RLS) las opera.
create policy ai_request_log_deny_all
  on public.ai_request_log for all to anon, authenticated
  using (false) with check (false);

create policy wsr_config_deny_all
  on public.wsr_config for all to anon, authenticated
  using (false) with check (false);
