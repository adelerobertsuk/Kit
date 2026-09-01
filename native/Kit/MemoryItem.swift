import Foundation

enum MemoryItemKind: String, Codable {
    case morningPages
    case runningThought
    case appIdea
    case reflection
    case shopping
    case task
    case idea
    case person

    var title: String {
        switch self {
        case .morningPages: return "Morning Pages"
        case .runningThought: return "Running Thought"
        case .appIdea: return "App Idea"
        case .reflection: return "Reflection"
        case .shopping: return "Shopping"
        case .task: return "Task"
        case .idea: return "Idea"
        case .person: return "People"
        }
    }

    var tapeCode: String {
        switch self {
        case .morningPages: return "MORN"
        case .runningThought: return "RUN"
        case .appIdea: return "APP"
        case .reflection: return "RFL"
        case .shopping: return "SHOP"
        case .task: return "TASK"
        case .idea: return "IDEA"
        case .person: return "PEPL"
        }
    }

    var reportLabel: String {
        switch self {
        case .morningPages: return "MORNING PAGES"
        case .runningThought: return "RUNNING THOUGHTS"
        case .appIdea: return "APP IDEAS"
        case .reflection: return "REFLECTIONS"
        case .shopping: return "SHOPPING"
        case .task: return "TASKS"
        case .idea: return "IDEAS"
        case .person: return "PEOPLE"
        }
    }

    var family: TapeFamily {
        switch self {
        case .idea: return .creative
        case .appIdea: return .appIdea
        case .runningThought: return .running
        case .person: return .people
        case .reflection: return .reflection
        case .morningPages: return .morningPages
        case .shopping: return .shopping
        case .task: return .tasks
        }
    }
}

/// Eight tape colours. Console lamps still group these into CRE, RFL, and ACT.
enum TapeFamily: String, CaseIterable, Identifiable {
    case creative
    case appIdea
    case running
    case people
    case reflection
    case morningPages
    case shopping
    case tasks

    var id: String { rawValue }

    var lampCode: String {
        switch self {
        case .creative: return "CRE"
        case .appIdea: return "APP"
        case .running: return "RUN"
        case .people: return "PEPL"
        case .reflection: return "RFL"
        case .morningPages: return "MORN"
        case .shopping: return "SHOP"
        case .tasks: return "ACT"
        }
    }

    var label: String {
        switch self {
        case .creative: return "CREATIVE"
        case .appIdea: return "APP IDEA"
        case .running: return "RUNNING THOUGHT"
        case .people: return "PEOPLE"
        case .reflection: return "DAILY REFLECTION"
        case .morningPages: return "MORNING PAGES"
        case .shopping: return "SHOPPING"
        case .tasks: return "HEALTH / ACTION"
        }
    }

    var reportLabel: String { label }

    var tapeStock: String {
        switch self {
        case .creative: return "SUPER VHS"
        case .appIdea: return "HQ"
        case .running: return "RUN"
        case .people: return "T-120"
        case .reflection: return "T-120"
        case .morningPages: return "PAGES"
        case .shopping: return "LIST"
        case .tasks: return "HQ T-120"
        }
    }

    var consoleGroup: ConsoleLampGroup {
        switch self {
        case .creative, .appIdea, .running, .people:
            return .creative
        case .reflection, .morningPages:
            return .reflection
        case .shopping, .tasks:
            return .action
        }
    }
}

enum ConsoleLampGroup: String, CaseIterable, Identifiable {
    case creative
    case reflection
    case action

    var id: String { rawValue }

    var mixLabel: String {
        switch self {
        case .creative: return "CREATIVE"
        case .reflection: return "DAILY REFLECTION"
        case .action: return "HEALTH / ACTION"
        }
    }

    var reportLabel: String {
        switch self {
        case .creative: return "CREATIVE"
        case .reflection: return "REFLECTION"
        case .action: return "HEALTH / ACTION"
        }
    }
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

    /// Same session, same kind, same text bar case and surrounding space — so a
    /// mid-session "hold this thought" extraction and the end-of-session sweep don't
    /// both file the same item.
    func isDuplicate(of other: MemoryItem) -> Bool {
        guard sourceSessionID == other.sourceSessionID, kind == other.kind else { return false }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(other.text.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
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
        for item in newItems where !items.contains(where: { $0.isDuplicate(of: item) }) {
            items.append(item)
        }
        save(items)
    }

    static func items(for sessionID: UUID?) -> [MemoryItem] {
        guard let sessionID else { return [] }
        return load().filter { $0.sourceSessionID == sessionID }
    }

    static func dominantKind(for sessionID: UUID?) -> MemoryItemKind? {
        let counts = Dictionary(grouping: items(for: sessionID), by: \.kind)
            .mapValues(\.count)
        return counts.max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.rawValue > rhs.key.rawValue
            }
            return lhs.value < rhs.value
        }?.key
    }

    static func itemsThisWeek(referenceDate: Date = .now) -> [MemoryItem] {
        let calendar = Calendar.current
        return load().filter { calendar.isDate($0.createdAt, equalTo: referenceDate, toGranularity: .weekOfYear) }
    }

    static func familyCounts(in items: [MemoryItem]? = nil) -> [TapeFamily: Int] {
        let source = items ?? load()
        var counts: [TapeFamily: Int] = [:]
        for item in source {
            counts[item.kind.family, default: 0] += 1
        }
        return counts
    }

    static func topKindsThisWeek(limit: Int = 3, referenceDate: Date = .now) -> [(kind: MemoryItemKind, count: Int)] {
        let counts = Dictionary(grouping: itemsThisWeek(referenceDate: referenceDate), by: \.kind)
            .mapValues(\.count)
        return counts
            .sorted {
                if $0.value == $1.value {
                    return $0.key.rawValue < $1.key.rawValue
                }
                return $0.value > $1.value
            }
            .prefix(limit)
            .map { ($0.key, $0.value) }
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
