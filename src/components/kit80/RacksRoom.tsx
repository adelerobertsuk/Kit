import { useEffect, useRef, useState } from "react";
import { Pause, Play, Trash2, X } from "lucide-react";
import { deleteRecording, updateRecording } from "@/lib/recordings.functions";
import { deleteLocalRecording } from "@/lib/local-vault";
import { playSfx } from "@/lib/sfx";
import { fmt, tagOf, type CloudRecording } from "./shared";

export function RacksRoom({
  vault,
  onChanged,
}: {
  vault: CloudRecording[];
  onChanged: () => void;
}) {
  const [openId, setOpenId] = useState<string | null>(null);
  const [draft, setDraft] = useState("");
  const [playingId, setPlayingId] = useState<string | null>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const open = vault.find((v) => v.id === openId) ?? null;

  useEffect(() => {
    return () => {
      audioRef.current?.pause();
      audioRef.current = null;
    };
  }, []);

  function togglePlay(rec: CloudRecording) {
    if (!rec.audioUrl) return;
    if (playingId === rec.id) {
      audioRef.current?.pause();
      setPlayingId(null);
      return;
    }
    audioRef.current?.pause();
    const el = new Audio(rec.audioUrl);
    el.onended = () => setPlayingId(null);
    el.onerror = () => setPlayingId(null);
    audioRef.current = el;
    void el.play().then(
      () => setPlayingId(rec.id),
      () => setPlayingId(null),
    );
  }

  async function erase(rec: CloudRecording) {
    if (rec.local) {
      deleteLocalRecording(rec.id);
    } else {
      try {
        await deleteRecording({ data: { id: rec.id } });
      } catch {
        /* noop */
      }
    }
    if (playingId === rec.id) {
      audioRef.current?.pause();
      setPlayingId(null);
    }
  }

  return (
    <div className="w-full">
      <h2 className="font-[family-name:var(--font-display)] text-2xl font-bold tracking-tight text-white">
        The Racks Room
      </h2>
      <p className="mt-1 text-[11px] tracking-[0.25em] text-white/35">
        {vault.length} TAPES ARCHIVED
      </p>

      <div className="mt-5 flex flex-col gap-2">
        {vault.length === 0 && (
          <p className="glow-amber text-xs tracking-[0.2em] opacity-60">
            &gt; RACKS EMPTY — TALK A TAPE
          </p>
        )}
        {vault.map((r) => {
          const tag = tagOf(r.category);
          return (
            <div key={r.id} className="vhs-spine flex items-stretch gap-2 p-2 text-left">
              <button
                type="button"
                onClick={() => {
                  playSfx("select");
                  setOpenId(r.id);
                  setDraft(r.transcript ?? "");
                }}
                className="flex min-w-0 flex-1 items-stretch gap-2 text-left"
              >
              <span
                className="w-2 shrink-0 rounded-sm"
                style={{ background: tag.color, boxShadow: `0 0 12px ${tag.color}` }}
              />
              <span className="flex w-14 shrink-0 flex-col justify-center rounded-sm bg-black/60 px-1 text-center text-[8px] leading-tight tracking-widest text-white/50">
                {tag.tape}
              </span>
              <span className="vhs-label flex min-w-0 flex-1 items-center px-3 py-3">
                <span
                  className="truncate font-[family-name:var(--font-hand)] text-lg"
                  style={{ color: tag.color, filter: "saturate(0.8) brightness(0.75)" }}
                >
                  {r.title || "UNTITLED TAPE"}
                </span>
              </span>
              <span className="flex w-16 shrink-0 flex-col items-end justify-center gap-1 pr-1 text-[9px] tracking-widest text-white/45">
                <span>{new Date(r.created_at).toLocaleDateString()}</span>
                <span>{fmt(r.duration_sec)}</span>
              </span>
              </button>
              <button
                type="button"
                disabled={!r.audioUrl}
                aria-label={playingId === r.id ? "Pause tape audio" : "Play tape audio"}
                onClick={() => togglePlay(r)}
                className="hifi-card flex w-11 shrink-0 items-center justify-center disabled:opacity-25"
                style={
                  playingId === r.id
                    ? {
                        color: "var(--color-led-red)",
                        boxShadow:
                          "0 0 18px color-mix(in oklab, var(--color-led-red) 55%, transparent)",
                      }
                    : undefined
                }
              >
                {playingId === r.id ? <Pause size={16} /> : <Play size={16} />}
              </button>
            </div>
          );
        })}
      </div>

      {open && (
        <div
          className="fixed inset-0 z-50 flex items-end bg-black/75"
          onClick={() => setOpenId(null)}
        >
          <div
            className="animate-fade-in grid-bg max-h-[88vh] w-full overflow-y-auto rounded-t-3xl border-t border-white/10 bg-black p-5"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <span
                  className="rounded-md px-2 py-1 text-[10px] font-bold tracking-[0.25em]"
                  style={{
                    color: tagOf(open.category).color,
                    background: `color-mix(in oklab, ${tagOf(open.category).color} 16%, transparent)`,
                  }}
                >
                  {tagOf(open.category).label}
                </span>
                <h3 className="mt-2 truncate font-[family-name:var(--font-hand)] text-3xl text-white">
                  {open.title || "UNTITLED TAPE"}
                </h3>
                <p className="text-[11px] tracking-[0.2em] text-white/35">
                  {new Date(open.created_at).toLocaleString()} • {fmt(open.duration_sec)}
                  {open.mood ? ` • MOOD: ${open.mood.toUpperCase()}` : ""}
                </p>
              </div>
              <button
                type="button"
                aria-label="Close tape"
                onClick={() => setOpenId(null)}
                className="hifi-card glow-red p-2"
              >
                <X size={16} />
              </button>
            </div>

            {open.summary && (
              <p className="mt-3 text-sm leading-6 text-white/60">KITT: {open.summary}</p>
            )}
            {open.photoUrl && (
              <img
                src={open.photoUrl}
                alt="Photo attached to this voice entry"
                className="mt-4 max-h-56 w-full rounded-xl object-cover"
              />
            )}
            {open.audioUrl && <audio src={open.audioUrl} controls className="mt-4 w-full" />}
            {!open.audioUrl && (
              <p className="mt-4 text-[11px] tracking-[0.2em] text-white/30">NO AUDIO ON THIS TAPE</p>
            )}

            <textarea
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              rows={6}
              className="hifi-well mt-4 w-full resize-none p-3 font-[family-name:var(--font-term)] text-sm leading-6 text-white/85 outline-none"
            />

            <div className="mt-3 grid grid-cols-2 gap-3">
              <button
                type="button"
                onClick={async () => {
                  try {
                    if (!open.local) {
                      await updateRecording({ data: { id: open.id, transcript: draft } });
                    }
                  } catch {
                    /* noop */
                  }
                  onChanged();
                  setOpenId(null);
                }}
                className="btn-solid-blue py-3 font-[family-name:var(--font-display)] text-sm font-bold tracking-[0.2em]"
              >
                SAVE EDIT
              </button>
              <button
                type="button"
                onClick={async () => {
                  await erase(open);
                  setOpenId(null);
                  onChanged();
                }}
                className="btn-solid-red flex items-center justify-center gap-2 py-3 font-[family-name:var(--font-display)] text-sm font-bold tracking-[0.2em]"
              >
                <Trash2 size={14} /> ERASE
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}