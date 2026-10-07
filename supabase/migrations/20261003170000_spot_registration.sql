-- ==============================================================================
-- SRISHTI 2.7 — Database Migration: Spot Registration Architecture
-- ==============================================================================
-- Phase 1: Events & Registrations Schema Enhancements
-- Phase 2: Concurrency-Safe Participant Code Sequence & Security Definer Function
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Events Table Enhancements (Dynamic Configuration from Database)
-- ------------------------------------------------------------------------------
ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS registration_type TEXT DEFAULT 'individual'
    CHECK (registration_type IN ('individual', 'team')),
  ADD COLUMN IF NOT EXISTS max_team_size INTEGER DEFAULT 1
    CHECK (max_team_size >= 1),
  ADD COLUMN IF NOT EXISTS registration_fee NUMERIC(10,2) DEFAULT 0.00
    CHECK (registration_fee >= 0),
  ADD COLUMN IF NOT EXISTS is_spot_registration_enabled BOOLEAN DEFAULT true;

-- Update test events if they exist with proper default fees and limits
UPDATE public.events
SET 
  registration_type = COALESCE(registration_type, 'individual'),
  max_team_size = COALESCE(max_team_size, 1),
  registration_fee = COALESCE(registration_fee, 150.00),
  is_spot_registration_enabled = COALESCE(is_spot_registration_enabled, true)
WHERE event_code = 'TEST-EV-01';

UPDATE public.events
SET 
  registration_type = COALESCE(registration_type, 'team'),
  max_team_size = COALESCE(max_team_size, 4),
  registration_fee = COALESCE(registration_fee, 400.00),
  is_spot_registration_enabled = COALESCE(is_spot_registration_enabled, true)
WHERE event_code = 'TEST-EV-02';

-- ------------------------------------------------------------------------------
-- 2. Registrations Table Audit & Payment Columns
-- ------------------------------------------------------------------------------
ALTER TABLE public.registrations
  ADD COLUMN IF NOT EXISTS registration_source TEXT NOT NULL DEFAULT 'web'
    CHECK (registration_source IN ('web', 'spot', 'admin', 'import')),
  ADD COLUMN IF NOT EXISTS registered_by UUID
    REFERENCES public.volunteers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'verified'
    CHECK (payment_status IN ('pending', 'verified', 'waived', 'failed')),
  ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash'
    CHECK (payment_method IN ('upi', 'cash', 'waived', 'online_gateway')),
  ADD COLUMN IF NOT EXISTS payment_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00
    CHECK (payment_amount >= 0),
  ADD COLUMN IF NOT EXISTS payment_reference TEXT,
  ADD COLUMN IF NOT EXISTS payment_verified_by UUID
    REFERENCES public.volunteers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS payment_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS team_members JSONB DEFAULT '[]'::jsonb;

-- Create helpful indexes for spot audit and coordinator lookups
CREATE INDEX IF NOT EXISTS idx_registrations_source 
  ON public.registrations(registration_source);

CREATE INDEX IF NOT EXISTS idx_registrations_registered_by 
  ON public.registrations(registered_by);

CREATE INDEX IF NOT EXISTS idx_registrations_payment_status 
  ON public.registrations(payment_status);

-- ------------------------------------------------------------------------------
-- 3. Concurrency-Safe Participant Code Sequence
-- ------------------------------------------------------------------------------
-- Inspect existing production participant_code values to guarantee zero collision.
DO $$
DECLARE
    v_max_suffix INTEGER := 1000;
    v_extracted INTEGER;
BEGIN
    -- Inspect any existing numeric codes with format SRI27-XXXX or TEST-SRI27-XXX
    SELECT COALESCE(MAX(
        CASE 
            WHEN participant_code ~ '^SRI27-[0-9]+$' 
            THEN substring(participant_code from '[0-9]+$')::INTEGER
            WHEN participant_code ~ '^[A-Za-z0-9_-]+-[0-9]+$' 
            THEN substring(participant_code from '[0-9]+$')::INTEGER
            ELSE 0 
        END
    ), 1000) INTO v_extracted
    FROM public.participants;

    IF v_extracted >= v_max_suffix THEN
        v_max_suffix := v_extracted + 1;
    END IF;

    -- Create or advance the sequence safely
    IF NOT EXISTS (
        SELECT 1 FROM pg_sequences 
        WHERE schemaname = 'public' AND sequencename = 'participant_code_seq'
    ) THEN
        EXECUTE 'CREATE SEQUENCE public.participant_code_seq START WITH ' || v_max_suffix || ' INCREMENT BY 1';
    ELSE
        PERFORM setval('public.participant_code_seq', GREATEST(v_max_suffix, (SELECT last_value FROM public.participant_code_seq)));
    END IF;
END $$;

