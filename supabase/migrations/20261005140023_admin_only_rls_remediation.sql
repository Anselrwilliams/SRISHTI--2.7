-- SRISHTI 2.7 security remediation for the shared project sdkadflrxjdhxduwvrsz.
-- Removes observed anonymous table access and makes audit logs administrator-only.
-- Existing scoped authenticated staff policies are preserved.

BEGIN;

ALTER TABLE public.participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.volunteers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.arrival_checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public access for participants" ON public.participants;
DROP POLICY IF EXISTS "Public access for volunteers" ON public.volunteers;
DROP POLICY IF EXISTS "Public access for event_staff" ON public.event_staff;
DROP POLICY IF EXISTS "Public access for registrations" ON public.registrations;
DROP POLICY IF EXISTS "Public access for arrival_checkins" ON public.arrival_checkins;
DROP POLICY IF EXISTS "Public access for event_attendance" ON public.event_attendance;
DROP POLICY IF EXISTS "Public admin can delete events" ON public.events;
DROP POLICY IF EXISTS "Public admin can insert events" ON public.events;
DROP POLICY IF EXISTS "Public admin can update events" ON public.events;

REVOKE ALL ON TABLE public.participants FROM anon;
REVOKE ALL ON TABLE public.volunteers FROM anon;
REVOKE ALL ON TABLE public.event_staff FROM anon;
REVOKE ALL ON TABLE public.registrations FROM anon;
REVOKE ALL ON TABLE public.arrival_checkins FROM anon;
REVOKE ALL ON TABLE public.event_attendance FROM anon;
REVOKE ALL ON TABLE public.events FROM anon;
GRANT SELECT ON TABLE public.events TO anon;

-- Security-definer helpers are needed by authenticated RLS policies, never anon.
REVOKE ALL ON FUNCTION public.is_srishti_admin() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_srishti_registration() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_srishti_staff() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_event_staff_for_event(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_srishti_admin() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_srishti_registration() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_srishti_staff() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_event_staff_for_event(uuid) TO authenticated, service_role;

-- The public site uses the server-side web-register function; code generation
-- must not be callable as an anonymous RPC or used to consume sequence values.
REVOKE ALL ON FUNCTION public.fn_generate_participant_code() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_generate_participant_code() TO service_role;
ALTER FUNCTION public.fn_generate_participant_code() SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.fn_create_spot_registration(
  uuid, uuid, text, text, text, text, text, text, jsonb, text, numeric, text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_create_spot_registration(
  uuid, uuid, text, text, text, text, text, text, jsonb, text, numeric, text
) TO service_role;

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action text NOT NULL,
  status text NOT NULL DEFAULT 'SUCCESS',
  user_email text,
  participant_code text,
  participant_name text,
  client_ip text,
  city text,
  region text,
  country text,
  isp text,
  latitude double precision,
  longitude double precision,
  accuracy_meters double precision,
  location_source text DEFAULT 'ip_network',
  maps_url text,
  user_agent text,
  device_info jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_email ON public.audit_logs(user_email);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_client_ip ON public.audit_logs(client_ip);
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow anon and auth insert on audit_logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Allow staff and admin to read audit_logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Public can read audit logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Admins can read audit logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Admins can delete audit logs" ON public.audit_logs;
CREATE POLICY "Admins can read audit logs" ON public.audit_logs
  FOR SELECT TO authenticated USING (public.is_srishti_admin());
CREATE POLICY "Admins can delete audit logs" ON public.audit_logs
  FOR DELETE TO authenticated USING (public.is_srishti_admin());
REVOKE ALL ON TABLE public.audit_logs FROM PUBLIC, anon, authenticated;
GRANT SELECT, DELETE ON TABLE public.audit_logs TO authenticated;
GRANT ALL ON TABLE public.audit_logs TO service_role;

COMMIT;
