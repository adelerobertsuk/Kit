import Foundation

/// Who is in the seat. Like Cursor’s model picker. Maps one-to-one onto the three
/// console buttons: Normal Cruise, Auto Cruise, Pursuit Mode.
enum Chair: String, Codable, CaseIterable, Identifiable {
    case diane
    case auto
    case kit

    var id: String { rawValue }

    /// The console button that selects this seat.
    var modeLabel: String {
        switch self {
        case .diane: return "NORMAL CRUISE"
        case .auto: return "AUTO CRUISE"
        case .kit: return "PURSUIT"
        }
    }

    var title: String {
        switch self {
        case .diane: return "DIANE"
        case .auto: return "AUTO"
        case .kit: return "KIT"
        }
    }

    var blurb: String {
        switch self {
        case .diane: return "CASSETTE"
        case .auto: return "FRIEND"
        case .kit: return "PARTNER"
        }
    }

    /// Diane only writes it down. Auto and Kit both speak back — Auto keeps it
    /// snappy, Kit goes deep.
    var talksBack: Bool { self != .diane }
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
