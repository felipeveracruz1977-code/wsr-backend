-- 077 — Eliminación de cuenta self-service (Apple 5.1.1(v) + Art. 4 Ley 21.719)
--
-- Contexto (auditoría 2026-07-12): el borrado de cuenta in-app estaba roto —
-- la app invocaba la Edge Function 'delete-account' (no desplegada, job de cron
-- que exige service_role → 401 al JWT de la usuaria) y la RPC real
-- fn_forget_runner es admin-only. Apple rechaza si el borrado no se completa
-- dentro de la app. Decisión de producto: Opción A (borrado inmediato).
--
-- Diseño: se extrae la purga a un helper interno compartido para no duplicar
-- lógica ni arriesgar el flujo admin ya operativo.
--   fn_purge_runner_cascade(runner, reason, requested_by) → purga completa, SIN
--       chequeo de autorización (interno; revocado de anon + authenticated).
--   fn_forget_runner(runner, reason)  → admin-only, delega en el helper (auth.uid()).
--   fn_forget_my_account()            → resuelve el runner de la llamante por
--       runners.user_id = auth.uid() y delega en el helper. La usa la Edge
--       Function delete-my-account (verify_jwt=true), que además borra auth.users.
--
-- NOTA: ninguna de estas borra auth.users (lo hace la Edge Function con la admin
-- API). Reversible a nivel de esquema (CREATE OR REPLACE / DROP de las nuevas).

-- ── 1. Helper interno: purga en cascada (sin autorización propia) ──────────────
CREATE OR REPLACE FUNCTION public.fn_purge_runner_cascade(
  p_runner_id uuid,
  p_reason text,
  p_requested_by uuid
) RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_email      text;
  v_user_id    uuid;
  v_deleted_at timestamptz;
  n_tokens     int; n_anamnesis int; n_webregs int; n_legacy int; n_winners int;
  n_account    jsonb;
  c_activities int; c_ai_log int; c_channel_part int; c_checkins int;
  c_emo_checkins int; c_notifications int; c_point_tx int; c_post_likes int;
  c_reactivation int; c_reward_redemptions int; c_training_checkins int;
  c_training_group_members int; c_training_leaders int; c_training_surveys int;
  c_user_achievements int; c_user_onboarding int; c_user_roles int;
  c_feed_posts int; c_messages int; c_follows int; c_blocked int;
  c_referrals int; c_user_profiles int;
begin
  select email, user_id into v_email, v_user_id
    from public.runners where id = p_runner_id;

  if v_email is null then
    return jsonb_build_object('ok', false, 'error', 'runner_not_found', 'runner_id', p_runner_id);
  end if;

  delete from public.anamnesis_tokens where lower(runner_email) = lower(v_email);
  get diagnostics n_tokens = row_count;

  delete from public.anamnesis where runner_id = p_runner_id or lower(runner_email) = lower(v_email);
  get diagnostics n_anamnesis = row_count;

  delete from public.web_registrations where lower(email) = lower(v_email);
  get diagnostics n_webregs = row_count;

  delete from public.legacy_web_registrations where runner_id = p_runner_id;
  get diagnostics n_legacy = row_count;

  update public.event_winners set nombre_externo = null, email_externo = null
   where runner_id = p_runner_id or lower(email_externo) = lower(v_email);
  get diagnostics n_winners = row_count;

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

  delete from public.runners where id = p_runner_id;

  v_deleted_at := now();
  insert into public.gdpr_deletion_log (runner_id, deleted_at, requested_by, reason)
  values (p_runner_id, v_deleted_at, p_requested_by, p_reason);

  return jsonb_build_object(
    'ok', true, 'deleted_at', v_deleted_at, 'runner_id', p_runner_id,
    'purged', jsonb_build_object(
      'anamnesis_tokens', n_tokens, 'anamnesis', n_anamnesis,
      'web_registrations', n_webregs, 'legacy_web_registrations', n_legacy,
      'event_winners_anonimizados', n_winners, 'cuenta_social', n_account),
    'auth_account_purge_required', (v_user_id is not null),
    'user_id_pendiente_borrado', v_user_id
  );
exception
  when others then
    return jsonb_build_object('ok', false, 'error', sqlerrm, 'sqlstate', sqlstate, 'runner_id', p_runner_id);
end;
$function$;

-- Helper interno: fuera del alcance de cualquier cliente.
REVOKE EXECUTE ON FUNCTION public.fn_purge_runner_cascade(uuid, text, uuid) FROM PUBLIC, anon, authenticated;

-- ── 2. fn_forget_runner (admin) ahora delega en el helper ─────────────────────
CREATE OR REPLACE FUNCTION public.fn_forget_runner(
  p_runner_id uuid,
  p_reason text DEFAULT 'Solicitud de supresión Art. 4 Ley 21.719'::text
) RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.fn_is_admin_or_super() then
    raise exception 'Acceso denegado: se requiere rol de administrador (Ley 21.719 Art. 4).'
      using errcode = 'insufficient_privilege';
  end if;
  return public.fn_purge_runner_cascade(p_runner_id, p_reason, auth.uid());
end;
$function$;

-- ── 3. fn_forget_my_account: self-service (la usuaria borra SU cuenta) ─────────
CREATE OR REPLACE FUNCTION public.fn_forget_my_account()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_runner_id uuid;
begin
  if auth.uid() is null then
    raise exception 'No autenticada' using errcode = '42501';
  end if;

  select id into v_runner_id from public.runners where user_id = auth.uid();

  if v_runner_id is null then
    -- La usuaria tiene cuenta app pero no fila runner: no hay datos de dominio
    -- que purgar; la Edge Function igual borrará auth.users.
    return jsonb_build_object('ok', true, 'note', 'sin_runner_vinculado', 'user_id', auth.uid());
  end if;

  return public.fn_purge_runner_cascade(
    v_runner_id,
    'Autoservicio: eliminación de cuenta in-app (Apple 5.1.1(v) / Art. 4 Ley 21.719)',
    auth.uid()
  );
end;
$function$;

-- La llama la usuaria autenticada (vía Edge Function con su JWT); nunca anon.
REVOKE EXECUTE ON FUNCTION public.fn_forget_my_account() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_forget_my_account() TO authenticated;
