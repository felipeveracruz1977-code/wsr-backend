// Supabase Edge Function — Compañera IA de WSR (Claude)
//
// El corazón conversacional de la Fase 3. Acompaña a la usuaria con el tono WSR:
// cálido, contenido, sin culpa, nunca prescriptivo médico. Construye el contexto
// server-side (onboarding + check-ins recientes) y nunca expone esos datos a otra
// usuaria. Autentica al llamador por su JWT; consulta con service role.
//
// Modelo por defecto: claude-opus-4-7 (configurable vía WSR_AI_MODEL).
// El system prompt es estable y se cachea (prompt caching) para bajar costo/latencia.

import Anthropic from 'npm:@anthropic-ai/sdk@0.69.0';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { withObservability } from '../_shared/withObservability.ts';

const MODEL = Deno.env.get('WSR_AI_MODEL') ?? 'claude-opus-4-7';

const SYSTEM_PROMPT = `Eres la compañera de Woman Social Run (WSR), una comunidad de running femenino en Santiago de Chile.

Tu filosofía: "La meta no es hacer correr más. La meta es ayudar a sostener el running en la vida real."

Tu voz:
- Cálida, cercana, femenina, contenida y elegante. Como una amiga que cuida, no una entrenadora que exige.
- Breve: 2-4 frases. Nunca un sermón.
- En español de Chile, natural, sin tecnicismos.

Reglas innegociables:
- NUNCA uses lenguaje de culpa. Prohibido: "perdiste tu racha", "no cumpliste", "sin excusas", "fallaste".
- Si la usuaria faltó o está cansada, reencuadra con amabilidad: descansar es parte del proceso.
- Celebra la constancia y el regreso, no el rendimiento ni el pace.
- NO des consejo médico ni diagnósticos. Si menciona dolor, lesión o salud, sugiere con suavidad consultar a un profesional.
- No prometas resultados físicos ni hables de peso o estética.
- Adapta el tono al ánimo y la energía de la usuaria que verás en su contexto.

Tu objetivo siempre: que se sienta acompañada y con ganas de volver, a su ritmo.`;

interface CheckinRow { energy: number; mood: string; created_at: string }
interface OnboardingRow {
  running_relationship: string | null;
  motivations: string[] | null;
  barriers: string[] | null;
  support_style: string | null;
}

Deno.serve(withObservability('ai-companion', async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (!apiKey) return new Response('Missing ANTHROPIC_API_KEY', { status: 500 });

  // Autenticar a la usuaria por su JWT.
  const authHeader = req.headers.get('Authorization') ?? '';
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
  const { data: userData, error: userErr } = await supabase.auth.getUser(
    authHeader.replace('Bearer ', ''),
  );
  if (userErr || !userData.user) return new Response('Unauthorized', { status: 401 });
  const userId = userData.user.id;

  // Rate limit: 20 requests / 60 minutos por usuaria (protección de costos IA).
  const { data: withinLimit, error: rlErr } = await supabase
    .rpc('check_ai_rate_limit', { p_user_id: userId });
  if (rlErr) {
    console.error('[ai-companion] Rate limit check failed:', rlErr.message);
    return new Response('Service unavailable', { status: 503 });
  }
  if (!withinLimit) {
    return new Response(
      JSON.stringify({ error: 'rate_limit_exceeded', retry_after_minutes: 60 }),
      { status: 429, headers: { 'Content-Type': 'application/json' } },
    );
  }

  let message = '';
  try {
    const body = await req.json();
    message = String(body.message ?? '').slice(0, 2000);
  } catch {
    return new Response('Invalid body', { status: 400 });
  }
  if (!message.trim()) return new Response('Empty message', { status: 400 });

  // Contexto privado de la usuaria.
  const [{ data: profile }, { data: onboarding }, { data: checkins }] = await Promise.all([
    supabase.from('user_profiles').select('full_name').eq('id', userId).maybeSingle(),
    supabase
      .from('user_onboarding')
      .select('running_relationship, motivations, barriers, support_style')
      .eq('user_id', userId)
      .maybeSingle(),
    supabase
      .from('emotional_checkins')
      .select('energy, mood, created_at')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(5),
  ]);

  const firstName = (profile?.full_name as string | undefined)?.split(' ')[0] ?? null;
  const ob = (onboarding ?? null) as OnboardingRow | null;
  const recent = (checkins ?? []) as CheckinRow[];

  const contextLines: string[] = ['Contexto privado de la usuaria (no lo repitas literal, úsalo para tu tono):'];
  if (firstName) contextLines.push(`- Nombre: ${firstName}`);
  if (ob?.running_relationship) contextLines.push(`- Relación con correr: ${ob.running_relationship}`);
  if (ob?.motivations?.length) contextLines.push(`- La mueve: ${ob.motivations.join(', ')}`);
  if (ob?.barriers?.length) contextLines.push(`- Le cuesta: ${ob.barriers.join(', ')}`);
  if (ob?.barriers?.includes('culpa')) {
    contextLines.push('- IMPORTANTE: marcó la culpa como barrera. Tono extra-suave, jamás reproche.');
  }
  if (recent.length) {
    const last = recent[0];
    contextLines.push(`- Último check-in: ánimo "${last.mood}", energía ${last.energy}/5.`);
  }
  const userContext = contextLines.join('\n');

  const anthropic = new Anthropic({ apiKey });

  try {
    const response = await anthropic.messages.create({
      model: MODEL,
      max_tokens: 1024,
      system: [
        { type: 'text', text: SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } },
      ],
      messages: [
        { role: 'user', content: `${userContext}\n\nMensaje de la usuaria:\n${message}` },
      ],
    });

    const text = response.content
      .filter((b) => b.type === 'text')
      .map((b) => (b as { text: string }).text)
      .join('')
      .trim();

    return new Response(JSON.stringify({ reply: text }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error('[ai-companion] Anthropic error:', e);
    return new Response('AI error', { status: 502 });
  }
}));
