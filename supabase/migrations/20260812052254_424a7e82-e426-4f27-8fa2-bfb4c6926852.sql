CREATE TABLE public.kit_recordings (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  device_id text NOT NULL,
  category text NOT NULL DEFAULT 'NOTE',
  transcript text NOT NULL DEFAULT '',
  duration_sec integer NOT NULL DEFAULT 0,
  marks integer NOT NULL DEFAULT 0,
  audio_path text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

GRANT ALL ON public.kit_recordings TO service_role;

ALTER TABLE public.kit_recordings ENABLE ROW LEVEL SECURITY;

CREATE INDEX kit_recordings_device_created_idx ON public.kit_recordings (device_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER update_kit_recordings_updated_at
BEFORE UPDATE ON public.kit_recordings
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();