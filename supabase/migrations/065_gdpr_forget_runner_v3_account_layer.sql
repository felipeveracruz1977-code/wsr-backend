-- 065 — Derecho al Olvido v3: cierre de la capa de cuenta/social
--
-- AUDITORÍA DPO 2026-07-09 (segunda pasada): fn_forget_runner v2 (migración 045)
-- purga correctamente todo lo que cuelga de runners.id vía FK CASCADE, más
-- web_registrations / legacy_web_registrations / event_winners (sin FK, por
-- email). Pero ~23 tablas de la capa social/cuenta están vinculadas por
-- user_id (= auth.users.id, vía runners.user_id) y NO cuelgan de runners por
-- ninguna FK declarada: sobrevivían intactas a una "corredora olvidada"
-- (mensajes, posts, notificaciones, perfil social, transacciones de puntos...).
-- v3 captura runners.user_id ANTES del borrado y purga también esa capa.
--
-- Nota de diseño: NO se borra auth.users aquí (Supabase desaconseja DELETE SQL
-- directo sobre auth.* — riesgo de dejar caches/refresh tokens de GoTrue
-- inconsistentes). El resultado marca auth_account_purge_required=true y
-- devuelve el user_id para que el llamador complete el borrado de la cuenta
-- de acceso vía Admin API (auth.admin.deleteUser), igual que el patrón ya
-- usado por la función delete-account del repo.
--
-- Exclusiones deliberadas (no se tocan, requieren decisión de negocio/legal,
-- no técnica): audit_logs (trazabilidad de acciones admin sobre terceros),
-- reported_content (registros de moderación/confianza y seguridad),
-- training_sos_alerts (incidentes de seguridad en terreno — posible deber de
-- retención legal), gdpr_deletion_log (es el propio registro de la supresión).
--
-- Aplicada directamente al clúster APP (thirekzbfbwchstvcqxw) el 2026-07-09
-- via MCP; este archivo salda la deuda documental del repositorio.

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
  v_user_id    uuid;
  v_deleted_at timestamptz;
  n_tokens     int;
  n_anamnesis  int;
  n_webregs    int;
  n_legacy     int;
  n_winners    int;
  n_account    jsonb;
  c_activities int; c_ai_log int; c_channel_part int; c_checkins int;
  c_emo_checkins int; c_notifications int; c_point_tx int; c_post_likes int;
  c_reactivation int; c_reward_redemptions int; c_training_checkins int;
  c_training_group_members int; c_training_leaders int; c_training_surveys int;
  c_user_achievements int; c_user_onboarding int; c_user_roles int;
  c_feed_posts int; c_messages int; c_follows int; c_blocked int;
  c_referrals int; c_user_profiles int;
