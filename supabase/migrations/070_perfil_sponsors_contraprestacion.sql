-- 070 — Consentimiento específico para datos de perfil como contraprestación
--
-- Decisión de negocio (12-jul-2026): estado_civil, tiene_hijos, nivel_educativo
-- y ocupacion vuelven a ser obligatorios para inscribirse, porque alimentan las
-- campañas de marketing con las marcas auspiciadoras que permiten que WSR sea
-- gratuito. Esto solo es sostenible bajo la excepción del art. 12, inciso
-- final, de la Ley 21.719:
--
--   "Con todo, lo dispuesto en el inciso anterior no se aplicará cuando quien
--   ofrezca bienes, servicios o beneficios, requiera como única
--   contraprestación el consentimiento para tratar datos."
--
-- Es decir: el acceso gratuito a WSR puede condicionarse a este consentimiento
-- SOLO SI se declara explícita y específicamente como la contraprestación del
-- servicio -- no puede quedar bundleado dentro del consentimiento general de
-- "gestionar mi participación" (autoriza_datos) ni disfrazado de opcional como
-- antes. Por eso es un campo propio, no una reutilización de acepta_marketing
-- (que sigue cubriendo los datos que SÍ siguen siendo opcionales: hobbies,
-- productos de interés, redes sociales, etc.).

alter table public.runners
  add column if not exists autoriza_perfil_sponsors boolean not null default false;

comment on column public.runners.autoriza_perfil_sponsors is
  'Consentimiento OBLIGATORIO y específico (Ley 21.719 art. 12, inciso final -- contraprestación) para usar y compartir con marcas auspiciadoras el estado civil, hijos, nivel educativo y ocupación, condición declarada del acceso gratuito a WSR. Distinto de acepta_marketing (datos que siguen siendo opcionales).';
