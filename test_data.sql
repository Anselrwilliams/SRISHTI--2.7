-- ==============================================================================
-- SRISHTI 2.7 — SQL Test Data for Attendance Workflow Verification
-- ==============================================================================
-- This script sets up:
--   1. Three test participants (TEST-SRI27-001, TEST-SRI27-002, TEST-SRI27-003)
--   2. Two test events (TEST-EV-01: Code Sprint, TEST-EV-02: HackAI)
--   3. Event registrations connecting the participants to the events
--
-- Safe to run in Supabase SQL Editor.
-- Rollback/cleanup queries are provided at the end of this script.
-- ==============================================================================

BEGIN;

-- 1. Insert 3 Test Participants
INSERT INTO participants (participant_code, name, email, phone, college, department, year)
VALUES
  ('TEST-SRI27-001', 'Rahul Sharma', 'rahul.test@srishti.org', '+91 9876543210', 'Govt Engineering College Thrissur', 'Computer Science', '3rd Year'),
  ('TEST-SRI27-002', 'Ananya Nair', 'ananya.test@srishti.org', '+91 9876543211', 'St. Thomas College (Autonomous)', 'Data Science', '2nd Year'),
  ('TEST-SRI27-003', 'Karthik Raj', 'karthik.test@srishti.org', '+91 9876543212', 'Model Engineering College', 'Electronics & Comm', '4th Year')
ON CONFLICT (participant_code) DO UPDATE
SET
  name = EXCLUDED.name,
  email = EXCLUDED.email,
  phone = EXCLUDED.phone,
  college = EXCLUDED.college,
  department = EXCLUDED.department,
  year = EXCLUDED.year;

-- 2. Insert 2 Test Events
INSERT INTO events (event_code, name, category, venue, date, start_time, end_time)
VALUES
  ('TEST-EV-01', 'Code Sprint (Speed Coding)', 'Coding', 'CS Lab 3', CURRENT_DATE, '10:30:00', '12:30:00'),
  ('TEST-EV-02', 'HackAI 24h Hackathon', 'Web & App', 'Main Auditorium', CURRENT_DATE, '14:00:00', '18:00:00')
ON CONFLICT (event_code) DO UPDATE
SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  venue = EXCLUDED.venue,
  date = EXCLUDED.date;

-- 3. Register Participants for Events
-- Participant 1 (TEST-SRI27-001) registered for BOTH events
INSERT INTO registrations (participant_id, event_id, status)
SELECT p.id, e.id, 'registered'
FROM participants p, events e
WHERE p.participant_code = 'TEST-SRI27-001'
  AND e.event_code IN ('TEST-EV-01', 'TEST-EV-02')
ON CONFLICT (participant_id, event_id) DO NOTHING;

-- Participant 2 (TEST-SRI27-002) registered ONLY for Code Sprint (TEST-EV-01)
INSERT INTO registrations (participant_id, event_id, status)
SELECT p.id, e.id, 'registered'
FROM participants p, events e
WHERE p.participant_code = 'TEST-SRI27-002'
  AND e.event_code = 'TEST-EV-01'
ON CONFLICT (participant_id, event_id) DO NOTHING;

-- Participant 3 (TEST-SRI27-003) registered ONLY for HackAI (TEST-EV-02)
INSERT INTO registrations (participant_id, event_id, status)
SELECT p.id, e.id, 'registered'
FROM participants p, events e
WHERE p.participant_code = 'TEST-SRI27-003'
  AND e.event_code = 'TEST-EV-02'
ON CONFLICT (participant_id, event_id) DO NOTHING;

COMMIT;

-- ==============================================================================
-- VERIFICATION QUERIES (Optional checks)
-- ==============================================================================
-- SELECT participant_code, name FROM participants WHERE participant_code LIKE 'TEST-%';
-- SELECT event_code, name FROM events WHERE event_code LIKE 'TEST-%';
-- SELECT p.participant_code, e.event_code, r.status
-- FROM registrations r
-- JOIN participants p ON p.id = r.participant_id
-- JOIN events e ON e.id = r.event_id
-- WHERE p.participant_code LIKE 'TEST-%';

-- ==============================================================================
-- CLEANUP SCRIPT (Run when you want to remove this test data)
-- ==============================================================================
/*
BEGIN;
DELETE FROM event_attendance
WHERE participant_id IN (SELECT id FROM participants WHERE participant_code LIKE 'TEST-%');

DELETE FROM arrival_checkins
WHERE participant_id IN (SELECT id FROM participants WHERE participant_code LIKE 'TEST-%');

DELETE FROM registrations
WHERE participant_id IN (SELECT id FROM participants WHERE participant_code LIKE 'TEST-%');

DELETE FROM events
WHERE event_code LIKE 'TEST-%';

DELETE FROM participants
WHERE participant_code LIKE 'TEST-%';
COMMIT;
*/
