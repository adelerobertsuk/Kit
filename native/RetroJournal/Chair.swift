import Foundation

/// Who is in the seat. Like Cursor’s model picker.
enum Chair: String, CaseIterable, Identifiable {
    case diane
    case kit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .diane: return "DIANE"
        case .kit: return "KIT"
        }
    }

    var blurb: String {
        switch self {
        case .diane: return "CASSETTE"
        case .kit: return "PARTNER"
        }
    }

    /// Kit may talk back. Diane only writes it down.
    var talksBack: Bool { self == .kit }
}

enum ChairStore {
    private static let key = "kit.chair.v1"

    static func load() -> Chair {
        Chair(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .kit
    }

    static func save(_ chair: Chair) {
        UserDefaults.standard.set(chair.rawValue, forKey: key)
    }
}
