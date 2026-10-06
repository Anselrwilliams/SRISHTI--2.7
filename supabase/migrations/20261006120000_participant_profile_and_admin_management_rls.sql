-- ==============================================================================
-- SRISHTI 2.7 Migration: Participant Profile Self-Service & Admin Management RLS
-- Target Project: sdkadflrxjdhxduwvrsz
-- ==============================================================================

BEGIN;

-- 1. Admin Full Management on participants
DROP POLICY IF EXISTS "Admin can manage participants" ON public.participants;
CREATE POLICY "Admin can manage participants" ON public.participants
  FOR ALL TO authenticated
  USING (public.is_srishti_admin())
  WITH CHECK (public.is_srishti_admin());

-- 2. Participant Self-Service Profile Access
DROP POLICY IF EXISTS "Participants can view own profile" ON public.participants;
CREATE POLICY "Participants can view own profile" ON public.participants
  FOR SELECT TO authenticated
  USING (
    (LOWER(email) = LOWER(auth.jwt() ->> 'email'))
    OR (email = (auth.jwt() ->> 'email'))
  );

DROP POLICY IF EXISTS "Participants can update own profile" ON public.participants;
CREATE POLICY "Participants can update own profile" ON public.participants
  FOR UPDATE TO authenticated
  USING (
    (LOWER(email) = LOWER(auth.jwt() ->> 'email'))
    OR (email = (auth.jwt() ->> 'email'))
  )
  WITH CHECK (
    (LOWER(email) = LOWER(auth.jwt() ->> 'email'))
    OR (email = (auth.jwt() ->> 'email'))
  );

-- 3. Participant Field Protection Trigger (Immutable participant_code and id for participants)
CREATE OR REPLACE FUNCTION public.fn_protect_participant_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_srishti_admin() THEN
    NEW.participant_code := OLD.participant_code;
    NEW.id := OLD.id;
    NEW.email := OLD.email;
    NEW.created_at := OLD.created_at;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_participant_fields ON public.participants;
CREATE TRIGGER trg_protect_participant_fields
  BEFORE UPDATE ON public.participants
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_protect_participant_fields();

-- 4. Participant Self-Service Read on registrations
DROP POLICY IF EXISTS "Participants can view own registrations" ON public.registrations;
CREATE POLICY "Participants can view own registrations" ON public.registrations
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.participants p
      WHERE p.id = registrations.participant_id
        AND ((LOWER(p.email) = LOWER(auth.jwt() ->> 'email')) OR (p.email = (auth.jwt() ->> 'email')))
    )
  );

-- 5. Participant Self-Service Read on arrival_checkins
DROP POLICY IF EXISTS "Participants can view own arrival checkin" ON public.arrival_checkins;
CREATE POLICY "Participants can view own arrival checkin" ON public.arrival_checkins
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.participants p
      WHERE p.id = arrival_checkins.participant_id
        AND ((LOWER(p.email) = LOWER(auth.jwt() ->> 'email')) OR (p.email = (auth.jwt() ->> 'email')))
    )
  );

-- 6. Participant Self-Service Read on event_attendance
DROP POLICY IF EXISTS "Participants can view own event attendance" ON public.event_attendance;
CREATE POLICY "Participants can view own event attendance" ON public.event_attendance
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.participants p
      WHERE p.id = event_attendance.participant_id
        AND ((LOWER(p.email) = LOWER(auth.jwt() ->> 'email')) OR (p.email = (auth.jwt() ->> 'email')))
    )
  );

-- 7. Grant Permissions to authenticated role
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.participants TO authenticated;
GRANT SELECT ON TABLE public.registrations TO authenticated;
GRANT SELECT ON TABLE public.arrival_checkins TO authenticated;
GRANT SELECT ON TABLE public.event_attendance TO authenticated;

COMMIT;
