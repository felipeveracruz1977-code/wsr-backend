-- 052_revoke_anon_community_views.sql
-- Auditoría de seguridad 2026-07-05 — Hallazgo P1-2:
-- Vistas SECURITY DEFINER concedidas al rol `anon` saltan RLS y exponían
-- datos de perfil comunitario (nombre real, ciudad, bio, fotos, ranking)
-- al internet anónimo sin opt-in.
--
-- Este REVOKE cierra la puerta: las vistas comunitarias quedan accesibles
-- EXCLUSIVAMENTE para el rol `authenticated` (y service_role/postgres).
--
-- EXCEPCIÓN DELIBERADA — `trainings_web` NO se revoca:
--   * La consume el calendario público de la Web sin sesión
--     (Web/womansocialrun-main/src/components/training/TrainingCalendar.tsx).
--   * Solo expone datos de eventos (título, fecha, ubicación, cupos) — cero PII.
--   Revocar anon ahí rompería la página pública de Entrenamientos.

-- Perfiles comunitarios: nombre real, ciudad, bio, fotos, rachas.
revoke select on public.public_profiles from anon;

-- Ranking de lealtad: nombre real + puntos + posición.
revoke select on public.loyalty_leaderboard from anon;

-- Progreso de tier por usuaria.
revoke select on public.user_tier_progress from anon;

-- Feed de actividad: nombre y avatar de la actora.
revoke select on public.feed_activities from anon;

-- Conteos de inscripción por entrenamiento (la consume solo la App autenticada).
revoke select on public.training_with_counts from anon;

-- vw_social_feed ya no tenía grant para anon (verificado 2026-07-05);
-- se revoca igualmente por idempotencia y para dejar constancia explícita.
revoke select on public.vw_social_feed from anon;

-- Garantizar que el rol authenticated conserva el acceso que la App requiere.
grant select on public.public_profiles      to authenticated;
grant select on public.loyalty_leaderboard  to authenticated;
grant select on public.user_tier_progress   to authenticated;
grant select on public.feed_activities      to authenticated;
grant select on public.training_with_counts to authenticated;
grant select on public.vw_social_feed       to authenticated;
