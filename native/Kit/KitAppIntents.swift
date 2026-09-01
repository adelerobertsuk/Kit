import AppIntents

struct StartTalkingIntent: AppIntent {
    static var title: LocalizedStringResource { "Talk to Kit" }
    static var description: IntentDescription {
        IntentDescription("Opens Kit and starts listening.")
    }
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Mode")
    var mode: KitTalkMode?

    init() {
        self.mode = nil
    }

    init(mode: KitTalkMode?) {
        self.mode = mode
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            KitLaunch.requestTalk(chair: mode?.chair)
        }
        return .result()
    }
}

enum KitTalkMode: String, AppEnum {
    case diane
    case auto
    case kit

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Kit mode")
    }

    static var caseDisplayRepresentations: [KitTalkMode: DisplayRepresentation] {
        [
            .diane: DisplayRepresentation(title: "Diane"),
            .auto: DisplayRepresentation(title: "Auto Cruise"),
            .kit: DisplayRepresentation(title: "Kit")
        ]
    }

    var chair: Chair {
        switch self {
        case .diane: return .diane
        case .auto: return .auto
        case .kit: return .kit
        }
    }
}

struct KitAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTalkingIntent(),
            phrases: [
                "Talk to \(.applicationName)",
                "Start \(.applicationName)"
            ],
            shortTitle: "Talk to Kit",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: StartTalkingIntent(mode: .diane),
            phrases: [
                "Start Diane in \(.applicationName)"
            ],
            shortTitle: "Start Diane",
            systemImageName: "waveform"
        )
        AppShortcut(
            intent: StartTalkingIntent(mode: .auto),
            phrases: [
                "Start Auto Cruise in \(.applicationName)"
            ],
            shortTitle: "Start Auto Cruise",
            systemImageName: "figure.walk"
        )
        AppShortcut(
            intent: StartTalkingIntent(mode: .kit),
            phrases: [
                "Start Pursuit in \(.applicationName)"
            ],
            shortTitle: "Start Pursuit",
            systemImageName: "bolt.fill"
        )
    }
}
