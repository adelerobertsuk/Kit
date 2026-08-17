import { createFileRoute } from "@tanstack/react-router";
import { useCallback, useEffect, useState } from "react";
import { Archive, BrainCircuit, Gauge } from "lucide-react";
import { listRecordings } from "@/lib/recordings.functions";
import { listLocalRecordings } from "@/lib/local-vault";
import { ConsoleTab } from "@/components/kit80/ConsoleTab";
import { RacksRoom } from "@/components/kit80/RacksRoom";
import { SmartKit } from "@/components/kit80/SmartKit";
import { playSfx } from "@/lib/sfx";
import type { CloudRecording } from "@/components/kit80/shared";

const TITLE = "KIT — Retro Voice AI & VHS Memory Archive";
const DESC =
  "KIT is an 80s KITT-console voice journal: hands-free capture, live transcription, a VHS rack archive and AI mood reports on dot-matrix paper.";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: TITLE },
      { name: "description", content: DESC },
      { property: "og:title", content: TITLE },
      { property: "og:description", content: DESC },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Index,
});

type Tab = "CONSOLE" | "RACKS" | "SMART";

const TABS: Array<[Tab, string, typeof Gauge]> = [
  ["CONSOLE", "CONSOLE", Gauge],
  ["RACKS", "RACKS ROOM", Archive],
  ["SMART", "SMART KIT", BrainCircuit],
];

function Index() {
  const [tab, setTab] = useState<Tab>("CONSOLE");
  const [vault, setVault] = useState<CloudRecording[]>([]);

  const refresh = useCallback(async () => {
    const local = listLocalRecordings();
    try {
      const data = await listRecordings();
      setVault([...(data as unknown as CloudRecording[]), ...local]);
    } catch {
      setVault(local);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  return (
    <main className="grid-bg min-h-screen w-full overflow-x-hidden bg-black px-4 pt-8 pb-32 font-[family-name:var(--font-term)] text-[color:var(--color-led-amber)] sm:px-5">
      <div className="mx-auto flex w-full max-w-md min-w-0 flex-col items-center gap-5">
        <header className="flex w-full flex-col items-center gap-3">
          <h1 className="font-[family-name:var(--font-display)] text-4xl font-bold tracking-[0.32em] text-white">
            K I T
          </h1>
          <span className="glow-teal flex items-center gap-2 rounded-xl border border-[color:color-mix(in_oklab,var(--color-led-teal)_35%,transparent)] bg-[color:oklch(0.16_0.03_220_/_60%)] px-4 py-2 text-[11px] font-medium tracking-[0.2em]">
            <span className="inline-block size-1.5 animate-pulse rounded-full bg-[color:var(--color-led-teal)]" />
            VOICE AI • RETRO MEMORY ARCHIVE
          </span>
        </header>

        {tab === "CONSOLE" && <ConsoleTab vault={vault} onSaved={() => void refresh()} />}
        {tab === "RACKS" && <RacksRoom vault={vault} onChanged={() => void refresh()} />}
        {tab === "SMART" && <SmartKit vault={vault} />}
      </div>

      <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-white/10 bg-black/95 px-4 py-3 backdrop-blur">
        <div className="mx-auto grid max-w-md grid-cols-3 gap-3">
          {TABS.map(([id, label, Icon]) => {
            const active = tab === id;
            return (
              <button
                key={id}
                type="button"
                aria-pressed={active}
                onClick={() => {
                  playSfx("select");
                  setTab(id);
                }}
                className="hifi-card flex flex-col items-center gap-1 py-2 text-[10px] font-bold tracking-[0.2em]"
                style={{
                  color: active ? "var(--color-led-red)" : "var(--color-led-amber)",
                  textShadow: "0 0 10px currentColor",
                  boxShadow: active
                    ? "0 0 20px color-mix(in oklab, var(--color-led-red) 45%, transparent), inset 0 -3px 8px oklch(0 0 0 / 60%)"
                    : undefined,
                }}
              >
                <Icon size={16} />
                {label}
              </button>
            );
          })}
        </div>
      </nav>
    </main>
  );
}
