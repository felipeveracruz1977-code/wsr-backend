-- 085 — Observatorio de Instagram: serie temporal cruda + capa derivada de KPIs
--
-- Motivo (2026-08-11): hoy el Event Wrap-Up Engine consulta Windsor.ai en vivo
-- cada vez que alguien genera un informe. Eso funciona para el informe puntual y
-- falla para todo lo demás, por una razón que no es de ingeniería sino de la
-- naturaleza del dato: las métricas de Instagram cambian retroactivamente. El
-- alcance de un Reel del martes NO es el mismo consultado el miércoles que
-- consultado tres semanas después, y Meta solo devuelve el valor de HOY.
--
-- Consecuencia práctica: sin persistencia no existe forma de responder "¿este
-- Reel creció o se apagó?", ni de detectar una caída de alcance, ni de reproducir
-- un informe entregado a una marca hace dos meses. Y `follower_count_1d` solo
-- retrocede 30 días: lo que no se guarda hoy, se pierde para siempre.
--
-- Esta migración instala la separación exigida:
--   · capa CRUDA  — `*_snapshots`, append-only, una foto por día de corrida.
--   · capa DERIVADA — vistas recalculables, ningún KPI se materializa.
-- Cambiar una fórmula = reemplazar una vista. Nunca reprocesar historia.
--
-- IDEMPOTENCIA: la clave primaria de cada tabla cruda incluye `corrida_dia`
-- (el día en que se capturó), no un id sintético. Re-ejecutar la ingesta el
-- mismo día hace UPSERT sobre la misma fila; ejecutarla al día siguiente crea
-- la siguiente foto. Correr el cron diez veces en una tarde deja exactamente
-- las mismas filas que correrlo una vez.
--
-- LEY I: esta migración vive en wsr-backend, el Cerebro Único. La Web solo lee.
-- LEY III: escritura exclusiva de service_role (el cron). Los clientes no tienen
-- ninguna política de INSERT/UPDATE/DELETE — no existe flujo legítimo en que la
-- Web o la App escriban métricas de Instagram.
--
-- Las vistas se declaran `security_invoker = true` (igual que la migración 075):
-- la RLS de las tablas base hace el trabajo de autorización y no hay que
-- reimplementarla. Una vista SECURITY DEFINER acá sería un agujero: expondría
-- métricas a cualquier `authenticated` saltándose fn_is_admin_or_super().

-- ============================================================================
-- 1. CAPA CRUDA — append-only, una foto por día
-- ============================================================================

-- ── 1.1 Serie diaria a nivel cuenta ────────────────────────────────────────
CREATE TABLE public.instagram_dia_snapshots (
  -- Día al que corresponde la métrica.
  fecha date NOT NULL,
  -- Día en que se capturó. Junto con `fecha` forma la PK: es lo que hace la
  -- ingesta idempotente sin necesidad de deduplicar a mano.
  corrida_dia date NOT NULL,
  capturado_en timestamptz NOT NULL DEFAULT now(),

  -- Denominador oficial de todos los KPIs de engagement (ver vistas más abajo).
  alcance integer,
  visualizaciones integer,
  interacciones integer,
  cuentas_activadas integer,

  me_gusta integer,
  comentarios integer,
  compartidos integer,
  guardados integer,
  respuestas integer,
  reposteos integer,

  -- `profile_links_taps`: toques en dirección/llamada/correo/mensaje.
  -- NO son visitas al perfil ni clics en el enlace de la bio (Meta deprecó
  -- `profile_views` y `website_clicks`). Se guarda con su nombre real.
  toques_botones_perfil integer,

  seguidores_nuevos integer,
  -- Foto del total de hoy (`user_info.followers_count`). Meta no da histórico:
  -- esta columna ES el histórico, construido un día a la vez.
  seguidores_totales integer,

  CONSTRAINT pk_ig_dia_snapshots PRIMARY KEY (fecha, corrida_dia)
);

COMMENT ON TABLE public.instagram_dia_snapshots IS
  'Serie temporal cruda de métricas de cuenta. Una fila por (día métrico, día de captura): las métricas de Instagram mutan retroactivamente y esta tabla conserva cada versión. Append-only, escribe solo el cron.';

COMMENT ON COLUMN public.instagram_dia_snapshots.corrida_dia IS
  'Día en que se capturó la fila. Parte de la PK: garantiza idempotencia (UPSERT dentro del mismo día) y a la vez preserva la serie entre días.';

