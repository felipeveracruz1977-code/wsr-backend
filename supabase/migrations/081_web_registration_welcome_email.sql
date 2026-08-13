-- Bug detectado 2026-07-13: ninguna corredora nueva recibía el correo de
-- bienvenida. wsr_confirmar_inscripcion_web() solo enviaba la confirmación
-- de entrenamiento; el envío de bienvenida vivía en el edge function
-- enviar-bienvenida, que nunca se desplegó y no tenía webhook que lo invocara.
-- Este fix agrega el envío de bienvenida directamente al trigger existente,
-- disparado únicamente en la primera reserva confirmada de cada email en
-- web_registrations.

CREATE OR REPLACE FUNCTION public.wsr_confirmar_inscripcion_web()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_key              text;
  v_primer_nombre    text;
  v_titulo           text;
  v_titulo_cap       text;
  v_fecha_hora       timestamptz;
  v_ubicacion        text;
  v_ubicacion_texto  text;
  v_latitud          float8;
  v_longitud         float8;
  v_dia_semana       text;
  v_dia_num          text;
  v_mes              text;
  v_anio             text;
  v_hora             text;
  v_fecha_txt        text;
  v_fila_ubicacion   text;
  v_cta_url          text;
  v_nota_encuentro   text;
  v_html             text;
  v_html_bienvenida  text;
  v_dow              int;
  v_mon              int;
  v_es_primera       boolean;
