// Tiny WebAudio blip generator for retro arcade feedback.
type Sound = "start" | "stop" | "select" | "mark";

let ctx: AudioContext | null = null;

function audio(): AudioContext | null {
  if (typeof window === "undefined") return null;
  const Ctor = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  if (!Ctor) return null;
  ctx ??= new Ctor();
  void ctx.resume();
  return ctx;
}

const RECIPES: Record<Sound, { freq: number[]; dur: number; type: OscillatorType }> = {
  start: { freq: [440, 880], dur: 0.12, type: "square" },
  stop: { freq: [660, 220], dur: 0.16, type: "square" },
  select: { freq: [1200], dur: 0.05, type: "square" },
  mark: { freq: [980, 1320], dur: 0.07, type: "triangle" },
};

export function playSfx(sound: Sound) {
  const ac = audio();
  if (!ac) return;
  const recipe = RECIPES[sound];
  recipe.freq.forEach((f, i) => {
    const osc = ac.createOscillator();
    const gain = ac.createGain();
    const t = ac.currentTime + i * recipe.dur;
    osc.type = recipe.type;
    osc.frequency.setValueAtTime(f, t);
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(0.09, t + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + recipe.dur);
    osc.connect(gain).connect(ac.destination);
    osc.start(t);
    osc.stop(t + recipe.dur + 0.02);
  });
}