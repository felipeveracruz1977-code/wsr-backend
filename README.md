# wsr-backend — Cerebro Canónico del Backend WSR

**Creado:** 2026-07-02 · FASE 1 del plan de refactorización (ver `../WSR_ARCHITECTURE_AUDIT_AND_REFACTOR.md`)
**Cluster canónico:** `thirekzbfbwchstvcqxw` (https://thirekzbfbwchstvcqxw.supabase.co)

Este repositorio es el **único dueño** de las Edge Functions (y, tras `supabase db pull`, de las migraciones) del ecosistema WSR. Las carpetas `supabase/functions/` de los repos Web y App fueron archivadas (`_archived_functions_DO_NOT_DEPLOY/`) — el CLI de Supabase ya no las reconoce y no pueden desplegarse por accidente. **Ningún archivo fue borrado.**

## Estructura

```
supabase/
├── functions/                     ← ÚNICA fuente desplegable (11 funciones)
│   ├── adherence-engine/          ← v2.0 "Behavioral" (origen: repo WEB — implementación canónica)
│   ├── confirmar-inscripcion/     ← origen: repo WEB
│   ├── enviar-bienvenida/         ← origen: repo WEB
│   ├── ai-companion/              ← origen: repo APP
│   ├── delete-account/            ← origen: repo APP
│   ├── dynamic-responder/         ← origen: repo APP
│   ├── emotional-reactivation/    ← origen: repo APP
│   ├── post-training-survey/      ← origen: repo APP
│   ├── push-message-notify/       ← origen: repo APP
│   ├── send-push-notification/    ← origen: repo APP
│   └── send-training-reminder/    ← origen: repo APP
└── _archive/
    └── adherence-engine_app_legacy/  ← variante DESCARTADA del repo APP (modelo 2 semanas).
                                        Preservada por el principio Zero-Loss. NO desplegar.
```

## Reglas

1. **Todo deploy de Edge Functions sale de aquí** (`supabase functions deploy <nombre>`). Nunca desde los repos cliente.
2. La implementación canónica de `adherence-engine` es la **v2.0 Behavioral** (ventana 28 días, auth `x-cron-secret`). La variante del repo APP quedó en `_archive/` solo como registro histórico.
3. Próximo paso (pendiente): `supabase link` + `supabase db pull` para capturar el baseline real del esquema (comandos en el Reporte de Extracción Segura).