BEGIN
  IF NEW.estado_reserva <> 'confirmada' THEN RETURN NEW; END IF;

  SELECT value INTO v_key FROM wsr_config WHERE key = 'resend_api_key';
  IF v_key IS NULL OR v_key = 'PEGA_TU_API_KEY_DE_RESEND_AQUI' THEN RETURN NEW; END IF;
  IF NEW.email IS NULL THEN RETURN NEW; END IF;

  SELECT title, scheduled_at, location_name, location_detail, latitude, longitude
  INTO v_titulo, v_fecha_hora, v_ubicacion, v_ubicacion_texto, v_latitud, v_longitud
  FROM trainings WHERE id = NEW.training_id;

  v_primer_nombre := split_part(trim(coalesce(NEW.nombre, 'Corredora')), ' ', 1);
  v_titulo_cap    := upper(left(v_titulo, 1)) || substring(v_titulo from 2);

  v_dow := extract(dow  FROM v_fecha_hora AT TIME ZONE 'America/Santiago');
  v_mon := extract(month FROM v_fecha_hora AT TIME ZONE 'America/Santiago');
  v_dia_num := to_char(v_fecha_hora AT TIME ZONE 'America/Santiago', 'DD');
  v_anio    := to_char(v_fecha_hora AT TIME ZONE 'America/Santiago', 'YYYY');
  v_hora    := to_char(v_fecha_hora AT TIME ZONE 'America/Santiago', 'HH24:MI');

  v_dia_semana := CASE v_dow
    WHEN 0 THEN 'Domingo'  WHEN 1 THEN 'Lunes'   WHEN 2 THEN 'Martes'
    WHEN 3 THEN 'Miércoles' WHEN 4 THEN 'Jueves'  WHEN 5 THEN 'Viernes'
    WHEN 6 THEN 'Sábado'
  END;
  v_mes := CASE v_mon
    WHEN 1  THEN 'enero'     WHEN 2  THEN 'febrero'   WHEN 3  THEN 'marzo'
    WHEN 4  THEN 'abril'     WHEN 5  THEN 'mayo'       WHEN 6  THEN 'junio'
    WHEN 7  THEN 'julio'     WHEN 8  THEN 'agosto'     WHEN 9  THEN 'septiembre'
    WHEN 10 THEN 'octubre'   WHEN 11 THEN 'noviembre'  WHEN 12 THEN 'diciembre'
  END;

  v_fecha_txt      := v_dia_semana || ' ' || v_dia_num || ' de ' || v_mes || ' de ' || v_anio;
  v_fila_ubicacion := CASE WHEN v_ubicacion IS NOT NULL
    THEN '<tr><td style="padding:5px 0;font-size:.875rem;color:#7B4F60;">📍 ' || v_ubicacion || '</td></tr>'
    ELSE ''
  END;

  IF v_latitud IS NOT NULL AND v_longitud IS NOT NULL THEN
    v_cta_url        := 'https://www.google.com/maps?q=' || v_latitud::text || ',' || v_longitud::text;
    v_nota_encuentro := coalesce(v_ubicacion_texto, v_ubicacion, 'Te esperamos en el punto marcado en el mapa.');
  ELSE
    v_cta_url        := 'https://www.instagram.com/woman_social_run/';
    v_nota_encuentro := 'El lugar exacto se confirma por Instagram antes del entrenamiento. Síguenos para no perderte nada.';
  END IF;

  -- ¿Es la primera reserva confirmada de este email en toda la historia?
  SELECT NOT EXISTS (
    SELECT 1 FROM web_registrations
    WHERE email = NEW.email
      AND estado_reserva = 'confirmada'
      AND id <> NEW.id
  ) INTO v_es_primera;

  IF v_es_primera THEN
    v_html_bienvenida :=
      '<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"/></head>' ||
      '<body style="margin:0;padding:0;background:#FFF0F8;font-family:Helvetica Neue,Arial,sans-serif;">' ||
      '<div style="max-width:560px;margin:0 auto;padding:40px 16px 32px;">' ||
      '<p style="text-align:center;margin:0 0 28px;font-size:9px;letter-spacing:.35em;text-transform:uppercase;color:#D9488C;font-weight:500;">Woman Social Run</p>' ||
      '<div style="background:#fff;border:1px solid #FFD1F1;border-radius:4px;overflow:hidden;">' ||
      '<div style="height:3px;background:linear-gradient(90deg,#D9488C,#F08EC0,#C9A66B);"></div>' ||
      '<div style="padding:48px 40px 28px;text-align:center;">' ||
      '<p style="margin:0 0 14px;font-size:9px;letter-spacing:.32em;text-transform:uppercase;color:#D9488C;opacity:.8;">Bienvenida</p>' ||
      '<h1 style="margin:0;font-family:Georgia,serif;font-size:2.1rem;font-weight:400;color:#3D1020;line-height:1.15;">Hola, ' || v_primer_nombre || '.</h1>' ||
      '</div>' ||
      '<div style="margin:0 40px;height:1px;background:linear-gradient(90deg,transparent,rgba(217,72,140,.2),transparent);"></div>' ||
      '<div style="padding:28px 40px 40px;">' ||
      '<p style="margin:0 0 16px;font-size:1rem;color:#5C3248;line-height:1.75;">Nos alegra mucho que estés aquí. Woman Social Run es una comunidad de mujeres que corren juntas, a su propio ritmo, sin presión ni marcas de tiempo.</p>' ||
      '<p style="margin:0 0 28px;font-size:1rem;color:#5C3248;line-height:1.75;">En cada encuentro buscamos lo mismo: movimiento, compañía y presencia. Pronto te avisaremos de los próximos entrenamientos.</p>' ||
      '<div style="text-align:center;margin:8px 0;">' ||
      '<a href="https://www.instagram.com/woman_social_run/" style="display:inline-block;padding:14px 34px;background:#D9488C;color:#fff;text-decoration:none;font-size:.72rem;letter-spacing:.16em;text-transform:uppercase;border-radius:999px;font-weight:500;">Síguenos en Instagram →</a>' ||
      '</div></div></div>' ||
      '<div style="text-align:center;padding:28px 16px 0;font-size:.68rem;color:#B07A90;letter-spacing:.06em;line-height:1.8;">' ||
      '<p style="margin:0;">Woman Social Run · Santiago, Chile</p>' ||
      '<p style="margin:4px 0 0;opacity:.65;">Recibiste este correo porque te registraste en WSR.</p>' ||
      '</div></div></body></html>';

    PERFORM net.http_post(
      url     := 'https://api.resend.com/emails',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_key
      ),
      body := jsonb_build_object(
        'from',    'Woman Social Run <felipe@womansocialrun.cl>',
        'to',      ARRAY[NEW.email],
        'subject', 'Bienvenida a Woman Social Run ·',
        'html',    v_html_bienvenida
      )
    );
  END IF;

  v_html :=
    '<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"/></head>' ||
    '<body style="margin:0;padding:0;background:#FFF0F8;font-family:Helvetica Neue,Arial,sans-serif;">' ||
    '<div style="max-width:560px;margin:0 auto;padding:40px 16px 32px;">' ||
    '<p style="text-align:center;margin:0 0 28px;font-size:9px;letter-spacing:.35em;text-transform:uppercase;color:#D9488C;font-weight:500;">Woman Social Run</p>' ||
    '<div style="background:#fff;border:1px solid #FFD1F1;border-radius:4px;overflow:hidden;">' ||
    '<div style="height:3px;background:linear-gradient(90deg,#D9488C,#F08EC0,#C9A66B);"></div>' ||
    '<div style="padding:48px 40px 28px;text-align:center;">' ||
    '<p style="margin:0 0 14px;font-size:9px;letter-spacing:.32em;text-transform:uppercase;color:#D9488C;opacity:.8;">Inscripción confirmada</p>' ||
    '<h1 style="margin:0;font-family:Georgia,serif;font-size:2.1rem;font-weight:400;color:#3D1020;line-height:1.15;">¡Tu lugar está<br/>confirmado, ' || v_primer_nombre || '!</h1>' ||
    '</div>' ||
    '<div style="margin:0 40px;height:1px;background:linear-gradient(90deg,transparent,rgba(217,72,140,.2),transparent);"></div>' ||
    '<div style="padding:28px 40px 40px;">' ||
    '<p style="margin:0 0 22px;font-size:1rem;color:#5C3248;line-height:1.75;">Te esperamos en el siguiente entrenamiento:</p>' ||
    '<div style="background:#FFF5FB;border:1px solid #FFD1F1;border-left:3px solid #D9488C;border-radius:4px;padding:22px 22px 18px;">' ||
    '<p style="margin:0 0 12px;font-family:Georgia,serif;font-size:1.2rem;font-weight:400;color:#3D1020;line-height:1.3;">' || v_titulo_cap || '</p>' ||
    '<table style="border-collapse:collapse;width:100%;">' ||
    '<tr><td style="padding:5px 0;font-size:.875rem;color:#7B4F60;">📅 ' || v_fecha_txt || '</td></tr>' ||
    '<tr><td style="padding:5px 0;font-size:.875rem;color:#7B4F60;">🕐 ' || v_hora || ' hrs</td></tr>' ||
    v_fila_ubicacion ||
    '</table></div>' ||
    '<div style="margin:22px 0 0;padding:16px 18px;background:#FFF9FB;border:1px solid #FFE6F4;border-radius:4px;">' ||
    '<p style="margin:0;font-size:.875rem;color:#7B4F60;line-height:1.7;"><strong style="color:#5C3248;display:block;margin-bottom:3px;">📍 Punto de encuentro</strong>' || v_nota_encuentro || '</p>' ||
    '</div>' ||
    '<div style="text-align:center;margin:32px 0 8px;">' ||
    '<a href="' || v_cta_url || '" style="display:inline-block;padding:14px 34px;background:#D9488C;color:#fff;text-decoration:none;font-size:.72rem;letter-spacing:.16em;text-transform:uppercase;border-radius:999px;font-weight:500;">Ver punto de encuentro →</a>' ||
    '</div></div></div>' ||
    '<div style="text-align:center;padding:28px 16px 0;font-size:.68rem;color:#B07A90;letter-spacing:.06em;line-height:1.8;">' ||
    '<p style="margin:0;">Woman Social Run · Santiago, Chile</p>' ||
    '<p style="margin:4px 0 0;opacity:.65;">Recibiste este correo porque te inscribiste en un entrenamiento WSR.</p>' ||
    '</div></div></body></html>';

  PERFORM net.http_post(
    url     := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body := jsonb_build_object(
      'from',    'Woman Social Run <felipe@womansocialrun.cl>',
      'to',      ARRAY[NEW.email],
      'subject', '¡Estás inscrita! ' || v_titulo_cap,
      'html',    v_html
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'wsr_confirmar_inscripcion_web: % (training_id=%, email=%)', SQLERRM, NEW.training_id, NEW.email;
  RETURN NEW;
END;
$function$;
