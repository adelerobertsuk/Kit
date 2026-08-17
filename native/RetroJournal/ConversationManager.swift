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

    private let geminiClient = GeminiClient()
    private let voice = KittVoice()
    private var history: [GeminiClient.Turn] = []
    /// The live session, alive from the moment Start is pressed until End Session resolves it
    /// into a Memory Bank entry. Persisted to ActiveSessionStore on every change.
    private var currentSession: Session?

    init() {
        entries = JournalStore.load()

        if let recovered = ActiveSessionStore.load(), !recovered.turns.isEmpty {
            currentSession = recovered
            sessionTurns = recovered.turns
            history = recovered.history.map { GeminiClient.Turn(isFromAI: $0.isFromAI, text: $0.text) }
            recoveredSessionNotice = true
        }

        speechManager.onFinalTranscript = { [weak self] text in
            self?.handleUserSpeech(text)
        }

        voice.onFinishSpeaking = { [weak self] in
            Task { @MainActor in
                self?.state = .idle
            }
        }
    }

    func toggleTalk() {
        // Block starting a new recording while KITT is thinking or speaking —
        // stopping an in-progress recording is always allowed.
        guard state == .idle || speechManager.isListening else { return }
        if !speechManager.isListening {
            // A session exists from the moment Start is pressed, not from the first
            // successful transcript — so it's recoverable even if this very burst is lost.
            ensureSession()
        }
        speechManager.toggleTalk()
    }

    func dismissRecoveredNotice() {
        recoveredSessionNotice = false
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

    /// MUTE: cancels whatever KITT is currently hearing without submitting it.
    func muteCurrentTurn() {
        speechManager.cancelListening()
    }

    /// Commits Memory Card edits (title/summary) made in the review sheet back to the
    /// Memory Bank. Entries are value types, so this finds-and-replaces by id.
    func updateEntry(id: UUID, title: String, summary: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].title = title
        entries[index].text = summary
        JournalStore.save(entries)
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
    }

    private func handleUserSpeech(_ text: String) {
        errorMessage = nil
        recoveredSessionNotice = false

        // Keep session control inside Kitt rather than trusting the model to
        // remember to perform a side effect. This gives the hands-free portal
        // a natural closing ritual: the user can simply say “Goodnight, Kitt.”
        if Self.isEndSessionCommand(text) {
            endSession()
            return
        }

        if sessionTurns.isEmpty {
            batteryNudge.startMonitoring()
        }
        ensureSession()
        let userEntry = JournalEntry(text: text, isFromAI: false)
        sessionTurns.insert(userEntry, at: 0)
        // Persist the user's turn to disk before ever calling Gemini — if the network call
        // fails or the app dies mid-request, this turn is already safe on disk either way.
        persistCurrentSession()

        state = .thinking
        let priorHistory = history
        let relevantMemories = MemoryRetrieval.relevantItems(for: text).map(\.text)
        Task {
            do {
                let reply = try await geminiClient.reply(to: text, history: priorHistory, relevantMemories: relevantMemories)
                let aiEntry = JournalEntry(text: reply, isFromAI: true)
                sessionTurns.insert(aiEntry, at: 0)
                history.append(.init(isFromAI: false, text: text))
                history.append(.init(isFromAI: true, text: reply))
                persistCurrentSession()
                state = .speaking
                voice.speak(reply)
            } catch {
                // Never clear Running Memory on failure — the user's turn is already
                // persisted above, so a failed reply loses nothing but KITT's response.
                errorMessage = error.localizedDescription
                state = .idle
            }
        }
    }

    func endSession() {
        // Gate on sessionTurns, not history — history only gains entries after a *successful*
        // Gemini reply, so gating on it would strand a fully-offline session (every reply
        // failed) with no way to ever finalize it, even though its turns are safely persisted.
        guard !sessionTurns.isEmpty else { return }
        batteryNudge.stopMonitoring()
        state = .thinking
        let finishedHistory = history
        let turnsSnapshot = sessionTurns
        Task {
            do {
                guard !finishedHistory.isEmpty else {
                    // No successful AI exchange to summarise at all.
                    throw GeminiError.emptyReply
                }
                let summary = try await geminiClient.summarize(history: finishedHistory)
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

        let summaryEntry = JournalEntry(text: text, isFromAI: true, isBasicFallback: isBasicFallback, sourceSessionID: archivedSession?.id)
        entries.insert(summaryEntry, at: 0)
        JournalStore.save(entries)

        if let archivedSession, !archivedSession.history.isEmpty {
            extractMemoryItems(for: archivedSession)
        }

        sessionTurns = []
        history = []
        currentSession = nil
        ActiveSessionStore.clear()
        errorMessage = nil
        state = .saved
    }

    /// Runs after the session is already safely archived and summarized — extraction
    /// failing or returning nothing must never affect the save above, so errors are
    /// silently absorbed rather than surfaced through errorMessage/state.
    private func extractMemoryItems(for session: Session) {
        let turns = session.history.map { GeminiClient.Turn(isFromAI: $0.isFromAI, text: $0.text) }
        Task {
            guard let extracted = try? await geminiClient.extractMemoryItems(history: turns), !extracted.isEmpty else { return }
            let items = extracted.map { MemoryItem(sourceSessionID: session.id, kind: $0.kind, text: $0.text) }
            MemoryItemStore.append(contentsOf: items)
        }
    }

    private static func basicFallbackSummary(from turns: [JournalEntry]) -> String {
        let transcript = turns
            .reversed() // sessionTurns is newest-first; make it chronological for reading.
            .filter { !$0.isMarker }
            .map { "\($0.isFromAI ? "KITT" : "Me"): \($0.text)" }
            .joined(separator: "\n")
        return "Needs review — saved offline without an AI summary.\n\n\(transcript)"
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
            "end session",
            "end the session",
            "save this session",
            "save this to my journal",
            "save that to my journal"
        ].contains(words)
    }
}
