-- 083 — Captura diaria de Stories de Instagram antes de que expiren
--
-- Motivo (2026-08-01): el Event Wrap-Up Engine (informe de cierre de evento
-- patrocinado) necesita reportar cuántas Stories se publicaron sobre la marca y
-- cómo rindieron. La API de Meta expone las Stories SOLO durante las 24 horas en
-- que están vivas: pasado ese plazo desaparecen para siempre, para cualquiera.
-- Sin esta tabla, un informe generado una semana después del evento no puede
-- incluir ninguna Story — que suele ser el formato con más volumen en una
-- activación presencial.
--
-- Fix: una tarea programada diaria (Vercel Cron → /api/cron/birthdays?task=
-- instagram-stories) lee las Stories vivas vía Windsor.ai y las persiste aquí.
-- Cada corrida diaria alcanza a ver toda Story publicada en las 24 h previas,
-- porque el intervalo del cron es igual a la vida útil de una Story.
--
-- LIMITACIÓN CONOCIDA — las cifras son una foto, no un total final:
-- una Story se captura en promedio a mitad de su vida (~12 h), así que su
-- alcance y visualizaciones quedan por debajo del número definitivo. El plan
-- Hobby de Vercel permite un solo disparo diario, así que no hay re-captura
-- posible antes de que expire. Se documenta en la columna `capturada_en` para
-- que el informe pueda declarar la antigüedad del dato.
--
-- LEY III (Frontera Clínica / Zero-Trust): esta tabla es de solo lectura para
-- los clientes. La escritura ocurre exclusivamente desde el cron con
-- service_role (que bypassa RLS deliberadamente). No se otorga INSERT/UPDATE/
-- DELETE a authenticated: no existe ningún flujo legítimo en el que la Web o la
-- App escriban aquí.

-- ============================================================================
-- 1. Tabla de Stories capturadas
-- ============================================================================

CREATE TABLE public.instagram_stories_capturadas (
  -- ID que asigna Instagram a la Story. Es la clave natural y permite que el
  -- cron haga UPSERT sin duplicar si una corrida se repite o se dispara manual.
  story_id text PRIMARY KEY,

  publicada_en timestamp with time zone NOT NULL,
  capturada_en timestamp with time zone DEFAULT now() NOT NULL,

  permalink text,
  thumbnail_url text,

  -- Métricas de la Story al momento de la captura. Nullable: Meta no siempre
  -- entrega todas (una Story con muy pocas vistas omite varias).
  alcance integer,
  visualizaciones integer,
  respuestas integer,
  compartidos integer,
  interacciones integer,
  salidas integer,
  toques_adelante integer,
  toques_atras integer,

  creado_en timestamp with time zone DEFAULT now() NOT NULL
);

COMMENT ON TABLE public.instagram_stories_capturadas IS
  'Stories de Instagram persistidas por el cron diario antes de que Meta las elimine a las 24 h. Alimenta el Event Wrap-Up Engine. Solo lectura para clientes; escribe el cron con service_role.';

COMMENT ON COLUMN public.instagram_stories_capturadas.capturada_en IS
  'Momento de la captura. La distancia con publicada_en indica cuán maduras estaban las metricas: mientras mayor, mas cercanas al total final.';

COMMENT ON COLUMN public.instagram_stories_capturadas.respuestas IS
  'Cantidad de respuestas recibidas. Meta NUNCA expone el texto de una respuesta a Story (son mensajes privados), solo el conteo.';

-- El informe siempre consulta por rango de fechas del evento.
CREATE INDEX idx_ig_stories_publicada_en
  ON public.instagram_stories_capturadas (publicada_en DESC);

-- ============================================================================
-- 2. RLS — lectura solo para admin/super_admin
-- ============================================================================

ALTER TABLE public.instagram_stories_capturadas ENABLE ROW LEVEL SECURITY;

-- Derechos de invocador (sin SECURITY DEFINER): RLS hace el trabajo de
-- autorización y no hay que reimplementarla a mano (Ley III).
CREATE POLICY "Admin lee stories capturadas"
  ON public.instagram_stories_capturadas
  FOR SELECT
  TO authenticated
  USING (public.fn_is_admin_or_super());

-- Sin políticas de INSERT/UPDATE/DELETE: ningún cliente escribe aquí.

REVOKE ALL ON public.instagram_stories_capturadas FROM anon;
REVOKE ALL ON public.instagram_stories_capturadas FROM PUBLIC;
GRANT SELECT ON public.instagram_stories_capturadas TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.instagram_stories_capturadas TO service_role;
