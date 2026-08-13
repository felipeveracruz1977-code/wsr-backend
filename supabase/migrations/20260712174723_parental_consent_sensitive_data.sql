-- 069 — Consentimiento parental para datos sensibles de adolescentes 14-15 años
--
-- Ley 21.719, art. 16 quáter: "Los datos personales sensibles de los
-- adolescentes menores de dieciséis años sólo se podrán tratar con el
-- consentimiento otorgado por sus padres o representantes legales o quien
-- tiene a su cargo el cuidado personal del menor, salvo que expresamente lo
-- autorice o mandate la ley."
--
-- El gate de edad de la migración anterior (inscripción, ver Inscripcion.tsx)
-- solo bloquea menores de 14 años en el registro base (datos NO sensibles).
-- Una corredora de 14-15 años puede registrarse válidamente, pero sus datos
-- de salud (anamnesis, check-in) requieren este consentimiento adicional
-- ANTES de poder tratarse — hoy nada lo verificaba.

alter table public.runners
  add column if not exists parental_consent_sensitive_data boolean not null default false,
  add column if not exists parental_consent_confirmed_by   text,
  add column if not exists parental_consent_confirmed_at    timestamptz;

comment on column public.runners.parental_consent_sensitive_data is
  'Ley 21.719 art. 16 quáter: true si se acreditó consentimiento de madre/padre/tutor para tratar datos sensibles (anamnesis, check-in) de esta corredora, requerido cuando su edad es < 16 años.';
comment on column public.runners.parental_consent_confirmed_by is
  'Correo del staff que confirmó haber verificado y documentado el consentimiento parental (auditoría).';
comment on column public.runners.parental_consent_confirmed_at is
  'Momento en que se confirmó el consentimiento parental.';
