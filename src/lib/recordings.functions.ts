import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

const BUCKET = "kit-recordings";

async function ctx() {
  const { currentDeviceId } = await import("./device-session.server");
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  return { deviceId: await currentDeviceId(), db: supabaseAdmin };
}

export const listRecordings = createServerFn({ method: "GET" }).handler(async () => {
  const { deviceId, db } = await ctx();
  const { data, error } = await db
    .from("kit_recordings")
    .select(
      "id, category, transcript, duration_sec, marks, audio_path, photo_path, title, summary, mood, created_at",
    )
    .eq("device_id", deviceId)
    .order("created_at", { ascending: false })
    .limit(60);
  if (error) throw new Error("Could not load recordings");

  const rows = data ?? [];
  return Promise.all(
    rows.map(async (r) => {
      let audioUrl: string | null = null;
      if (r.audio_path) {
        const { data: signed } = await db.storage
          .from(BUCKET)
          .createSignedUrl(r.audio_path, 60 * 60);
        audioUrl = signed?.signedUrl ?? null;
      }
      let photoUrl: string | null = null;
      if (r.photo_path) {
        const { data: signed } = await db.storage
          .from(BUCKET)
          .createSignedUrl(r.photo_path, 60 * 60);
        photoUrl = signed?.signedUrl ?? null;
      }
      return { ...r, audioUrl, photoUrl };
    }),
  );
});

export const saveRecording = createServerFn({ method: "POST" })
  .inputValidator((input: unknown) =>
    z
      .object({
        category: z.enum(["IDEA", "TASK", "NOTE"]),
        persona: z.enum(["KIT", "SASS", "PURSUIT"]).default("KIT"),
        force_category: z.boolean().default(false),
        transcript: z.string().max(20000).default(""),
        duration_sec: z.number().int().nonnegative().max(86400),
        marks: z.number().int().nonnegative().max(10000),
        // base64 (no data: prefix) — capped at ~8MB of audio
        audio_base64: z.string().max(11_000_000).optional(),
        audio_mime: z.string().max(80).optional(),
        photo_base64: z.string().max(8_000_000).optional(),
        photo_mime: z.string().max(80).optional(),
      })
      .parse(input),
  )
  .handler(async ({ data }) => {
    const { deviceId, db } = await ctx();

    // Gemini (server-side GEMINI_API_KEY) refines transcript + category.
    const { analyseSession } = await import("./gemini.server");
    const ai = await analyseSession({
      transcript: data.transcript,
      audioBase64: data.audio_base64,
      audioMime: data.audio_mime,
      persona: data.persona,
    });
    const category = data.force_category ? data.category : (ai?.category ?? data.category);
    const transcript = (ai?.transcript ?? data.transcript).slice(0, 20000);
    const title = (ai?.title || transcript.split(/\s+/).slice(0, 4).join(" ") || "UNTITLED TAPE")
      .toUpperCase()
      .slice(0, 60);
    const mood = ai?.mood ?? "";

    let audioPath: string | null = null;
    if (data.audio_base64) {
      const mime = data.audio_mime?.split(";")[0] ?? "audio/webm";
      const ext = mime.includes("mp4") ? "mp4" : mime.includes("ogg") ? "ogg" : "webm";
      const bytes = Uint8Array.from(atob(data.audio_base64), (c) => c.charCodeAt(0));
      const path = `${deviceId}/${crypto.randomUUID()}.${ext}`;
      const { error: upErr } = await db.storage
        .from(BUCKET)
        .upload(path, bytes, { contentType: mime, upsert: false });
      if (!upErr) audioPath = path;
    }

    let photoPath: string | null = null;
    if (data.photo_base64) {
      const mime = data.photo_mime?.split(";")[0] ?? "image/jpeg";
      const ext = mime.includes("png") ? "png" : mime.includes("webp") ? "webp" : "jpg";
      const bytes = Uint8Array.from(atob(data.photo_base64), (c) => c.charCodeAt(0));
      const path = `${deviceId}/${crypto.randomUUID()}.${ext}`;
      const { error: upErr } = await db.storage
        .from(BUCKET)
        .upload(path, bytes, { contentType: mime, upsert: false });
      if (!upErr) photoPath = path;
    }

    const { error } = await db.from("kit_recordings").insert({
      device_id: deviceId,
      category,
      transcript,
      duration_sec: data.duration_sec,
      marks: data.marks,
      audio_path: audioPath,
      photo_path: photoPath,
      title,
      summary: ai?.summary ?? "",
      mood,
    });
    if (error) throw new Error("Could not save recording");
    return {
      ok: true,
      stored: audioPath !== null,
      category,
      transcript,
      title,
      mood,
      summary: ai?.summary ?? "",
      ai: ai !== null,
    };
  });

export const updateRecording = createServerFn({ method: "POST" })
  .inputValidator((input: unknown) =>
    z
      .object({
        id: z.string().uuid(),
        title: z.string().max(60).optional(),
        transcript: z.string().max(20000).optional(),
        category: z.enum(["IDEA", "TASK", "NOTE"]).optional(),
      })
      .parse(input),
  )
  .handler(async ({ data }) => {
    const { deviceId, db } = await ctx();
    const patch: { title?: string; transcript?: string; category?: string } = {};
    if (data.title !== undefined) patch.title = data.title.toUpperCase();
    if (data.transcript !== undefined) patch.transcript = data.transcript;
    if (data.category !== undefined) patch.category = data.category;
    if (Object.keys(patch).length === 0) return { ok: true };
    const { error } = await db
      .from("kit_recordings")
      .update(patch)
      .eq("id", data.id)
      .eq("device_id", deviceId);
    if (error) throw new Error("Could not update recording");
    return { ok: true };
  });

export const deleteRecording = createServerFn({ method: "POST" })
  .inputValidator((input: unknown) => z.object({ id: z.string().uuid() }).parse(input))
  .handler(async ({ data }) => {
    const { deviceId, db } = await ctx();
    const { data: row } = await db
      .from("kit_recordings")
      .select("audio_path")
      .eq("id", data.id)
      .eq("device_id", deviceId)
      .maybeSingle();
    if (row?.audio_path) await db.storage.from(BUCKET).remove([row.audio_path]);
    const { error } = await db
      .from("kit_recordings")
      .delete()
      .eq("id", data.id)
      .eq("device_id", deviceId);
    if (error) throw new Error("Could not delete recording");
    return { ok: true };
  });
