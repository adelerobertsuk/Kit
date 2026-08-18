import Foundation

enum MemoryItemKind: String, Codable {
    case shopping
    case task
    case idea
    case person
}

/// A structured item extracted from a finished session — a shopping item, task, idea,
/// or person mentioned — kept alongside the session summary so it can later be searched
/// or surfaced on its own, without re-parsing the raw transcript each time.
struct MemoryItem: Identifiable, Codable {
    let id: UUID
    /// Links back to the raw session in SessionArchiveStore this was extracted from.
    let sourceSessionID: UUID
    let kind: MemoryItemKind
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), sourceSessionID: UUID, kind: MemoryItemKind, text: String, createdAt: Date = Date()) {
        self.id = id
        self.sourceSessionID = sourceSessionID
        self.kind = kind
        self.text = text
        self.createdAt = createdAt
    }
}

enum MemoryItemStore {
    // Same atomic-file pattern as JournalStore/SessionArchiveStore — see Session.swift
    // for why this isn't UserDefaults.
    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("memory-items.json")
    }()

    static func load() -> [MemoryItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([MemoryItem].self, from: data)) ?? []
    }

    static func save(_ items: [MemoryItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func append(contentsOf newItems: [MemoryItem]) {
        guard !newItems.isEmpty else { return }
        var items = load()
        items.append(contentsOf: newItems)
        save(items)
    }
}

/// Surfaces past MemoryItems relevant to what the user just said, so a later session can
/// recall them without the user repeating themselves. Local keyword overlap only — no
/// embeddings, no network call — the smallest thing that lets Kit say "you mentioned
/// wanting oat milk" days later. Revisit if recall quality needs improving once there's
/// real multi-session usage to evaluate against.
enum MemoryRetrieval {
    private static let stopwords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "to", "of", "in", "on", "for", "with",
        "at", "is", "are", "was", "were", "i", "you", "me", "my", "your", "it", "this", "that"
    ]

    static func relevantItems(for query: String, limit: Int = 3) -> [MemoryItem] {
        let queryWords = significantWords(in: query)
        guard !queryWords.isEmpty else { return [] }

        let scored = MemoryItemStore.load().map { item in
            (item, queryWords.intersection(significantWords(in: item.text)).count)
        }.filter { $0.1 > 0 }

        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }

    private static func significantWords(in text: String) -> Set<String> {
        Set(
            text
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 && !stopwords.contains($0) }
        )
    }
}
