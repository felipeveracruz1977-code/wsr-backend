// DEPRECADA (2026-08-10): reemplazada por el trigger de BD
// wsr_confirmar_inscripcion_web + wsr_enviar_bienvenida_runner
// (ver supabase/migrations/081_web_registration_welcome_email.sql y
// 084_runner_signup_welcome_email.sql). El frontend ya no la invoca.
//
// Se dejaba desplegada pero desconectada del frontend, invocando
// registrations.runner_id — columna que ya no existe (el esquema migró a
// user_id) — lo que producía errores en cada inscripción a un entrenamiento.
// Se reemplaza por este no-op en vez de borrarla porque el despliegue vía
// MCP no permite eliminar funciones, solo reemplazar contenido. Borrado real
// pendiente desde el dashboard de Supabase o `supabase functions delete
// confirmar-inscripcion`.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(() => new Response("gone: reemplazada por trigger de BD", { status: 410 }));
