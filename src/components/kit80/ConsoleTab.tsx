import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Bookmark } from "lucide-react";
import { saveRecording } from "@/lib/recordings.functions";
import { playSfx } from "@/lib/sfx";
import { addLocalRecording } from "@/lib/local-vault";
import {
  CATEGORY_LAMPS,
  DRIVE_MODES,
  fileToBase64,
  fmtLong,
  loadMode,
  saveMode,
  savePersona,
  tagOf,
  type Category,
  type CloudRecording,
  type DriveMode,
} from "./shared";

type Status = "ready" | "listening" | "processing";

const BAR_COUNT = 3;
const SEGMENTS = 16;
const SILENCE_MS = 2000;

export function ConsoleTab({
  vault,
  onSaved,
}: {
  vault: CloudRecording[];
  onSaved: () => void;
}) {
  const [status, setStatus] = useState<Status>("ready");
  const [elapsed, setElapsed] = useState(0);
  const [levels, setLevels] = useState<number[]>(() => Array(BAR_COUNT).fill(0));
  const [lines, setLines] = useState<string[]>([]);
  const [interim, setInterim] = useState("");
  const [mode, setMode] = useState<DriveMode>("NORMAL");
  const [lock, setLock] = useState<Category | null>(null);
  const [cloudStatus, setCloudStatus] = useState("CLOUD LINK IDLE");
  const [summary, setSummary] = useState<{
    category: Category;
    title: string;
    duration: number;
    transcript: string;
    aiSummary: string;
  } | null>(null);

  const raf = useRef<number | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const ctxRef = useRef<AudioContext | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const recogRef = useRef<any>(null);
  const mediaRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const silenceRef = useRef<number | null>(null);
  const startedAt = useRef(0);
  const endRef = useRef<() => void>(() => {});
  const termRef = useRef<HTMLDivElement | null>(null);

  const drive = DRIVE_MODES.find((m) => m.id === mode) ?? DRIVE_MODES[0]!;

  const teardown = useCallback(() => {
    if (raf.current) cancelAnimationFrame(raf.current);
    raf.current = null;
    if (silenceRef.current) window.clearTimeout(silenceRef.current);
    silenceRef.current = null;
    try {
      recogRef.current?.stop();
    } catch {
      /* noop */
    }
    recogRef.current = null;
    try {
      if (mediaRef.current && mediaRef.current.state !== "inactive") mediaRef.current.stop();
    } catch {
      /* noop */
    }
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
    void ctxRef.current?.close();
    ctxRef.current = null;
    analyserRef.current = null;
  }, []);

  useEffect(() => teardown, [teardown]);

  useEffect(() => {
    const m = loadMode();
    setMode(m);
    savePersona(DRIVE_MODES.find((d) => d.id === m)?.persona ?? "KIT");
  }, []);

  const counts = useMemo(() => {
    const c: Record<string, number> = {};
    vault.forEach((v) => {
      c[v.category] = (c[v.category] ?? 0) + 1;
    });
    return c;
  }, [vault]);

  useEffect(() => {
    termRef.current?.scrollTo({ top: termRef.current.scrollHeight });
  }, [lines, interim]);

  const loop = useCallback(() => {
    const analyser = analyserRef.current;
    const next: number[] = [];
    if (analyser) {
      const data = new Uint8Array(analyser.frequencyBinCount);
      analyser.getByteFrequencyData(data);
      const chunk = Math.floor(data.length / BAR_COUNT);
      for (let i = 0; i < BAR_COUNT; i++) {
        let sum = 0;
        for (let j = 0; j < chunk; j++) sum += data[i * chunk + j] ?? 0;
        next.push(Math.min(1, sum / chunk / 140));
      }
    } else {
      for (let i = 0; i < BAR_COUNT; i++) {
        next.push(0.25 + Math.abs(Math.sin(Date.now() / (220 + i * 60))) * 0.7);
      }
    }
    setLevels(next);
    setElapsed((performance.now() - startedAt.current) / 1000);
    raf.current = requestAnimationFrame(loop);
  }, []);

  const armSilence = useCallback(() => {
    if (silenceRef.current) window.clearTimeout(silenceRef.current);
    silenceRef.current = window.setTimeout(() => endRef.current(), SILENCE_MS);
  }, []);

  const start = useCallback(async () => {
    if (status !== "ready") return;
    playSfx("start");
    try {
      window.speechSynthesis?.cancel();
    } catch {
      /* noop */
    }
    startedAt.current = performance.now();
    setElapsed(0);
    setSummary(null);
    setLines([`> SESSION OPENED — ${drive.label} — MIC ARMED`]);
    setInterim("");
    setStatus("listening");
    try {
      if (!navigator.mediaDevices?.getUserMedia) {
        throw new Error("unsupported");
      }
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;
      const AC: typeof AudioContext =
        (window as any).AudioContext ?? (window as any).webkitAudioContext;
      const ctx = new AC();
      if (ctx.state === "suspended") await ctx.resume();
      ctxRef.current = ctx;
      const analyser = ctx.createAnalyser();
      analyser.fftSize = 256;
      ctx.createMediaStreamSource(stream).connect(analyser);
      analyserRef.current = analyser;
      chunksRef.current = [];
      // Normal Cruise is Cooper to Diane: text only. Do not keep an audio file.
      if (drive.id === "NORMAL") {
        mediaRef.current = null;
        setLines((l) => [...l, "> TEXT TAPE — NO AUDIO FILE"]);
      } else {
        try {
          const preferred = ["audio/webm;codecs=opus", "audio/webm", "audio/mp4", "audio/ogg"].find(
            (t) =>
              typeof MediaRecorder !== "undefined" &&
              typeof MediaRecorder.isTypeSupported === "function" &&
              MediaRecorder.isTypeSupported(t),
          );
          const rec = preferred ? new MediaRecorder(stream, { mimeType: preferred }) : new MediaRecorder(stream);
          rec.ondataavailable = (e) => {
            if (e.data.size > 0) chunksRef.current.push(e.data);
          };
          rec.onerror = () => setLines((l) => [...l, "> RECORDER FAULT — TEXT ONLY"]);
          rec.start(1000);
          mediaRef.current = rec;
        } catch {
          mediaRef.current = null;
          setLines((l) => [...l, "> AUDIO RECORDER UNSUPPORTED — TEXT ONLY"]);
        }
      }
    } catch (err) {
      analyserRef.current = null;
      const name = (err as { name?: string })?.name ?? "";
      const msg =
        name === "NotAllowedError" || name === "SecurityError"
          ? "> MIC BLOCKED — ALLOW MICROPHONE ACCESS IN YOUR BROWSER"
          : name === "NotFoundError" || name === "OverconstrainedError"
            ? "> NO MICROPHONE FOUND — CONNECT ONE AND RETRY"
            : "> MIC UNAVAILABLE — SIMULATING SIGNAL";
      setLines((l) => [...l, msg]);
    }

    const SR = (window as any).SpeechRecognition ?? (window as any).webkitSpeechRecognition;
    if (SR) {
      const recog = new SR();
      recog.continuous = true;
      recog.interimResults = true;
      recog.lang = "en-GB";
      recog.onresult = (e: any) => {
        let live = "";
        for (let i = e.resultIndex; i < e.results.length; i++) {
          const res = e.results[i];
          const text = String(res[0]?.transcript ?? "").trim();
          if (!text) continue;
          if (res.isFinal) {
            setLines((l) => [...l, `> Transcribing: ${text}`]);
            live = "";
          } else {
            live = text;
          }
        }
        setInterim(live);
        armSilence();
      };
      recog.onerror = () => setInterim("");
      try {
        recog.start();
        recogRef.current = recog;
      } catch {
        recogRef.current = null;
      }
    } else {
      setLines((l) => [...l, "> SPEECH ENGINE NOT SUPPORTED IN THIS BROWSER"]);
    }

    raf.current = requestAnimationFrame(loop);
  }, [status, loop, armSilence, drive]);

  const end = useCallback(() => {
    if (status !== "listening") return;
    playSfx("stop");
    const duration = elapsed;
    const transcript = lines
      .filter((l) => l.startsWith("> Transcribing:"))
      .map((l) => l.replace("> Transcribing:", "").trim())
      .join(" ");
    const recorder = mediaRef.current;
    const stopped = new Promise<Blob | null>((resolve) => {
      if (!recorder || recorder.state === "inactive") return resolve(null);
      recorder.onstop = () => {
        const type = recorder.mimeType || "audio/webm";
        resolve(chunksRef.current.length ? new Blob(chunksRef.current, { type }) : null);
      };
      try {
        recorder.stop();
      } catch {
        resolve(null);
      }
    });
    teardown();
    setInterim("");
    setLevels(Array(BAR_COUNT).fill(0));
    setStatus("processing");
    setLines((l) => [...l, "> SIGNAL CLOSED — PROCESSING MEMORY"]);

    void (async () => {
      const category: Category = lock ?? (duration > 12 ? "IDEA" : "NOTE");

      if (drive.id === "NORMAL") {
        const local = addLocalRecording({
          category,
          transcript,
          duration_sec: duration,
          audioDataUrl: null,
        });
        setCloudStatus("SAVED ON THIS DEVICE");
        setSummary({
          category,
          title: local.title ?? "TAPE",
          duration,
          transcript,
          aiSummary: "",
        });
        setLines((l) => [...l, "> TAPE FILED — RACKS ROOM"]);
        onSaved();
        setStatus("ready");
        setElapsed(0);
        return;
      }

      setCloudStatus("UPLOADING TO CLOUD…");
      let audio_base64: string | undefined;
      let audio_mime: string | undefined;
      const blob = await stopped;
      if (blob && blob.size > 0 && blob.size < 8_000_000) {
        audio_base64 = await fileToBase64(blob);
        audio_mime = blob.type;
      }
      try {
        const saved = await saveRecording({
          data: {
            category,
            persona: drive.persona,
            force_category: lock !== null,
            transcript,
            duration_sec: Math.round(duration),
            marks: 0,
            ...(audio_base64 ? { audio_base64, audio_mime } : {}),
          },
        });
        setSummary({
          category: (saved.category as Category) ?? category,
          title: saved.title,
          duration,
          transcript: saved.transcript || transcript,
          aiSummary: saved.summary,
        });
        setCloudStatus(saved.ai ? "KITT ANALYSED • SAVED" : "SAVED TO CLOUD");
        if (drive.speaks && saved.summary) {
          try {
            const u = new SpeechSynthesisUtterance(saved.summary);
            u.rate = drive.id === "PURSUIT" ? 1.15 : 1;
            u.pitch = drive.id === "PURSUIT" ? 0.85 : 1.1;
            window.speechSynthesis?.speak(u);
            setLines((l) => [...l, `> ${drive.label}: ${saved.summary}`]);
          } catch {
            /* noop */
          }
        }
        onSaved();
      } catch {
        // Cloud unreachable / locked — keep the memo on this device instead.
        const local = addLocalRecording({
          category,
          transcript,
          duration_sec: duration,
          audioDataUrl:
            audio_base64 && audio_mime ? `data:${audio_mime};base64,${audio_base64}` : null,
        });
        setCloudStatus("CLOUD OFFLINE • SAVED ON THIS DEVICE");
        setSummary({
          category,
          title: local.title ?? "VOICE MEMO",
          duration,
          transcript,
          aiSummary: "",
        });
        onSaved();
      }
      setStatus("ready");
      setElapsed(0);
    })();
  }, [status, elapsed, lines, teardown, onSaved, lock, drive]);

  useEffect(() => {
    endRef.current = end;
  }, [end]);

  const recording = status === "listening";

  return (
    <div className="mx-auto flex w-full max-w-md flex-col items-center gap-5">
      <div className="flex w-full items-stretch justify-center gap-3">
        <div className="flex w-14 shrink-0 flex-col gap-3 rounded-2xl bg-[oklch(0.16_0_0)] p-2 sm:w-16">
          {CATEGORY_LAMPS.map((lamp) => {
            const active = lock === lamp.category;
            const color = tagOf(lamp.category).color;
            return (
              <Lamp
                key={lamp.code}
                label={lamp.code}
                sub={String(counts[lamp.category] ?? 0).padStart(2, "0")}
                color={color}
                active={active}
                title={`Lock this tape to ${lamp.label}`}
                onPress={() => {
                  playSfx("select");
                  setLock(active ? null : lamp.category);
                }}
              />
            );
          })}
          <Lamp
            label="AUTO"
            sub="AI"
            color="oklch(0.8 0.16 65)"
            active={lock === null}
            title="Let KIT classify the memory automatically"
            onPress={() => {
              playSfx("select");
              setLock(null);
            }}
          />
        </div>

        <div className="flex min-w-0 flex-1 flex-col gap-3">
          <button
            type="button"
            onClick={recording ? end : start}
            disabled={status === "processing"}
            aria-label={recording ? "Stop capture and save" : "Start capture"}
            className="led-floor hifi-well p-4"
          >
            <div className="flex h-52 items-end justify-center gap-3">
              {levels.map((lv, i) => (
                <div key={i} className="flex flex-col-reverse gap-[4px]">
                  {Array.from({ length: SEGMENTS }).map((_, s) => {
                    const boost = i === 1 ? 1.15 : 0.9;
                    const on = recording && s < Math.round(Math.min(1, lv * boost) * SEGMENTS);
                    return (
                      <span
                        key={s}
                        className="h-[9px] w-6 rounded-[3px] transition-[background,box-shadow] duration-75 sm:w-8"
                        style={{
                          background: on
                            ? "linear-gradient(180deg, oklch(0.72 0.24 27), oklch(0.55 0.23 27))"
                            : "linear-gradient(180deg, oklch(0.26 0.07 27), oklch(0.19 0.05 27))",
                          boxShadow: on
                            ? "0 0 14px color-mix(in oklab, var(--color-led-red) 85%, transparent), inset 0 1px 0 oklch(1 0 0 / 30%)"
                            : "inset 0 1px 0 oklch(1 0 0 / 6%)",
                        }}
                      />
                    );
                  })}
                </div>
              ))}
            </div>
            <div className="glow-red mt-5 flex items-center justify-center gap-2 font-[family-name:var(--font-display)] text-3xl font-semibold tracking-widest">
              {fmtLong(elapsed)}
            </div>
            <p className="mt-2 text-center text-[10px] tracking-[0.3em] text-white/40">
              {status === "processing"
                ? "PROCESSING MEMORY"
                : recording
                  ? "TAP TO STOP & SAVE"
                  : "TAP TO TALK TO KIT"}
            </p>
          </button>

          <div className="flex flex-col gap-2" aria-label="Driving mode">
            {DRIVE_MODES.map((m) => {
              const active = mode === m.id;
              return (
                <button
                  key={m.id}
                  type="button"
                  onClick={() => {
                    playSfx("select");
                    setMode(m.id);
                    saveMode(m.id);
                    savePersona(m.persona);
                    try {
                      window.speechSynthesis?.cancel();
                    } catch {
                      /* noop */
                    }
                  }}
                  aria-pressed={active}
                  className="rounded-lg px-3 py-2 text-center font-[family-name:var(--font-display)] text-sm font-bold tracking-[0.12em]"
                  style={{
                    background: active
                      ? "linear-gradient(180deg, oklch(0.45 0.2 27), oklch(0.3 0.16 27))"
                      : "linear-gradient(180deg, oklch(0.22 0.09 27), oklch(0.15 0.06 27))",
                    color: active ? "oklch(0.12 0.03 27)" : "oklch(0.35 0.14 27)",
                    textShadow: active ? "0 0 12px oklch(0.7 0.24 27)" : "none",
                    boxShadow: active
                      ? "0 0 22px color-mix(in oklab, var(--color-led-red) 45%, transparent), inset 0 1px 0 oklch(1 0 0 / 18%)"
                      : "inset 0 1px 0 oklch(1 0 0 / 6%)",
                  }}
                >
                  {m.label}
                </button>
              );
            })}
          </div>
        </div>

        <div
          aria-label="System status lamps"
          className="flex w-14 shrink-0 flex-col gap-3 rounded-2xl bg-[oklch(0.16_0_0)] p-2 sm:w-16"
        >
          <Lamp label="MIC" color="oklch(0.8 0.16 65)" active={recording} readOnly />
          <Lamp label="REC" color="oklch(0.6 0.25 27)" active={recording} readOnly />
          <Lamp label="AI" color="oklch(0.7 0.16 190)" active={status === "processing"} readOnly />
          <Lamp label="SAV" color="oklch(0.72 0.19 145)" active={summary !== null} readOnly />
        </div>
      </div>

      <p className="glow-amber w-full text-center text-[10px] tracking-[0.28em]">
        {drive.blurb}
      </p>

      <section aria-label="Live transcription drawer" className="hifi-well w-full p-4">
        <div className="mb-2 flex items-center justify-between text-[10px] tracking-[0.3em] text-white/35">
          <span>LIVE SPEECH DRAWER</span>
          <span style={{ color: recording ? "var(--color-led-red)" : undefined }}>
            {recording ? "LIVE" : "IDLE"}
          </span>
        </div>
        <div ref={termRef} className="glow-amber h-28 overflow-y-auto text-[13px] leading-6">
          {lines.length === 0 && !interim && <p className="opacity-50">&gt; AWAITING INPUT_</p>}
          {lines.map((l, i) => (
            <p key={i}>{l}</p>
          ))}
          {interim && <p className="opacity-70">&gt; Transcribing: {interim}_</p>}
        </div>
      </section>

      {summary && (
        <section className="hifi-card animate-fade-in w-full p-6">
          <p className="text-[11px] tracking-[0.3em] text-[color:var(--color-led-amber)]">
            {cloudStatus}
          </p>
          <h2 className="mt-1 font-[family-name:var(--font-display)] text-3xl font-bold tracking-tight text-white">
            {summary.title || "Session Memory"}
          </h2>
          {summary.aiSummary && (
            <p className="mt-2 text-sm leading-6 text-white/60">
              {drive.id === "NORMAL" ? "KITT" : drive.label}: {summary.aiSummary}
            </p>
          )}
          {summary.transcript && (
            <p className="mt-4 font-[family-name:var(--font-display)] text-base leading-7 text-white/85">
              {summary.transcript}
            </p>
          )}
          <p className="mt-4 flex items-center justify-end gap-2 text-[11px] tracking-[0.2em] text-white/35">
            <Bookmark size={12} />
            {summary.category} • {fmtLong(summary.duration)}
          </p>
        </section>
      )}
    </div>
  );
}

