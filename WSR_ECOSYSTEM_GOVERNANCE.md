# WSR — Constitución Técnica del Ecosistema

> Este documento es la **ÚNICA FUENTE DE VERDAD arquitectónica** de Woman Social Run.
> Vincula a los tres repositorios del ecosistema:
> - `wsr-backend/` — el Cerebro Único (Supabase: esquema, funciones, contrato de tipos)
> - `Web/womansocialrun-main/` — cliente Vite/React
> - `App/wsr-app/` — cliente Expo/React Native
>
> Vigente desde 2026-07-02, tras la inyección del SSOT (`@wsr/contracts`) y la
> restauración de la frontera RLS (migración `043_restore_missing_rpcs.sql`).
> Cualquier cambio a estas leyes requiere actualizar este archivo en el mismo
> commit que lo motiva — nunca por fuera de él.

## Ley I — El Cerebro Único

`wsr-backend` es el único dueño legítimo de:
- **Edge Functions** (`supabase/functions/`)
- **Migraciones SQL** (`supabase/migrations/`, numeradas `NNN_snake_case.sql`, append-only)
- **Tipos generados** (`contracts/database.types.ts`, vía `supabase gen types typescript --linked`)

**La Web y la App tienen PROHIBIDO alojar carpetas `supabase/functions/` propias.**
Si un cliente necesita lógica server-side, esa lógica se crea en `wsr-backend` y se
despliega desde ahí. Ningún cliente despliega funciones a Supabase directamente.

## Ley II — El Contrato Compartido

Los clientes (Web y App) **solo pueden consumir el tipado exportado por `@wsr/contracts`**
(`Tables<>`, `TablesInsert<>`, `TablesUpdate<>`, `Enums<>`, `Database`).

- **Cero tipos generados localmente.** Ningún cliente ejecuta su propio `supabase gen types`.
- **Cero tipos de dominio escritos a mano** que dupliquen filas o enums de la base de datos.
  Capas semánticas de UI (view-models, tipos de Realtime efímeros que nunca tocan
  PostgreSQL) sí pueden vivir en el cliente, pero SIEMPRE derivadas de `Tables<>`/`Enums<>`,
  nunca redeclaradas desde cero.
- Regenerar el contrato: `cd wsr-backend && npx --yes supabase gen types typescript --linked > contracts/database.types.ts`
  (el script `npm run gen:types` asume `supabase` en el PATH del sistema, lo cual no
  está garantizado — usar siempre `npx --yes supabase` si el script falla).

## Ley III — La Frontera Clínica (Zero-Trust)

**La App y la Web NUNCA deben realizar mutaciones directas (`INSERT`/`UPDATE`/`DELETE`)
sobre tablas protegidas por RLS que no otorgan escritura al rol del cliente.**

- Antes de escribir un `.from('tabla').insert(...)` o `.update(...)` desde un cliente,
  verificar las políticas RLS de esa tabla. Si la política del rol de la usuaria es
  `FOR SELECT` únicamente (patrón común en tablas clínicas/sensibles: `session_results`,
  `training_sessions`, `checkins`, `health_alerts`, datos de ciclo/salud), el cliente
  **no tiene autoridad para escribir ahí**, sin importar que TypeScript compile.
- Toda modificación clínica o de negocio sensible se encapsula en una función RPC
  `SECURITY DEFINER` dentro de `wsr-backend`, que:
  1. Verifica explícitamente la propiedad/pertenencia del recurso (ej. `p_runner_id = fn_runner_id_for_user()`).
  2. Ejecuta la mutación con privilegios elevados, deliberadamente y de forma auditable.
  3. Se declara con `SET search_path TO 'public'` para evitar hijacking de search_path.
- Las funciones de **solo lectura** NO requieren `SECURITY DEFINER` si las políticas
  RLS existentes ya autorizan el acceso — usar derechos de invocador ahí es más seguro
  (RLS hace el trabajo; no hay que reimplementar autorización a mano).
- Un error de compilador (`tsc`) por un RPC faltante **nunca** se resuelve reemplazando
  la llamada por una mutación directa de cliente. Se resuelve restaurando el RPC en
  `wsr-backend/supabase/migrations/`.

## Cómo verificar cumplimiento

```bash
# ¿Algún cliente tiene su propia carpeta de Edge Functions activa? (viola Ley I)
find Web App -type d -name functions -path "*/supabase/*" ! -path "*_archived*"

# ¿Algún cliente define tipos de dominio sin derivarlos del contrato? (viola Ley II)
grep -rn "from '@wsr/contracts'" Web/*/src App/*/[a-z]*  # deben ser los únicos imports de tipos DB

# ¿Algún cliente muta tablas RLS-restringidas directamente? (viola Ley III)
# — requiere revisión manual: cruzar cada .from('tabla').insert/update/delete
#   contra las políticas RLS de esa tabla en wsr-backend/supabase/migrations/
```
