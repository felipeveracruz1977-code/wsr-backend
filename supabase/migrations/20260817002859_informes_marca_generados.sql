-- 087 — Persistencia de informes de marca generados
--
-- Motivo (2026-08-16): el Informe de Marca (Web, InformeMarcaTab.tsx) es 100%
-- efímero — vive en useState y se pierde al cambiar de pestaña o cerrar el
-- navegador. La encargada pidió poder guardar un informe y reabrirlo después
-- con las métricas actualizadas, sin tener que reingresar toda la ficha cada
-- vez. Este es exactamente el hueco que ya anticipó el comentario de soft-delete
-- en `marcas_patrocinadoras` (086): "esos informes no se persisten, pero si
-- alguna vez se guardan, no queremos una FK rota" — ese momento es este.
--
-- DECISIÓN DE FONDO: esta tabla guarda los INSUMOS del informe (ficha, marcas
-- seleccionadas, piezas colaborativas manuales, totales de Historias con su
-- fuente declarada, comentarios editados, narrativa), NUNCA los números
-- calculados (alcance, EMV, tasas, CPM). Mismo principio que la capa derivada
-- del Observatorio (085): "vistas recalculables, ningún KPI se materializa".
-- Al reabrir un informe guardado, la Web vuelve a consultar
-- v_instagram_pieza_kpis / v_instagram_dia_kpis / valorizacion_parametros y
-- recalcula en el momento — así el informe "se actualiza de acuerdo a las
-- nuevas métricas" automáticamente, sin necesitar ningún mecanismo de
-- sincronización aparte. Confirmado con el usuario: quiere la versión siempre
-- viva, no una copia congelada de lo que se envió en su momento.
--
-- `marca_ids` es un array de uuid sin FK formal (Postgres no soporta FK sobre
-- elementos de array). No es un descuido: `marcas_patrocinadoras` ya resuelve
-- la integridad por el lado contrario con soft-delete (`activa = false`, nunca
-- DELETE), así que un id guardado acá nunca queda huérfano.
--
-- Ley III: esta es data administrada directamente por el admin desde el
-- cliente (no un cron ni lógica clínica sensible), así que
-- SELECT/INSERT/UPDATE/DELETE van a `authenticated` con la misma condición
-- fn_is_admin_or_super() que ya gatea el resto del panel B2B — no hace falta
-- una función RPC SECURITY DEFINER porque no hay más lógica de negocio que
-- verificar que "es admin", que es exactamente lo que RLS con derechos de
-- invocador ya resuelve (mismo razonamiento que 086).
--
-- A diferencia de `marcas_patrocinadoras`, SÍ se otorga DELETE: estos son
-- borradores de trabajo propios del admin, no un roster referenciado por otra
-- tabla — borrar uno no deja nada huérfano.

create table public.informes_marca_generados (
  id uuid primary key default gen_random_uuid(),
  creado_por uuid not null references auth.users(id) default auth.uid(),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),

  tipo_informe text not null default 'evento'
    check (tipo_informe in ('evento', 'trimestral')),
  nombre text not null default '',
  lugar text not null default '',
  desde date not null,
  hasta date not null,
  inversion_clp numeric not null default 0,
  asistentes integer,
  costo_produccion_clp numeric,
  solo_marca boolean not null default true,

  -- Referencias a marcas_patrocinadoras(id) — ver nota sobre FK de array arriba.
  marca_ids uuid[] not null default '{}',

  -- Snapshot del borrador de "piezas colaborativas" (mismo shape que
  -- PiezaManualInput en la Web) al momento de guardar.
  piezas_manuales jsonb not null default '[]'::jsonb,

  -- { totales, visualizaciones, interacciones, porMarca, fuente }. `fuente`
  -- es el campo nuevo que declara cómo se obtuvo el dato (ej. "revisado a
  -- mano en Instagram Insights, 15-08-2026") — sin este dato no hay forma de
  -- defenderlo ante una marca, mismo criterio que `fuente` en
  -- valorizacion_parametros (085).
  historias jsonb not null default '{}'::jsonb,

  comentarios text not null default '',
  narrativa jsonb,

  constraint informes_marca_generados_rango_check check (desde <= hasta)
);

comment on table public.informes_marca_generados is
  'Borradores guardados del Informe de Marca (Web, InformeMarcaTab.tsx). Guarda los insumos del informe, nunca los números calculados: al reabrir, la Web recalcula en vivo contra el Observatorio de Instagram vigente en ese momento.';

comment on column public.informes_marca_generados.historias is
  'Totales de Historias cargados a mano: { totales, visualizaciones, interacciones, porMarca, fuente }. `fuente` declara cómo se obtuvo el dato — obligatorio para poder defenderlo ante la marca.';

comment on column public.informes_marca_generados.marca_ids is
  'IDs de marcas_patrocinadoras seleccionadas para este informe. Sin FK formal (no soportado sobre arrays); marcas_patrocinadoras usa soft-delete específicamente para que estos ids nunca queden huérfanos.';

create index informes_marca_generados_creado_por_idx
  on public.informes_marca_generados (creado_por);

create index informes_marca_generados_desde_idx
  on public.informes_marca_generados (desde desc);

create trigger informes_marca_generados_actualizado_en
  before update on public.informes_marca_generados
  for each row execute function public.fn_set_actualizado_en();

alter table public.informes_marca_generados enable row level security;

create policy "Admin lee informes de marca guardados"
  on public.informes_marca_generados for select to authenticated
  using (public.fn_is_admin_or_super());

create policy "Admin crea informes de marca guardados"
  on public.informes_marca_generados for insert to authenticated
  with check (public.fn_is_admin_or_super());

create policy "Admin edita informes de marca guardados"
  on public.informes_marca_generados for update to authenticated
  using (public.fn_is_admin_or_super())
  with check (public.fn_is_admin_or_super());

create policy "Admin elimina informes de marca guardados"
  on public.informes_marca_generados for delete to authenticated
  using (public.fn_is_admin_or_super());

revoke all on public.informes_marca_generados from anon, public;
grant select, insert, update, delete on public.informes_marca_generados to authenticated;
grant all on public.informes_marca_generados to service_role;
