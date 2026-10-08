-- ==============================================================================
-- SRISHTI 2.7 Security Migration: Event Attendance RLS & Server-Side Attribution
-- Fixes: SEC-01 (Event Attendance RLS INSERT Enforcement)
--        SEC-02 (Server-Side Attribution for arrival_checkins and event_attendance)
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Table Grants & Permissions
-- ------------------------------------------------------------------------------
GRANT SELECT, INSERT ON TABLE public.event_attendance TO authenticated;
GRANT SELECT, INSERT ON TABLE public.arrival_checkins TO authenticated;
GRANT ALL ON TABLE public.event_attendance TO service_role;
GRANT ALL ON TABLE public.arrival_checkins TO service_role;
REVOKE ALL ON TABLE public.event_attendance FROM anon;
REVOKE ALL ON TABLE public.arrival_checkins FROM anon;

-- ------------------------------------------------------------------------------
-- 2. SEC-01: Row Level Security on public.event_attendance
-- ------------------------------------------------------------------------------
ALTER TABLE public.event_attendance ENABLE ROW LEVEL SECURITY;

-- Clean up existing / obsolete policies
DROP POLICY IF EXISTS "Event staff can create assigned attendance" ON public.event_attendance;
DROP POLICY IF EXISTS "Event staff can view assigned attendance" ON public.event_attendance;
DROP POLICY IF EXISTS "Admin can manage event attendance" ON public.event_attendance;
DROP POLICY IF EXISTS "Staff can insert assigned event attendance" ON public.event_attendance;
DROP POLICY IF EXISTS "Staff can view assigned event attendance" ON public.event_attendance;
DROP POLICY IF EXISTS "Admins can manage event attendance" ON public.event_attendance;
DROP POLICY IF EXISTS "Admins can update event attendance" ON public.event_attendance;
DROP POLICY IF EXISTS "Admins can delete event attendance" ON public.event_attendance;

-- Admins: Full management of event attendance
CREATE POLICY "Admins can manage event attendance" ON public.event_attendance
  FOR ALL TO authenticated
  USING (public.is_srishti_admin())
  WITH CHECK (public.is_srishti_admin());

-- Event Staff: Can view attendance only for assigned events
CREATE POLICY "Staff can view assigned event attendance" ON public.event_attendance
  FOR SELECT TO authenticated
  USING (public.is_event_staff_for_event(event_id));

-- Event Staff: Can INSERT attendance ONLY for events assigned to them
CREATE POLICY "Staff can insert assigned event attendance" ON public.event_attendance
  FOR INSERT TO authenticated
  WITH CHECK (public.is_event_staff_for_event(event_id));

-- Update/Delete: Restricted to Admins only
CREATE POLICY "Admins can update event attendance" ON public.event_attendance
  FOR UPDATE TO authenticated
  USING (public.is_srishti_admin())
  WITH CHECK (public.is_srishti_admin());

CREATE POLICY "Admins can delete event attendance" ON public.event_attendance
  FOR DELETE TO authenticated
  USING (public.is_srishti_admin());

-- ------------------------------------------------------------------------------
-- 3. Row Level Security on public.arrival_checkins
-- ------------------------------------------------------------------------------
ALTER TABLE public.arrival_checkins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Registration can create arrival check-ins" ON public.arrival_checkins;
DROP POLICY IF EXISTS "Registration can view arrival check-ins" ON public.arrival_checkins;
DROP POLICY IF EXISTS "Admin can manage arrival check-ins" ON public.arrival_checkins;
DROP POLICY IF EXISTS "Admins can manage arrival checkins" ON public.arrival_checkins;
DROP POLICY IF EXISTS "Registration staff can view arrival checkins" ON public.arrival_checkins;
DROP POLICY IF EXISTS "Registration staff can insert arrival checkins" ON public.arrival_checkins;
DROP POLICY IF EXISTS "Admins can update arrival checkins" ON public.arrival_checkins;
DROP POLICY IF EXISTS "Admins can delete arrival checkins" ON public.arrival_checkins;

-- Admins: Full management of arrival checkins
CREATE POLICY "Admins can manage arrival checkins" ON public.arrival_checkins
  FOR ALL TO authenticated
  USING (public.is_srishti_admin())
  WITH CHECK (public.is_srishti_admin());

-- Registration Staff: Can view arrival checkins
CREATE POLICY "Registration staff can view arrival checkins" ON public.arrival_checkins
  FOR SELECT TO authenticated
  USING (public.is_srishti_registration());

-- Registration Staff: Can INSERT arrival checkins
CREATE POLICY "Registration staff can insert arrival checkins" ON public.arrival_checkins
  FOR INSERT TO authenticated
  WITH CHECK (public.is_srishti_registration());

-- Update/Delete: Restricted to Admins only
CREATE POLICY "Admins can update arrival checkins" ON public.arrival_checkins
  FOR UPDATE TO authenticated
  USING (public.is_srishti_admin())
  WITH CHECK (public.is_srishti_admin());

CREATE POLICY "Admins can delete arrival checkins" ON public.arrival_checkins
  FOR DELETE TO authenticated
  USING (public.is_srishti_admin());

