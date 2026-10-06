BEGIN;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.participant_otps TO anon, authenticated, service_role;

ALTER TABLE public.participant_otps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role only on participant_otps" ON public.participant_otps;
CREATE POLICY "Service role only on participant_otps" ON public.participant_otps
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

NOTIFY pgrst, 'reload schema';

COMMIT;
