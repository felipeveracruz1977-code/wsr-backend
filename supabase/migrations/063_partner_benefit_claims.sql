-- Crea partner_benefit_claims: registra solicitudes de beneficios de partners
-- que no están atados a una carrera (ej. "you-just-better"), usadas por
-- Web/api/claim-race-code.ts. La tabla nunca se creó junto con ese código,
-- por lo que cada solicitud fallaba silenciosamente (insertError -> 500)
-- desde que se lanzó el lead magnet de YOU just better.

CREATE TABLE public.partner_benefit_claims (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  runner_id uuid NOT NULL REFERENCES public.runners(id) ON DELETE CASCADE,
  partner_slug text NOT NULL,
  claimed_at timestamp with time zone DEFAULT now() NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT partner_benefit_claims_runner_partner_uniq UNIQUE (runner_id, partner_slug)
);

ALTER TABLE public.partner_benefit_claims ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_partner_benefit_claims_updated_at
  BEFORE UPDATE ON public.partner_benefit_claims
  FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- Mismo patrón que event_winners_admin_all: solo admin/super leen y escriben
-- vía RLS. Los inserts desde api/claim-race-code.ts usan SUPABASE_SERVICE_ROLE_KEY
-- y por lo tanto bypasean RLS (Ley III: mutación server-side, no cliente directo).
CREATE POLICY partner_benefit_claims_admin_all ON public.partner_benefit_claims
  TO authenticated
  USING (public.fn_is_admin_or_super())
  WITH CHECK (public.fn_is_admin_or_super());

COMMENT ON TABLE public.partner_benefit_claims IS 'Solicitudes de beneficios de partners no asociados a una carrera (ej. YOU just better). Insertadas por Web/api/claim-race-code.ts vía service_role.';
