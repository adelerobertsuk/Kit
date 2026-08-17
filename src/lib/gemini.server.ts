const MODEL = "gemini-2.5-flash";
const ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

export type Analysis = {
  category: "IDEA" | "TASK" | "NOTE";
  transcript: string;
  summary: string;
  title: string;
  mood: string;
  source: "gemini" | "local";
};

const BASE = `You are KITT, a voice memo analyst.
Return ONLY minified JSON: {"category":"IDEA|TASK|NOTE","transcript":"...","summary":"...","title":"...","mood":"..."}
- transcript: the full verbatim speech from the audio (or clean up the provided text if no audio).
- category: IDEA for concepts/brainstorms, TASK for actionable to-dos/reminders, NOTE for everything else.
- summary: one short sentence (max 18 words).
- title: a punchy VHS-spine style label, 2-4 words, UPPERCASE.
- mood: one lowercase word describing the emotional tone (e.g. calm, excited, tired, focused, anxious).`;

const VOICE: Record<string, string> = {
  KIT: `\nVoice: calm, precise, loyal AI co-pilot. The summary is factual and supportive.`,
  SASS: `\nVoice: a cheeky, witty, sassy '80s co-pilot with attitude. The summary must be a sharp one-liner with dry humour (still accurate, never mean). Titles can be playful.`,
  PURSUIT: `\nVoice: PURSUIT MODE — a supercharged '80s AI co-pilot running hot. The summary is a punchy, high-energy one-liner with sharp banter and a decisive next move implied. Titles are bold and cinematic.`,
};

function coerce(text: string, fallbackTranscript: string): Analysis | null {
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) return null;
  try {
    const raw = JSON.parse(match[0]) as Record<string, unknown>;
    const cat = String(raw['category'] ?? "NOTE").toUpperCase();
    return {
      category: cat === "IDEA" || cat === "TASK" ? cat : "NOTE",
      transcript: String(raw['transcript'] ?? fallbackTranscript ?? "").trim() || fallbackTranscript,
      summary: String(raw['summary'] ?? "").trim(),
      title: String(raw['title'] ?? "").trim().slice(0, 60),
      mood: String(raw['mood'] ?? "").trim().toLowerCase().slice(0, 24),
      source: "gemini",
    };
  } catch {
    return null;
  }
}

export async function analyseSession(input: {
  transcript: string;
  audioBase64?: string | undefined;
  audioMime?: string | undefined;
  persona?: string | undefined;
}): Promise<Analysis | null> {
  const key = process.env['GEMINI_API_KEY'];
  if (!key) return null;
  if (!input.audioBase64 && !input.transcript.trim()) return null;

  const prompt = BASE + (VOICE[input.persona ?? "KIT"] ?? VOICE['KIT']);
  const parts: Array<Record<string, unknown>> = [{ text: prompt }];
  if (input.transcript.trim()) {
    parts.push({ text: `On-device draft transcript: ${input.transcript}` });
  }
  if (input.audioBase64) {
    parts.push({
      inline_data: {
        mime_type: (input.audioMime ?? "audio/webm").split(";")[0],
        data: input.audioBase64,
      },
    });
  }

  try {
    const res = await fetch(`${ENDPOINT}?key=${encodeURIComponent(key)}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts }],
        generationConfig: { temperature: 0.2, responseMimeType: "application/json" },
      }),
    });
    if (!res.ok) {
      console.error(`Gemini analyse failed [${res.status}]: ${await res.text()}`);
      return null;
    }
    const json = (await res.json()) as any;
    const text: string =
      json?.candidates?.[0]?.content?.parts?.map((p: any) => p?.text ?? "").join("") ?? "";
    return coerce(text, input.transcript);
  } catch (err) {
    console.error("Gemini analyse error", err);
    return null;
  }
}
