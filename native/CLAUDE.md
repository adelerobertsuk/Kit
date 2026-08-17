# KITT product north star

KITT is a retro voice-note journal — the antidote to slick, sterile AI interfaces. It's a hands-free way to capture a thought or a moment, wrapped in a nostalgic 80s Knight Rider persona, aimed at people who want less screen and less "smart" in their life, not more.

- The retro persona and ritual are the product. Nostalgia and simplicity are the pitch, not intelligence.
- AI (currently Gemini) stays wired up under the hood for replies and summarization, but it is backgrounded — a capability KITT uses, never the headline feature or the thing being sold.
- The journal (Memory Bank) is the durable output that matters most; the raw AI exchange is secondary to it.
- KITT is presently the only skin. Do not build a skin picker, multi-persona switcher, or "Penny" work as part of this v1 — that's shelved, not day-one scope.

## Core experience

The user opens KITT, taps or holds the voice control, speaks naturally, optionally hears a short reply, and continues the conversation. KITT owns the interaction channel, so it receives both the user's transcript and the model's exact response; do not try to record or scrape another AI app.

Persist every user turn before making a network request. Persist every successful model response immediately. A provider failure, app termination, or flat battery must never erase captured speech.

When the user taps **End Session** or says a closing phrase such as **"Goodnight, KITT"** or **"save this to my journal,"** summarize the full session and save one durable Memory Bank entry. If AI summarization is unavailable, save a clearly labelled local transcript fallback that can be enhanced later.

## Architecture rule

Keep provider-specific code behind the client boundary. The journal, session persistence, voice interface, sharing, and skin belong to KITT and must not depend on Gemini-specific storage or UI. Gemini is the current engine, not the product identity — this matters more now than before, since AI being backgrounded in the product pitch means it should stay easy to swap, reduce, or drop later without touching the journal itself.

## Current test acceptance

1. Start a voice session in KITT.
2. Complete at least two spoken turns with Gemini.
3. Say "Goodnight, KITT."
4. KITT automatically ends the session, creates a journal summary, displays `SAVED`, and places the entry at the top of the Memory Bank.
5. Relaunching KITT preserves the saved entry.
6. Repeating the test offline still creates a fallback entry and never loses the user's transcript.

Do not broaden the first version into a model marketplace, account system, or skin store until this complete loop is reliable on a physical iPhone and AirPods.
