/**
 * send-push-notification — WSR Push Delivery
 * ============================================
 * Supabase Edge Function · Deno Runtime
 *
 * Flujo:
 *   INSERT en `notifications` (trigger DB)
 *   → Supabase Database Webhook
 *   → Esta función
 *   → Expo Push API → 🔔 Sistema iOS / Android
 *
 * ── Secrets (Supabase Dashboard → Settings → Edge Functions) ──────
 *   SUPABASE_URL              auto-inyectado
 *   SUPABASE_SERVICE_ROLE_KEY auto-inyectado
 *   WEBHOOK_SECRET            secreto que configuras tú (string largo
 *                             aleatorio) y pones también en el header
 *                             del Webhook → x-webhook-secret
 * ─────────────────────────────────────────────────────────────────
 *
 * Deploy:
 *   supabase functions deploy send-push-notification --no-verify-jwt
 *
 * Configurar secreto:
 *   supabase secrets set WEBHOOK_SECRET=<string-aleatorio-seguro>
 */

import { serve }        from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ── Tipos ─────────────────────────────────────────────────────────────────────

type NotificationKind =
  | 'new_message'
  | 'new_training'
  | 'support_reaction'
  | 'anti_abandonment'
  | 'general';

interface NotificationRecord {
  id:         string;
  user_id:    string;
  kind:       NotificationKind;
  title:      string;
  body:       string;
  ref_id:     string | null;
  ref_type:   string | null;
  is_read:    boolean;
  created_at: string;
}

interface WebhookPayload {
  type:       'INSERT' | 'UPDATE' | 'DELETE';
  table:      string;
  schema:     string;
  record:     NotificationRecord;
  old_record: NotificationRecord | null;
}

interface ExpoReceipt {
  status:   'ok' | 'error';
  message?: string;
  details?: { error?: string };
}

// ── Copywriting emocional WSR ─────────────────────────────────────────────────
//
// Reglas de oro:
//   ✅ Cálido, breve, comunitario
//   ✅ Invita sin presionar
//   ✅ Primera persona cercana ("tu comunidad", "te escribió")
//   ❌ Sin tecnicismos, jerga corporativa ni urgencia artificial
//   ❌ Sin "¡Alerta!", "No te lo pierdas", "Última oportunidad"

function buildPushCopy(
  kind:   NotificationKind,
  record: NotificationRecord,
): { title: string; body: string } {
  switch (kind) {

    case 'new_message':
      // record.body trae el texto real del mensaje (truncado a 120 chars)
      // Mostrarlo directamente es la experiencia más humana (como WhatsApp)
      return {
        title: '💬 Nuevo mensaje',
        body:  record.body?.trim() || 'Alguien en tu comunidad te escribió. 🤍',
      };

    case 'new_training':
      // record.body trae el título del entrenamiento (desde el trigger)
      return {
        title: '🏃‍♀️ Nuevo entrenamiento',
        body:  record.body?.trim()
          ? `"${record.body.trim()}" ya está publicado. ¿Nos vemos?`
          : 'Un nuevo plan te está esperando. ¿Te sumas?',
      };

    case 'support_reaction':
      // record.title = "🤍 Apoyo" / "💪 Fuerza" etc. (del trigger)
      // record.body  = "Nombre te envió apoyo"          (del trigger)
      return {
        title: record.title?.trim() || '💜 Tu comunidad te apoya',
        body:  record.body?.trim()  || 'Alguien en WSR te envió cariño hoy.',
      };

    case 'anti_abandonment':
      return {
        title: '🤍 Te extrañamos',
        body:  'Hace tiempo que no nos vemos. Aquí seguimos, sin presión. 💜',
      };

    default:
      return {
        title: record.title?.trim() || '🔔 WSR',
        body:  record.body?.trim()  || 'Tienes una actualización.',
      };
  }
}

// ── Handler principal ─────────────────────────────────────────────────────────

