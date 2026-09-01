import Foundation

enum KitLaunch {
    enum Action {
        case talk(Chair?)
        case fileTape
    }

    private static let talkKey = "kit.pendingTalk"
    private static let chairKey = "kit.pendingChair"
    private static let fileKey = "kit.pendingFile"

    static func requestTalk(chair: Chair?) {
        UserDefaults.standard.set(true, forKey: talkKey)
        if let chair {
            UserDefaults.standard.set(chair.rawValue, forKey: chairKey)
        } else {
            UserDefaults.standard.removeObject(forKey: chairKey)
        }
    }

    static func requestFileTape() {
        UserDefaults.standard.set(true, forKey: fileKey)
    }

    static func consume() -> Action? {
        if UserDefaults.standard.bool(forKey: fileKey) {
            UserDefaults.standard.set(false, forKey: fileKey)
            return .fileTape
        }
        guard UserDefaults.standard.bool(forKey: talkKey) else { return nil }
        UserDefaults.standard.set(false, forKey: talkKey)
        let chair = UserDefaults.standard.string(forKey: chairKey).flatMap(Chair.init(rawValue:))
        UserDefaults.standard.removeObject(forKey: chairKey)
        return .talk(chair)
    }
}
