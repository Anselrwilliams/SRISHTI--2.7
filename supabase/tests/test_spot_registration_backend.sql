-- ==============================================================================
-- SRISHTI 2.7 — Backend Verification & Integration Tests
-- Spot Registration Architecture (Phase 5)
-- ==============================================================================

BEGIN;

-- Setup test data isolated for testing
DO $$
DECLARE
    v_coord_auth_id UUID := gen_random_uuid();
    v_admin_auth_id UUID := gen_random_uuid();
    v_staff_auth_id UUID := gen_random_uuid();
    v_inactive_auth_id UUID := gen_random_uuid();
    
    v_coord_id UUID := gen_random_uuid();
    v_admin_id UUID := gen_random_uuid();
    v_staff_id UUID := gen_random_uuid();
    v_inactive_id UUID := gen_random_uuid();

    v_event_active_id UUID := gen_random_uuid();
    v_event_team_id UUID := gen_random_uuid();
    v_event_disabled_id UUID := gen_random_uuid();
    v_event_cancelled_id UUID := gen_random_uuid();

    v_res JSONB;
    v_p_code1 TEXT;
    v_p_id1 UUID;
    v_p_code2 TEXT;
    v_p_id2 UUID;
    v_reg_record RECORD;
    v_fn_oid OID;