serve(async (req: Request) => {

  // ── 1. Método ────────────────────────────────────────────────────
  if (req.method !== 'POST') {
    return json({ ok: false, error: 'method_not_allowed' }, 405);
  }

  // ── 2. Autenticación del webhook (WEBHOOK_SECRET header) ─────────
  //      WEBHOOK_SECRET es OBLIGATORIO. Si no está configurado en los
  //      secrets del proyecto, la función falla cerrada (fail-closed)
  //      en lugar de quedar abierta a cualquier caller.
  const webhookSecret = Deno.env.get('WEBHOOK_SECRET');
  if (!webhookSecret) {
    console.error('[wsr-push] WEBHOOK_SECRET no configurado — función bloqueada.');
    return json({ ok: false, error: 'misconfigured' }, 500);
  }
  const incoming = req.headers.get('x-webhook-secret');
  if (incoming !== webhookSecret) {
    console.warn('[wsr-push] Webhook secret inválido.');
    return json({ ok: false, error: 'unauthorized' }, 401);
  }

  // ── 3. Parsear payload ───────────────────────────────────────────
  let payload: WebhookPayload;
  try {
    payload = await req.json();
  } catch {
    return json({ ok: false, error: 'invalid_json' }, 400);
  }

  // Solo procesamos INSERTs en la tabla notifications
  if (payload.type !== 'INSERT' || payload.table !== 'notifications') {
    return json({ ok: true, skipped: 'not_a_notification_insert' });
  }

  const notif = payload.record;

  // ── 4. Cliente Supabase con service_role ─────────────────────────
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  // ── 5. Fetch push_token + unread count en paralelo ───────────────
  const [profileRes, countRes] = await Promise.all([
    supabase
      .from('user_profiles')
      .select('push_token')
      .eq('id', notif.user_id)
      .single(),
    supabase
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', notif.user_id)
      .eq('is_read', false),
  ]);

  if (profileRes.error) {
    console.error('[wsr-push] Error leyendo perfil:', profileRes.error.message);
    return json({ ok: false, error: 'db_error' }, 500);
  }

  const pushToken = profileRes.data?.push_token;

  // Sin token → respuesta 200 silenciosa (el centro in-app igual funciona)
  if (!pushToken) {
    return json({ ok: true, skipped: 'no_push_token' });
  }

  // Validar formato Expo Push Token
  if (!pushToken.startsWith('ExponentPushToken')) {
    console.warn('[wsr-push] Formato de token inválido:', pushToken.slice(0, 20));
    return json({ ok: true, skipped: 'invalid_token_format' });
  }

  const badgeCount = (countRes.count ?? 0) + 1; // +1 por la notif recién creada

  // ── 6. Construir mensaje con copy emocional ───────────────────────
  const { title, body } = buildPushCopy(notif.kind, notif);

  // ── 7. Enviar via Expo Push API ───────────────────────────────────
  let expoRes: Response;
  try {
    expoRes = await fetch('https://exp.host/--/api/v2/push/send', {
      method: 'POST',
      headers: {
        'Content-Type':    'application/json',
        'Accept':          'application/json',
        'Accept-Encoding': 'gzip, deflate',
      },
      body: JSON.stringify({
        to:        pushToken,
        title,
        body,
        sound:     'default',
        badge:     badgeCount,
        channelId: 'default',         // Android; ignorado en iOS
        data: {
          notif_id: notif.id,
          kind:     notif.kind,
          ref_id:   notif.ref_id,
          ref_type: notif.ref_type,
        },
      }),
    });
  } catch (networkErr) {
    console.error('[wsr-push] Error de red llamando a Expo:', networkErr);
    return json({ ok: false, error: 'expo_network_error' }, 502);
  }

  // ── 8. Parsear respuesta de Expo ──────────────────────────────────
  // HTTP 200 de Expo NO significa éxito — hay que verificar el receipt.
  let expoData: { data?: ExpoReceipt[] };
  try {
    expoData = await expoRes.json();
  } catch {
    return json({ ok: false, error: 'expo_invalid_response' }, 502);
  }

  const receipt = expoData?.data?.[0];

  // ── 9. Manejar errores de Expo ────────────────────────────────────
  if (receipt?.status === 'error') {
    const errorCode = receipt.details?.error;
    console.warn('[wsr-push] Expo receipt error:', errorCode, '—', receipt.message);

    // DeviceNotRegistered: la usuaria desinstalió la app.
    // Limpiar el token para no volver a intentarlo (y evitar cuota de Expo).
    if (errorCode === 'DeviceNotRegistered') {
      const { error: clearErr } = await supabase
        .from('user_profiles')
        .update({ push_token: null })
        .eq('id', notif.user_id);

      if (clearErr) {
        console.error('[wsr-push] No se pudo limpiar el token:', clearErr.message);
      } else {
        console.log('[wsr-push] Token limpiado para user:', notif.user_id);
      }
    }

    return json({ ok: false, expo_error: errorCode ?? 'unknown' });
  }

  // ── 10. Éxito ─────────────────────────────────────────────────────
  console.log(`[wsr-push] ✅ Push enviado | kind=${notif.kind} | user=${notif.user_id}`);
  return json({ ok: true, receipt });
});

// ── Utilidad ──────────────────────────────────────────────────────────────────

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
