DROP POLICY IF EXISTS "Devices manage their own notes" ON public.kit_notes;
DROP POLICY IF EXISTS "Devices manage their own runs" ON public.kit_runs;

REVOKE ALL ON public.kit_notes FROM anon, authenticated;
REVOKE ALL ON public.kit_runs FROM anon, authenticated;

GRANT ALL ON public.kit_notes TO service_role;
GRANT ALL ON public.kit_runs TO service_role;

ALTER TABLE public.kit_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kit_runs ENABLE ROW LEVEL SECURITY;

DROP FUNCTION IF EXISTS public.kit_current_device();