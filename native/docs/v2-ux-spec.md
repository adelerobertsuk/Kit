# KIT v2 UX Specification

_Working design specification, 2026-08-10. Product spelling is **Kit** in prose and **KIT** only where the all-caps wordmark is intentionally shown._

## 1. Product promise

Kit is a voice-first companion that turns a hands-free session into a useful private memory. The screen supports the experience before and after a session; it must never become a dashboard the user has to operate while moving.

Every interaction should pass three tests:

1. **Zero gaze during capture:** the user can start, speak, hear confirmation, and finish without looking at the phone.
2. **Private by default:** raw capture stays local; sharing is an explicit, previewable action.
3. **A memory, not a transcript:** the durable artifact is a concise, editable Memory Card. Raw turns remain secondary.

## 2. Information architecture

The app has three top-level destinations, but capture remains globally available:

- **Home:** readiness, last session, and one dominant start control.
- **Memory Bank:** searchable session cards and smart silos.
- **Settings:** persona, skin, voice, privacy, integrations, and geofences.

The active-session view temporarily replaces normal navigation. It exposes only session state, the voice box, elapsed time, and a large stop control. The Running Memory transcript is available behind a deliberate reveal for accessibility and debugging, not as the visual centre of the session.

## 3. Core session flow

### 3.1 Ready

- Primary spoken/UI label: **Start a session**.
- Secondary status line: `Ready · AirPods connected` or `Ready · iPhone microphone`.
- A small local-privacy label says `Audio deleted after transcription`.
- The most recent Memory Card appears below the fold, never competing with Start.

### 3.2 Listening

- One short rising tone and one haptic acknowledge recording start.
- A persistent recording indicator is visible whenever the microphone is active.
- The three-column red voice box responds to amplitude; it is a state signal, not decoration.
- Silence for 1.5 seconds ends the burst, followed by a medium haptic and a short confirmation tone.
- Kit replies in one or two spoken sentences. A new burst can then begin without ending the session.

### 3.3 Ending

- Manual command: `End session` by button or configured remote gesture.
- Home Arrival may suggest ending, but should not silently save on first entry into the boundary. Spoken prompt: `You’re home. Save this session?`
- If the user does not answer, keep the session recoverable and show a notification. This avoids accidental truncation caused by GPS drift.

### 3.4 Review

The session resolves into one Memory Card. The review screen uses a short progressive flow:

1. Show the generated card immediately.
2. Let the user edit the title, summary, silos, and privacy-sensitive fields.
3. Offer **Save privately** as the primary action.
4. Offer **Share or export** as a secondary action.

Saving must never depend on network summarisation. When the AI provider is unavailable, Kit stores the local transcript and produces a clearly labelled basic on-device card that can be enhanced later.

## 4. Memory Bank bento system

The Memory Bank is a calm review space rather than an analytics dashboard. Use a two-column adaptive grid on iPhone and a wider masonry grid on iPad. Avoid dense tables and tiny metrics.

### 4.1 Bento hierarchy

- **Hero card (2 columns):** most recent or pinned session; title, date, 2–3 line summary, duration.
- **Silo card (1 column):** Groceries, Ideas, Reminders, Safety, or Movement; count plus the newest useful item.
- **Moment card (1 column):** a photo or short quote explicitly selected by the user.
- **Route card (2 columns, optional):** deliberately imprecise route preview with start/end locations hidden by default.
- **Prompt card (1 column):** a gentle follow-up such as `You mentioned calling Mum` with snooze/done actions.

The first screen should contain no more than one hero card and four supporting modules. `See all` opens the complete chronological bank.

### 4.2 Card anatomy

Every session card uses the same semantic order even when the skin changes:

1. Privacy/status marker (`Private`, `Shared`, or `Needs review`).
2. Human-readable title.
3. Date and session duration.
4. Summary.
5. Up to three silo chips.
6. Optional movement/photo/route module.
7. `Open card` affordance.

Colour must never be the only way a silo or status is distinguished. Each uses an icon and a text label.

### 4.3 Smart silos

Classification is suggestion-only. Kit may propose:

- **Groceries:** concrete items and shopping locations.
- **Reminders:** commitments with an optional date or place.
- **Ideas:** product, writing, creative, or problem-solving thoughts.
- **Safety:** user-described incidents and observations.
- **Movement:** steps, distance, duration, and pace when permission exists.

Safety content never appears on a shareable card by default. Location, faces, contact names, and health data each require a separate inclusion toggle.

## 5. Shareable Memory Cards

### 5.1 Default card

The default share artifact is a portrait image sized for messaging and social previews (1080 × 1350), accompanied by accessible plain text in the Share Sheet.

It contains:

- Kit wordmark or selected persona mark.
- Session title and calendar date.
- A 40–80 word edited summary.
- Up to three selected highlights.
- Optional high-level movement stat.
- `Made with Kit` footer, removable in settings.

It excludes by default:

- Exact timestamps below day precision.
- Exact route, home location, or coordinates.
- Raw transcript and audio.
- Safety silo contents.
- Names, phone numbers, email addresses, and other detected identifiers.
- Health metrics beyond a user-selected aggregate.

### 5.2 Share preview

Sharing always opens an in-app preview before the system Share Sheet. Each sensitive section has an explicit switch, and a one-line warning appears when precise location or safety content is enabled. The preview also offers:

- **Image** for Messages and social apps.
- **Plain text** for Apple Journal, Notes, and Day One.
- **Markdown** for portable archival.
- **Activity summary** for compatible fitness destinations; do not imply direct Strava support until its accepted data path is verified.

### 5.3 Proposed local data shape

