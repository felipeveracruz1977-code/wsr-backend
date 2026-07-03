// supabase/functions/_shared/withObservability.ts
//
// Middleware de observabilidad para Edge Functions (Deno Deploy / Supabase).
// Envuelve un handler `(req: Request) => Promise<Response>` y:
//   - mide tiempo de ejecución (wall clock, ms)
//   - captura memoria del proceso vía Deno.memoryUsage() cuando el runtime la expone
//     (Deno Deploy la restringe en algunos planes; por eso es opcional/best-effort)
//   - captura cualquier excepción no manejada del handler y la reporta como 500
//     estructurado, en vez de dejar que Supabase devuelva un 546/502 opaco
//   - emite un único log JSON estructurado por invocación (éxito o error), para
//     que un pipeline de logs (Logflare/Datadog/etc.) lo pueda parsear sin regex
//
// No usa `console.table` ni logs multi-línea: una línea JSON por request.

export type EdgeHandler = (req: Request) => Response | Promise<Response>;

interface ObservabilityLog {
  fn: string;
  request_id: string;
  method: string;
  status: number;
  duration_ms: number;
  memory_mb: number | null;
  ok: boolean;
  error?: string;
  timestamp: string;
}

function readMemoryMb(): number | null {
  // Deno.memoryUsage() no siempre está disponible (permisos/entorno Deploy);
  // fallar en silencio a null es preferible a romper la función por telemetría.
  try {
    const usage = (Deno as unknown as { memoryUsage?: () => { rss: number } }).memoryUsage?.();
    if (!usage) return null;
    return Math.round((usage.rss / (1024 * 1024)) * 100) / 100;
  } catch {
    return null;
  }
}

/**
 * Envuelve un handler de Edge Function con medición de tiempo/memoria y
 * captura de errores no manejados como 500 estructurado.
 */
export function withObservability(fnName: string, handler: EdgeHandler): EdgeHandler {
  return async (req: Request): Promise<Response> => {
    const requestId = crypto.randomUUID();
    const startedAt = performance.now();

    const emit = (status: number, ok: boolean, error?: string) => {
      const log: ObservabilityLog = {
        fn: fnName,
        request_id: requestId,
        method: req.method,
        status,
        duration_ms: Math.round((performance.now() - startedAt) * 100) / 100,
        memory_mb: readMemoryMb(),
        ok,
        timestamp: new Date().toISOString(),
      };
      if (error !== undefined) log.error = error;

      // Los 500 son fallos silenciosos potenciales (p.ej. una IA que devuelve
      // texto vacío o un error de proveedor tragado aguas arriba): van a
      // console.error para que las alertas de log level los enganchen.
      if (status >= 500) {
        console.error(JSON.stringify(log));
      } else {
        console.log(JSON.stringify(log));
      }
    };

    try {
      const res = await handler(req);
      emit(res.status, res.status < 500);
      return res;
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      emit(500, false, message);
      return new Response(
        JSON.stringify({ error: "internal_error", request_id: requestId }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }
  };
}
