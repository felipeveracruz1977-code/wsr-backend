import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Config ────────────────────────────────────────────────────────────────────

const RESEND_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
// SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY son inyectadas automáticamente
// por el runtime de Supabase Edge Functions.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FROM = "Woman Social Run <felipe@womansocialrun.cl>";
const INSTAGRAM_URL = "https://www.instagram.com/woman_social_run/";

// Headers CORS requeridos para invocaciones desde el navegador.
// Solo se aceptan los orígenes del ecosistema WSR: producción y desarrollo local.
const ALLOWED_ORIGINS = [
  "https://www.womansocialrun.cl",
  "https://womansocialrun.cl",
  "http://localhost:5173",
  "http://localhost:3000",
];

function corsFor(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin") ?? "";
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGINS.includes(origin)
      ? origin
      : ALLOWED_ORIGINS[0],
    Vary: "Origin",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };
}

// ── Handler principal ─────────────────────────────────────────────────────────

serve(async (req) => {
  const CORS = corsFor(req);
  // Preflight CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  try {
    const body = await req.json() as {
      email: string;
      nombre: string;
      training: {
        titulo: string;
        fecha_hora: string;
        ubicacion?: string | null;
      };
    };

    const { email, nombre, training } = body;

    if (!email || !nombre || !training?.titulo) {
      return json({ error: "missing fields" }, 400, CORS);
    }

    const primerNombre = primerToken(nombre);

    // Verificar si es la primera inscripción de esta corredora
    const esPrimera = await esFirstRegistration(email);

    // Enviar bienvenida solo en la primera inscripción
    if (esPrimera) {
      await enviarCorreo({
        to: email,
        subject: "Bienvenida a Woman Social Run ·",
        html: htmlBienvenida(primerNombre),
      });
    }

    // Siempre enviar confirmación
    await enviarCorreo({
      to: email,
      subject: `¡Estás inscrita! ${training.titulo}`,
      html: htmlConfirmacion(primerNombre, training),
    });

    return json({ ok: true, bienvenida: esPrimera }, 200, CORS);
  } catch (err) {
    console.error("[confirmar-inscripcion]", err);
    return json({ error: "internal error" }, 500, CORS);
  }
});

// ── Helpers ───────────────────────────────────────────────────────────────────

function json(
  data: unknown,
  status = 200,
  cors: Record<string, string> = {},
) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function primerToken(nombre: string): string {
  return nombre.trim().split(/\s+/)[0] || "Corredora";
}

async function esFirstRegistration(email: string): Promise<boolean> {
  try {
    const db = createClient(SUPABASE_URL, SERVICE_KEY);

    // Buscar el runner por email
    const { data: runner } = await db
      .from("runners")
      .select("id")
      .eq("email", email.toLowerCase().trim())
      .maybeSingle();

    if (!runner?.id) return true; // nuevo, mandar bienvenida

    // Contar sus inscripciones totales
    const { count } = await db
      .from("registrations")
      .select("id", { count: "exact", head: true })
      .eq("runner_id", runner.id);

    // count === 1 significa que esta que acabamos de crear es la primera
    return (count ?? 0) === 1;
  } catch {
    return false; // si falla la consulta, no bloquear el flujo
  }
}

async function enviarCorreo({
  to,
  subject,
  html,
}: {
  to: string;
  subject: string;
  html: string;
}): Promise<void> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from: FROM, to: [to], subject, html }),
  });

  if (!res.ok) {
    const err = await res.text();
    console.error("[Resend]", res.status, err);
    throw new Error(`Resend ${res.status}: ${err}`);
  }
}

// ── Template: Bienvenida ──────────────────────────────────────────────────────

