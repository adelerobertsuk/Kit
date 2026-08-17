import Foundation

/// A real session, alive from the moment Start is pressed — not just an
/// in-memory array that vanishes if Gemini fails or the app is killed.
struct Session: Codable {
    let id: UUID
    let startedAt: Date
    /// Mirrors ConversationManager.sessionTurns (newest first).
    var turns: [JournalEntry] = []
    /// Chronological Gemini context, persisted alongside turns so a
    /// recovered session can keep replying with full history.
    var history: [HistoryTurn] = []

    struct HistoryTurn: Codable {
        let isFromAI: Bool
        let text: String
    }
}

/// Persists the in-progress session continuously, independent of the
/// finished-session Memory Bank in JournalStore. Whatever's here on next
/// launch is a session that never made it to End Session.
///
/// Deliberately NOT UserDefaults: UserDefaults writes go through cfprefsd's
/// own caching/flush schedule, not a synchronous disk write, so a hard kill
/// can race ahead of the flush and silently lose the very turn durability
/// exists to protect (verified live: a kill right after a save persisted
/// "turns":[] to the plist despite the in-memory session having a turn).
/// `Data.write(options: .atomic)` writes to a temp file and renames — an
/// actual synchronous filesystem write, not a cache.
enum ActiveSessionStore {
    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("active-session.json")
    }()

    static func load() -> Session? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    static func save(_ session: Session) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

/// Archive of finished sessions' raw turns, kept as the durable source a Memory Bank
/// summary was built from. Distinct from ActiveSessionStore (only the *in-progress*
/// session) and JournalStore (the AI-written summary, not the raw turns) — this is what
/// lets a summary be re-derived or structured items re-extracted later without the
/// original conversation having been thrown away.
enum SessionArchiveStore {
    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("session-archive.json")
    }()

    static func load() -> [Session] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Session].self, from: data)) ?? []
    }

    static func append(_ session: Session) {
        var sessions = load()
        sessions.append(session)
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func session(withID id: UUID) -> Session? {
        load().first { $0.id == id }
    }
}
