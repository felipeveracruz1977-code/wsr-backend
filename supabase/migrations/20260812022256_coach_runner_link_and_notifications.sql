-- ═══════════════════════════════════════════════════════════════════════════
-- Vinculación alumna↔coach + notificaciones por correo (check-in / alerta)
-- ═══════════════════════════════════════════════════════════════════════════
-- Cuando Laura, Gabriela o Felipe generan un plan, plans.coach_id ya queda
-- poblado con el uid del coach (api/generate-plan.ts). Pero el RLS que filtra
-- qué ve un coach en el panel (plan_check_ins_coach_read, health_alerts_*,
-- anamnesis_coach_read, etc.) depende de runners.coach_id, no de
-- plans.coach_id — y nada sincronizaba esa columna. Este archivo:
--
--   1. Sincroniza runners.coach_id cada vez que se genera/edita un plan
--      (gana siempre el coach del plan más reciente).
--   2. Aplica esa misma regla a los datos históricos (backfill).
--   3. Envía un correo de rutina al coach responsable en cada check-in.
--   4. Envía un correo urgente al coach responsable en cada alerta de salud
--      (dolor, cumplimiento o adherencia — los tres orígenes insertan con
--      runner_id directo).
--
-- Mismo patrón que 081/084: función SECURITY DEFINER + net.http_post directo
-- a Resend, api key desde wsr_config, EXCEPTION WHEN OTHERS para que un fallo
-- de correo jamás bloquee el check-in de la alumna ni la creación de la alerta.

-- ── 1. Sincronización runners.coach_id ← plans.coach_id ──────────────────────

CREATE OR REPLACE FUNCTION public.wsr_sync_runner_coach()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.coach_id IS NULL THEN
    RETURN NEW;
  END IF;

  UPDATE public.runners
     SET coach_id = NEW.coach_id
   WHERE id = NEW.runner_id
     AND coach_id IS DISTINCT FROM NEW.coach_id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'wsr_sync_runner_coach: % (plan_id=%, runner_id=%)', SQLERRM, NEW.id, NEW.runner_id;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS wsr_on_plan_sync_runner_coach ON public.plans;
CREATE TRIGGER wsr_on_plan_sync_runner_coach
  AFTER INSERT OR UPDATE OF coach_id ON public.plans
  FOR EACH ROW
  EXECUTE FUNCTION public.wsr_sync_runner_coach();

-- ── 2. Backfill: alumnas que ya tienen plan hoy ───────────────────────────────

UPDATE public.runners r
   SET coach_id = latest.coach_id
  FROM (
    SELECT DISTINCT ON (runner_id) runner_id, coach_id
      FROM public.plans
     WHERE coach_id IS NOT NULL
     ORDER BY runner_id, created_at DESC
  ) latest
 WHERE r.id = latest.runner_id
   AND r.coach_id IS DISTINCT FROM latest.coach_id;

-- ── 3. Helper: email del coach responsable de una alumna ─────────────────────

