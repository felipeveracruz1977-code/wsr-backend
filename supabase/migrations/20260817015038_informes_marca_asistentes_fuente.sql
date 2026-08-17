-- 088 — Fuente declarada para el conteo de asistentes en informes de marca
--
-- Motivo (2026-08-17): "Asistentes atribuidos" en el Informe de Marca es un
-- número que la encargada escribe a mano (ver `asistentes` en
-- informes_marca_generados, 087), sin ningún campo que diga cómo se contó
-- -¿asistentes únicas registradas en el sistema? ¿conteo manual en la
-- puerta? ¿acumulado de check-ins?-. Auditoría interna del informe detectó
-- que esa cifra no tiene metodología declarada en ninguna parte, lo que la
-- hace indefendible si una marca pregunta de dónde sale.
--
-- Mismo criterio que `fuente` en valorizacion_parametros (085) y el campo
-- `fuente` dentro de `historias` (jsonb, 087): un dato transcrito a mano no
-- entra al informe sin declarar cómo se obtuvo.

alter table public.informes_marca_generados
  add column asistentes_fuente text;

comment on column public.informes_marca_generados.asistentes_fuente is
  'Cómo se obtuvo el número de asistentes (ej. "Conteo manual en la puerta", "Check-ins registrados en el sistema"). Nullable a propósito: si está vacío, el informe debe avisar que falta declarar la fuente, no ocultarlo.';
