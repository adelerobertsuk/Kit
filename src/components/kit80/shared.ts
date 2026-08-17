export type Category = "IDEA" | "TASK" | "NOTE";

export type Persona = "KIT" | "SASS" | "PURSUIT";

/** Dashboard driving modes bind the red console buttons to AI behaviour. */
export type DriveMode = "NORMAL" | "AUTO" | "PURSUIT";

export const DRIVE_MODES: Array<{
  id: DriveMode;
  label: string;
  blurb: string;
  persona: Persona;
  speaks: boolean;
}> = [
  {
    id: "NORMAL",
    label: "NORMAL CRUISE",
    blurb: "SILENT LOGGING • NO VOICE REPLY",
    persona: "KIT",
    speaks: false,
  },
  {
    id: "AUTO",
    label: "AUTO CRUISE",
    blurb: "SASSY '80s CO-PILOT • TALKS BACK",
    persona: "SASS",
    speaks: true,
  },
  {
    id: "PURSUIT",
    label: "PURSUIT MODE",
    blurb: "FULL PURSUIT AI • MAX BANTER",
    persona: "PURSUIT",
    speaks: true,
  },
];

const MODE_KEY = "kit.mode.v1";

export function loadMode(): DriveMode {
  if (typeof window === "undefined") return "NORMAL";
  const v = window.localStorage.getItem(MODE_KEY);
  return v === "AUTO" || v === "PURSUIT" ? v : "NORMAL";
}

export function saveMode(m: DriveMode) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(MODE_KEY, m);
}

const PERSONA_KEY = "kit.persona.v1";

export function loadPersona(): Persona {
  if (typeof window === "undefined") return "KIT";
  return window.localStorage.getItem(PERSONA_KEY) === "SASS" ? "SASS" : "KIT";
}

export function savePersona(p: Persona) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(PERSONA_KEY, p);
}

/** KITT dashboard lamps map 1:1 to the archive's memory categories. */
export const CATEGORY_LAMPS: Array<{
  code: string;
  category: Category;
  label: string;
}> = [
  { code: "CRE", category: "IDEA", label: "CREATIVE" },
  { code: "RFL", category: "NOTE", label: "DAILY REFLECTION" },
  { code: "ACT", category: "TASK", label: "HEALTH / ACTION" },
];

export type CloudRecording = {
  id: string;
  category: string;
  transcript: string;
  duration_sec: number;
  marks: number;
  created_at: string;
  title: string | null;
  summary: string | null;
  mood: string | null;
  audioUrl: string | null;
  photoUrl: string | null;
  /** True when the entry lives only in this browser (cloud save unavailable). */
  local?: boolean;
};

/** Rack colour language: pink = creative, amber = daily reflection, green = health / action. */
export function tagOf(category: string) {
  if (category === "IDEA")
    return { color: "var(--color-vhs-pink)", label: "CREATIVE", tape: "SUPER VHS" };
  if (category === "TASK")
    return { color: "var(--color-vhs-green)", label: "HEALTH / ACTION", tape: "HQ T-120" };
  return { color: "var(--color-vhs-amber)", label: "DAILY REFLECTION", tape: "T-120" };
}

export function fmt(t: number) {
  const m = Math.floor(t / 60)
    .toString()
    .padStart(2, "0");
  const s = Math.floor(t % 60)
    .toString()
    .padStart(2, "0");
  return `${m}:${s}`;
}

export function fmtLong(t: number) {
  const c = Math.floor((t % 1) * 100)
    .toString()
    .padStart(2, "0");
  return `${fmt(t)}.${c}`;
}

export async function fileToBase64(file: Blob): Promise<string> {
  const buf = new Uint8Array(await file.arrayBuffer());
  let bin = "";
  for (let i = 0; i < buf.length; i++) bin += String.fromCharCode(buf[i]!);
  return btoa(bin);
}