```swift
struct MemoryCard: Identifiable, Codable {
    let id: UUID
    var createdAt: Date
    var title: String
    var summary: String
    var highlights: [String]
    var silos: Set<MemorySilo>
    var duration: TimeInterval?
    var movement: MovementSummary?
    var photoIdentifiers: [String]
    var route: PrivateRouteSummary?
    var sourceEntryIDs: [UUID]
    var reviewState: ReviewState
}
```

Store semantic data independently of presentation so both skins render the same card without duplicating or migrating user content.

## 6. Skin system

Skins change expression, not structure, language, accessibility, or interaction placement.

### 6.0 Translation of the supplied visual references

The three references point to two deliberately different Kit experiences:

- **Paperpillar / Sense:** use its asymmetric bento rhythm, generous gutters, rounded containers, quiet hierarchy, and image-led modules for Penny's Memory Bank and post-session review. Do not copy its desktop sidebar or meditation taxonomy; Kit needs a phone-first, session-first information architecture.
- **Gleb Kuznetsov / glowing home:** use the edge-to-edge diffused colour, very low information density, large central invitation, and light-as-state approach for Mindful Walk. It should feel like the phone is emitting a calm environmental signal rather than presenting a dashboard.
- **Gleb Kuznetsov / voice interaction:** use the single dominant invitation and thumb-reachable hold/tap control as guidance for zero-gaze capture. Kit still requires a persistent recording indicator and strong contrast, which the concept artwork does not need to solve.

Shared visual rules derived from the references:

- Let one element dominate each state: Start, Listening, Review, or Latest Memory.
- Prefer a few large modules over many small controls.
- Use soft atmospheric colour behind content, never behind long body copy without a solid contrast surface.
- Keep navigation visually quiet while a session is active.
- Treat glow as feedback: dormant glow is slow and diffuse; listening glow tightens and brightens; processing glow becomes a restrained pulse.
- Avoid glass-on-glass layering. At most one translucent plane sits above an atmospheric background.

The current Interceptor Memory Bank adopts the bento **hierarchy** first while retaining its own dark technical materials. Penny later changes the palette, corner treatment, typography, and persona details without changing card meaning.

The supplied KITT console reference sharpens the Interceptor treatment:

- The voice box is three columns of individually illuminated red LED cells, with the centre column carrying slightly more energy than its neighbours.
- Inactive cells remain faintly visible so the component reads as physical hardware even when silent.
- Controls borrow the chunky illuminated-key silhouette and decisive amber/red state colours, but use Kit language such as `Start`, `Save`, and `End`; vehicle labels such as `Oil`, `Pursuit`, and `P1–P4` are not reproduced.
- A near-black recessed panel surrounds the voice box. Glow stays close to active cells rather than washing over the whole screen.
- The console is inspiration for tactile confidence and glanceable state, not a literal replica or a novelty dashboard.

### 6.1 Interceptor

- Background: near-black, not pure black in card surfaces.
- Accent roles: cyan for user/action, amber for Kit/status, red only for listening/recording energy and destructive warnings.
- Typography: monospaced display labels paired with a highly legible system body face.
- Shape: clipped technical panels with restrained glow. Avoid glowing every edge.
- Motion: scanner sweep on activation; amplitude-driven LED columns while listening.

### 6.2 Penny Journal

- Background: warm cream.
- Accent roles: dusty pink, mint, plum, and ink blue with WCAG-compliant text contrast.
- Typography: friendly rounded display face paired with the system body face.
- Shape: tactile rounded bento cards, subtle paper layers, and pixel details used sparingly.
- Motion: the pixel paw wakes/blinks on activation; cards settle with soft spring motion.

The 8-bit paw is a persona indicator, not a replacement for the system recording indicator.

## 7. Geofenced Shopping Loop

Geofences are opt-in and created from a named place, never inferred silently.

1. User selects a grocery list and a shop boundary.
2. On entry, Kit gives one discreet audio cue: `You’re near the shop. Want your list?`
3. `Yes` reads a short grouped list; `later` snoozes for this visit; `no` dismisses it.
4. Kit does not repeat the prompt until the user exits and re-enters after a cooldown.
5. Completed items update locally and can be reviewed later in the Grocery silo.

## 8. Watch companion

The first Watch version is a tether, not a miniature Memory Bank:

- Start/stop a session.
- Show recording state and the scanner/voice animation.
- Deliver haptics.
- Show elapsed time and phone connection state.
- Recover gracefully if the phone becomes unreachable.

The Watch must make it unambiguous whether audio is being captured by the phone or Watch.

## 9. Accessibility and safety requirements

- Support Dynamic Type without truncating primary controls.
- Provide Reduce Motion alternatives for scanner, glow, and spring effects.
- Ensure VoiceOver announces state transitions (`Listening`, `Processing`, `Saved`).
- Never use a persona voice as the only recording-state signal.
- Provide an immediate, discoverable stop action on phone, Watch, and supported remote controls.
- Treat emergency-contact features as a separate consent-led product project, not an extension of incident logging.

## 10. Recommended implementation order

1. Separate `SessionTurn` from the persisted `MemoryCard` model.
2. Build the post-session review and private save flow.
3. Build the Memory Bank bento layout using mock cards in both skins.
4. Add the privacy-aware share preview and text/Markdown export.
5. Add the Watch remote-control tether.
6. Add opt-in geofences and the Home Arrival confirmation flow.
7. Add photo matching and movement modules behind permission gates.

This order makes the core promise—turning speech into a durable, private memory—coherent before location and platform integrations increase complexity.

## 11. Decisions still needed

- Whether raw Running Memory is retained after a card is generated, and for how long.
- Whether Memory Cards can span several sessions.
- Which field is the canonical export: edited summary or generated summary.
- Whether Penny is a bundled persona, a skin name, or both.
- Whether users can rename Kit independently of the chosen visual skin.
- Final layout decisions after Adele’s screenshots and references are added.
