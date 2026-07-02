import { serve }        from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type NotificationKind = 'new_message' | 'new_training' | 'support_reaction' | 'anti_abandonment' | 'general';

interface NotificationRecord {
  id: string; user_id: string; kind: NotificationKind;
  title: string; body: string; ref_id: string | null;
  ref_type: string | null; is_read: boolean; created_at: string;
}
interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE'; table: string; schema: string;
  record: NotificationRecord; old_record: NotificationRecord | null;
}
interface ExpoReceipt {
  status: 'ok' | 'error'; message?: string; details?: { error?: string };
}

function buildPushCopy(kind: NotificationKind, record: NotificationRecord): { title: string; body: string } {
  switch (kind) {
    case 'new_message':
      return { title: '💬 Nuevo mensaje', body: record.body?.trim() || 'Alguien en tu comunidad te escribio. 🤍' };
    case 'new_training':
      return { title: '🏃 Nuevo entrenamiento', body: record.body?.trim() ? `"${record.body.trim()}" ya esta publicado. Nos vemos?` : 'Un nuevo plan te esta esperando. Te sumas?' };
    case 'support_reaction':
      return { title: record.title?.trim() || 'Tu comunidad te apoya 💜', body: record.body?.trim() || 'Alguien en WSR te envio carino hoy.' };
    case 'anti_abandonment':
      return { title: '🤍 Te extranamos', body: 'Hace tiempo que no nos vemos. Aqui seguimos, sin presion. 💜' };
    default:
      return { title: record.title?.trim() || 'WSR 🔔', body: record.body?.trim() || 'Tienes una actualizacion.' };
  }
}

serve(async (req: Request) => {
  if (req.method !== 'POST') return json({ ok: false, error: 'method_not_allowed' }, 405);

  const webhookSecret = Deno.env.get('WEBHOOK_SECRET');
  if (!webhookSecret) {
    console.error('[dynamic-responder] WEBHOOK_SECRET no configurado — función bloqueada.');
    return json({ ok: false, error: 'misconfigured' }, 500);
  }
  if (req.headers.get('x-webhook-secret') !== webhookSecret) {
    return json({ ok: false, error: 'unauthorized' }, 401);
  }

  let payload: WebhookPayload;
  try { payload = await req.json(); }
  catch { return json({ ok: false, error: 'invalid_json' }, 400); }

  if (payload.type !== 'INSERT' || payload.table !== 'notifications') {
    return json({ ok: true, skipped: 'not_a_notification_insert' });
  }

  const notif = payload.record;
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } }
  );

  const [profileRes, countRes] = await Promise.all([
    supabase.from('user_profiles').select('push_token').eq('id', notif.user_id).single(),
    supabase.from('notifications').select('*', { count: 'exact', head: true }).eq('user_id', notif.user_id).eq('is_read', false),
  ]);

  if (profileRes.error) return json({ ok: false, error: 'db_error' }, 500);

  const pushToken = profileRes.data?.push_token;
  if (!pushToken) return json({ ok: true, skipped: 'no_push_token' });
  if (!pushToken.startsWith('ExponentPushToken')) return json({ ok: true, skipped: 'invalid_token_format' });

  const badgeCount = (countRes.count ?? 0) + 1;
  const { title, body } = buildPushCopy(notif.kind, notif);

  let expoRes: Response;
  try {
    expoRes = await fetch('https://exp.host/--/api/v2/push/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      body: JSON.stringify({ to: pushToken, title, body, sound: 'default', badge: badgeCount, channelId: 'default', data: { notif_id: notif.id, kind: notif.kind, ref_id: notif.ref_id, ref_type: notif.ref_type } }),
    });
  } catch { return json({ ok: false, error: 'expo_network_error' }, 502); }

  let expoData: { data?: ExpoReceipt[] };
  try { expoData = await expoRes.json(); }
  catch { return json({ ok: false, error: 'expo_invalid_response' }, 502); }

  const receipt = expoData?.data?.[0];
  if (receipt?.status === 'error') {
    if (receipt.details?.error === 'DeviceNotRegistered') {
      await supabase.from('user_profiles').update({ push_token: null }).eq('id', notif.user_id);
    }
    return json({ ok: false, expo_error: receipt.details?.error ?? 'unknown' });
  }

  console.log(`[wsr-push] Push enviado | kind=${notif.kind} | user=${notif.user_id}`);
  return json({ ok: true, receipt });
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}