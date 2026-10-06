-- ==============================================================================
-- SRISHTI 2.7 Migration: Secure Server-Side Participant OTP Table
-- Target Project: sdkadflrxjdhxduwvrsz
--
-- Security properties:
--   1. Stores ONLY secure cryptographic SHA-256 hash of numeric OTP (never plaintext).
--   2. Strict expiration tracking (10 minutes).
--   3. Failed attempts rate-limiting (max 5 attempts).
--   4. Resend cooldown tracking (60 seconds).
--   5. Full RLS lockdown: Completely inaccessible to anon and authenticated roles.
--      Accessible exclusively by service_role inside Edge Functions.
-- ==============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.participant_otps (
  email text PRIMARY KEY,
  otp_hash text NOT NULL,
  attempts integer NOT NULL DEFAULT 0,
  expires_at timestamptz NOT NULL,
  last_sent_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_participant_otps_expires_at ON public.participant_otps(expires_at);

-- Lockdown permissions: No direct access from client applications
ALTER TABLE public.participant_otps ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.participant_otps FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.participant_otps TO service_role;

COMMIT;