CREATE OR REPLACE FUNCTION public.wsr_coach_email_for_runner(p_runner_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT au.email
    FROM public.runners r
    JOIN auth.users au ON au.id = r.coach_id
   WHERE r.id = p_runner_id;
$function$;

-- ── 4. Correo de rutina: check-in nuevo ───────────────────────────────────────

CREATE OR REPLACE FUNCTION public.wsr_notify_coach_checkin()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_key         text;
  v_coach_email text;
  v_nombre      text;
  v_fecha_txt   text;
  v_dolor_txt   text;
  v_html        text;
BEGIN
  SELECT value INTO v_key FROM wsr_config WHERE key = 'resend_api_key';
  IF v_key IS NULL OR v_key = 'PEGA_TU_API_KEY_DE_RESEND_AQUI' THEN RETURN NEW; END IF;

  v_coach_email := public.wsr_coach_email_for_runner(NEW.runner_id);
  IF v_coach_email IS NULL THEN RETURN NEW; END IF;

  SELECT nombre_apellido INTO v_nombre FROM public.runners WHERE id = NEW.runner_id;
  v_nombre    := COALESCE(v_nombre, 'Una alumna');
  v_fecha_txt := to_char(NEW.week_start, 'DD/MM/YYYY');
  v_dolor_txt := NEW.pain::text || '/10' || COALESCE(' — ' || NULLIF(TRIM(NEW.pain_location), ''), '');

  v_html :=
    '<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"/></head>' ||
    '<body style="margin:0;padding:0;background:#FFF0F8;font-family:Helvetica Neue,Arial,sans-serif;">' ||
    '<div style="max-width:560px;margin:0 auto;padding:40px 16px 32px;">' ||
    '<p style="text-align:center;margin:0 0 28px;font-size:9px;letter-spacing:.35em;text-transform:uppercase;color:#D9488C;font-weight:500;">Woman Social Run</p>' ||
    '<div style="background:#fff;border:1px solid #FFD1F1;border-radius:4px;overflow:hidden;">' ||
    '<div style="height:3px;background:linear-gradient(90deg,#D9488C,#F08EC0,#C9A66B);"></div>' ||
    '<div style="padding:40px 40px 20px;text-align:center;">' ||
    '<p style="margin:0 0 14px;font-size:9px;letter-spacing:.32em;text-transform:uppercase;color:#D9488C;opacity:.8;">Nuevo check-in</p>' ||
    '<h1 style="margin:0;font-family:Georgia,serif;font-size:1.8rem;font-weight:400;color:#3D1020;line-height:1.2;">' || v_nombre || '</h1>' ||
    '<p style="margin:8px 0 0;font-size:.85rem;color:#7B4F60;">Semana del ' || v_fecha_txt || '</p>' ||
    '</div>' ||
    '<div style="margin:0 40px;height:1px;background:linear-gradient(90deg,transparent,rgba(217,72,140,.2),transparent);"></div>' ||
    '<div style="padding:24px 40px 40px;">' ||
    '<table style="border-collapse:collapse;width:100%;font-size:.9rem;color:#5C3248;">' ||
    '<tr><td style="padding:6px 0;">Cumplimiento</td><td style="padding:6px 0;text-align:right;font-weight:600;">' || COALESCE(NEW.compliance_pct::text, '—') || '% (' || NEW.sessions_completed || '/' || NEW.sessions_planned || ' sesiones)</td></tr>' ||
    '<tr><td style="padding:6px 0;">Energía</td><td style="padding:6px 0;text-align:right;">' || NEW.energy || '/10</td></tr>' ||
    '<tr><td style="padding:6px 0;">Sueño</td><td style="padding:6px 0;text-align:right;">' || NEW.sleep_quality || '/10</td></tr>' ||
    '<tr><td style="padding:6px 0;">Motivación</td><td style="padding:6px 0;text-align:right;">' || NEW.motivation || '/10</td></tr>' ||
    '<tr><td style="padding:6px 0;">Dolor</td><td style="padding:6px 0;text-align:right;">' || v_dolor_txt || '</td></tr>' ||
    '</table>' ||
    COALESCE('<div style="margin:18px 0 0;padding:14px 16px;background:#FFF9FB;border:1px solid #FFE6F4;border-radius:4px;font-size:.85rem;color:#7B4F60;line-height:1.6;">' || NEW.comments || '</div>', '') ||
    '<div style="text-align:center;margin:28px 0 0;">' ||
    '<a href="https://womansocialrun.cl/admin" style="display:inline-block;padding:13px 30px;background:#D9488C;color:#fff;text-decoration:none;font-size:.72rem;letter-spacing:.16em;text-transform:uppercase;border-radius:999px;font-weight:500;">Ver en el panel →</a>' ||
    '</div></div></div>' ||
    '<div style="text-align:center;padding:24px 16px 0;font-size:.68rem;color:#B07A90;letter-spacing:.06em;">' ||
    '<p style="margin:0;">Woman Social Run · Panel de coaches</p>' ||
    '</div></div></body></html>';

  PERFORM net.http_post(
    url     := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body := jsonb_build_object(
      'from',    'Woman Social Run <felipe@womansocialrun.cl>',
      'to',      ARRAY[v_coach_email],
      'subject', 'Check-in de ' || v_nombre || ' · semana ' || v_fecha_txt,
      'html',    v_html
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'wsr_notify_coach_checkin: % (check_in_id=%, runner_id=%)', SQLERRM, NEW.id, NEW.runner_id;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS wsr_on_checkin_notify_coach ON public.plan_check_ins;
CREATE TRIGGER wsr_on_checkin_notify_coach
  AFTER INSERT ON public.plan_check_ins
  FOR EACH ROW
  EXECUTE FUNCTION public.wsr_notify_coach_checkin();

-- ── 5. Correo urgente: alerta de salud nueva ──────────────────────────────────

CREATE OR REPLACE FUNCTION public.wsr_notify_coach_alert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_key            text;
  v_coach_email    text;
  v_nombre         text;
  v_severity_label text;
  v_severity_color text;
  v_tipo_label     text;
  v_html           text;
BEGIN
  SELECT value INTO v_key FROM wsr_config WHERE key = 'resend_api_key';
  IF v_key IS NULL OR v_key = 'PEGA_TU_API_KEY_DE_RESEND_AQUI' THEN RETURN NEW; END IF;

  v_coach_email := public.wsr_coach_email_for_runner(NEW.runner_id);
  IF v_coach_email IS NULL THEN RETURN NEW; END IF;

  SELECT nombre_apellido INTO v_nombre FROM public.runners WHERE id = NEW.runner_id;
  v_nombre := COALESCE(v_nombre, 'Una alumna');

  v_severity_label := CASE NEW.severity WHEN 'roja' THEN '🔴 Alerta roja' ELSE '🟠 Alerta naranja' END;
  v_severity_color := CASE NEW.severity WHEN 'roja' THEN '#D9304F' ELSE '#E8952F' END;
  v_tipo_label := CASE NEW.alert_type
    WHEN 'dolor'       THEN 'Dolor'
    WHEN 'cumplimiento' THEN 'Bajo cumplimiento'
    WHEN 'adherencia'   THEN 'Riesgo de abandono'
    ELSE initcap(NEW.alert_type)
  END;

  v_html :=
    '<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"/></head>' ||
    '<body style="margin:0;padding:0;background:#FFF0F8;font-family:Helvetica Neue,Arial,sans-serif;">' ||
    '<div style="max-width:560px;margin:0 auto;padding:40px 16px 32px;">' ||
    '<p style="text-align:center;margin:0 0 28px;font-size:9px;letter-spacing:.35em;text-transform:uppercase;color:#D9488C;font-weight:500;">Woman Social Run</p>' ||
    '<div style="background:#fff;border:1px solid #FFD1F1;border-radius:4px;overflow:hidden;">' ||
    '<div style="height:4px;background:' || v_severity_color || ';"></div>' ||
    '<div style="padding:40px 40px 20px;text-align:center;">' ||
    '<p style="margin:0 0 14px;font-size:9px;letter-spacing:.32em;text-transform:uppercase;color:' || v_severity_color || ';font-weight:700;">' || v_severity_label || ' · requiere tu atención</p>' ||
    '<h1 style="margin:0;font-family:Georgia,serif;font-size:1.8rem;font-weight:400;color:#3D1020;line-height:1.2;">' || v_nombre || '</h1>' ||
    '</div>' ||
    '<div style="margin:0 40px;height:1px;background:linear-gradient(90deg,transparent,rgba(217,72,140,.2),transparent);"></div>' ||
    '<div style="padding:24px 40px 40px;">' ||
    '<div style="padding:16px 18px;background:#FFF5F5;border:1px solid ' || v_severity_color || ';border-left:3px solid ' || v_severity_color || ';border-radius:4px;">' ||
    '<p style="margin:0 0 6px;font-size:.8rem;letter-spacing:.05em;text-transform:uppercase;color:' || v_severity_color || ';font-weight:600;">' || v_tipo_label || '</p>' ||
    '<p style="margin:0;font-size:.95rem;color:#3D1020;line-height:1.6;">' || NEW.reason || '</p>' ||
    '</div>' ||
    '<div style="text-align:center;margin:28px 0 0;">' ||
    '<a href="https://womansocialrun.cl/admin" style="display:inline-block;padding:13px 30px;background:' || v_severity_color || ';color:#fff;text-decoration:none;font-size:.72rem;letter-spacing:.16em;text-transform:uppercase;border-radius:999px;font-weight:500;">Atender en el panel →</a>' ||
    '</div></div></div>' ||
    '<div style="text-align:center;padding:24px 16px 0;font-size:.68rem;color:#B07A90;letter-spacing:.06em;">' ||
    '<p style="margin:0;">Woman Social Run · Panel de coaches</p>' ||
    '</div></div></body></html>';

  PERFORM net.http_post(
    url     := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body := jsonb_build_object(
      'from',    'Woman Social Run <felipe@womansocialrun.cl>',
      'to',      ARRAY[v_coach_email],
      'subject', v_severity_label || ' · ' || v_nombre,
      'html',    v_html
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'wsr_notify_coach_alert: % (alert_id=%, runner_id=%)', SQLERRM, NEW.id, NEW.runner_id;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS wsr_on_alert_notify_coach ON public.health_alerts;
CREATE TRIGGER wsr_on_alert_notify_coach
  AFTER INSERT ON public.health_alerts
  FOR EACH ROW
  EXECUTE FUNCTION public.wsr_notify_coach_alert();
