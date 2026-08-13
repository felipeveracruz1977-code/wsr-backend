-- 071 — Remediación auditoría 2026-07-12: autorización faltante en 3 RPC críticas
--
-- Hallazgos (clúster APP thirekzbfbwchstvcqxw, SECURITY DEFINER sin verificar identidad):
--
-- C-1 · redeem_reward(p_user_id, p_reward_id): gastaba los puntos de la usuaria
--       cuyo id se pasara por parámetro, sin verificar que coincida con la
--       llamante. Cualquier usuaria autenticada podía canjear recompensas a
--       nombre de otra (o, combinado con award_points, cometer fraude de puntos).
--       Fix: exigir p_user_id = auth.uid(). El cliente (App useRewards.ts) ya
--       pasa el id propio, por lo que el flujo legítimo no cambia.
--
-- C-2 · add_training_leader / remove_training_leader: INSERT/DELETE sobre
--       training_leaders SIN ninguna verificación de rol → escalada de
--       privilegios (cualquiera se nombra coach/pacer de cualquier entrenamiento).
--       Fix: exigir rol admin/super_admin de la llamante (fn_is_admin_or_super()).
--       El panel admin (CoachesTab) las invoca autenticado como admin → sin cambios.

-- C-1
CREATE OR REPLACE FUNCTION public.redeem_reward(p_user_id uuid, p_reward_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_reward        rewards_catalog%ROWTYPE;
  v_profile       user_profiles%ROWTYPE;
  v_redemption_id UUID;
  v_tier_order    SMALLINT;
  v_req_order     SMALLINT;
BEGIN
  -- Autorización: solo la propia titular puede canjear sus puntos.
  IF p_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'No autorizada para canjear a nombre de otra usuaria'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_reward FROM rewards_catalog WHERE id = p_reward_id AND is_active FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Recompensa no disponible'; END IF;

  SELECT * INTO v_profile FROM user_profiles WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Usuaria no encontrada'; END IF;

  IF v_profile.total_points < v_reward.points_cost THEN
    RAISE EXCEPTION 'Puntos insuficientes (tienes %, necesitas %)', v_profile.total_points, v_reward.points_cost;
  END IF;

  IF v_reward.required_tier IS NOT NULL THEN
    SELECT sort_order INTO v_tier_order FROM loyalty_tiers WHERE tier = v_profile.current_tier;
    SELECT sort_order INTO v_req_order  FROM loyalty_tiers WHERE tier = v_reward.required_tier;
    IF v_tier_order < v_req_order THEN
      RAISE EXCEPTION 'Nivel insuficiente: requiere %', v_reward.required_tier;
    END IF;
  END IF;

  IF v_reward.stock IS NOT NULL AND v_reward.stock <= 0 THEN
    RAISE EXCEPTION 'Sin stock disponible';
  END IF;

  PERFORM award_points(p_user_id, -v_reward.points_cost, 'redemption', p_reward_id,
                       'Canje: ' || v_reward.name);

  INSERT INTO reward_redemptions (user_id, reward_id, points_spent)
  VALUES (p_user_id, p_reward_id, v_reward.points_cost)
  RETURNING id INTO v_redemption_id;

  IF v_reward.stock IS NOT NULL THEN
    UPDATE rewards_catalog SET stock = stock - 1 WHERE id = p_reward_id;
  END IF;

  RETURN v_redemption_id;
END;
$function$;

-- C-2a
CREATE OR REPLACE FUNCTION public.add_training_leader(p_training_id uuid, p_user_id uuid, p_role text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.fn_is_admin_or_super() THEN
    RAISE EXCEPTION 'Solo administradoras pueden gestionar líderes de entrenamiento'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO training_leaders (training_id, user_id, role)
  VALUES (p_training_id, p_user_id, p_role)
  ON CONFLICT (training_id, user_id) DO UPDATE SET role = p_role;
END;
$function$;

-- C-2b
CREATE OR REPLACE FUNCTION public.remove_training_leader(p_training_id uuid, p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.fn_is_admin_or_super() THEN
    RAISE EXCEPTION 'Solo administradoras pueden gestionar líderes de entrenamiento'
      USING ERRCODE = '42501';
  END IF;

  DELETE FROM training_leaders
  WHERE training_id = p_training_id AND user_id = p_user_id;
END;
$function$;