begin
  if not public.fn_is_admin_or_super() then
    raise exception 'Acceso denegado: se requiere rol de administrador (Ley 21.719 Art. 4).'
      using errcode = 'insufficient_privilege';
  end if;

  select email, user_id
    into v_email, v_user_id
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

  -- 6. NUEVO v3 — capa de cuenta/social (vinculada por user_id, no por
  --    runner_id): estas tablas NO cuelgan de runners.id por FK y
  --    sobrevivirían al borrado de la fila runners si no se purgan aquí.
  if v_user_id is not null then
    delete from public.activities where user_id = v_user_id; get diagnostics c_activities = row_count;
    delete from public.ai_request_log where user_id = v_user_id; get diagnostics c_ai_log = row_count;
    delete from public.channel_participants where user_id = v_user_id; get diagnostics c_channel_part = row_count;
    delete from public.checkins where user_id = v_user_id; get diagnostics c_checkins = row_count;
    delete from public.emotional_checkins where user_id = v_user_id; get diagnostics c_emo_checkins = row_count;
    delete from public.notifications where user_id = v_user_id; get diagnostics c_notifications = row_count;
    delete from public.point_transactions where user_id = v_user_id; get diagnostics c_point_tx = row_count;
    delete from public.post_likes where user_id = v_user_id; get diagnostics c_post_likes = row_count;
    delete from public.reactivation_log where user_id = v_user_id; get diagnostics c_reactivation = row_count;
    delete from public.reward_redemptions where user_id = v_user_id; get diagnostics c_reward_redemptions = row_count;
    delete from public.training_checkins where user_id = v_user_id; get diagnostics c_training_checkins = row_count;
    delete from public.training_group_members where user_id = v_user_id; get diagnostics c_training_group_members = row_count;
    delete from public.training_leaders where user_id = v_user_id; get diagnostics c_training_leaders = row_count;
    delete from public.training_surveys where user_id = v_user_id; get diagnostics c_training_surveys = row_count;
    delete from public.user_achievements where user_id = v_user_id; get diagnostics c_user_achievements = row_count;
    delete from public.user_onboarding where user_id = v_user_id; get diagnostics c_user_onboarding = row_count;
    delete from public.user_roles where user_id = v_user_id; get diagnostics c_user_roles = row_count;
    delete from public.feed_posts where author_id = v_user_id; get diagnostics c_feed_posts = row_count;
    delete from public.messages where sender_id = v_user_id; get diagnostics c_messages = row_count;
    delete from public.follows where follower_id = v_user_id or following_id = v_user_id; get diagnostics c_follows = row_count;
    delete from public.blocked_users where blocker_id = v_user_id or blocked_id = v_user_id; get diagnostics c_blocked = row_count;
    delete from public.referrals where referrer_id = v_user_id or referred_id = v_user_id; get diagnostics c_referrals = row_count;
    delete from public.user_profiles where id = v_user_id; get diagnostics c_user_profiles = row_count;

    n_account := jsonb_build_object(
      'activities', c_activities, 'ai_request_log', c_ai_log,
      'channel_participants', c_channel_part, 'checkins', c_checkins,
      'emotional_checkins', c_emo_checkins, 'notifications', c_notifications,
      'point_transactions', c_point_tx, 'post_likes', c_post_likes,
      'reactivation_log', c_reactivation, 'reward_redemptions', c_reward_redemptions,
      'training_checkins', c_training_checkins,
      'training_group_members', c_training_group_members,
      'training_leaders', c_training_leaders, 'training_surveys', c_training_surveys,
      'user_achievements', c_user_achievements, 'user_onboarding', c_user_onboarding,
      'user_roles', c_user_roles, 'feed_posts', c_feed_posts, 'messages', c_messages,
      'follows', c_follows, 'blocked_users', c_blocked, 'referrals', c_referrals,
      'user_profiles', c_user_profiles
    );
  else
    n_account := jsonb_build_object('skipped', 'runner sin user_id vinculado (nunca tuvo cuenta app)');
  end if;

  -- 7. Borrar runner → CASCADE elimina plans, plan_check_ins, health_alerts,
  --    scores IA, adherence_scores, health_profiles, runner_profiles,
  --    assessments, session_results, partner_benefit_claims, training_weeks,
  --    training_sessions y la cadena completa.
  delete from public.runners
   where id = p_runner_id;

  -- 8. Log de auditoría (sin PII — solo UUID). Nunca se borra de aquí.
  v_deleted_at := now();

  insert into public.gdpr_deletion_log (runner_id, deleted_at, requested_by, reason)
  values (p_runner_id, v_deleted_at, auth.uid(), p_reason);

  return jsonb_build_object(
    'ok',                          true,
    'deleted_at',                  v_deleted_at,
    'runner_id',                   p_runner_id,
    'purged',                      jsonb_build_object(
      'anamnesis_tokens',           n_tokens,
      'anamnesis',                  n_anamnesis,
      'web_registrations',          n_webregs,
      'legacy_web_registrations',   n_legacy,
      'event_winners_anonimizados', n_winners,
      'cuenta_social',              n_account
    ),
    'auth_account_purge_required', (v_user_id is not null),
    'user_id_pendiente_borrado',   v_user_id,
    'nota', 'auth.users NO se borra aquí por diseño. Completar el borrado de la ' ||
            'credencial de acceso vía auth.admin.deleteUser(user_id) desde una ' ||
            'Edge Function con service_role, siguiendo el patrón de delete-account.'
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

revoke all on function public.fn_forget_runner(uuid, text) from public, anon;
grant execute on function public.fn_forget_runner(uuid, text) to authenticated, service_role;