-- Collision-safe code generator helper
CREATE OR REPLACE FUNCTION public.fn_generate_participant_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_code TEXT;
    v_next_val BIGINT;
BEGIN
    LOOP
        v_next_val := nextval('public.participant_code_seq');
        v_new_code := 'SRI27-' || LPAD(v_next_val::TEXT, 4, '0');
        
        -- Guard against rare pre-existing manual insertions
        IF NOT EXISTS (SELECT 1 FROM public.participants WHERE participant_code = v_new_code) THEN
            RETURN v_new_code;
        END IF;
    END LOOP;
END;
$$;

-- ------------------------------------------------------------------------------
-- 4. Atomic Security Definer Spot Registration Function
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_create_spot_registration(
    p_coordinator_auth_id UUID,
    p_event_id UUID,
    p_participant_name TEXT,
    p_participant_phone TEXT,
    p_participant_email TEXT,
    p_participant_college TEXT,
    p_participant_department TEXT DEFAULT 'General',
    p_participant_year TEXT DEFAULT '1st Year',
    p_team_members JSONB DEFAULT '[]'::JSONB,
    p_payment_method TEXT DEFAULT 'cash',
    p_payment_amount NUMERIC DEFAULT NULL,
    p_payment_reference TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_coordinator RECORD;
    v_event RECORD;
    v_participant RECORD;
    v_clean_phone TEXT;
    v_clean_email TEXT;
    v_clean_name TEXT;
    v_clean_college TEXT;
    v_participant_id UUID;
    v_participant_code TEXT;
    v_registration_id UUID;
    v_official_fee NUMERIC(10,2);
    v_total_team_size INTEGER;
    v_team_array JSONB;
    v_sanitized_reference TEXT;
BEGIN
    -- 1. Validate Coordinator Identity & Roles
    IF p_coordinator_auth_id IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED: Authentication required' USING ERRCODE = '28000';
    END IF;

    SELECT id, name, username, role, status 
    INTO v_coordinator
    FROM public.volunteers
    WHERE auth_user_id = p_coordinator_auth_id;

    IF v_coordinator.id IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED: Coordinator volunteer record not found' USING ERRCODE = '28000';
    END IF;

    IF v_coordinator.status != 'active' THEN
        RAISE EXCEPTION 'FORBIDDEN: Volunteer account is inactive' USING ERRCODE = '28001';
    END IF;

    IF v_coordinator.role NOT IN ('registration', 'admin') THEN
        RAISE EXCEPTION 'FORBIDDEN: Only Registration Coordinators and Admins can perform Spot Registration' USING ERRCODE = '28002';
    END IF;

    -- 2. Validate Event & Capacity/Availability (Row Lock)
    SELECT id, event_code, name, category, venue, date, start_time, end_time,
           status, registration_type, max_team_size, registration_fee, is_spot_registration_enabled
    INTO v_event
    FROM public.events
    WHERE id = p_event_id
    FOR SHARE;

    IF v_event.id IS NULL THEN
        RAISE EXCEPTION 'EVENT_NOT_FOUND: Selected event does not exist' USING ERRCODE = 'P0002';
    END IF;

    IF v_event.status ILIKE 'cancelled' THEN
        RAISE EXCEPTION 'EVENT_UNAVAILABLE: Event has been cancelled' USING ERRCODE = '22023';
    END IF;

    IF v_event.is_spot_registration_enabled IS FALSE THEN
        RAISE EXCEPTION 'SPOT_REGISTRATION_DISABLED: Spot registration is closed for this event' USING ERRCODE = '22024';
    END IF;

    -- 3. Validate Inputs
    v_clean_name := TRIM(p_participant_name);
    v_clean_phone := TRIM(p_participant_phone);
    v_clean_email := LOWER(TRIM(p_participant_email));
    v_clean_college := TRIM(p_participant_college);

    IF v_clean_name = '' THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Full name is required' USING ERRCODE = '22000';
    END IF;

    IF v_clean_phone = '' THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Phone number is required' USING ERRCODE = '22000';
    END IF;

    IF v_clean_college = '' THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: College name is required' USING ERRCODE = '22000';
    END IF;

    -- 4. Validate Team Size & Rules
    v_team_array := COALESCE(p_team_members, '[]'::JSONB);

    IF jsonb_typeof(v_team_array) != 'array' THEN
        RAISE EXCEPTION 'INVALID_TEAM_ROSTER: team_members must be a JSON array' USING ERRCODE = '22025';
    END IF;

    v_total_team_size := 1 + jsonb_array_length(v_team_array);

    IF v_event.registration_type = 'individual' AND v_total_team_size > 1 THEN
        RAISE EXCEPTION 'INVALID_TEAM_SIZE: Individual events allow only 1 participant' USING ERRCODE = '22025';
    END IF;

    IF v_total_team_size > COALESCE(v_event.max_team_size, 4) THEN
        RAISE EXCEPTION 'TEAM_LIMIT_EXCEEDED: Team size exceeds maximum limit of %', v_event.max_team_size USING ERRCODE = '22026';
    END IF;

    -- 5. Validate Payment Method & Official Fee
    p_payment_method := LOWER(TRIM(p_payment_method));
    IF p_payment_method NOT IN ('cash', 'upi', 'waived') THEN
        RAISE EXCEPTION 'INVALID_PAYMENT_METHOD: Supported payment methods are cash or upi' USING ERRCODE = '22027';
    END IF;

    v_official_fee := COALESCE(v_event.registration_fee, 0.00);

    -- Ensure payment amount strictly matches the official event fee (NULL is rejected)
    IF p_payment_amount IS NULL OR p_payment_amount != v_official_fee THEN
        RAISE EXCEPTION 'PAYMENT_MISMATCH: Provided amount does not match official event fee (₹%)', v_official_fee
        USING ERRCODE = '22028';
    END IF;

    -- Reference validation
    IF p_payment_method = 'upi' THEN
        v_sanitized_reference := TRIM(COALESCE(p_payment_reference, ''));
        IF v_sanitized_reference = '' THEN
            RAISE EXCEPTION 'MISSING_PAYMENT_REFERENCE: UPI reference is required' USING ERRCODE = '22029';
        END IF;
    ELSIF p_payment_method = 'cash' THEN
        v_sanitized_reference := COALESCE(NULLIF(TRIM(p_payment_reference), ''), 'CASH-VERIFIED');
    ELSE
        v_sanitized_reference := 'FEE-WAIVED';
    END IF;

    -- 6. Participant Resolution (Find Existing by Phone or Email)
    SELECT id, participant_code, name, email, phone, college
    INTO v_participant
    FROM public.participants
    WHERE (v_clean_phone != '' AND phone = v_clean_phone)
       OR (v_clean_email != '' AND LOWER(email) = v_clean_email)
    LIMIT 1;

    IF v_participant.id IS NOT NULL THEN
        v_participant_id := v_participant.id;
        v_participant_code := v_participant.participant_code;

        -- Check if already registered for this event
        IF EXISTS (
            SELECT 1 FROM public.registrations
            WHERE participant_id = v_participant_id
              AND event_id = p_event_id
              AND status = 'registered'
        ) THEN
            RAISE EXCEPTION 'DUPLICATE_REGISTRATION: Participant % is already registered for %', v_participant_code, v_event.name USING ERRCODE = '23505';
        END IF;
    ELSE
        -- Generate collision-safe participant code
        v_participant_code := public.fn_generate_participant_code();

        -- Insert Participant atomically
        INSERT INTO public.participants (
            participant_code,
            name,
            email,
            phone,
            college,
            department,
            year,
            created_at,
            updated_at
        ) VALUES (
            v_participant_code,
            v_clean_name,
            v_clean_email,
            v_clean_phone,
            v_clean_college,
            COALESCE(p_participant_department, 'General'),
            COALESCE(p_participant_year, '1st Year'),
            now(),
            now()
        ) RETURNING id INTO v_participant_id;
    END IF;

    -- 7. Insert Registration Record
    INSERT INTO public.registrations (
        participant_id,
        event_id,
        status,
        registration_source,
        registered_by,
        payment_status,
        payment_method,
        payment_amount,
        payment_reference,
        payment_verified_by,
        payment_verified_at,
        team_members,
        registered_at,
        updated_at
    ) VALUES (
        v_participant_id,
        p_event_id,
        'registered',
        'spot',
        v_coordinator.id,
        'verified',
        p_payment_method,
        v_official_fee,
        v_sanitized_reference,
        v_coordinator.id,
        now(),
        v_team_array,
        now(),
        now()
    ) RETURNING id INTO v_registration_id;

    -- 8. Return Complete Atomic Registration Result
    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'participant_id', v_participant_id,
            'participant_code', v_participant_code,
            'registration_id', v_registration_id,
            'event_id', v_event.id,
            'event_code', v_event.event_code,
            'event_name', v_event.name,
            'registered_at', now(),
            'status', 'registered',
            'payment_status', 'verified',
            'payment_method', p_payment_method,
            'payment_amount', v_official_fee,
            'registered_by', jsonb_build_object(
                'volunteer_id', v_coordinator.id,
                'name', v_coordinator.name,
                'role', v_coordinator.role
            )
        )
    );
END;
$$;

-- Security: Revoke public and authenticated execution, grant strictly to service_role
REVOKE ALL ON FUNCTION public.fn_create_spot_registration FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_create_spot_registration TO service_role;

COMMIT;
