-- Explicit, default-deny access control for the private 'kit-recordings' bucket.
-- All legitimate access goes through server functions using the service role,
-- which bypasses RLS. anon/authenticated clients get no direct access.

DROP POLICY IF EXISTS "kit_recordings_no_public_select" ON storage.objects;
DROP POLICY IF EXISTS "kit_recordings_no_public_insert" ON storage.objects;
DROP POLICY IF EXISTS "kit_recordings_no_public_update" ON storage.objects;
DROP POLICY IF EXISTS "kit_recordings_no_public_delete" ON storage.objects;

CREATE POLICY "kit_recordings_no_public_select"
ON storage.objects FOR SELECT TO anon, authenticated
USING (bucket_id <> 'kit-recordings' AND false);

CREATE POLICY "kit_recordings_no_public_insert"
ON storage.objects FOR INSERT TO anon, authenticated
WITH CHECK (bucket_id <> 'kit-recordings' AND false);

CREATE POLICY "kit_recordings_no_public_update"
ON storage.objects FOR UPDATE TO anon, authenticated
USING (bucket_id <> 'kit-recordings' AND false)
WITH CHECK (bucket_id <> 'kit-recordings' AND false);

CREATE POLICY "kit_recordings_no_public_delete"
ON storage.objects FOR DELETE TO anon, authenticated
USING (bucket_id <> 'kit-recordings' AND false);