COMMENT ON COLUMN public.instagram_dia_snapshots.toques_botones_perfil IS
  'profile_links_taps de Meta: toques en los botones de dirección, llamada, correo y mensaje. NO es visitas al perfil (profile_views está deprecado) ni clics en el enlace de la bio.';

CREATE INDEX idx_ig_dia_fecha ON public.instagram_dia_snapshots (fecha DESC);

-- ── 1.2 Serie por pieza publicada ──────────────────────────────────────────
CREATE TABLE public.instagram_pieza_snapshots (
  media_id text NOT NULL,
  corrida_dia date NOT NULL,
  capturado_en timestamptz NOT NULL DEFAULT now(),

  publicada_en timestamptz,
  permalink text,
  caption text,
  -- FEED | REELS | IGTV | STORY | AD  (Meta: media_product_type)
  formato text,
  -- IMAGE | VIDEO | CAROUSEL_ALBUM | REEL  (Meta: media_type)
  tipo text,

  alcance integer,
  visualizaciones integer,
  interacciones integer,
  me_gusta integer,
  comentarios integer,
  guardados integer,
  compartidos integer,

  -- `media_follows`: cuentas que siguieron el perfil DESPUÉS de ver esta pieza.
  -- `media_profile_visits`: visitas al perfil originadas en esta pieza.
  -- Meta NO entrega ninguno de los dos para Reels — quedan null ahí, y las
  -- vistas derivadas devuelven null en vez de cero (ver v_instagram_pieza_kpis).
  seguidores_ganados integer,
  visitas_perfil integer,
  actividad_perfil integer,

  -- Milisegundos. Meta NO expone la duración del video, así que el porcentaje
  -- de retención es incalculable por API: solo el tiempo absoluto es real.
  reel_tiempo_medio_ms integer,
  reel_tiempo_total_ms bigint,

  CONSTRAINT pk_ig_pieza_snapshots PRIMARY KEY (media_id, corrida_dia)
);

COMMENT ON TABLE public.instagram_pieza_snapshots IS
  'Serie temporal cruda por pieza publicada. Una fila por (media_id, día de captura) para poder responder si una pieza siguió creciendo o se apagó. Append-only, escribe solo el cron.';

COMMENT ON COLUMN public.instagram_pieza_snapshots.reel_tiempo_medio_ms IS
  'ig_reels_avg_watch_time en milisegundos. La retención porcentual NO es calculable: Meta no expone la duración del video.';

CREATE INDEX idx_ig_pieza_publicada ON public.instagram_pieza_snapshots (publicada_en DESC);
CREATE INDEX idx_ig_pieza_corrida ON public.instagram_pieza_snapshots (corrida_dia DESC);

-- ── 1.3 Bitácora de ingesta — el sistema falla ruidosamente ────────────────
CREATE TABLE public.instagram_ingesta_corridas (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tarea text NOT NULL,
  iniciada_en timestamptz NOT NULL DEFAULT now(),
  terminada_en timestamptz,
  estado text NOT NULL DEFAULT 'error'
    CHECK (estado IN ('ok', 'parcial', 'error')),

  filas_dia integer NOT NULL DEFAULT 0,
  filas_pieza integer NOT NULL DEFAULT 0,
  filas_story integer NOT NULL DEFAULT 0,

  rango_desde date,
  rango_hasta date,

  advertencias text[] NOT NULL DEFAULT '{}',
  error text
);

COMMENT ON TABLE public.instagram_ingesta_corridas IS
  'Bitácora de cada corrida de ingesta. Existe para que un quiebre sea visible: sin esta tabla, una ingesta caída produce informes silenciosamente incompletos, que es el modo de falla más caro del sistema.';

CREATE INDEX idx_ig_corridas_iniciada ON public.instagram_ingesta_corridas (iniciada_en DESC);

-- ── 1.4 Parámetros de valorización ─────────────────────────────────────────
-- Los benchmarks públicos de CPM se contradicen porque cada fuente usa distinta
-- base. Esta tabla obliga a que todo número que entre a un informe tenga fuente
-- citable y fecha: `fuente` es NOT NULL a propósito.
CREATE TABLE public.valorizacion_parametros (
  clave text PRIMARY KEY,
  valor numeric NOT NULL,
  unidad text NOT NULL,
  fuente text NOT NULL,
  vigente_desde date NOT NULL DEFAULT CURRENT_DATE,
  nota text
);

