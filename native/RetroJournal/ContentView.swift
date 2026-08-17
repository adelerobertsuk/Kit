import SwiftUI

struct ContentView: View {
    @StateObject private var conversation: ConversationManager
    @ObservedObject private var speechManager: SpeechManager
    @ObservedObject private var batteryNudge: BatteryNudgeManager
    @State private var selectedCardEntry: JournalEntry?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter
    }()

    private let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    init() {
        let convo = ConversationManager()
        _conversation = StateObject(wrappedValue: convo)
        _speechManager = ObservedObject(wrappedValue: convo.speechManager)
        _batteryNudge = ObservedObject(wrappedValue: convo.batteryNudge)
    }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.045).ignoresSafeArea()

            VStack(spacing: 18) {
                header

                if conversation.recoveredSessionNotice {
                    recoveredSessionBanner
                }

                if let nudgeMessage = batteryNudge.nudgeMessage {
                    batteryNudgeBanner(nudgeMessage)
                }

                voiceBox

                transcriptBox

                endSessionButton

                secondaryButtonRow

                Divider().background(Color.cyan.opacity(0.2))

                logList

                clockReadout
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .preferredColorScheme(.dark)
        .sheet(item: $selectedCardEntry) { entry in
            MemoryCardReviewView(entry: entry) { title, summary in
                conversation.updateEntry(id: entry.id, title: title, summary: summary)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Text("K . I . T . T .")
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .foregroundColor(.white.opacity(0.92))
                .tracking(4)

            HStack(spacing: 14) {
                grille
                privacyBadge
                grille
            }
        }
        .padding(.top, 8)
    }

    private var grille: some View {
        VStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { _ in
                Capsule().fill(Color.white.opacity(0.12)).frame(width: 34, height: 2)
            }
        }
    }

    private var privacyBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .bold))
            Text("PRIVATE · ON DEVICE")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .tracking(1)
        }
        .foregroundColor(.cyan)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - Voice box + status plate

    private var voiceBox: some View {
        VStack(spacing: 12) {
            KITTEqualizerView(
                level: speechManager.audioLevel,
                isActive: speechManager.isListening || conversation.state == .speaking,
                style: conversation.state == .speaking ? .scanner : .reactive
            )

            statusPlate

            if conversation.state == .idle && !speechManager.isListening && conversation.errorMessage == nil && !speechManager.permissionDenied {
                Text("tap the voice box or use AirPods")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { conversation.toggleTalk() }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(speechManager.isListening ? "Stop talking to KITT" : "Talk to KITT")
    }

    private var status: (text: String, color: Color) {
        if speechManager.permissionDenied || conversation.errorMessage != nil {
            return ("ERROR", .red)
        }
        if speechManager.isListening {
            return ("LISTENING", .red)
        }
        switch conversation.state {
        case .thinking: return ("THINKING", .orange)
        case .speaking: return ("SPEAKING", .orange)
        case .saved: return ("SAVED", .cyan)
        case .idle: return ("READY", .orange)
        }
    }

    private var statusPlate: some View {
        Text(status.text)
            .font(.system(.footnote, design: .monospaced, weight: .bold))
            .tracking(3)
            .foregroundColor(status.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(status.color.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .animation(.easeOut(duration: 0.15), value: status.text)
    }

    // MARK: - Transcript box

    @ViewBuilder
    private var transcriptBox: some View {
        let content = transcriptContent
        Text(content.text)
            .font(.system(.callout, design: .monospaced))
            .foregroundColor(content.color)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .frame(maxWidth: .infinity, minHeight: 70)
            .padding(.horizontal, 12)
            .background(Color.black.opacity(0.4))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var transcriptContent: (text: String, color: Color) {
        if speechManager.permissionDenied {
            return ("Microphone / Speech access denied — enable it in Settings.", .red)
        }
        if let errorMessage = conversation.errorMessage {
            return (errorMessage, .red)
        }
        if speechManager.isListening {
            return (speechManager.liveTranscript.isEmpty ? "I'm listening..." : speechManager.liveTranscript, .red.opacity(0.9))
        }
        switch conversation.state {
        case .thinking: return ("kitt is thinking...", .orange)
        case .speaking: return ("kitt is speaking...", .orange)
        case .saved: return ("saved to memory bank.", .cyan)
        case .idle: return ("ready when you are.", .white.opacity(0.4))
        }
    }

    // MARK: - Buttons

    private var endSessionDisabled: Bool {
        conversation.state != .idle || conversation.sessionTurns.isEmpty
    }

    private var endSessionButton: some View {
        Button(action: { conversation.endSession() }) {
            Text("END SESSION")
                .font(.system(.headline, design: .monospaced, weight: .heavy))
                .tracking(2)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.85, green: 0.1, blue: 0.08), Color(red: 0.55, green: 0.03, blue: 0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.red.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: .red.opacity(endSessionDisabled ? 0 : 0.4), radius: 10)
        }
        .disabled(endSessionDisabled)
        .opacity(endSessionDisabled ? 0.35 : 1.0)
    }

    private var secondaryButtonRow: some View {
        HStack(spacing: 14) {
            secondaryButton(title: "MARK MOMENT", disabled: false) {
                conversation.markMoment()
            }
            secondaryButton(title: "MUTE", disabled: !speechManager.isListening) {
                conversation.muteCurrentTurn()
            }
        }
    }

    private func secondaryButton(title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.footnote, design: .monospaced, weight: .bold))
                .tracking(1)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.65, blue: 0.15), Color(red: 0.75, green: 0.45, blue: 0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                )
        }
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1.0)
    }

    private var recoveredSessionBanner: some View {
        HStack(spacing: 10) {
            Text("Recovered an unfinished session — your last thoughts are still here.")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.cyan)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button(action: { conversation.dismissRecoveredNotice() }) {
                Text("DISMISS")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundColor(.cyan)
            }
        }
        .padding(10)
        .background(Color.cyan.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
        )
    }

    private func batteryNudgeBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Text(message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.orange)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button(action: { batteryNudge.dismissNudge() }) {
                Text("DISMISS")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundColor(.orange)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Log

    private var logList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if conversation.sessionTurns.isEmpty && conversation.entries.isEmpty {
                    Text("> no entries yet")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.5))
                        .padding(.top, 12)
                }
                if !conversation.sessionTurns.isEmpty {
                    sectionHeader("RUNNING MEMORY · THIS SESSION")
                    ForEach(conversation.sessionTurns) { entry in
                        entryRow(entry)
                    }
                }
                if !conversation.entries.isEmpty {
                    sectionHeader("MEMORY BANK")
                    MemoryBankBentoView(entries: conversation.entries) { entry in
                        selectedCardEntry = entry
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption2, design: .monospaced, weight: .bold))
            .tracking(2)
            .foregroundColor(.cyan.opacity(0.6))
            .padding(.top, 8)
    }

    private func entryRow(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(entry.isMarker ? "★ MOMENT" : (entry.isFromAI ? "KITT" : "YOU")) · \(dateFormatter.string(from: entry.timestamp))")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(entry.isMarker ? .yellow.opacity(0.9) : .orange.opacity(0.8))
            if !entry.isMarker {
                Text(entry.text)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(entry.isFromAI ? .orange : .cyan)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background((entry.isMarker ? Color.yellow : (entry.isFromAI ? Color.orange : Color.cyan)).opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke((entry.isMarker ? Color.yellow : (entry.isFromAI ? Color.orange : Color.cyan)).opacity(0.25), lineWidth: 1)
        )
    }

    private var clockReadout: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text(clockFormatter.string(from: context.date))
                .font(.system(.footnote, design: .monospaced, weight: .bold))
                .foregroundColor(.red.opacity(0.6))
                .tracking(1)
        }
        .padding(.top, 4)
    }
}

#Preview {
    ContentView()
}
