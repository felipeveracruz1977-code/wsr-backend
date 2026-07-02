import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const FROM = "Woman Social Run <felipe@womansocialrun.cl>";
const INSTAGRAM_URL = "https://www.instagram.com/woman_social_run/";

serve(async (req) => {
  try {
    const payload = await req.json();

    // Solo procesar inserciones nuevas de corredoras
    if (payload.type !== "INSERT") {
      return new Response("skip", { status: 200 });
    }

    const record = payload.record as {
      email?: string;
      nombre_apellido?: string;
    };

    if (!record.email) {
      return new Response("skip: no email", { status: 200 });
    }

    const nombre = primerNombre(record.nombre_apellido);

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: FROM,
        to: [record.email],
        subject: "Bienvenida a Woman Social Run ·",
        html: htmlBienvenida(nombre),
      }),
    });

    if (!res.ok) {
      const body = await res.text();
      console.error("Resend error:", res.status, body);
      return new Response("email error", { status: 500 });
    }

    return new Response("ok", { status: 200 });
  } catch (err) {
    console.error("Function error:", err);
    return new Response("internal error", { status: 500 });
  }
});

// ── Helpers ───────────────────────────────────────────────────────────────────

function primerNombre(nombreCompleto?: string): string {
  if (!nombreCompleto) return "Corredora";
  return nombreCompleto.trim().split(/\s+/)[0];
}

// ── Template HTML ─────────────────────────────────────────────────────────────

function htmlBienvenida(nombre: string): string {
  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Bienvenida a WSR</title>
</head>
<body style="margin:0;padding:0;background-color:#FFF0F8;font-family:'Helvetica Neue',Arial,sans-serif;-webkit-font-smoothing:antialiased;">

  <div style="max-width:560px;margin:0 auto;padding:40px 16px 32px;">

    <!-- Logotipo / marca -->
    <div style="text-align:center;margin-bottom:28px;">
      <p style="margin:0;font-size:9px;letter-spacing:0.35em;text-transform:uppercase;color:#D9488C;font-weight:500;">
        Woman Social Run
      </p>
    </div>

    <!-- Tarjeta principal -->
    <div style="background:#ffffff;border:1px solid #FFD1F1;border-radius:4px;overflow:hidden;">

      <!-- Franja decorativa superior -->
      <div style="height:3px;background:linear-gradient(90deg,#D9488C,#F08EC0,#C9A66B);"></div>

      <!-- Encabezado -->
      <div style="padding:48px 40px 32px;text-align:center;">
        <p style="margin:0 0 16px;font-size:9px;letter-spacing:0.32em;text-transform:uppercase;color:#D9488C;opacity:0.8;">
          Bienvenida
        </p>
        <h1 style="margin:0;font-family:Georgia,'Times New Roman',serif;font-size:2.15rem;font-weight:400;color:#3D1020;line-height:1.15;letter-spacing:-0.01em;">
          Hola, ${nombre}.
        </h1>
      </div>

      <!-- Separador -->
      <div style="margin:0 40px;height:1px;background:linear-gradient(90deg,transparent,#D9488C33,transparent);"></div>

      <!-- Cuerpo del mensaje -->
      <div style="padding:32px 40px 40px;">
        <p style="margin:0 0 18px;font-size:1rem;color:#5C3248;line-height:1.75;">
          Nos alegra mucho que estés aquí. Woman Social Run es una comunidad de mujeres que corren juntas, a su propio ritmo, sin presión ni marcas de tiempo.
        </p>
        <p style="margin:0 0 18px;font-size:1rem;color:#5C3248;line-height:1.75;">
          En cada encuentro buscamos lo mismo: movimiento, compañía y presencia. Pronto te avisaremos de los próximos entrenamientos.
        </p>
        <p style="margin:0;font-size:1rem;color:#5C3248;line-height:1.75;">
          Mientras tanto, síguenos en Instagram para estar al día con los puntos de encuentro y novedades.
        </p>

        <!-- CTA Instagram -->
        <div style="text-align:center;margin:36px 0 8px;">
          <a href="${INSTAGRAM_URL}"
             style="display:inline-block;padding:14px 34px;background:#D9488C;color:#ffffff;text-decoration:none;font-size:0.72rem;letter-spacing:0.16em;text-transform:uppercase;border-radius:999px;font-weight:500;">
            Síguenos en Instagram →
          </a>
        </div>
      </div>

    </div>

    <!-- Footer -->
    <div style="text-align:center;padding:28px 16px 0;font-size:0.68rem;color:#B07A90;letter-spacing:0.06em;line-height:1.8;">
      <p style="margin:0;">Woman Social Run · Santiago, Chile</p>
      <p style="margin:4px 0 0;opacity:0.65;">Recibiste este correo porque te registraste en WSR.</p>
    </div>

  </div>
</body>
</html>`;
}
