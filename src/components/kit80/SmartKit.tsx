import { useMemo, useState } from "react";
import { Printer } from "lucide-react";
import { fmt, tagOf, type CloudRecording } from "./shared";

export function SmartKit({ vault }: { vault: CloudRecording[] }) {
  const [printed, setPrinted] = useState(false);

  const stats = useMemo(() => {
    const week = vault.filter(
      (r) => Date.now() - new Date(r.created_at).getTime() < 7 * 864e5,
    );
    const seconds = vault.reduce((a, r) => a + r.duration_sec, 0);
    const counts: Record<string, number> = {};
    vault.forEach((r) => {
      counts[r.category] = (counts[r.category] ?? 0) + 1;
    });
    const moods: Record<string, number> = {};
    vault.forEach((r) => {
      if (r.mood) moods[r.mood] = (moods[r.mood] ?? 0) + 1;
    });
    const topMood =
      Object.entries(moods).sort((a, b) => b[1] - a[1])[0]?.[0] ?? "unlogged";
    const words = vault
      .flatMap((r) => (r.transcript ?? "").toLowerCase().match(/[a-z]{5,}/g) ?? [])
      .reduce<Record<string, number>>((acc, w) => {
        acc[w] = (acc[w] ?? 0) + 1;
        return acc;
      }, {});
    const topics = Object.entries(words)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 6)
      .map(([w, n]) => ({ w, n }));
    return { week: week.length, seconds, counts, topMood, topics };
  }, [vault]);

  return (
    <div className="w-full">
      <h2 className="font-[family-name:var(--font-display)] text-2xl font-bold tracking-tight text-white">
        Smart Kit
      </h2>
      <p className="mt-1 text-[11px] tracking-[0.25em] text-white/35">
        AI ANALYTICS • MOOD • TOPICS
      </p>

      <div className="mt-5 grid grid-cols-2 gap-3">
        <Stat label="TAPES" value={String(vault.length).padStart(2, "0")} />
        <Stat label="THIS WEEK" value={String(stats.week).padStart(2, "0")} />
        <Stat label="TOTAL TIME" value={fmt(stats.seconds)} />
        <Stat label="TOP MOOD" value={stats.topMood.toUpperCase()} />
      </div>

      <div className="hifi-card mt-4 p-4">
        <p className="text-[10px] tracking-[0.3em] text-white/35">CATEGORY MIX</p>
        <div className="mt-3 space-y-2">
          {["IDEA", "NOTE", "TASK"].map((c) => {
            const n = stats.counts[c] ?? 0;
            const pct = vault.length ? Math.round((n / vault.length) * 100) : 0;
            const tag = tagOf(c);
            return (
              <div key={c}>
                <div className="flex justify-between text-[10px] tracking-[0.2em] text-white/45">
                  <span>{tag.label}</span>
                  <span>{pct}%</span>
                </div>
                <div className="mt-1 h-2 rounded-full bg-white/10">
                  <div
                    className="h-2 rounded-full"
                    style={{
                      width: `${pct}%`,
                      background: tag.color,
                      boxShadow: `0 0 12px ${tag.color}`,
                    }}
                  />
                </div>
              </div>
            );
          })}
        </div>
      </div>

      <div className="hifi-card mt-4 p-4">
        <p className="text-[10px] tracking-[0.3em] text-white/35">TOPIC SIGNAL</p>
        <div className="mt-3 flex flex-wrap gap-2">
          {stats.topics.length === 0 && (
            <span className="glow-amber text-xs opacity-60">&gt; NO TOPICS YET</span>
          )}
          {stats.topics.map((t) => (
            <span
              key={t.w}
              className="glow-teal rounded-md border border-white/10 px-2 py-1 text-[11px] tracking-[0.15em]"
            >
              {t.w.toUpperCase()} ×{t.n}
            </span>
          ))}
        </div>
      </div>

      <button
        type="button"
        onClick={() => setPrinted((p) => !p)}
        className="btn-solid-amber mt-5 flex w-full items-center justify-center gap-3 py-4 font-[family-name:var(--font-display)] text-base font-bold tracking-[0.2em]"
      >
        <Printer size={18} /> {printed ? "TEAR OFF" : "PRINT DOT-MATRIX SUMMARY"}
      </button>

      {printed && (
        <pre className="dot-matrix animate-fade-in mt-4 overflow-x-auto rounded-sm p-4 text-[13px] leading-[22px]">
{`*  *  *  K I T   S Y S T E M   R E P O R T  *  *  *
------------------------------------------
PRINTED : ${new Date().toLocaleString()}
TAPES   : ${String(vault.length).padStart(3, "0")}
7-DAY   : ${String(stats.week).padStart(3, "0")}
RUNTIME : ${fmt(stats.seconds)}
MOOD    : ${stats.topMood.toUpperCase()}
------------------------------------------
CREATIVE .......... ${String(stats.counts['IDEA'] ?? 0).padStart(3, "0")}
REFLECTION ........ ${String(stats.counts['NOTE'] ?? 0).padStart(3, "0")}
HEALTH / ACTION ... ${String(stats.counts['TASK'] ?? 0).padStart(3, "0")}
------------------------------------------
TOPICS  : ${stats.topics.map((t) => t.w).join(", ") || "n/a"}
------------------------------------------
END OF FEED >> KITT SIGNING OFF`}
        </pre>
      )}
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="hifi-card p-4">
      <p className="text-[10px] tracking-[0.3em] text-white/35">{label}</p>
      <p className="glow-amber mt-1 font-[family-name:var(--font-display)] text-2xl font-bold">
        {value}
      </p>
    </div>
  );
}