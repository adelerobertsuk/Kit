import Foundation
import Combine
import UIKit

enum KittState {
    case idle
    case thinking
    case speaking
    case saved
}

@MainActor
final class ConversationManager: ObservableObject {
    let speechManager = SpeechManager()
    let batteryNudge = BatteryNudgeManager()

    /// Persisted Memory Bank — one summary entry per finished session, not a raw transcript.
    @Published var entries: [JournalEntry]
    /// Running Memory — the live, unsaved back-and-forth for the session in progress.
    /// Mirrors currentSession.turns; currentSession/ActiveSessionStore is the source of truth
    /// that survives a kill, this is just what the view binds to.
    @Published var sessionTurns: [JournalEntry] = []
    @Published var state: KittState = .idle
    @Published var errorMessage: String?
    /// Set on launch when an unfinished session was recovered from disk (app killed, crashed,
    /// or battery died mid-session) so the UI can surface it instead of silently resuming.
    @Published var recoveredSessionNotice: Bool = false
    /// Who is in the seat. Diane writes. Kit answers.
    @Published var chair: Chair
    /// Bumps when extracted memory items land, so Console lamps and Smart Kit can refresh.
    @Published var memoryRevision: Int = 0
    /// Start of this talk burst. Nil when the burst is over and the clock is frozen.
    @Published private(set) var turnClockStartedAt: Date?
    /// Last burst length, held still so the dial does not keep climbing between turns.
    @Published private(set) var frozenTurnSeconds: TimeInterval = 0

    private let geminiClient = GeminiClient()
    private let voice = KittVoice()
    private var history: [GeminiClient.Turn] = []
    /// The live session, alive from the moment Start is pressed until End Session resolves it
    /// into a Memory Bank entry. Persisted to ActiveSessionStore on every change.
    private var currentSession: Session?
    private var replyTask: Task<Void, Never>?
    /// After this much quiet, an unfinished walk is filed as a tape on next open.
    private static let staleQuiet: TimeInterval = 4 * 60 * 60

    init() {
        chair = ChairStore.load()
        entries = JournalStore.load()

        if let recovered = ActiveSessionStore.load(), !recovered.turns.isEmpty {
            currentSession = recovered
            sessionTurns = recovered.turns
            history = recovered.history.map { GeminiClient.Turn(isFromAI: $0.isFromAI, text: $0.text) }
            if Date().timeIntervalSince(recovered.lastActivity) >= Self.staleQuiet {
                endSession()
            } else {
                recoveredSessionNotice = true
                KitSessionReminder.reschedule(lastActivity: recovered.lastActivity)
            }
        }

        speechManager.onFinalTranscript = { [weak self] text, raw in
            self?.handleUserSpeech(text, raw: raw)
        }
        speechManager.onEmptyListen = { [weak self] in
            self?.freezeTurnClock()
        }

        voice.onFinishSpeaking = { [weak self] in
            guard let self, self.state == .speaking else { return }
            self.freezeTurnClock()
            self.state = .idle
        }
    }

    func startTalkingFromLaunch() {
        guard state == .idle, !speechManager.isListening else { return }
        toggleTalk()
    }

    func toggleTalk() {
        // Block starting a new recording while Kit is thinking or speaking —
        // stopping an in-progress recording is always allowed.
        guard state == .idle || speechManager.isListening else { return }
        if !speechManager.isListening {
            // A session exists from the moment Start is pressed, not from the first
            // successful transcript — so it's recoverable even if this very burst is lost.
            ensureSession()
            errorMessage = nil
            voice.stop()
            startTurnClock()
        }
        speechManager.toggleTalk()
    }

    func dismissRecoveredNotice() {
        recoveredSessionNotice = false
    }