COMMENT ON TABLE public.valorizacion_parametros IS
  'Constantes de valorización (CPM de referencia, coeficientes por formato). `fuente` es NOT NULL deliberadamente: un informe a una marca no puede contener un número sin procedencia.';

-- ============================================================================
-- 2. CAPA DERIVADA — vistas recalculables. Ningún KPI se materializa.
-- ============================================================================

-- ── 2.1 Última foto conocida de cada pieza ─────────────────────────────────
CREATE VIEW public.v_instagram_pieza_ultima
WITH (security_invoker = true) AS
SELECT DISTINCT ON (media_id) *
FROM public.instagram_pieza_snapshots
ORDER BY media_id, corrida_dia DESC;

COMMENT ON VIEW public.v_instagram_pieza_ultima IS
  'La captura más reciente de cada pieza. Es la que debe usar cualquier informe: es el valor más maduro disponible.';

-- ── 2.2 KPIs por pieza ─────────────────────────────────────────────────────
--
-- DENOMINADOR ÚNICO: `alcance` (cuentas únicas alcanzadas) para toda la familia
-- de tasas de engagement. No se mezcla jamás con seguidores ni con
-- visualizaciones. Un solo denominador es lo que hace que las tasas de dos
-- períodos sean comparables entre sí.
--
-- Las dos excepciones están marcadas y usan otro denominador A PROPÓSITO:
--   · ratio_comentario_like — comentarios/me_gusta. Mide qué tan conversacional
--     es la pieza, no cuánta gente reaccionó. Es un ratio, no una tasa.
--   · conversion_visita_seguidor — seguidores/visitas al perfil. Es un embudo.
--
-- NULLIF en cada divisor: sin alcance no hay tasa. Devolver 0 sería afirmar
-- "nadie guardó esta pieza" cuando la verdad es "no sabemos".
CREATE VIEW public.v_instagram_pieza_kpis
WITH (security_invoker = true) AS
SELECT
  p.media_id,
  p.publicada_en,
  p.permalink,
  p.caption,
  p.formato,
  p.tipo,
  p.corrida_dia AS medido_el,
  p.alcance,
  p.visualizaciones,
  p.interacciones,
  p.me_gusta,
  p.comentarios,
  p.guardados,
  p.compartidos,

  -- Familia con denominador ALCANCE ─────────────────────────────────────────
  ROUND(p.interacciones::numeric / NULLIF(p.alcance, 0), 4) AS tasa_interaccion,
  ROUND(p.compartidos::numeric   / NULLIF(p.alcance, 0), 4) AS tasa_envios,
  ROUND(p.guardados::numeric     / NULLIF(p.alcance, 0), 4) AS tasa_guardado,
  ROUND(p.me_gusta::numeric      / NULLIF(p.alcance, 0), 4) AS tasa_me_gusta,
  ROUND(p.comentarios::numeric   / NULLIF(p.alcance, 0), 4) AS tasa_comentarios,

  -- Índice de revisualización — NO es hook rate ─────────────────────────────
  -- vistas/alcance = cuántas veces reprodujo la pieza cada cuenta alcanzada.
  -- El hook rate real (vistas de 3 s / alcance) NO es calculable: Meta no expone
  -- ninguna métrica de reproducción de 3 segundos desde la unificación en
  -- `views`. Nombrar a esto "hook rate" sería renombrar un dato para que calce
  -- con una tarjeta del informe.
  ROUND(p.visualizaciones::numeric / NULLIF(p.alcance, 0), 4) AS indice_revisualizacion,

  -- Excepciones declaradas de denominador ───────────────────────────────────
  ROUND(p.comentarios::numeric / NULLIF(p.me_gusta, 0), 4) AS ratio_comentario_like,
  ROUND(p.seguidores_ganados::numeric / NULLIF(p.visitas_perfil, 0), 4)
    AS conversion_visita_seguidor,

  -- Tiempo absoluto, no porcentaje (Meta no expone duración del video).
  ROUND(p.reel_tiempo_medio_ms::numeric / 1000, 1) AS reel_segundos_promedio,

  p.seguidores_ganados,
  p.visitas_perfil
FROM public.v_instagram_pieza_ultima p;

COMMENT ON VIEW public.v_instagram_pieza_kpis IS
  'KPIs por pieza. Denominador único = alcance para toda la familia de tasas. Excepciones declaradas: ratio_comentario_like (denominador me_gusta) y conversion_visita_seguidor (denominador visitas_perfil).';