-- ------------------------------------------------------------------------------
-- 4. SEC-02: Server-Side Attribution Trigger for arrival_checkins
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_set_arrival_checkin_attribution()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_volunteer RECORD;
BEGIN
  -- Service role / internal bypass for migrations and backend scripts without authenticated JWT
  IF auth.role() = 'service_role' OR auth.uid() IS NULL THEN
    IF NEW.checked_in_by IS NULL THEN
      RAISE EXCEPTION 'checked_in_by is required for service_role inserts' USING ERRCODE = '23502';
    END IF;
    RETURN NEW;
  END IF;

  -- Authenticated user validation
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Authentication required to record arrival check-in'
      USING ERRCODE = '28000';
  END IF;

  SELECT id, role, status INTO v_volunteer
  FROM public.volunteers
  WHERE auth_user_id = auth.uid();

  IF v_volunteer.id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: No active volunteer profile associated with this account'
      USING ERRCODE = '28000';
  END IF;

  IF v_volunteer.status != 'active' THEN
    RAISE EXCEPTION 'FORBIDDEN: Volunteer account is not active'
      USING ERRCODE = '28001';
  END IF;

  IF v_volunteer.role NOT IN ('registration', 'admin') THEN
    RAISE EXCEPTION 'FORBIDDEN: Only registration coordinators and admins can check in participants'
      USING ERRCODE = '28002';
  END IF;

  -- Enforce authentic volunteer ID from database record (cannot be spoofed by client payload)
  NEW.checked_in_by := v_volunteer.id;
  NEW.checked_in_at := COALESCE(NEW.checked_in_at, now());
  NEW.source := COALESCE(NEW.source, 'qr');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_arrival_checkin_attribution ON public.arrival_checkins;
CREATE TRIGGER trg_set_arrival_checkin_attribution
  BEFORE INSERT ON public.arrival_checkins
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_set_arrival_checkin_attribution();

-- ------------------------------------------------------------------------------
-- 5. SEC-02: Server-Side Attribution Trigger for event_attendance
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_set_event_attendance_attribution()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_volunteer RECORD;
BEGIN
  -- Service role / internal bypass for migrations and backend scripts without authenticated JWT
  IF auth.role() = 'service_role' OR auth.uid() IS NULL THEN
    IF NEW.marked_by IS NULL THEN
      RAISE EXCEPTION 'marked_by is required for service_role inserts' USING ERRCODE = '23502';
    END IF;
    RETURN NEW;
  END IF;

  -- Authenticated user validation
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Authentication required to record event attendance'
      USING ERRCODE = '28000';
  END IF;

  SELECT id, role, status INTO v_volunteer
  FROM public.volunteers
  WHERE auth_user_id = auth.uid();

  IF v_volunteer.id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: No active volunteer profile associated with this account'
      USING ERRCODE = '28000';
  END IF;

  IF v_volunteer.status != 'active' THEN
    RAISE EXCEPTION 'FORBIDDEN: Volunteer account is not active'
      USING ERRCODE = '28001';
  END IF;

  IF v_volunteer.role = 'admin' THEN
    -- Admin allowed
    NULL;
  ELSIF v_volunteer.role = 'event_staff' THEN
    -- Verify assignment to the target event
    IF NOT EXISTS (
      SELECT 1 FROM public.event_staff es
      WHERE es.volunteer_id = v_volunteer.id
        AND es.event_id = NEW.event_id
    ) THEN
      RAISE EXCEPTION 'FORBIDDEN: Coordinator is not assigned to this event'
        USING ERRCODE = '28003';
    END IF;
  ELSE
    RAISE EXCEPTION 'FORBIDDEN: Only event coordinators and admins can mark attendance'
      USING ERRCODE = '28002';
  END IF;

  -- Enforce authentic volunteer ID from database record (cannot be spoofed by client payload)
  NEW.marked_by := v_volunteer.id;
  NEW.marked_at := COALESCE(NEW.marked_at, now());
  NEW.source := COALESCE(NEW.source, 'qr');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_event_attendance_attribution ON public.event_attendance;
CREATE TRIGGER trg_set_event_attendance_attribution
  BEFORE INSERT ON public.event_attendance
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_set_event_attendance_attribution();

-- ------------------------------------------------------------------------------
-- 6. Immutability Guards for Past Check-in and Attendance Records
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_prevent_attendance_tampering()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_srishti_admin() THEN
    RAISE EXCEPTION 'FORBIDDEN: Attendance records cannot be modified'
      USING ERRCODE = '42501';
  END IF;
  -- Prevent altering core relationship keys even by admin update
  NEW.participant_id := OLD.participant_id;
  IF TG_TABLE_NAME = 'event_attendance' THEN
    NEW.event_id := OLD.event_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_arrival_tampering ON public.arrival_checkins;
CREATE TRIGGER trg_prevent_arrival_tampering
  BEFORE UPDATE ON public.arrival_checkins
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_prevent_attendance_tampering();

DROP TRIGGER IF EXISTS trg_prevent_attendance_tampering ON public.event_attendance;
CREATE TRIGGER trg_prevent_attendance_tampering
  BEFORE UPDATE ON public.event_attendance
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_prevent_attendance_tampering();

-- ------------------------------------------------------------------------------
-- 7. Secure Function Execution Permissions
-- ------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.fn_set_arrival_checkin_attribution() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_set_event_attendance_attribution() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_prevent_attendance_tampering() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.fn_set_arrival_checkin_attribution() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_set_event_attendance_attribution() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_prevent_attendance_tampering() TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;