function Lamp({
  label,
  sub,
  color,
  active,
  title,
  readOnly,
  onPress,
}: {
  label: string;
  sub?: string;
  color: string;
  active: boolean;
  title?: string;
  readOnly?: boolean;
  onPress?: () => void;
}) {
  const style = {
    background: active ? color : `color-mix(in oklab, ${color} 30%, oklch(0.1 0 0))`,
    color: active ? "oklch(0.12 0.02 60)" : "oklch(0.22 0.05 40)",
    boxShadow: active
      ? `0 0 26px color-mix(in oklab, ${color} 60%, transparent), inset 0 -3px 8px oklch(0 0 0 / 30%)`
      : "inset 0 -3px 8px oklch(0 0 0 / 60%)",
  } as const;
  const inner = (
    <>
      <span className="font-[family-name:var(--font-display)] text-sm font-extrabold tracking-wider sm:text-base">
        {label}
      </span>
      {sub && <span className="text-[9px] font-bold tracking-widest opacity-80">{sub}</span>}
    </>
  );
  const cls =
    "flex h-14 flex-col items-center justify-center rounded-[999px] leading-none transition-[box-shadow,background]";

  if (readOnly) {
    return (
      <div aria-label={`${label} ${active ? "on" : "off"}`} className={cls} style={style}>
        {inner}
      </div>
    );
  }
  return (
    <button type="button" aria-pressed={active} title={title} onClick={onPress} className={cls} style={style}>
      {inner}
    </button>
  );
}