function htmlBienvenida(nombre: string): string {
  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1.0"/>
  <title>Bienvenida a WSR</title>
</head>
<body style="margin:0;padding:0;background:#FFF0F8;font-family:'Helvetica Neue',Arial,sans-serif;-webkit-font-smoothing:antialiased;">
<div style="max-width:560px;margin:0 auto;padding:40px 16px 32px;">

  <!-- Marca -->
  <p style="text-align:center;margin:0 0 28px;font-size:9px;letter-spacing:.35em;text-transform:uppercase;color:#D9488C;font-weight:500;">
    Woman Social Run
  </p>

  <!-- Tarjeta -->
  <div style="background:#fff;border:1px solid #FFD1F1;border-radius:4px;overflow:hidden;">
    <div style="height:3px;background:linear-gradient(90deg,#D9488C,#F08EC0,#C9A66B);"></div>

    <!-- Encabezado -->
    <div style="padding:48px 40px 28px;text-align:center;">
      <p style="margin:0 0 14px;font-size:9px;letter-spacing:.32em;text-transform:uppercase;color:#D9488C;opacity:.8;">
        Bienvenida
      </p>
      <h1 style="margin:0;font-family:Georgia,'Times New Roman',serif;font-size:2.1rem;font-weight:400;color:#3D1020;line-height:1.15;letter-spacing:-.01em;">
        Hola, ${nombre}.
      </h1>
    </div>

    <!-- Separador -->
    <div style="margin:0 40px;height:1px;background:linear-gradient(90deg,transparent,#D9488C30,transparent);"></div>

    <!-- Cuerpo -->
    <div style="padding:28px 40px 40px;">
      <p style="margin:0 0 16px;font-size:1rem;color:#5C3248;line-height:1.75;">
        Nos alegra mucho que estés aquí. Woman Social Run es una comunidad de mujeres que corren juntas, a su propio ritmo, sin presión ni marcas de tiempo.
      </p>
      <p style="margin:0 0 28px;font-size:1rem;color:#5C3248;line-height:1.75;">
        En cada encuentro buscamos lo mismo: movimiento, compañía y presencia. Pronto te avisaremos de los próximos entrenamientos.
      </p>

      <!-- CTA -->
      <div style="text-align:center;margin:8px 0;">
        <a href="${INSTAGRAM_URL}"
           style="display:inline-block;padding:14px 34px;background:#D9488C;color:#fff;text-decoration:none;font-size:.72rem;letter-spacing:.16em;text-transform:uppercase;border-radius:999px;font-weight:500;">
          Síguenos en Instagram →
        </a>
      </div>
    </div>
  </div>

  <!-- Footer -->
  <div style="text-align:center;padding:28px 16px 0;font-size:.68rem;color:#B07A90;letter-spacing:.06em;line-height:1.8;">
    <p style="margin:0;">Woman Social Run · Santiago, Chile</p>
    <p style="margin:4px 0 0;opacity:.65;">Recibiste este correo porque te registraste en WSR.</p>
  </div>

</div>
</body>
</html>`;
}

// ── Template: Confirmación de inscripción ─────────────────────────────────────

interface TrainingInfo {
  titulo: string;
  fecha_hora: string;
  ubicacion?: string | null;
  ubicacion_texto?: string | null;
  latitud?: number | null;
  longitud?: number | null;
}

function formatFecha(fechaHora: string): string {
  const d = new Date(fechaHora.slice(0, 16));
  const str = d.toLocaleDateString("es-CL", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  });
  // Capitalizar primera letra
  return str.charAt(0).toUpperCase() + str.slice(1);
}

function formatHora(fechaHora: string): string {
  const d = new Date(fechaHora.slice(0, 16));
  return d.toLocaleTimeString("es-CL", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
}

function htmlConfirmacion(nombre: string, training: TrainingInfo): string {
  const fecha = formatFecha(training.fecha_hora);
  const hora = formatHora(training.fecha_hora);
  const tituloCapital =
    training.titulo.charAt(0).toUpperCase() + training.titulo.slice(1);

  const filaUbicacion = training.ubicacion
    ? `<tr>
         <td style="padding:5px 0;font-size:.875rem;color:#7B4F60;">
           <span style="margin-right:6px;">📍</span>${training.ubicacion}
         </td>
       </tr>`
    : "";

  const tieneCoords =
    training.latitud != null && training.longitud != null;

  const ctaUrl = tieneCoords
    ? `https://www.google.com/maps?q=${training.latitud},${training.longitud}`
    : INSTAGRAM_URL;

  const notaEncuentro = tieneCoords
    ? (training.ubicacion_texto || training.ubicacion || "Te esperamos en el punto marcado en el mapa.")
    : "El lugar exacto se confirma por Instagram antes del entrenamiento. Síguenos para no perderte nada.";

  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1.0"/>
  <title>Inscripción confirmada · WSR</title>
</head>
<body style="margin:0;padding:0;background:#FFF0F8;font-family:'Helvetica Neue',Arial,sans-serif;-webkit-font-smoothing:antialiased;">
<div style="max-width:560px;margin:0 auto;padding:40px 16px 32px;">

  <!-- Marca -->
  <p style="text-align:center;margin:0 0 28px;font-size:9px;letter-spacing:.35em;text-transform:uppercase;color:#D9488C;font-weight:500;">
    Woman Social Run
  </p>

  <!-- Tarjeta -->
  <div style="background:#fff;border:1px solid #FFD1F1;border-radius:4px;overflow:hidden;">
    <div style="height:3px;background:linear-gradient(90deg,#D9488C,#F08EC0,#C9A66B);"></div>

    <!-- Encabezado -->
    <div style="padding:48px 40px 28px;text-align:center;">
      <p style="margin:0 0 14px;font-size:9px;letter-spacing:.32em;text-transform:uppercase;color:#D9488C;opacity:.8;">
        Inscripción confirmada
      </p>
      <h1 style="margin:0;font-family:Georgia,'Times New Roman',serif;font-size:2.1rem;font-weight:400;color:#3D1020;line-height:1.15;letter-spacing:-.01em;">
        ¡Tu lugar está<br/>confirmado, ${nombre}!
      </h1>
    </div>

    <!-- Separador -->
    <div style="margin:0 40px;height:1px;background:linear-gradient(90deg,transparent,#D9488C30,transparent);"></div>

    <!-- Cuerpo -->
    <div style="padding:28px 40px 40px;">
      <p style="margin:0 0 22px;font-size:1rem;color:#5C3248;line-height:1.75;">
        Te esperamos en el siguiente entrenamiento:
      </p>

      <!-- Tarjeta del entrenamiento -->
      <div style="background:#FFF5FB;border:1px solid #FFD1F1;border-left:3px solid #D9488C;border-radius:4px;padding:22px 22px 18px;">
        <p style="margin:0 0 12px;font-family:Georgia,'Times New Roman',serif;font-size:1.2rem;font-weight:400;color:#3D1020;line-height:1.3;">
          ${tituloCapital}
        </p>
        <table style="border-collapse:collapse;width:100%;">
          <tr>
            <td style="padding:5px 0;font-size:.875rem;color:#7B4F60;">
              <span style="margin-right:6px;">📅</span>${fecha}
            </td>
          </tr>
          <tr>
            <td style="padding:5px 0;font-size:.875rem;color:#7B4F60;">
              <span style="margin-right:6px;">🕐</span>${hora} hrs
            </td>
          </tr>
          ${filaUbicacion}
        </table>
      </div>

      <!-- Nota punto de encuentro -->
      <div style="margin:22px 0 0;padding:16px 18px;background:#FFF9FB;border:1px solid #FFE6F4;border-radius:4px;">
        <p style="margin:0;font-size:.875rem;color:#7B4F60;line-height:1.7;">
          <strong style="color:#5C3248;display:block;margin-bottom:3px;">📍 Punto de encuentro</strong>
          ${notaEncuentro}
        </p>
      </div>

      <!-- CTA -->
      <div style="text-align:center;margin:32px 0 8px;">
        <a href="${ctaUrl}"
           style="display:inline-block;padding:14px 34px;background:#D9488C;color:#fff;text-decoration:none;font-size:.72rem;letter-spacing:.16em;text-transform:uppercase;border-radius:999px;font-weight:500;">
          Ver punto de encuentro →
        </a>
      </div>
    </div>
  </div>

  <!-- Footer -->
  <div style="text-align:center;padding:28px 16px 0;font-size:.68rem;color:#B07A90;letter-spacing:.06em;line-height:1.8;">
    <p style="margin:0;">Woman Social Run · Santiago, Chile</p>
    <p style="margin:4px 0 0;opacity:.65;">Recibiste este correo porque te inscribiste en un entrenamiento WSR.</p>
  </div>

</div>
</body>
</html>`;
}
