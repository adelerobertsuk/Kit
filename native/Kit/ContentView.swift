import SwiftUI
import UIKit
import AppIntents

struct ContentView: View {
    @StateObject private var conversation: ConversationManager
    @ObservedObject private var speechManager: SpeechManager
    @ObservedObject private var batteryNudge: BatteryNudgeManager
    @StateObject private var tapePlayer = TapeVoice()
    @State private var selectedCardEntry: JournalEntry?
    @State private var selectedTab: KitTab = .console
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let convo = ConversationManager()
        _conversation = StateObject(wrappedValue: convo)
        _speechManager = ObservedObject(wrappedValue: convo.speechManager)
        _batteryNudge = ObservedObject(wrappedValue: convo.batteryNudge)
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 18) {
                header

                Group {
                    switch selectedTab {
                    case .console:
                        ConsoleTab(
                            conversation: conversation,
                            speechManager: speechManager,
                            batteryNudge: batteryNudge
                        )
                    case .racks:
                        racksTab
                    case .smart:
                        SmartKitView(
                            entries: conversation.entries,
                            chair: conversation.chair,
                            memoryRevision: conversation.memoryRevision,
                            onSelect: { selectedCardEntry = $0 },
                            onTearOff: { image, text in
                                KitShare.present(items: image.map { [$0, text] } ?? [text])
                            }
                        )
                    }
                }

                bottomTabs
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)
        }
        .preferredColorScheme(.dark)
        .sheet(item: $selectedCardEntry) { entry in
            TapeDetailView(
                entry: entry,
                player: tapePlayer,
                onSave: { title, summary in
                    conversation.updateEntry(id: entry.id, title: title, summary: summary)
                },
                onDelete: {
                    conversation.deleteEntry(id: entry.id)
                }
            )
        }
        .onChange(of: selectedTab) { _, _ in
            tapePlayer.stop()
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            KitAppShortcuts.updateAppShortcutParameters()
            consumeLaunchAction()
        }
        .onChange(of: scenePhase) { _, phase in
            UIApplication.shared.isIdleTimerDisabled = (phase == .active)
            if phase == .active {
                consumeLaunchAction()
            }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func consumeLaunchAction() {
        guard let action = KitLaunch.consume() else { return }
        switch action {
        case .talk(let chair):
            selectedTab = .console
            if let chair {
                conversation.setChair(chair)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                conversation.startTalkingFromLaunch()
            }
        case .fileTape:
            selectedTab = .console
            conversation.endSession()
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("K I T")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(KitPalette.ink)
                .tracking(10)

            HStack(spacing: 8) {
                Circle()
                    .fill(KitPalette.ledTeal)
                    .frame(width: 6, height: 6)
                    .shadow(color: KitPalette.ledTeal, radius: 6)
                Text("VOICE AI  •  RETRO MEMORY ARCHIVE")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.8)
            }
            .foregroundStyle(KitPalette.ledTeal)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(KitPalette.ledTeal.opacity(0.08))
            .overlay(
                Capsule()
                    .stroke(KitPalette.ledTeal.opacity(0.28), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .padding(.top, 6)
    }

    private var racksTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("The Racks Room")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(KitPalette.ink)

                Text("\(conversation.entries.count) TAPES ARCHIVED")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2.4)
                    .foregroundStyle(KitPalette.faint)

                if conversation.entries.isEmpty {
                    Text("> RACKS EMPTY. TALK A TAPE.")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(KitPalette.ledAmber)
                        .padding(.top, 8)
                } else {
                    MemoryBankBentoView(entries: Array(conversation.entries.prefix(10)), player: tapePlayer) { entry in
                        selectedCardEntry = entry
                    }

                    if conversation.entries.count > 10 {
                        Text("\(conversation.entries.count - 10) OLDER TAPES FILED")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(KitPalette.faint)
                            .padding(.top, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
    }

    private var bottomTabs: some View {
        HStack(spacing: 10) {
            ForEach(KitTab.allCases) { tab in
                Button {
                    KitHaptics.soft()
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 15, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.6)
                    }
                    .foregroundStyle(selectedTab == tab ? tab.activeColor : KitPalette.ledAmber)
                    .shadow(color: (selectedTab == tab ? tab.activeColor : KitPalette.ledAmber).opacity(0.45), radius: 8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .kitCard(radius: 20, glow: selectedTab == tab ? tab.activeColor : nil)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.top, 2)
    }

    private var background: some View {
        ZStack {
            KitPalette.bg.ignoresSafeArea()

            GeometryReader { geo in
                Path { path in
                    let spacing: CGFloat = 32
                    var x: CGFloat = 0
                    while x <= geo.size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                        x += spacing
                    }
                    var y: CGFloat = 0
                    while y <= geo.size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        y += spacing
                    }
                }
                .stroke(KitPalette.ledTeal.opacity(0.10), lineWidth: 0.7)
            }
            .ignoresSafeArea()
        }
    }
}

private enum KitTab: String, CaseIterable, Identifiable {
    case console
    case racks
    case smart

    var id: String { rawValue }

    var title: String {
        switch self {
        case .console: return "CONSOLE"
        case .racks: return "RACKS ROOM"
        case .smart: return "SMART KIT"
        }
    }

    var icon: String {
        switch self {
        case .console: return "gauge"
        case .racks: return "archivebox"
        case .smart: return "brain.head.profile"
        }
    }

    var activeColor: Color {
        KitPalette.ledRed
    }
}

#Preview {
    ContentView()
}
