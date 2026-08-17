CREATE TABLE public.kit_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id text NOT NULL,
  category text NOT NULL DEFAULT 'note',
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.kit_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id text NOT NULL,
  title text NOT NULL DEFAULT 'RUN',
  distance_km numeric NOT NULL DEFAULT 0,
  duration_sec integer NOT NULL DEFAULT 0,
  xp integer NOT NULL DEFAULT 0,
  quote text,
  route jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX kit_notes_device_idx ON public.kit_notes (device_id, created_at DESC);
CREATE INDEX kit_runs_device_idx ON public.kit_runs (device_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.kit_current_device()
RETURNS text
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT nullif(((current_setting('request.headers', true))::json ->> 'x-kit-device'), '')
$$;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.kit_notes TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.kit_runs TO anon, authenticated;
GRANT ALL ON public.kit_notes TO service_role;
GRANT ALL ON public.kit_runs TO service_role;

ALTER TABLE public.kit_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kit_runs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Devices manage their own notes" ON public.kit_notes
  FOR ALL TO anon, authenticated
  USING (device_id = public.kit_current_device())
  WITH CHECK (device_id = public.kit_current_device());

CREATE POLICY "Devices manage their own runs" ON public.kit_runs
  FOR ALL TO anon, authenticated
  USING (device_id = public.kit_current_device())
  WITH CHECK (device_id = public.kit_current_device());