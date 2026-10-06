-- ==============================================================================
-- SRISHTI 2.7 Migration: Fix RLS Infinite Recursion on participants & related tables
-- Target Project: sdkadflrxjdhxduwvrsz
--
-- Root Cause:
--   "Registration can view registered participants" and "Event staff can view assigned event participants"
--   on public.participants executed raw subqueries on public.registrations.
--   Simultaneously, "Participants can view own registrations" on public.registrations
--   executed a raw subquery on public.participants.
--   When Postgres evaluated RLS for any authenticated user, it triggered infinite
--   recursion (error code 42P17).
--
-- Fix:
--   1. Create SECURITY DEFINER helper functions with search_path = public, pg_temp
--      to break the RLS recursion chain.
--   2. Update public.participants policies to use SECURITY DEFINER functions and role checks.
--   3. Update public.registrations, arrival_checkins, and event_attendance policies
--      to use get_auth_participant_id() instead of querying public.participants under RLS.
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Helper Function: Get authenticated participant's UUID without triggering RLS
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_auth_participant_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT id FROM public.participants
  WHERE (lower(email) = lower(auth.jwt() ->> 'email') OR email = (auth.jwt() ->> 'email'))
  LIMIT 1;
$$;

-- ------------------------------------------------------------------------------
-- 2. Helper Function: Check if user is event staff for participant without RLS
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_event_staff_for_participant(target_participant_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.volunteers v
    JOIN public.event_staff es ON es.volunteer_id = v.id
    JOIN public.registrations r ON r.event_id = es.event_id
    WHERE v.auth_user_id = auth.uid()
      AND v.status = 'active'
      AND v.role = 'event_staff'
      AND r.participant_id = target_participant_id
  );
$$;

-- ------------------------------------------------------------------------------
-- 3. Fix policies on public.participants
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admin can manage participants" ON public.participants;
DROP POLICY IF EXISTS "Admin can view all participants" ON public.participants;
CREATE POLICY "Admin can manage participants" ON public.participants
  FOR ALL TO authenticated
  USING (public.is_srishti_admin())
  WITH CHECK (public.is_srishti_admin());

DROP POLICY IF EXISTS "Registration can view registered participants" ON public.participants;
DROP POLICY IF EXISTS "Registration can view participants" ON public.participants;
CREATE POLICY "Registration can view participants" ON public.participants
  FOR SELECT TO authenticated
  USING (public.is_srishti_registration());

DROP POLICY IF EXISTS "Event staff can view assigned event participants" ON public.participants;
CREATE POLICY "Event staff can view assigned event participants" ON public.participants
  FOR SELECT TO authenticated
  USING (public.is_event_staff_for_participant(id));

DROP POLICY IF EXISTS "Participants can view own profile" ON public.participants;
CREATE POLICY "Participants can view own profile" ON public.participants
  FOR SELECT TO authenticated
  USING (
    (lower(email) = lower(auth.jwt() ->> 'email'))
    OR (email = (auth.jwt() ->> 'email'))
  );

DROP POLICY IF EXISTS "Participants can update own profile" ON public.participants;
CREATE POLICY "Participants can update own profile" ON public.participants
  FOR UPDATE TO authenticated
  USING (
    (lower(email) = lower(auth.jwt() ->> 'email'))
    OR (email = (auth.jwt() ->> 'email'))
  )
  WITH CHECK (
    (lower(email) = lower(auth.jwt() ->> 'email'))
    OR (email = (auth.jwt() ->> 'email'))
  );

-- ------------------------------------------------------------------------------
-- 4. Fix policies on public.registrations (eliminate subquery to participants)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Participants can view own registrations" ON public.registrations;
CREATE POLICY "Participants can view own registrations" ON public.registrations
  FOR SELECT TO authenticated
  USING (
    participant_id = public.get_auth_participant_id()
  );

-- ------------------------------------------------------------------------------
-- 5. Fix policies on public.arrival_checkins
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Participants can view own arrival checkin" ON public.arrival_checkins;
CREATE POLICY "Participants can view own arrival checkin" ON public.arrival_checkins
  FOR SELECT TO authenticated
  USING (
    participant_id = public.get_auth_participant_id()
  );

DROP POLICY IF EXISTS "Event staff can view assigned participant arrivals" ON public.arrival_checkins;
CREATE POLICY "Event staff can view assigned participant arrivals" ON public.arrival_checkins
  FOR SELECT TO authenticated
  USING (
    public.is_event_staff_for_participant(participant_id)
  );

-- ------------------------------------------------------------------------------
-- 6. Fix policies on public.event_attendance
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Participants can view own event attendance" ON public.event_attendance;
CREATE POLICY "Participants can view own event attendance" ON public.event_attendance
  FOR SELECT TO authenticated
  USING (
    participant_id = public.get_auth_participant_id()
  );

COMMIT;