    func setChair(_ next: Chair) {
        guard next != chair else { return }
        replyTask?.cancel()
        replyTask = nil
        voice.stop()
        if state == .speaking || state == .thinking {
            state = .idle
        }
        chair = next
        ChairStore.save(next)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// MARK MOMENT: drops a lightweight, unlabeled bookmark into Running Memory
    /// so a moment can be flagged without waiting on a reply.
    func markMoment() {
        ensureSession()
        let marker = JournalEntry(text: "Moment marked", isMarker: true)
        sessionTurns.insert(marker, at: 0)
        persistCurrentSession()
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    /// HOLD THIS THOUGHT: "remember this", "save this", "hold that thought". Drops a
    /// labelled marker, quietly kicks a background extraction of the last few turns into
    /// Smart Kit, and gives a short spoken nod (talkback seats only). No model reply,
    /// never enters `.thinking` — it stays out of the way.
    func holdThought(_ trailing: String) {
        errorMessage = nil
        recoveredSessionNotice = false
        if sessionTurns.isEmpty { batteryNudge.startMonitoring() }
        let session = ensureSession()

        // Anything said after the trigger phrase is real content — keep it in the record.
        if !trailing.isEmpty {
            sessionTurns.insert(JournalEntry(text: trailing, isFromAI: false), at: 0)
            history.append(.init(isFromAI: false, text: trailing))
        }
        sessionTurns.insert(JournalEntry(text: "Held that thought", isMarker: true), at: 0)
        persistCurrentSession()
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        let recent = Array(history.suffix(8))
        let sessionID = session.id
        Task { @MainActor in
            guard let extracted = try? await geminiClient.extractMemoryItems(history: recent),
                  !extracted.isEmpty else { return }
            MemoryItemStore.append(contentsOf: extracted.map {
                MemoryItem(sourceSessionID: sessionID, kind: $0.kind, text: $0.text)
            })
            memoryRevision += 1
        }

        if chair.talksBack {
            state = .speaking
            voice.speak(trailing.isEmpty ? "Held that thought." : "Got it, saved.")
            return
        }
        freezeTurnClock()
        state = .idle
    }

    /// MUTE: cancels whatever Kit is currently hearing without submitting it.
    func muteCurrentTurn() {
        speechManager.cancelListening()
        freezeTurnClock()
    }

    /// Commits Memory Card edits (title/summary) made in the review sheet back to the
    /// Memory Bank. Entries are value types, so this finds-and-replaces by id.
    func updateEntry(id: UUID, title: String, summary: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].title = title
        entries[index].text = summary
        JournalStore.save(entries)
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        JournalStore.save(entries)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private func startTurnClock() {
        frozenTurnSeconds = 0
        turnClockStartedAt = Date()
    }

    private func freezeTurnClock() {
        if let start = turnClockStartedAt {
            frozenTurnSeconds = Date().timeIntervalSince(start)
            turnClockStartedAt = nil
        }
    }

    @discardableResult
    private func ensureSession() -> Session {
        if let currentSession { return currentSession }
        let session = Session(id: UUID(), startedAt: Date())
        currentSession = session
        ActiveSessionStore.save(session)
        return session
    }

    private func persistCurrentSession() {
        guard var session = currentSession else { return }
        session.turns = sessionTurns
        session.history = history.map { Session.HistoryTurn(isFromAI: $0.isFromAI, text: $0.text) }
        currentSession = session
        ActiveSessionStore.save(session)
        if !sessionTurns.isEmpty {
            KitSessionReminder.reschedule(lastActivity: session.lastActivity)
        }
    }

    private func handleUserSpeech(_ text: String, raw: String) {
        errorMessage = nil
        recoveredSessionNotice = false

        // Keep session control inside Kitt rather than trusting the model to
        // remember to perform a side effect. This gives the hands-free portal
        // a natural closing ritual: the user can simply say “Goodnight, Kitt.”
        if Self.isEndSessionCommand(text) {
            endSession()
            return
        }

        if let trailing = Self.holdThoughtTrailing(in: text) {
            holdThought(trailing)
            return
        }

        if sessionTurns.isEmpty {
            batteryNudge.startMonitoring()
        }
        ensureSession()
        let userEntry = JournalEntry(text: text, rawText: raw == text ? nil : raw, isFromAI: false)
        sessionTurns.insert(userEntry, at: 0)
        // Persist the user's turn to disk before ever calling Gemini — if the network call
        // fails or the app dies mid-request, this turn is already safe on disk either way.
        persistCurrentSession()

        // Diane is the cassette. Write the words. Do not answer.
        guard chair.talksBack else {
            history.append(.init(isFromAI: false, text: text))
            persistCurrentSession()
            freezeTurnClock()
            state = .idle
            return
        }

        state = .thinking
        let priorHistory = history
        let replyChair = chair
        let relevantMemories = MemoryRetrieval.relevantItems(for: text).map(\.text)
        replyTask?.cancel()
        replyTask = Task { @MainActor in
            do {
                let reply = try await geminiClient.reply(to: text, history: priorHistory, relevantMemories: relevantMemories, chair: replyChair)
                try Task.checkCancellation()
                let aiEntry = JournalEntry(text: reply, isFromAI: true)
                sessionTurns.insert(aiEntry, at: 0)
                history.append(.init(isFromAI: false, text: text))
                history.append(.init(isFromAI: true, text: reply))
                persistCurrentSession()
                state = .speaking
                try? await Task.sleep(nanoseconds: 150_000_000)
                try Task.checkCancellation()
                voice.speak(Self.spokenReply(from: reply, chair: replyChair))
            } catch is CancellationError {
                return
            } catch {
                // Never clear Running Memory on failure — the user's turn is already
                // persisted above, so a failed reply loses nothing but Kit's response.
                if replyChair == .auto {
                    state = .speaking
                    voice.speak(["Got that.", "Logged.", "Noted."].randomElement() ?? "Got that.")
                } else {
                    errorMessage = error.localizedDescription
                    freezeTurnClock()
                    state = .idle
                }
            }
        }
    }

    func endSession() {
        recoveredSessionNotice = false
        KitSessionReminder.cancel()
        // Gate on sessionTurns, not history — history only gains entries after a *successful*
        // Gemini reply, so gating on it would strand a fully-offline session (every reply
        // failed) with no way to ever finalize it, even though its turns are safely persisted.
        guard !sessionTurns.isEmpty else { return }
        replyTask?.cancel()
        voice.stop()
        freezeTurnClock()
        batteryNudge.stopMonitoring()

        // Normal Cruise (Diane) is pure dictation — no AI pass. Bundle every spoken turn
        // from this session into one verbatim master entry, and drop a markdown copy in
        // the export folder for NotebookLM / Cursor to pick up.
        if chair == .diane {
            let turnsSnapshot = sessionTurns
            let master = Self.bundledTranscript(from: turnsSnapshot)
            KitExport.writeMarkdown(title: "Normal Cruise", body: master)
            finalizeSession(text: master, isBasicFallback: false)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                state = .idle
            }
            return
        }

        state = .thinking
        let finishedHistory = history
        let turnsSnapshot = sessionTurns
        Task { @MainActor in
            do {
                guard !finishedHistory.isEmpty else {
                    // No successful AI exchange to summarise at all.
                    throw GeminiError.emptyReply
                }
                let summary = try await geminiClient.summarize(history: finishedHistory, chair: chair)
                finalizeSession(text: summary, isBasicFallback: false)
            } catch {
                // Summarisation unavailable (offline, provider error, no successful exchange
                // at all, etc.) — don't lose the session. Save a clearly-labelled basic card
                // from the raw transcript instead; it can be enhanced later once the provider
                // is reachable again. This is a graceful degrade, not a failure, so it resolves
                // to .saved like the happy path — the isBasicFallback flag on the entry
                // (surfaced as a Memory Bank badge) is the persistent signal, not a transient
                // error message.
                finalizeSession(text: Self.basicFallbackSummary(from: turnsSnapshot), isBasicFallback: true)
            }
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            state = .idle
        }
    }

    private func finalizeSession(text: String, isBasicFallback: Bool) {
        // Archive the raw session before clearing it — this is the durable source the
        // summary below was built from, and what extractMemoryItems reads from next.
        let archivedSession = currentSession
        if let archivedSession {
            SessionArchiveStore.append(archivedSession)
        }

        let summaryEntry = JournalEntry(text: text, isFromAI: true, isBasicFallback: isBasicFallback, sourceSessionID: archivedSession?.id, chair: chair)
        entries.insert(summaryEntry, at: 0)
        JournalStore.save(entries)

        if let archivedSession, !archivedSession.history.isEmpty {
            extractMemoryItems(for: archivedSession)
        }

        sessionTurns = []
        history = []
        currentSession = nil
        ActiveSessionStore.clear()
        KitSessionReminder.cancel()
        errorMessage = nil
        state = .saved
    }

    /// Runs after the session is already safely archived and summarized — extraction
    /// failing or returning nothing must never affect the save above, so errors are
    /// silently absorbed rather than surfaced through errorMessage/state.
    private func extractMemoryItems(for session: Session) {
        let turns = session.history.map { GeminiClient.Turn(isFromAI: $0.isFromAI, text: $0.text) }
        Task { @MainActor in
            guard let extracted = try? await geminiClient.extractMemoryItems(history: turns), !extracted.isEmpty else { return }
            let items = extracted.map { MemoryItem(sourceSessionID: session.id, kind: $0.kind, text: $0.text) }
            MemoryItemStore.append(contentsOf: items)
            memoryRevision += 1
        }
    }

    /// The whole Normal Cruise session as one block of prose — every spoken turn,
    /// chronological, verbatim, markers dropped. No "Me:" labels: it's one voice.
    private static func bundledTranscript(from turns: [JournalEntry]) -> String {
        turns
            .reversed() // sessionTurns is newest-first
            .filter { !$0.isMarker }
            .map(\.text)
            .joined(separator: "\n\n")
    }

    private static func basicFallbackSummary(from turns: [JournalEntry]) -> String {
        let transcript = turns
            .reversed() // sessionTurns is newest-first; make it chronological for reading.
            .filter { !$0.isMarker }
            .map { "\($0.isFromAI ? "Kit" : "Me"): \($0.text)" }
            .joined(separator: "\n")
        return "Needs review. Saved offline without an AI summary.\n\n\(transcript)"
    }

    /// Plain speech for TTS — strip markdown and cap Pursuit length so long replies
    /// don't destabilise the audio stack on the next mic turn.
    private static func spokenReply(from reply: String, chair: Chair) -> String {
        var text = reply
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard chair == .kit, text.count > 420 else { return text }

        let prefix = text.prefix(420)
        if let lastStop = prefix.lastIndex(where: { ".!?".contains($0) }) {
            return String(prefix[...lastStop])
        }
        return String(prefix).trimmingCharacters(in: .whitespacesAndNewlines) + "."
    }

    /// Returns the text after a "hold this thought" trigger (empty string when the whole
    /// utterance *was* the trigger), or nil when it isn't one of those commands. Checked
    /// after `isEndSessionCommand`, so "save this session" / "save this to my journal"
    /// resolve to End Session, not this.
    private static func holdThoughtTrailing(in text: String) -> String? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // TranscriptCleaner adds a terminal stop, so "remember this" arrives as
        // "Remember this." — drop trailing sentence punctuation before matching.
        while let last = trimmed.last, ".?!".contains(last) { trimmed.removeLast() }
        let lowered = trimmed.lowercased()
        let triggers = [
            "hold this thought", "hold that thought", "hold the thought",
            "remember this", "save this", "note this", "keep this", "mark this"
        ]
        for trigger in triggers where lowered == trigger
            || lowered.hasPrefix(trigger + " ")
            || lowered.hasPrefix(trigger + ":")
            || lowered.hasPrefix(trigger + ",")
            || lowered.hasPrefix(trigger + " -")
            || lowered.hasPrefix(trigger + " —") {
            let rest = String(trimmed.dropFirst(trigger.count))
            return rest.trimmingCharacters(in: CharacterSet(charactersIn: " \t:,-—.").union(.whitespacesAndNewlines))
        }
        return nil
    }

    private static func isEndSessionCommand(_ text: String) -> Bool {
        let words = text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return [
            "goodnight kitt",
            "good night kitt",
            "goodnight kit",
            "good night kit",
            "goodnight diane",
            "good night diane",
            "end session",
            "end the session",
            "save this session",
            "save this to my journal",
            "save that to my journal"
        ].contains(words)
    }
}

/// Writes a finished Normal Cruise tape to a markdown file the user can hand to
/// NotebookLM or read in Cursor. Lands in the app's Documents directory (visible in
/// Files once the app declares document sharing). Best-effort — a write failure is
/// swallowed and never blocks the session save.
enum KitExport {
    static var directory: URL? {
        guard let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = base.appendingPathComponent("Kit Exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func writeMarkdown(title: String, date: Date = Date(), body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let directory, !trimmed.isEmpty else { return }
        let url = directory.appendingPathComponent("kit-\(fileStamp.string(from: date)).md")
        let markdown = "# \(title) — \(heading.string(from: date))\n\n\(trimmed)\n"
        try? markdown.data(using: .utf8)?.write(to: url, options: .atomic)
    }

    private static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        return f
    }()

    private static let heading: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
