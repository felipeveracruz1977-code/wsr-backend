/**
 * push-message-notify — WSR Chat Push Notifications
 * ==================================================
 * Supabase Edge Function · Deno Runtime
 *
 * Webhook configurado en Supabase sobre INSERT en la tabla `messages`.
 * Envía push notification a las participantes del canal que NO son la
 * emisora del mensaje, respetando `is_muted`.
 *
 * ── Anti-Ansiedad (Chat Engine Law) ──────────────────────────────
 *   ❌ NO se notifica quién leyó (last_read_at es privado)
 *   ❌ NO se envía "está escribiendo"
 *   ✅ Solo push al recibir un mensaje real y completo
 * ─────────────────────────────────────────────────────────────────
 *
 * Deploy:
 *   supabase functions deploy push-message-notify --no-verify-jwt
 *
 * Configurar webhook en Supabase Dashboard:
 *   Table: messages · Event: INSERT
 *   URL:   https://<project-ref>.supabase.co/functions/v1/push-message-notify
 *   Header x-webhook-secret: <WEBHOOK_SECRET>
 *
 * Secrets:
 *   SUPABASE_URL              auto-inyectado
 *   SUPABASE_SERVICE_ROLE_KEY auto-inyectado
 *   WEBHOOK_SECRET            secreto compartido con el webhook
 */

import { serve }        from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ── Tipos ─────────────────────────────────────────────────────────────────────

interface MessageRecord {
  id:         string;
  channel_id: string;
  sender_id:  string;
  body:       string | null;
  kind:       string;
  deleted_at: string | null;
  created_at: string;
}

interface WebhookPayload {
  type:       'INSERT' | 'UPDATE' | 'DELETE';
  table:      string;
  schema:     string;
  record:     MessageRecord;
  old_record: MessageRecord | null;
}

interface ExpoMessage {
  to:    string;
  title: string;
  body:  string;
  data?: Record<string, unknown>;
  sound?: 'default';
}

// ── Push via Expo ─────────────────────────────────────────────────────────────

async function sendExpoPush(messages: ExpoMessage[]): Promise<void> {
  const res = await fetch('https://exp.host/--/api/v2/push/send', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
    body: JSON.stringify(messages),
  });
  if (!res.ok) {
    console.error('[wsr-push-dm] Expo error', res.status, await res.text());
  }
}

// ── Copywriting ───────────────────────────────────────────────────────────────

function buildCopy(
  senderName:  string,
  messageBody: string | null,
  channelName: string | null,
  channelType: string,
): { title: string; body: string } {
  const preview = messageBody?.trim().slice(0, 80);

  if (channelType === 'direct') {
    return {
      title: `💬 ${senderName}`,
      body:  preview || 'Te envió un mensaje.',
    };
  }

  return {
    title: `💬 ${senderName} en ${channelName ?? 'el grupo'}`,
    body:  preview || 'Escribió algo en el canal.',
  };
}

// ── Helper ────────────────────────────────────────────────────────────────────

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// ── Handler ───────────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return json({ ok: false, error: 'method_not_allowed' }, 405);
  }

  // 1. Webhook secret — OBLIGATORIO (fail-closed)
  const webhookSecret = Deno.env.get('WEBHOOK_SECRET');
  if (!webhookSecret) {
    console.error('[wsr-push-dm] WEBHOOK_SECRET no configurado — función bloqueada.');
    return json({ ok: false, error: 'misconfigured' }, 500);
  }
  const incoming = req.headers.get('x-webhook-secret');
  if (incoming !== webhookSecret) {
    console.warn('[wsr-push-dm] Secret inválido.');
    return json({ ok: false, error: 'unauthorized' }, 401);
  }

  // 2. Parse payload
  let payload: WebhookPayload;
  try { payload = await req.json(); }
  catch { return json({ ok: false, error: 'invalid_json' }, 400); }

  if (payload.type !== 'INSERT' || payload.table !== 'messages') {
    return json({ ok: true, skipped: 'not_a_message_insert' });
  }

  const msg = payload.record;

  // Omit system messages and deleted messages
  if (msg.kind !== 'text' || msg.deleted_at) {
    return json({ ok: true, skipped: 'non_text_or_deleted' });
  }

  // 3. Supabase service client
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  // 4. Fetch channel info
  const { data: channel, error: chErr } = await supabase
    .from('channels')
    .select('id, name, type, is_archived')
    .eq('id', msg.channel_id)
    .maybeSingle();

  if (chErr || !channel) return json({ ok: false, error: 'channel_not_found' }, 404);
  if (channel.is_archived) return json({ ok: true, skipped: 'archived_channel' });

  // 5. Fetch channel participants (exclude sender and muted)
  const { data: participants, error: pErr } = await supabase
    .from('channel_participants')
    .select('user_id, is_muted')
    .eq('channel_id', msg.channel_id)
    .neq('user_id', msg.sender_id)
    .eq('is_muted', false);

  if (pErr) return json({ ok: false, error: pErr.message }, 500);
  if (!participants?.length) return json({ ok: true, skipped: 'no_recipients' });

  const recipientIds = participants.map((p) => p.user_id as string);

  // 6. Fetch sender name
  const { data: senderProfile } = await supabase
    .from('user_profiles')
    .select('full_name')
    .eq('id', msg.sender_id)
    .maybeSingle();

  const senderName = senderProfile?.full_name ?? 'WSR';

  // 7. Fetch push tokens of recipients
  const { data: profiles, error: tokenErr } = await supabase
    .from('user_profiles')
    .select('id, push_token')
    .in('id', recipientIds)
    .not('push_token', 'is', null);

  if (tokenErr) return json({ ok: false, error: tokenErr.message }, 500);

  const validTokens = (profiles ?? []).filter((p) =>
    p.push_token && (p.push_token as string).startsWith('ExponentPushToken['),
  );

  if (!validTokens.length) return json({ ok: true, skipped: 'no_valid_tokens' });

  // 8. Build and send push messages
  const copy = buildCopy(senderName, msg.body, channel.name, channel.type);

  const expoPushMessages: ExpoMessage[] = validTokens.map((p) => ({
    to:    p.push_token as string,
    title: copy.title,
    body:  copy.body,
    sound: 'default',
    data:  { type: 'new_message', channelId: msg.channel_id, messageId: msg.id },
  }));

  // Expo allows max 100 per request
  const CHUNK = 100;
  for (let i = 0; i < expoPushMessages.length; i += CHUNK) {
    await sendExpoPush(expoPushMessages.slice(i, i + CHUNK));
  }

  return json({ ok: true, sent: expoPushMessages.length });
});