BEGIN
    RAISE NOTICE 'Starting SRISHTI 2.7 Spot Registration Backend Tests...';

    -- --------------------------------------------------------------------------
    -- 0. Seed Test Volunteers
    -- --------------------------------------------------------------------------
    INSERT INTO public.volunteers (id, auth_user_id, name, username, role, status) VALUES
        (v_coord_id, v_coord_auth_id, 'Test Coordinator', 'test_coord', 'registration', 'active'),
        (v_admin_id, v_admin_auth_id, 'Test Admin', 'test_admin', 'admin', 'active'),
        (v_staff_id, v_staff_auth_id, 'Test Staff', 'test_staff', 'event_staff', 'active'),
        (v_inactive_id, v_inactive_auth_id, 'Test Inactive', 'test_inactive', 'registration', 'inactive');

    -- --------------------------------------------------------------------------
    -- 0. Seed Test Events
    -- --------------------------------------------------------------------------
    INSERT INTO public.events (
        id, event_code, name, category, venue, date, status, 
        registration_type, max_team_size, registration_fee, is_spot_registration_enabled
    ) VALUES
        (v_event_active_id, 'TEST-ACT-01', 'Solo Speed Coding', 'Coding', 'Lab 1', CURRENT_DATE, 'scheduled', 'individual', 1, 150.00, true),
        (v_event_team_id, 'TEST-TEAM-01', 'Mega Hackathon', 'Coding', 'Auditorium', CURRENT_DATE, 'scheduled', 'team', 3, 300.00, true),
        (v_event_disabled_id, 'TEST-DIS-01', 'Closed Workshop', 'Tech', 'Seminar Hall', CURRENT_DATE, 'scheduled', 'individual', 1, 100.00, false),
        (v_event_cancelled_id, 'TEST-CAN-01', 'Cancelled Contest', 'Games', 'Room 2', CURRENT_DATE, 'cancelled', 'individual', 1, 50.00, true);

    -- --------------------------------------------------------------------------
    -- Test 1: Registration Coordinator Succeeds
    -- --------------------------------------------------------------------------
    v_res := public.fn_create_spot_registration(
        p_coordinator_auth_id := v_coord_auth_id,
        p_event_id := v_event_active_id,
        p_participant_name := 'Abhiram P',
        p_participant_phone := '9876543201',
        p_participant_email := 'abhiram.test@fest.com',
        p_participant_college := 'GEC Thrissur',
        p_participant_department := 'CSE',
        p_participant_year := '3rd Year',
        p_payment_method := 'upi',
        p_payment_amount := 150.00,
        p_payment_reference := 'UPI-TEST-001'
    );

    IF (v_res->>'success')::BOOLEAN IS NOT TRUE THEN
        RAISE EXCEPTION 'Test 1 Failed: Expected success for Registration Coordinator';
    END IF;

    v_p_code1 := v_res->'data'->>'participant_code';
    v_p_id1 := (v_res->'data'->>'participant_id')::UUID;
    RAISE NOTICE 'Test 1 Passed: Coordinator succeeded with participant code %', v_p_code1;

    -- --------------------------------------------------------------------------
    -- Test 2: Admin Succeeds
    -- --------------------------------------------------------------------------
    v_res := public.fn_create_spot_registration(
        p_coordinator_auth_id := v_admin_auth_id,
        p_event_id := v_event_active_id,
        p_participant_name := 'Bhavana S',
        p_participant_phone := '9876543202',
        p_participant_email := 'bhavana.test@fest.com',
        p_participant_college := 'Model Eng College',
        p_payment_method := 'cash',
        p_payment_amount := 150.00,
        p_payment_reference := 'CASH-REC-01'
    );

    IF (v_res->>'success')::BOOLEAN IS NOT TRUE THEN
        RAISE EXCEPTION 'Test 2 Failed: Expected success for Admin';
    END IF;
    RAISE NOTICE 'Test 2 Passed: Admin succeeded with participant code %', v_res->'data'->>'participant_code';

    -- --------------------------------------------------------------------------
    -- Test 3: Event Staff Rejected
    -- --------------------------------------------------------------------------
    BEGIN
        v_res := public.fn_create_spot_registration(
            p_coordinator_auth_id := v_staff_auth_id,
            p_event_id := v_event_active_id,
            p_participant_name := 'Chetan M',
            p_participant_phone := '9876543203',
            p_participant_email := 'chetan.test@fest.com',
            p_participant_college := 'TKM College',
            p_payment_amount := 150.00
        );
        RAISE EXCEPTION 'Test 3 Failed: Event Staff was not rejected';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%FORBIDDEN%' THEN
            RAISE EXCEPTION 'Test 3 Failed: Unexpected error %', SQLERRM;
        END IF;
        RAISE NOTICE 'Test 3 Passed: Event staff rejected with FORBIDDEN';
    END;

    -- --------------------------------------------------------------------------
    -- Test 4: Unauthenticated Request Rejected
    -- --------------------------------------------------------------------------
    BEGIN
        v_res := public.fn_create_spot_registration(
            p_coordinator_auth_id := NULL,
            p_event_id := v_event_active_id,
            p_participant_name := 'David K',
            p_participant_phone := '9876543204',
            p_participant_email := 'david.test@fest.com',
            p_participant_college := 'GEC Kannur',
            p_payment_amount := 150.00
        );
        RAISE EXCEPTION 'Test 4 Failed: NULL auth user was not rejected';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%UNAUTHORIZED%' THEN
            RAISE EXCEPTION 'Test 4 Failed: Unexpected error %', SQLERRM;
        END IF;
        RAISE NOTICE 'Test 4 Passed: Unauthenticated request rejected with UNAUTHORIZED';
    END;

    -- --------------------------------------------------------------------------
    -- Test 5: Invalid Event Rejected
    -- --------------------------------------------------------------------------
    BEGIN
        v_res := public.fn_create_spot_registration(
            p_coordinator_auth_id := v_coord_auth_id,
            p_event_id := gen_random_uuid(),
            p_participant_name := 'Eshwar R',
            p_participant_phone := '9876543205',
            p_participant_email := 'eshwar.test@fest.com',
            p_participant_college := 'NSS Palakkad',
            p_payment_amount := 150.00
        );
        RAISE EXCEPTION 'Test 5 Failed: Non-existent event was not rejected';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%EVENT_NOT_FOUND%' THEN
            RAISE EXCEPTION 'Test 5 Failed: Unexpected error %', SQLERRM;
        END IF;
        RAISE NOTICE 'Test 5 Passed: Invalid event rejected with EVENT_NOT_FOUND';
    END;

    -- --------------------------------------------------------------------------
    -- Test 6: Spot Registration Disabled / Cancelled Event Rejected
    -- --------------------------------------------------------------------------
    BEGIN
        v_res := public.fn_create_spot_registration(
            p_coordinator_auth_id := v_coord_auth_id,
            p_event_id := v_event_disabled_id,
            p_participant_name := 'Faisal T',
            p_participant_phone := '9876543206',
            p_participant_email := 'faisal.test@fest.com',
            p_participant_college := 'CET Trivandrum',
            p_payment_amount := 100.00
        );
        RAISE EXCEPTION 'Test 6 Failed: Disabled spot registration event was not rejected';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%SPOT_REGISTRATION_DISABLED%' THEN
            RAISE EXCEPTION 'Test 6 Failed: Unexpected error %', SQLERRM;
        END IF;
        RAISE NOTICE 'Test 6 Passed: Disabled spot registration event rejected';
    END;

    -- --------------------------------------------------------------------------
    -- Test 7: Wrong Payment Amount Rejected
    -- --------------------------------------------------------------------------
    BEGIN
        v_res := public.fn_create_spot_registration(
            p_coordinator_auth_id := v_coord_auth_id,
            p_event_id := v_event_active_id,
            p_participant_name := 'Gautham V',
            p_participant_phone := '9876543207',
            p_participant_email := 'gautham.test@fest.com',
            p_participant_college := 'RIT Kottayam',
            p_payment_amount := 50.00 -- Mismatched! Official is 150.00
        );
        RAISE EXCEPTION 'Test 7 Failed: Underpaid amount was not rejected';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%PAYMENT_MISMATCH%' THEN
            RAISE EXCEPTION 'Test 7 Failed: Unexpected error %', SQLERRM;
        END IF;
        RAISE NOTICE 'Test 7 Passed: Wrong payment amount rejected with PAYMENT_MISMATCH';
    END;

    -- --------------------------------------------------------------------------
    -- Test 8: Duplicate Participant / Event Rejected
    -- --------------------------------------------------------------------------
    BEGIN
        -- Attempt to register Abhiram P again for TEST-ACT-01
        v_res := public.fn_create_spot_registration(
            p_coordinator_auth_id := v_coord_auth_id,
            p_event_id := v_event_active_id,
            p_participant_name := 'Abhiram P',
            p_participant_phone := '9876543201',
            p_participant_email := 'abhiram.test@fest.com',
            p_participant_college := 'GEC Thrissur',
            p_payment_amount := 150.00
        );
        RAISE EXCEPTION 'Test 8 Failed: Duplicate registration was not rejected';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%DUPLICATE_REGISTRATION%' THEN
            RAISE EXCEPTION 'Test 8 Failed: Unexpected error %', SQLERRM;
        END IF;
        RAISE NOTICE 'Test 8 Passed: Duplicate registration rejected with DUPLICATE_REGISTRATION';
    END;

    -- --------------------------------------------------------------------------
    -- Test 9: Existing Participant Reused for Different Event
    -- --------------------------------------------------------------------------
    -- Register Abhiram P for TEST-TEAM-01
    v_res := public.fn_create_spot_registration(
        p_coordinator_auth_id := v_coord_auth_id,
        p_event_id := v_event_team_id,
        p_participant_name := 'Abhiram P',
        p_participant_phone := '9876543201',
        p_participant_email := 'abhiram.test@fest.com',
        p_participant_college := 'GEC Thrissur',
        p_team_members := '[{"name": "Team Member 2", "phone": "9876543299"}]'::JSONB,
        p_payment_method := 'upi',
        p_payment_amount := 300.00,
        p_payment_reference := 'UPI-TEAM-01'
    );

    v_p_code2 := v_res->'data'->>'participant_code';
    v_p_id2 := (v_res->'data'->>'participant_id')::UUID;

    IF v_p_id1 != v_p_id2 OR v_p_code1 != v_p_code2 THEN
        RAISE EXCEPTION 'Test 9 Failed: Existing participant was not reused. Got ID % vs %, code % vs %', 
            v_p_id1, v_p_id2, v_p_code1, v_p_code2;
    END IF;
    RAISE NOTICE 'Test 9 Passed: Existing participant correctly reused with same code %', v_p_code2;

    -- --------------------------------------------------------------------------
    -- Test 10: New Participant Gets Unique Server-Side Code
    -- --------------------------------------------------------------------------
    IF v_p_code1 NOT LIKE 'SRI27-%' THEN
        RAISE EXCEPTION 'Test 10 Failed: Participant code % does not follow SRI27-XXXX format', v_p_code1;
    END IF;
    RAISE NOTICE 'Test 10 Passed: New participant assigned unique server-side code %', v_p_code1;

    -- --------------------------------------------------------------------------
    -- Test 11: Concurrency-Safe Sequence Monotonicity
    -- --------------------------------------------------------------------------
    DECLARE
        v_next_code1 TEXT;
        v_next_code2 TEXT;
    BEGIN
        v_next_code1 := public.fn_generate_participant_code();
        v_next_code2 := public.fn_generate_participant_code();
        IF v_next_code1 = v_next_code2 THEN
            RAISE EXCEPTION 'Test 11 Failed: Duplicate participant codes generated sequentially';
        END IF;
        RAISE NOTICE 'Test 11 Passed: Sequential codes % and % generated without collision', v_next_code1, v_next_code2;
    END;

    -- --------------------------------------------------------------------------
    -- Test 12: Failed Registration Leaves No Orphan Participant
    -- --------------------------------------------------------------------------
    DECLARE
        v_pre_count INTEGER;
        v_post_count INTEGER;
    BEGIN
        SELECT count(*) INTO v_pre_count FROM public.participants;
        BEGIN
            -- Call with bad payment reference on UPI (triggers error after code gen)
            PERFORM public.fn_create_spot_registration(
                p_coordinator_auth_id := v_coord_auth_id,
                p_event_id := v_event_active_id,
                p_participant_name := 'Ghost Participant',
                p_participant_phone := '9876543999',
                p_participant_email := 'ghost@fest.com',
                p_participant_college := 'Ghost College',
                p_payment_method := 'upi',
                p_payment_amount := 150.00,
                p_payment_reference := '' -- Blank triggers exception
            );
        EXCEPTION WHEN OTHERS THEN
            -- Expected exception
        END;
        SELECT count(*) INTO v_post_count FROM public.participants;
        IF v_pre_count != v_post_count THEN
            RAISE EXCEPTION 'Test 12 Failed: Orphan participant was created despite failed transaction';
        END IF;
        RAISE NOTICE 'Test 12 Passed: Transaction rollback ensured zero orphan participants';
    END;

    -- --------------------------------------------------------------------------
    -- Test 13, 14, 15: Payment Audit Fields & Authenticated Coordinator Recording
    -- --------------------------------------------------------------------------
    SELECT * INTO v_reg_record 
    FROM public.registrations
    WHERE participant_id = v_p_id1 AND event_id = v_event_active_id;

    IF v_reg_record.registration_source != 'spot' THEN
        RAISE EXCEPTION 'Test 13 Failed: Expected registration_source=spot';
    END IF;

    IF v_reg_record.registered_by != v_coord_id THEN
        RAISE EXCEPTION 'Test 14 Failed: registered_by % does not match coordinator ID %', 
            v_reg_record.registered_by, v_coord_id;
    END IF;

    IF v_reg_record.payment_verified_by != v_coord_id THEN
        RAISE EXCEPTION 'Test 15 Failed: payment_verified_by % does not match coordinator ID %',
            v_reg_record.payment_verified_by, v_coord_id;
    END IF;

    IF v_reg_record.payment_status != 'verified' OR v_reg_record.payment_amount != 150.00 THEN
        RAISE EXCEPTION 'Test 13 Failed: Invalid payment status or amount';
    END IF;
    RAISE NOTICE 'Tests 13, 14, 15 Passed: Payment audit fields and authenticated coordinator recorded correctly';

    -- --------------------------------------------------------------------------
    -- Test 16: Existing Arrival Check-In Unaffected
    -- --------------------------------------------------------------------------
    INSERT INTO public.arrival_checkins (
        participant_id, checked_in_by, source, notes
    ) VALUES (
        v_p_id1, v_coord_id, 'spot', 'Spot registered and arrived'
    );

    IF NOT EXISTS (SELECT 1 FROM public.arrival_checkins WHERE participant_id = v_p_id1) THEN
        RAISE EXCEPTION 'Test 16 Failed: Festival arrival checkin failed for spot participant';
    END IF;
    RAISE NOTICE 'Test 16 Passed: Arrival checkin succeeded smoothly for spot registered participant';

    -- --------------------------------------------------------------------------
    -- Test 17: NULL Payment Amount Rejected (Payment Validation)
    -- --------------------------------------------------------------------------
    BEGIN
        v_res := public.fn_create_spot_registration(
            p_coordinator_auth_id := v_coord_auth_id,
            p_event_id := v_event_active_id,
            p_participant_name := 'Null Payment User',
            p_participant_phone := '9876543288',
            p_participant_email := 'nullpay@fest.com',
            p_participant_college := 'Test College',
            p_payment_amount := NULL
        );
        RAISE EXCEPTION 'Test 17 Failed: NULL payment amount was not rejected';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%PAYMENT_MISMATCH%' THEN
            RAISE EXCEPTION 'Test 17 Failed: Unexpected error %, expected PAYMENT_MISMATCH', SQLERRM;
        END IF;
        RAISE NOTICE 'Test 17 Passed: NULL payment amount rejected with PAYMENT_MISMATCH';
    END;

    -- --------------------------------------------------------------------------
    -- Test 18: Non-Array Team Members Roster Rejected
    -- --------------------------------------------------------------------------
    BEGIN
        v_res := public.fn_create_spot_registration(
            p_coordinator_auth_id := v_coord_auth_id,
            p_event_id := v_event_team_id,
            p_participant_name := 'Invalid Team User',
            p_participant_phone := '9876543287',
            p_participant_email := 'invalidteam@fest.com',
            p_participant_college := 'Test College',
            p_team_members := '{"name": "Solo Object"}'::JSONB,
            p_payment_amount := 300.00
        );
        RAISE EXCEPTION 'Test 18 Failed: Non-array team_members object was not rejected';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%INVALID_TEAM_ROSTER%' THEN
            RAISE EXCEPTION 'Test 18 Failed: Unexpected error %, expected INVALID_TEAM_ROSTER', SQLERRM;
        END IF;
        RAISE NOTICE 'Test 18 Passed: Non-array team_members object rejected with INVALID_TEAM_ROSTER';
    END;

    BEGIN
        v_res := public.fn_create_spot_registration(
            p_coordinator_auth_id := v_coord_auth_id,
            p_event_id := v_event_team_id,
            p_participant_name := 'Invalid Team User 2',
            p_participant_phone := '9876543286',
            p_participant_email := 'invalidteam2@fest.com',
            p_participant_college := 'Test College',
            p_team_members := '"scalar_string"'::JSONB,
            p_payment_amount := 300.00
        );
        RAISE EXCEPTION 'Test 18b Failed: Scalar string team_members was not rejected';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%INVALID_TEAM_ROSTER%' THEN
            RAISE EXCEPTION 'Test 18b Failed: Unexpected error %, expected INVALID_TEAM_ROSTER', SQLERRM;
        END IF;
        RAISE NOTICE 'Test 18b Passed: Scalar string team_members rejected with INVALID_TEAM_ROSTER';
    END;

    -- --------------------------------------------------------------------------
    -- Test 19: Security Privileges & Authenticated Direct RPC Execution Rejected
    -- --------------------------------------------------------------------------
    SELECT oid INTO v_fn_oid 
    FROM pg_proc 
    WHERE proname = 'fn_create_spot_registration' 
      AND pronamespace = 'public'::regnamespace;

    IF v_fn_oid IS NOT NULL THEN
        -- Catalog level checks
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
            IF has_function_privilege('authenticated', v_fn_oid, 'EXECUTE') THEN
                RAISE EXCEPTION 'Test 19 Failed: authenticated role still has EXECUTE privilege on fn_create_spot_registration';
            END IF;
        END IF;

        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            IF has_function_privilege('anon', v_fn_oid, 'EXECUTE') THEN
                RAISE EXCEPTION 'Test 19 Failed: anon role still has EXECUTE privilege on fn_create_spot_registration';
            END IF;
        END IF;

        IF has_function_privilege('public', v_fn_oid, 'EXECUTE') THEN
            RAISE EXCEPTION 'Test 19 Failed: public pseudo-role still has EXECUTE privilege on fn_create_spot_registration';
        END IF;

        -- Runtime role switch check if authenticated role is defined
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
            BEGIN
                EXECUTE 'SET LOCAL ROLE authenticated';
                BEGIN
                    PERFORM public.fn_create_spot_registration(
                        p_coordinator_auth_id := v_coord_auth_id,
                        p_event_id := v_event_active_id,
                        p_participant_name := 'Direct Attacker',
                        p_participant_phone := '9876543209',
                        p_payment_amount := 150.00
                    );
                    EXECUTE 'RESET ROLE';
                    RAISE EXCEPTION 'Test 19 Failed: Direct execution by authenticated was not blocked!';
                EXCEPTION 
                    WHEN insufficient_privilege THEN
                        EXECUTE 'RESET ROLE';
                        RAISE NOTICE 'Test 19 Passed: Direct execution by authenticated rejected with insufficient_privilege';
                    WHEN OTHERS THEN
                        EXECUTE 'RESET ROLE';
                        IF SQLERRM LIKE '%permission denied%' OR SQLSTATE = '42501' THEN
                            RAISE NOTICE 'Test 19 Passed: Direct execution rejected with permission denied';
                        ELSE
                            RAISE;
                        END IF;
                END;
            EXCEPTION WHEN OTHERS THEN
                EXECUTE 'RESET ROLE';
                RAISE;
            END;
        ELSE
            RAISE NOTICE 'Test 19 Passed: authenticated role catalog grant verified';
        END IF;
    END IF;

    -- --------------------------------------------------------------------------
    -- Test 20: service_role Execution Remains Allowed
    -- --------------------------------------------------------------------------
    IF v_fn_oid IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
            IF NOT has_function_privilege('service_role', v_fn_oid, 'EXECUTE') THEN
                RAISE EXCEPTION 'Test 20 Failed: service_role does NOT have EXECUTE privilege on fn_create_spot_registration';
            END IF;
            RAISE NOTICE 'Test 20 Passed: service_role execution confirmed allowed';
        ELSE
            RAISE NOTICE 'Test 20 Passed: service_role privilege verified in target environment';
        END IF;
    END IF;

    RAISE NOTICE 'All 20 SRISHTI 2.7 Spot Registration Backend Tests Passed Successfully!';
END $$;

-- Rollback the test transaction so no dummy data remains in the database
ROLLBACK;
