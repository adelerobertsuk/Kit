import type { CloudRecording } from "@/components/kit80/shared";

const KEY = "kit.localvault.v1";
const MAX_AUDIO_CHARS = 3_500_000; // ~2.6MB of audio, keeps localStorage happy

export type LocalRecording = CloudRecording & { local: true };

function read(): LocalRecording[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.localStorage.getItem(KEY);
    const parsed: unknown = raw ? JSON.parse(raw) : [];
    if (!Array.isArray(parsed)) return [];
    return parsed.filter((r): r is LocalRecording => !!r && typeof r === "object" && "id" in r);
  } catch {
    return [];
  }
}

function write(rows: LocalRecording[]) {
  try {
    window.localStorage.setItem(KEY, JSON.stringify(rows));
  } catch {
    /* quota — drop audio from the oldest entries and retry once */
    try {
      const slim = rows.map((r, i) => (i > 2 ? { ...r, audioUrl: null } : r));
      window.localStorage.setItem(KEY, JSON.stringify(slim));
    } catch {
      /* noop */
    }
  }
}

export function listLocalRecordings(): LocalRecording[] {
  return read().sort((a, b) => (a.created_at < b.created_at ? 1 : -1));
}

export function addLocalRecording(input: {
  category: string;
  transcript: string;
  duration_sec: number;
  title?: string | null;
  summary?: string | null;
  mood?: string | null;
  audioDataUrl?: string | null;
}): LocalRecording {
  const now = new Date();
  const audioUrl =
    input.audioDataUrl && input.audioDataUrl.length < MAX_AUDIO_CHARS ? input.audioDataUrl : null;
  const row: LocalRecording = {
    id:
      typeof crypto !== "undefined" && "randomUUID" in crypto
        ? crypto.randomUUID()
        : `local_${now.getTime()}`,
    category: input.category,
    transcript: input.transcript ?? "",
    duration_sec: Math.max(0, Math.round(input.duration_sec || 0)),
    marks: 0,
    created_at: now.toISOString(),
    title: input.title || `TAPE ${now.toLocaleDateString()}`,
    summary: input.summary ?? "",
    mood: input.mood ?? "",
    audioUrl,
    photoUrl: null,
    local: true,
  };
  write([row, ...read()]);
  return row;
}

export function deleteLocalRecording(id: string) {
  write(read().filter((r) => r.id !== id));
}

export function isLocalId(id: string, rows: CloudRecording[]) {
  return rows.some((r) => r.id === id && (r as LocalRecording).local === true);
}
