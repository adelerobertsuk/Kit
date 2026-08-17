import Foundation

struct JournalEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    var text: String
    let isFromAI: Bool
    let isMarker: Bool
    /// True for a Memory Bank entry saved from the raw transcript because AI
    /// summarisation was unavailable (offline, provider error, etc.) — a
    /// clearly-labelled basic card that can be enhanced later, not a full loss.
    let isBasicFallback: Bool
    /// Links this summary back to its raw turns in SessionArchiveStore. Nil for
    /// entries saved before archiving existed.
    let sourceSessionID: UUID?
    /// User-editable Memory Card title. Nil for entries saved before Memory Cards
    /// existed or never renamed — falls back to a generic label at display time.
    var title: String?

    init(id: UUID = UUID(), timestamp: Date = Date(), text: String, isFromAI: Bool = false, isMarker: Bool = false, isBasicFallback: Bool = false, sourceSessionID: UUID? = nil, title: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.isFromAI = isFromAI
        self.isMarker = isMarker
        self.isBasicFallback = isBasicFallback
        self.sourceSessionID = sourceSessionID
        self.title = title
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, text, isFromAI, isMarker, isBasicFallback, sourceSessionID, title
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        text = try container.decode(String.self, forKey: .text)
        isFromAI = try container.decode(Bool.self, forKey: .isFromAI)
        // Older saved sessions predate marker, basic-fallback, source-session, and title fields.
        isMarker = try container.decodeIfPresent(Bool.self, forKey: .isMarker) ?? false
        isBasicFallback = try container.decodeIfPresent(Bool.self, forKey: .isBasicFallback) ?? false
        sourceSessionID = try container.decodeIfPresent(UUID.self, forKey: .sourceSessionID)
        title = try container.decodeIfPresent(String.self, forKey: .title)
    }

    /// The Memory Card title if the user has set one, else a stable generic default —
    /// never blank, so the card and share preview always have something to show.
    var displayTitle: String {
        title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? title! : "Session Memory"
    }
}

enum JournalStore {
    // Deliberately a file, not UserDefaults: UserDefaults writes go through cfprefsd's own
    // flush schedule rather than landing on disk synchronously, so a kill right after
    // finalizing a session can race ahead of the write and lose the entry — the same failure
    // mode ActiveSessionStore (Session.swift) was built to rule out for Running Memory.
    // `Data.write(options: .atomic)` is a real synchronous filesystem write.
    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("journal-entries.json")
    }()

    private static let legacyKey = "kit.journalEntries"
    private static let legacyLegacyKey = "kiit.journalEntries"

    static func load() -> [JournalEntry] {
        if let data = try? Data(contentsOf: fileURL),
           let entries = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            return entries
        }
        // One-time migration from the pre-file UserDefaults storage (and, before that, the
        // pre-rename key) so existing sessions aren't orphaned.
        if let data = UserDefaults.standard.data(forKey: legacyKey),
           let entries = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            save(entries)
            return entries
        }
        guard let legacyData = UserDefaults.standard.data(forKey: legacyLegacyKey),
              let legacyEntries = try? JSONDecoder().decode([JournalEntry].self, from: legacyData) else {
            return []
        }
        save(legacyEntries)
        return legacyEntries
    }

    static func save(_ entries: [JournalEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
