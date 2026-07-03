-- 047_executive_dashboard_rpcs.sql
-- Executive Dashboard (admin "Dirección" tab) aggregation RPCs.
--
-- Ley III (WSR_ECOSYSTEM_GOVERNANCE.md): admin/super_admin already have full
-- RLS read access to runners/plan_check_ins/health_alerts via the
-- *_admin_all policies (USING (fn_is_admin_or_super())). These are read-only
-- aggregates, so per governance they use INVOKER rights (no SECURITY
-- DEFINER) — RLS does the authorization work; a non-admin caller simply gets
-- results scoped to whatever RLS already lets them see (their own row),
-- never someone else's data.
--
-- Replaces client-side computation in DireccionTab.tsx that previously
-- fetched every runner's name/email and every check-in's clinical fields
-- (pain, sleep_quality, energy, comments) to the browser just to derive a
-- handful of aggregate numbers.

CREATE OR REPLACE FUNCTION public.fn_dashboard_kpis()
RETURNS TABLE (
  active_runners integer,
  adherencia_promedio numeric,
  total_checkins integer,
  alerts_amarilla integer,
  alerts_naranja integer,
  alerts_roja integer
)
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $$
  SELECT
    (SELECT count(*)::integer
       FROM public.runners r
       WHERE r.status IN ('activa', 'miembro', 'miembro_oficial')),
    (SELECT avg(pci.compliance_pct)
       FROM public.plan_check_ins pci
       WHERE pci.created_at >= now() - interval '28 days'),
    (SELECT count(*)::integer
       FROM public.plan_check_ins pci
       WHERE pci.created_at >= now() - interval '28 days'),
    (SELECT count(*)::integer
       FROM public.health_alerts ha
       WHERE ha.status = 'pendiente' AND ha.severity = 'amarilla'),
    (SELECT count(*)::integer
       FROM public.health_alerts ha
       WHERE ha.status = 'pendiente' AND ha.severity = 'naranja'),
    (SELECT count(*)::integer
       FROM public.health_alerts ha
       WHERE ha.status = 'pendiente' AND ha.severity = 'roja');
$$;

COMMENT ON FUNCTION public.fn_dashboard_kpis() IS
  'Executive dashboard KPI strip: active runners, 28-day adherence average, and pending health_alerts by severity. Invoker rights — relies on *_admin_all RLS policies.';

GRANT EXECUTE ON FUNCTION public.fn_dashboard_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_dashboard_risk_scores()
RETURNS TABLE (
  runner_id uuid,
  nombre_apellido text,
  email text,
  score integer,
  level text,
  days_since_checkin numeric,
  avg_compliance numeric,
  avg_motivation numeric,
  pending_alerts jsonb
)
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $$
  WITH active_runners AS (
    SELECT r.id, r.nombre_apellido, r.email
    FROM public.runners r
    WHERE r.status IN ('activa', 'miembro', 'miembro_oficial')
  ),
  recent_checkins AS (
    SELECT
      pci.id,
      pci.runner_id,
      pci.created_at,
      pci.compliance_pct,
      pci.motivation,
      ROW_NUMBER() OVER (PARTITION BY pci.runner_id ORDER BY pci.created_at DESC) AS rn
    FROM public.plan_check_ins pci
    WHERE pci.created_at >= now() - interval '28 days'
  ),
  last_checkin AS (
    SELECT runner_id, created_at
    FROM recent_checkins
    WHERE rn = 1
  ),
  compliance_agg AS (
    SELECT
      runner_id,
      avg(compliance_pct) AS avg_compliance,
      avg(motivation) AS avg_motivation
    FROM recent_checkins
    WHERE rn <= 4
    GROUP BY runner_id
  ),
  alerts_agg AS (
    SELECT
      rc.runner_id,
      count(*) FILTER (WHERE ha.severity = 'roja') AS rojas,
      count(*) FILTER (WHERE ha.severity = 'naranja') AS naranjas,
      jsonb_agg(
        jsonb_build_object('id', ha.id, 'severity', ha.severity, 'status', ha.status, 'reason', ha.reason)
        ORDER BY ha.created_at DESC
      ) AS alerts_json
    FROM recent_checkins rc
    JOIN public.health_alerts ha ON ha.check_in_id = rc.id AND ha.status = 'pendiente'
    GROUP BY rc.runner_id
  ),
  scored AS (
    SELECT
      ar.id AS runner_id,
      ar.nombre_apellido,
      ar.email,
      lc.created_at AS last_checkin_at,
      ca.avg_compliance,
      ca.avg_motivation,
      COALESCE(aa.rojas, 0) AS rojas,
      COALESCE(aa.naranjas, 0) AS naranjas,
      COALESCE(aa.alerts_json, '[]'::jsonb) AS pending_alerts,
      (
        CASE
          WHEN lc.created_at IS NULL THEN 60
          WHEN EXTRACT(EPOCH FROM (now() - lc.created_at)) / 86400.0 > 21 THEN 50
          WHEN EXTRACT(EPOCH FROM (now() - lc.created_at)) / 86400.0 > 14 THEN 35
          WHEN EXTRACT(EPOCH FROM (now() - lc.created_at)) / 86400.0 > 7 THEN 20
          ELSE 0
        END
        + CASE
            WHEN ca.avg_compliance IS NULL THEN 0
            WHEN ca.avg_compliance < 30 THEN 25
            WHEN ca.avg_compliance < 50 THEN 15
            ELSE 0
          END
        + CASE
            WHEN ca.avg_motivation IS NULL THEN 0
            WHEN ca.avg_motivation < 4 THEN 20
            WHEN ca.avg_motivation < 6 THEN 10
            ELSE 0
          END
        + COALESCE(aa.rojas, 0) * 20
        + COALESCE(aa.naranjas, 0) * 10
      ) AS raw_score
    FROM active_runners ar
    LEFT JOIN last_checkin lc ON lc.runner_id = ar.id
    LEFT JOIN compliance_agg ca ON ca.runner_id = ar.id
    LEFT JOIN alerts_agg aa ON aa.runner_id = ar.id
  )
  SELECT
    s.runner_id,
    s.nombre_apellido,
    s.email,
    LEAST(s.raw_score, 100)::integer AS score,
    CASE
      WHEN LEAST(s.raw_score, 100) <= 25 THEN 'bajo'
      WHEN LEAST(s.raw_score, 100) <= 50 THEN 'moderado'
      WHEN LEAST(s.raw_score, 100) <= 75 THEN 'alto'
      ELSE 'critico'
    END AS level,
    CASE
      WHEN s.last_checkin_at IS NULL THEN NULL
      ELSE EXTRACT(EPOCH FROM (now() - s.last_checkin_at)) / 86400.0
    END AS days_since_checkin,
    s.avg_compliance,
    s.avg_motivation,
    s.pending_alerts
  FROM scored s
  ORDER BY LEAST(s.raw_score, 100) DESC;
$$;

COMMENT ON FUNCTION public.fn_dashboard_risk_scores() IS
  'Executive dashboard abandonment-risk table: one row per active runner with pre-computed score/level (mirrors the former client-side computeRiskScore). Invoker rights — relies on *_admin_all RLS policies.';

GRANT EXECUTE ON FUNCTION public.fn_dashboard_risk_scores() TO authenticated;