COMMENT ON COLUMN public.v_instagram_pieza_kpis.indice_revisualizacion IS
  'visualizaciones/alcance. NO es hook rate: Meta no expone vistas de 3 segundos. Un valor de 1,4 significa que cada cuenta alcanzada reprodujo la pieza 1,4 veces en promedio.';

-- ── 2.3 KPIs diarios de cuenta ─────────────────────────────────────────────
--
-- El CTE `ultima` NO es cosmético: las funciones de ventana se evalúan ANTES
-- que DISTINCT ON, así que calcular la media móvil directamente sobre la tabla
-- la promediaría sobre todas las capturas de cada día —contando dos y tres
-- veces la misma fecha— en vez de sobre un valor por día. Primero se colapsa a
-- la captura más madura de cada fecha, después se calcula la ventana.
CREATE VIEW public.v_instagram_dia_kpis
WITH (security_invoker = true) AS
WITH ultima AS (
  SELECT DISTINCT ON (fecha) *
  FROM public.instagram_dia_snapshots
  ORDER BY fecha, corrida_dia DESC
)
SELECT
  d.fecha,
  d.corrida_dia AS medido_el,
  d.alcance,
  d.visualizaciones,
  d.interacciones,
  d.seguidores_nuevos,
  d.seguidores_totales,

  -- Mismo denominador que a nivel pieza: alcance. Comparables entre sí.
  ROUND(d.interacciones::numeric / NULLIF(d.alcance, 0), 4) AS tasa_interaccion,
  ROUND(d.compartidos::numeric   / NULLIF(d.alcance, 0), 4) AS tasa_envios,
  ROUND(d.guardados::numeric     / NULLIF(d.alcance, 0), 4) AS tasa_guardado,
  ROUND(d.me_gusta::numeric      / NULLIF(d.alcance, 0), 4) AS tasa_me_gusta,

  -- Media móvil de 7 días del alcance: la línea base contra la que se compara
  -- una caída. Se calcula sobre `fecha`, no sobre `corrida_dia`.
  ROUND(AVG(d.alcance) OVER (
    ORDER BY d.fecha ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
  ), 0) AS alcance_media_7d
FROM ultima d
ORDER BY d.fecha DESC;

COMMENT ON VIEW public.v_instagram_dia_kpis IS
  'KPIs diarios de cuenta usando la captura más madura de cada día. alcance_media_7d es la línea base para detectar caídas.';

-- ── 2.4 Salud de la ingesta — insumo de las alertas ────────────────────────
CREATE VIEW public.v_instagram_ingesta_salud
WITH (security_invoker = true) AS
SELECT
  (SELECT max(iniciada_en) FROM public.instagram_ingesta_corridas WHERE estado = 'ok')
    AS ultima_corrida_ok,
  (SELECT count(*) FROM public.instagram_ingesta_corridas
     WHERE iniciada_en > now() - interval '48 hours' AND estado = 'error')
    AS errores_48h,
  (SELECT max(fecha) FROM public.instagram_dia_snapshots)
    AS ultimo_dia_con_datos,
  -- Días transcurridos desde el último dato. Meta publica el día D recién en
  -- D+1, así que 1 es normal y 2 ya es sospechoso.
  (CURRENT_DATE - (SELECT max(fecha) FROM public.instagram_dia_snapshots))
    AS dias_de_atraso;

COMMENT ON VIEW public.v_instagram_ingesta_salud IS
  'Una fila con el estado de la ingesta. dias_de_atraso >= 2 significa quiebre: Meta publica el día D en D+1, un atraso de 1 día es lo normal.';

-- ============================================================================
-- 3. RLS — lectura admin, escritura solo service_role (Ley III)
-- ============================================================================

ALTER TABLE public.instagram_dia_snapshots     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.instagram_pieza_snapshots   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.instagram_ingesta_corridas  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.valorizacion_parametros     ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admin lee snapshots diarios"
  ON public.instagram_dia_snapshots FOR SELECT TO authenticated
  USING (public.fn_is_admin_or_super());

CREATE POLICY "Admin lee snapshots de piezas"
  ON public.instagram_pieza_snapshots FOR SELECT TO authenticated
  USING (public.fn_is_admin_or_super());

CREATE POLICY "Admin lee corridas de ingesta"
  ON public.instagram_ingesta_corridas FOR SELECT TO authenticated
  USING (public.fn_is_admin_or_super());

CREATE POLICY "Admin lee parametros de valorizacion"
  ON public.valorizacion_parametros FOR SELECT TO authenticated
  USING (public.fn_is_admin_or_super());

