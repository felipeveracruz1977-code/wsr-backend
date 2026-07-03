# Ley 21.719 — Mapa de Cumplimiento (Protección de Datos Personales, Chile)

> **Nota de procedencia:** este documento no existía como archivo en el repositorio
> (verificado por búsqueda exhaustiva el 2026-07-02). Fue **reconstruido** a partir de
> evidencia real y verificable: el commit `b8c704b` (`Web/womansocialrun-main`,
> 24-jun-2026), el código fuente actual, y las migraciones SQL de `wsr-backend`. No
> contiene interpretación legal más allá de lo que el propio código ya declara
> (comentarios con referencias a artículos). No sustituye asesoría legal formal —
> es un mapa técnico de trazabilidad entre requisitos y su implementación.

## Prioridades

### R-01 — Consentimiento diferenciado para Datos Sensibles (Nivel 2) y Ciclo Vital Femenino

**Estado: Implementado.**

Fuente: [`Web/womansocialrun-main/src/pages/Anamnesis.tsx:1916-1969`](../../Web/womansocialrun-main/src/pages/Anamnesis.tsx)

El formulario de Anamnesis reemplazó el checkbox único original por 3 consentimientos
independientes, cada uno con validación Zod obligatoria (`.refine(v => v === true)`)
y timestamp propio persistido en la tabla `anamnesis`:

| Checkbox (schema field) | Artículo citado en código | Columna DB | Cubre |
|---|---|---|---|
| `consent_health` | Art. 2.g | `consent_health_at` | Condiciones médicas, historial de lesiones, ciclo vital femenino, factores cardiovasculares |
| `consent_ai` | Art. 8 bis | `consent_ai_at` | Tratamiento automatizado de red flags (ver R-02) |
| `consent_retention` | Art. 4 | `consent_retention_at` | Plazo de conservación (membresía activa + 2 años) |

Las tres columnas (`consent_health_at`, `consent_ai_at`, `consent_retention_at`,
tipo `timestamptz | null`) son parte del contrato canónico
(`wsr-backend/contracts/database.types.ts`, tabla `anamnesis`) y se consumen en el
cliente vía `TablesInsert<'anamnesis'>` de `@wsr/contracts` — sin tipos locales
duplicados (ver `WSR_ECOSYSTEM_GOVERNANCE.md`, Ley II).

### R-02 — Consentimiento diferenciado para Tratamiento Automatizado / IA (Red Flags)

**Estado: Implementado.**

Fuente: [`Web/womansocialrun-main/src/pages/Anamnesis.tsx:1940-1953`](../../Web/womansocialrun-main/src/pages/Anamnesis.tsx)

El checkbox `consent_ai` cubre el motor de `red_flags` que corre en el cliente al
enviar el formulario (`embarazo`, `restriccion_medica`, `dolor_agudo` ≥ 7/10 —
ver `onSubmit` en `Anamnesis.tsx`). El copy declara explícitamente que la coach
humana revisa y decide (`"Mi coach siempre revisa y tiene la última palabra; ninguna
decisión sobre mi entrenamiento es totalmente automatizada"`), lo cual es el
elemento sustantivo que exige el artículo citado (Art. 8 bis) frente a decisiones
automatizadas: intervención humana significativa.

### G-08 — Consentimiento granular en formulario de Inscripción (fuera del alcance de Anamnesis)

**Estado: Implementado** (commit `b8c704b`, `Inscripcion.tsx`).

Separa el consentimiento obligatorio de participación en la comunidad
(`autoriza_comunidad`) del consentimiento opcional de marketing/sponsors
(`autoriza_marketing`) — antes fusionados en un único `autoriza_datos`. Evita
condicionar el ingreso a la comunidad a la aceptación de marketing.

## Frontera clínica y derecho al olvido (evidencia adicional, Ley III de la gobernanza)

Verificado en `wsr-backend/supabase/migrations/20260702135944_remote_schema.sql`:

- **RLS de `anamnesis`:** `anamnesis_public_submit` permite solo `INSERT` a
  `anon`/`authenticated` (línea 2518); `anamnesis_runner_own` permite `SELECT` únicamente
  de la fila propia vía `runner_id = fn_runner_id_for_user()` (línea 2519); `anamnesis_admin_all`
  reserva `UPDATE`/`DELETE` a `fn_is_admin_or_super()` (línea 2517). Un cliente no-admin
  no tiene autoridad de escritura fuera del `INSERT` inicial — consistente con la
  Ley III de `WSR_ECOSYSTEM_GOVERNANCE.md`.
- **Derecho al olvido:** función `fn_forget_runner(p_runner_id, p_reason)`
  (línea 626), `SECURITY DEFINER`, guardada por `fn_is_admin_or_super()`, con
  comentario explícito: *"Derecho al Olvido (Art. 4 Ley 21.719): borra atómicamente
  todos los datos personales de una titular"* (línea 690).

## Gap detectado (no corregido en esta sesión — requiere decisión legal, no técnica)

`Web/womansocialrun-main/src/pages/Privacidad.tsx:49-50` — la página pública
`/privacidad` declara actualmente:

> *"Somos responsables del tratamiento de tus datos personales de acuerdo con la
> Ley N° 19.628 sobre Protección de la Vida Privada (Chile)."*

Esto cita la ley **anterior** (19.628), mientras que el mecanismo de consentimiento
que ella describe implícitamente (Anamnesis, Inscripción) ya está construido citando
artículos de la **Ley 21.719** en el código. Este documento no resuelve esa
discrepancia — actualizar el texto legal público de una política de privacidad es
una decisión que corresponde al DPO/equipo legal humano, no a una refactorización
de código. Se deja consignado aquí para que no se pierda.

## Cómo se actualiza este documento

Cualquier cambio a los mecanismos de consentimiento, retención o derecho al olvido
descritos arriba debe actualizar este archivo en el mismo commit que lo motiva —
mismo principio que `WSR_ECOSYSTEM_GOVERNANCE.md`.
