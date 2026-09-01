# Kit product north star

Kit is a retro voice-note journal — the antidote to slick, sterile AI interfaces. It's a hands-free way to capture a thought or a moment, wrapped in a nostalgic 80s persona, aimed at people who want less screen and less "smart" in their life, not more.

- The retro persona and ritual are the product. Nostalgia and simplicity are the pitch, not intelligence.
- AI (currently Gemini) stays wired up under the hood for replies and summarization, but it is backgrounded — a capability Kit uses, never the headline feature or the thing being sold.
- The journal (Memory Bank) is the durable output that matters most; the raw AI exchange is secondary to it.
- Kit is presently the only skin. Do not build a skin picker, multi-persona switcher, or "Penny" work as part of this v1 — that's shelved, not day-one scope.

## The Chair

Top of Kit is who is in the seat. Three seats, one per red button:

- **Normal Cruise / Diane** — the cassette. Cooper to Diane. Talk to text. No AI reply. Just write it down.
- **Auto Cruise** — the lightweight friend. Kit reacts out loud in a sentence or two. Snappy, not deep.
- **Pursuit Mode / Kit** — the deep partner. Talks back on a walk, works the idea with you, files a debrief with next steps when the session ends. Cute, not clingy.

MEM on the side lights is memory, not a fourth mode. The bigger Auto Cruise vision (media, glasses, shopping) still lands in that same seat later — it is not a new button.

## Core experience

The user opens Kit, picks who is in the seat, taps or holds the voice control, speaks naturally, and optionally hears a spoken reply (Auto Cruise and Pursuit Mode; Normal Cruise stays silent). Kit owns the interaction channel, so it receives both the user's transcript and the model's exact response; do not try to record or scrape another AI app.

Persist every user turn before making a network request. Persist every successful model response immediately. A provider failure, app termination, or flat battery must never erase captured speech.

When the user taps **End Session** or says a closing phrase such as **"Goodnight, Kit"**, **"Goodnight, Diane"**, or **"save this to my journal,"** summarize the full session and save one durable Memory Bank entry. If AI summarization is unavailable, save a clearly labelled local transcript fallback that can be enhanced later.

## Architecture rule

Keep provider-specific code behind the client boundary. The journal, session persistence, voice interface, sharing, and skin belong to Kit and must not depend on Gemini-specific storage or UI. Gemini is the current engine, not the product identity — this matters more now than before, since AI being backgrounded in the product pitch means it should stay easy to swap, reduce, or drop later without touching the journal itself.

## Current test acceptance

1. Start a voice session in Kit.
2. Complete at least two spoken turns with Gemini (Pursuit Mode).
3. Say "Goodnight, Kit."
4. Kit automatically ends the session, creates a journal summary, displays `SAVED`, and places the entry at the top of the Memory Bank.
5. Relaunching Kit preserves the saved entry.
6. Repeating the test offline still creates a fallback entry and never loses the user's transcript.
7. Switch to Normal Cruise (Diane). Speak. Diane writes without an AI reply.
8. Switch to Auto Cruise. Speak. Kit replies out loud in a sentence or two.

Do not broaden the first version into a model marketplace, account system, or skin store until this complete loop is reliable on a physical iPhone and AirPods.