-- Sin políticas de INSERT/UPDATE/DELETE para `authenticated`: la escritura es
-- exclusiva del cron con service_role, que bypassa RLS deliberadamente.

REVOKE ALL ON public.instagram_dia_snapshots     FROM anon, PUBLIC;
REVOKE ALL ON public.instagram_pieza_snapshots   FROM anon, PUBLIC;
REVOKE ALL ON public.instagram_ingesta_corridas  FROM anon, PUBLIC;
REVOKE ALL ON public.valorizacion_parametros     FROM anon, PUBLIC;

GRANT SELECT ON public.instagram_dia_snapshots     TO authenticated;
GRANT SELECT ON public.instagram_pieza_snapshots   TO authenticated;
GRANT SELECT ON public.instagram_ingesta_corridas  TO authenticated;
GRANT SELECT ON public.valorizacion_parametros     TO authenticated;

GRANT SELECT, INSERT, UPDATE ON public.instagram_dia_snapshots    TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.instagram_pieza_snapshots  TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.instagram_ingesta_corridas TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.valorizacion_parametros    TO service_role;

-- Las vistas heredan la RLS de las tablas base (security_invoker).
REVOKE ALL ON public.v_instagram_pieza_ultima    FROM anon, PUBLIC;
REVOKE ALL ON public.v_instagram_pieza_kpis      FROM anon, PUBLIC;
REVOKE ALL ON public.v_instagram_dia_kpis        FROM anon, PUBLIC;
REVOKE ALL ON public.v_instagram_ingesta_salud   FROM anon, PUBLIC;

GRANT SELECT ON public.v_instagram_pieza_ultima  TO authenticated;
GRANT SELECT ON public.v_instagram_pieza_kpis    TO authenticated;
GRANT SELECT ON public.v_instagram_dia_kpis      TO authenticated;
GRANT SELECT ON public.v_instagram_ingesta_salud TO authenticated;

-- ============================================================================
-- 4. Semilla de parámetros de valorización
-- ============================================================================
--
-- HONESTIDAD SOBRE ESTOS NÚMEROS: el EMV no es una medición, es una convención
-- de la industria publicitaria. El coeficiente por formato pondera que un Reel
-- guardado vale más que una impresión pasiva, pero ningún organismo lo
-- estandariza. Por eso cada fila lleva su fuente y el informe los declara.
-- El CPM sembrado abajo es el punto de partida y DEBE reemplazarse por el CPM
-- real que WSR observe en Meta Ads Manager para su propia audiencia: ese es el
-- único benchmark que una marca no puede discutir, porque es su propio mercado.

INSERT INTO public.valorizacion_parametros (clave, valor, unidad, fuente, nota) VALUES
  ('cpm_referencia_clp', 4500, 'CLP por mil impresiones',
   'Placeholder a reemplazar con el CPM real de Meta Ads Manager para audiencia mujeres 25-44 en Chile.',
   'Hasta que se reemplace, todo informe que lo use debe declararlo como estimación. Medir el CPM real es una tarea de 10 minutos en Ads Manager y convierte el informe de estimado a verificable.'),

  ('coef_formato_reels', 1.30, 'multiplicador',
   'Convención interna WSR: un Reel entrega video completo con sonido, formato que en pauta se cotiza sobre el promedio.',
   'Ajustar solo con evidencia propia; no copiar de benchmarks de agencias que no publican su metodología.'),

  ('coef_formato_publicaciones', 1.00, 'multiplicador',
   'Convención interna WSR: la publicación de feed es la unidad base de comparación.',
   'Base 1.0 por definición. Todos los demás coeficientes se leen contra este.'),

  ('coef_formato_stories', 0.60, 'multiplicador',
   'Convención interna WSR: la Story dura 24 h y es de consumo pasivo, se pondera bajo la publicación.',
   NULL),

  ('coef_interaccion', 0.15, 'multiplicador sobre CPM',
   'Convención interna WSR: prima por interacción sobre el valor de exposición pura.',
   'Refleja que una cuenta que guarda o comparte vale más para la marca que una que solo vio. No confundir con un CPE de mercado.');

-- ============================================================================
-- 5. Backfill inicial
-- ============================================================================
-- No se hace por SQL: los datos vienen de Windsor.ai. Se dispara una vez con
--   POST /api/cron/birthdays?task=instagram-ingesta&dias=90
-- Ver README de operación. El backfill es idempotente y puede repetirse.
