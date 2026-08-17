# KIT — Master Strategy & Product Specification

_Renamed 2026-08-10 from KIIT/KITT to KIT — see [naming note](#naming-note) below._

The implementation-ready interaction, bento layout, Memory Card, privacy, Watch, and geofence details live in [v2-ux-spec.md](v2-ux-spec.md).

## 1. Vision
KIT (a nod to Knight Industries Two Thousand, meeting Kate & Adele's Intelligent Interface) is a hands-free, voice-first companion and dynamic session journal built for active movement, creative thought-capture, and personal safety. Designed as the antidote to slick, sterile AI interfaces, KIT pairs a nostalgic 80s/90s skin engine with zero-gaze interaction. By processing short voice micro-bursts in real time, KIT frees users to move, reflect, and navigate the world safely without breaking creative flow or staring at a screen.

**Core value proposition:** “The companion that helps you remember your life while you’re living it.”

**Initial audience:** people whose best thoughts happen away from their desks — walkers, runners, creators, voice thinkers, and anyone whose ideas arrive while moving through real life.

**Core tenet: KIT meets you where you are in life.** The skin engine isn't just cosmetic — each persona is built for a different life stage/audience (nostalgia-driven 80s KIT for older users, soft modular Skin B for journaling-focused users, etc.), so the companion feels native to whoever is using it rather than one-size-fits-all. Beyond audience-segmented skins, KIT also has context-segmented **modes** — e.g. the v3 Mindful Walk luminous-ambient mode for zero-gaze night walking — layered on top of whichever skin is active.

## 2. Decisions Made Tonight (2026-08-09)

- **Product identity & naming hierarchy:**
  - **KIT** — overarching brand and companion engine (allows custom AI persona names per user, e.g. KIT or Penny).
  - **Memory Bank** — the private local vault storing logs, smart silos, and structured micro-bursts.
  - **Memory Cards** — visual, shareable summary artifacts generated post-session.
  - **Running Memory** — the live, in-session contextual memory buffer during an active session (a concept inside KIT, not a separate app).
- **Skin engine targets two audience-segmented personas, plus a context-segmented ambient mode** (revised 2026-08-09 after mapping Kate's icon concepts + Dribbble mood board against Gemini's UI-reference analysis):
  - **Skin A — 80s KIT** (day-one): black/cyan/amber, red LED equalizer. Aimed at older users — nostalgia-driven.
  - **Skin B — 90s Penny Journal**: pastel pink/mint, 8-bit dog paw indicator, *plus* soft rounded Bento-style modular cards (Paperpillar's "Sense") for the post-session Memory Bank Review screen — walks/groceries/creative thoughts organized as clean visual modules instead of data tables. (icon designed, not yet wired into the app)
  - ~~Skin C — Glowing/Minimal companion~~ — retired as a standalone skin; its glowing/ambient aesthetic (Gleb Kuznetsov's glowing-orb/voice-interaction concepts) moves to the **v3 "Mindful Walk" ambient mode** below instead of being tied to one audience/persona.
- **Core interaction loop:** one-tap start, 1.5s Voice Activity Detection (VAD) auto-silence detection, haptic buzz confirmation, and immediate raw audio buffer deletion post-transcription. AirPods gesture start remains a day-one target, but first-turn activation is not yet reliable; see the reliability priorities below.
- **Smart silo classification:** transcripts auto-parse into categories (Groceries/Reminders, Product Ideas, Safety Logs, Movement/Health Stats). *(v2+, not day-one)*
- **Day-one prototype scope (thin slice):**
  - Single-screen SwiftUI layout, 80s KIT Interceptor theme (black/cyan/amber).
  - `AnimatedKITVoiceBox`: 3-column vertical red LED equalizer, bounces with live audio input.
  - Native permissions wired (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`).
  - On-device speech recognition, local text log list.

## 3. Market Positioning & Competitive Moat

KIT does not win by being another transcription utility or screen-first AI diary. Voice-note products can copy summarisation, and platform journals can absorb basic audio capture. KIT’s defensible product is the complete hands-free ritual:

- **Zero-gaze capture:** AirPods/Watch initiation, short VAD-controlled bursts, spoken state, and haptic confirmation.
- **Local-first trust:** durable local capture, explicit provider boundaries, recoverability, and no paywall between a user and memories they already created.
- **Companion identity:** a consistent, customizable presence rather than a meeting bot or generic chatbot.
- **Collectible Era Skins:** Interceptor, Penny Journal, and future original era interpretations that change emotional expression without changing interaction meaning.
- **Memory Cards:** beautiful, privacy-reviewed artifacts that transform a session into something useful and naturally shareable.

The clearest positioning line is: **for people whose best thoughts happen away from their desks.** Safety logging and movement context support that promise, but KIT should not market itself as an emergency-response product until a separately consented and thoroughly tested safety system exists.

## 4. Business Model & Monetisation Hypothesis

Pricing remains a launch experiment, not a locked commitment. The guiding rule is fixed: **existing memories are never paywalled.**

### KIT Free

- Unlimited local capture and basic Memory Bank.
- One complete companion skin chosen during onboarding.
- Basic privacy-reviewed Memory Cards.
- Plain-text and Markdown export.
- Continued access to every memory created on the free or paid plan.

### KIT Plus — target test price £4.99/month or £39.99/year

- AI summaries and Smart Silos.
- Apple Watch companion.
- iCloud sync, backup, and session recovery.
- Photo and movement matching.
- Geofenced shopping prompts and Home Arrival handshake.
- Advanced Memory Card layouts and cross-memory search.
- Multiple personas and AI-provider choices as those features mature.

### Permanent Era Skin purchases

- Individual skin: target £2.99–£4.99.
- Three-skin Era Pack: target £9.99.
- Complete launch collection: target £19.99.
- Each user chooses one full skin free so personalization is part of the core product, not merely a paywall preview.

### Family and local-first options

- **Family target price £59.99/year:** private Memory Bank per person, with separately consented shared grocery silos, arrival acknowledgements, giftable cards, and Family Sharing entitlement.
- **Local/BYO-key lifetime target price £39.99–£59.99:** permanent local features for privacy-conscious users who supply their own supported AI key; hosted AI usage is excluded so the purchase does not create unlimited server liability.

### Organic referral loop

1. A finished session produces a beautiful, privacy-redacted Memory Card.
2. The user explicitly selects its contents and skin.
3. Shared output carries a discreet, removable `Made with Kit` signature.
4. A recipient can discover KIT or unlock the card style without needing an account to view the artifact.
5. “Send this skin to a friend” referrals may reward both people with a promotional skin or subscription offer.

No safety log, exact route, home location, health detail, contact name, or raw transcript is included in a shared card by default.

## 5. Feature Roadmap

**Now (day-one slice / tomorrow's session)**
- 80s KIT UI with an animated three-column, 13-cell red LED voice box.
- One-tap start + 1.5s VAD silence auto-stop + haptic feedback; AirPods first-turn reliability remains open.
- On-device local speech-to-text (`SFSpeechRecognizer`).
- Basic transcript log (plain list, no parsing yet).
- Session battery/time nudge — periodic in-session reminder to log off so the user doesn't run out of battery mid-session.

**Near-term priority (before further feature work)**
- ~~Swap current placeholder/stub intelligence for a real Gemini API backend~~ — done 2026-08-10, `GeminiClient.swift` calls the live Generative Language API.
- Session battery/time nudge — done 2026-08-10, see `BatteryNudgeManager.swift`.

**Reliability priority (GG review, 2026-08-10 — before further feature work)**
GG's read: "a gorgeous voice companion that loses someone's thoughts once will be very difficult to trust again." Recommended order:
1. **Session durability** — Running Memory (`sessionTurns`) only lives in `ConversationManager`'s in-memory array today; if Gemini fails or the app is killed, the whole session is gone unsaved. Needs continuous persistence + crash/battery-loss/network-failure recovery.
2. **On-device speech guarantee** — `SpeechManager` doesn't currently force `requiresOnDeviceRecognition`, so `SFSpeechRecognizer` may silently fall back to Apple's servers. Either set the flag or fix the privacy copy to match reality.
3. **AirPods first-turn gap** — `RemoteControlManager`'s own doc comment admits remote-control events only fire after KIT holds "Now Playing" status (i.e. after its own TTS has played once), so AirPods can't reliably start turn one — contradicts the day-one promise in section 2 above.
4. **API key storage** — `Secrets.swift` is gitignored and untracked (verified 2026-08-10), so it's not currently being committed. Still worth moving to Keychain before any real distribution/TestFlight build.
5. **Interruption recovery** — no explicit handling yet for incoming calls, Siri, alarms, AirPods disconnect, backgrounding, or audio-route changes mid-session.
6. **Real session model** — a session only "starts" once the first speech transcript succeeds. Needs an explicit session object from the moment Start is pressed: id, start time, recovery state, raw-turn policy, local fallback summary.

**Acceptance test (GG, 2026-08-10):** speak a thought, kill the app at the worst possible moment, reopen it — the thought is still there. Nothing below counts as done until this passes:
1. A real `Session` (id, start time) is created the moment Start is pressed, not on first successful transcript.
2. Each transcript is persisted immediately, before the Gemini call — never held only in memory pending a network round-trip.
3. Running Memory is never cleared when AI summarisation fails.
4. A basic local Memory Card is generated when offline or the provider is unavailable.
5. An unfinished session is restored after the app is killed or the battery dies.
6. Explicitly tested: airplane mode, forced termination, incoming calls, AirPods disconnection.

**Build sequence after reliability (GG, 2026-08-10):** durability → Memory Card v1 → dogfood → only then Watch/geofences/monetisation. Do not start Watch, geofences, the Multi-Skin Engine, or paywall work until the acceptance test above passes and Memory Card v1 has been dogfooded across several real sessions.

- ~~**Memory Card v1 scope** (immediately after durability): one Interceptor template, editable title and summary, privacy review step, native Share Sheet, small `Made with Kit` signature.~~ — done 2026-08-10: tap any Memory Bank card to open `MemoryCardReviewView`, edit title/summary, see the privacy notice, then Save privately or Share (renders the card via `ImageRenderer` + native `UIActivityViewController`, with a removable "Made with Kit" signature toggle). Verified in Simulator end to end, including the real Share Sheet opening. Decided 2026-08-10: the Penny template waits — it ships together with Penny as a real selectable skin/persona (v2 Multi-Skin Engine), not ahead of it as a card-only preview.
- **Dogfooding, before any further build-out:** run several real sessions end to end (move → speak → remember → review → share) and record where the phone gets reached for anyway, where Kit talks too much, and whether the resulting card feels worth keeping.
- **Monetisation is explicitly deferred:** don't build the paywall until dogfooding shows people reliably finish sessions, save cards, and voluntarily share them — see [Business Model](#4-business-model--monetisation-hypothesis), which already treats pricing as an experiment, not a commitment.

**Icon (GG, 2026-08-10)**
- New master icon (`kit-icon-concept-v2-1024.png`) live in `AppIcon.appiconset` as of 2026-08-10 — three-column silhouette, taller centre column, no franchise imagery.
- Penny's refined 1024px companion icon is saved as `AppIcon.appiconset/penny-icon-concept-v2-1024.png`: a simplified pink/mint 90s computer-book with a dominant plum pixel paw and three mint status tracks linking it to the KIT family.
- Active-session visual references for both skins are saved in `docs/design/`: identical information hierarchy, translated into dark tactile Interceptor hardware and Penny's warm electronic journal.
- Pre-launch still needed: simplified low-detail version for tiny sizes, dedicated monochrome/tinted iOS variant, and small-size tests at 29/40/60/120px for both icons.
- **Open question raised 2026-08-10: should the user be able to choose their icon/persona (KIT vs. Penny) themselves?** Answer: yes, technically straightforward — iOS supports runtime alternate app icons (`UIApplication.setAlternateIconName`), so a picker (first-launch or in settings) could swap both the home-screen icon and in-app skin/theme together. This is the same idea as the existing "custom persona naming" line below; not day-one, but a natural v2 pairing once both master icons are finalized.

**v2 (post-launch)**
- **Apple Watch tether extension (remote trigger + scanner animation via `WatchConnectivity`) — priority, build as soon as feasible.**
- Geofenced Shopping Loop (CoreLocation 100m geofencing + AirPods audio prompts for grocery silos).
- Home Arrival Handshake (spoken confirmation prompt on re-entering the home geofence; never silently truncate a session because of GPS drift).
- Multi-Skin Engine (Skin B: 90s Penny Journal, incl. Bento-card Memory Bank Review screen) + custom persona naming — see audience-segmented skin list above.
- Photo matching (Photos framework, timestamp-linked to session).
- Share Sheet integration — native iOS share sheet for exporting/sharing privacy-reviewed Memory Cards to Journal, Notes, Day One, and other compatible destinations.

**v3 (long-term)**
- **"Mindful Walk" luminous-ambient mode**: translucent screen glow, voice-reactive aura, minimal-to-no text — for night walks and zero-gaze capture (inspired by Gleb Kuznetsov's "Natural AI" concepts). Context-triggered mode layered over any skin, not a standalone skin.
- Multi-AI companion provider toggle (Siri / Gemini / ChatGPT / Claude).
- Original Era Skin expansion (monetized): Time Circuit, Calm Lens, Star Navigator, Translucent Y2K, and Pocket Console. These may evoke an era but must not reproduce franchise names, voices, prop designs, or protected visual identities without licensing.
- Organic referral engine: “Send this skin to a friend,” gift purchases, and promotional offer codes tied to privacy-safe Memory Cards.
- Hardware/platform exports (Meta Glasses, Live Activities, Lock Screen widgets, Apple Journal/Strava/Markdown export).
- "Silent Guardian" emergency contact alerting — **requires explicit consent-flow design before any build work**, not a code task to pick up casually.

## 6. Open Questions
- Custom AI persona sync across Watch/iPhone when switching skins mid-session.
- Data export schema (JSON vs. raw Markdown) for third-party Memory Card sharing.
- Audio interruption priority (incoming calls/alarms mid-VAD-burst).

## 7. Technical Constraints & Risks
- **Legal/consent (audio recording):** one-party vs. two-party wiretapping consent varies by jurisdiction, especially for incident/conflict logging. KIT must surface a clear local indicator whenever it's actively recording.
- **Multi-AI complexity (v3):** per-provider SDKs, user-supplied API keys, cellular latency mid-session, dropped-connection handling.
- **Costs:** speech recognition + GPS run on-device (Apple native frameworks) — near-zero server cost. LLM summarization costs scale with usage; keep lightweight/pay-per-use.
- **Privacy/local-first:** raw audio buffers are deleted immediately post-transcription. Local transcripts, route, and health data remain in the app sandbox or the user's private iCloud by default. When cloud AI is enabled, the minimum necessary transcript content is sent to the explicitly selected provider for replies or summarisation; this boundary must be disclosed accurately and never described as fully on-device.

## Naming Note

The app and its default persona were originally spelled **KIIT** (double-I, Kate's call, for trademark/availability reasons) with the 80s persona spelled **KITT** (matching Knight Rider's car). Renamed to **KIT** (single I, single T) on 2026-08-10 — the double-I spelling wasn't working for TTS/STT (the persona couldn't reliably say or recognize its own name), and Adele decided a single consistent spelling across app and persona was worth revisiting the trademark question for. If KIT also proves unavailable, **Memory Bank** remains the backup name.

Also on 2026-08-10: the core interaction unit is called a **session**, not a "walk" — KIT doesn't require the user to be walking to use it. "Mindful Walk" (the v3 ambient mode) keeps its name since it's specifically about night walking, but every other generic reference to "walk" in the app/docs now says "session".
