import Foundation

struct JournalEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    var text: String
    /// The verbatim transcript before TranscriptCleaner tidied it, kept so captured
    /// speech is never lost to the cleanup pass. Nil when cleaning changed nothing,
    /// for AI turns, and for tapes saved before this existed.
    var rawText: String?
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

    /// Who was in the seat when this tape was filed. Nil on older tapes.
    var chair: Chair?

    init(id: UUID = UUID(), timestamp: Date = Date(), text: String, rawText: String? = nil, isFromAI: Bool = false, isMarker: Bool = false, isBasicFallback: Bool = false, sourceSessionID: UUID? = nil, title: String? = nil, chair: Chair? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.rawText = rawText
        self.isFromAI = isFromAI
        self.isMarker = isMarker
        self.isBasicFallback = isBasicFallback
        self.sourceSessionID = sourceSessionID
        self.title = title
        self.chair = chair
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, text, rawText, isFromAI, isMarker, isBasicFallback, sourceSessionID, title, chair
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        text = try container.decode(String.self, forKey: .text)
        rawText = try container.decodeIfPresent(String.self, forKey: .rawText)
        isFromAI = try container.decode(Bool.self, forKey: .isFromAI)
        isMarker = try container.decodeIfPresent(Bool.self, forKey: .isMarker) ?? false
        isBasicFallback = try container.decodeIfPresent(Bool.self, forKey: .isBasicFallback) ?? false
        sourceSessionID = try container.decodeIfPresent(UUID.self, forKey: .sourceSessionID)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        chair = try container.decodeIfPresent(Chair.self, forKey: .chair)
    }

    var displayTitle: String {
        let custom = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !custom.isEmpty, custom.caseInsensitiveCompare("Session Memory") != .orderedSame {
            return custom
        }
        switch chair {
        case .diane: return "Diane tape"
        case .auto: return "Auto Cruise tape"
        case .kit: return "Kit tape"
        case nil: return "Session Memory"
        }
    }

    var seatLabel: String {
        switch chair {
        case .diane: return "DIANE"
        case .auto: return "AUTO"
        case .kit: return "KIT"
        case nil: return tapeFamily.tapeStock
        }
    }

    var tapeFamily: TapeFamily {
        if let kind = MemoryItemStore.dominantKind(for: sourceSessionID) {
            return kind.family
        }
        switch chair {
        case .diane: return .morningPages
        case .auto, .kit: return .creative
        case nil: return .reflection
        }
    }

    var durationSeconds: Int {
        guard let sourceSessionID, let session = SessionArchiveStore.session(withID: sourceSessionID) else {
            return 0
        }
        return Int(session.duration)
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
