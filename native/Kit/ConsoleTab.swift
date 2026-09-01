import SwiftUI

struct ConsoleTab: View {
    @ObservedObject var conversation: ConversationManager
    @ObservedObject var speechManager: SpeechManager
    @ObservedObject var batteryNudge: BatteryNudgeManager

    private let lampButtonHeight: CGFloat = 52
    private let lampSpacing: CGFloat = 10
    private let lampVerticalPad: CGFloat = 12

    private var lampColumnHeight: CGFloat {
        (lampButtonHeight * 4) + (lampSpacing * 3) + (lampVerticalPad * 2)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if conversation.recoveredSessionNotice {
                    recoveredSessionBanner
                }

                if let nudgeMessage = batteryNudge.nudgeMessage {
                    batteryNudgeBanner(nudgeMessage)
                }

                Grid(alignment: .center, horizontalSpacing: 10, verticalSpacing: 0) {
                    GridRow {
                        lampColumn(items: leftLamps)
                        voiceWell
                        lampColumn(items: rightLamps)
                    }
                }

                cruiseStack

                Text(modeBlurb)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2.6)
                    .foregroundStyle(KitPalette.ledAmber)
                    .shadow(color: KitPalette.ledAmber.opacity(0.45), radius: 8)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                transcriptDrawer
                endSessionButton
            }
            .padding(.bottom, 8)
        }
    }

    private var voiceWell: some View {
        let recording = speechManager.isListening
        return Button {
            conversation.toggleTalk()
        } label: {
            VStack(spacing: 10) {
                KITTEqualizerView(
                    level: speechManager.audioLevel,
                    isActive: recording || conversation.state == .speaking,
                    style: conversation.state == .speaking ? .scanner : .reactive,
                    showsChrome: false
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                TimelineView(.periodic(from: .now, by: 0.07)) { context in
                    Text(KitFormat.longClock(elapsed(at: context.date)))
                        .font(.system(size: 26, weight: .semibold, design: .monospaced))
                        .foregroundStyle(KitPalette.ledRed)
                        .shadow(color: KitPalette.ledRed.opacity(0.7), radius: 10)
                        .tracking(2)
                }

                Text(voiceCaption)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(KitPalette.faint)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, minHeight: lampColumnHeight, maxHeight: .infinity)
            .kitWell(radius: 22)
            .shadow(color: KitPalette.ledRed.opacity(recording ? 0.45 : 0), radius: 22, y: 10)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(conversation.state == .thinking)
        .accessibilityLabel(recording ? "Stop talking to \(conversation.chair.title)" : "Talk to \(conversation.chair.title)")
    }

    private var cruiseStack: some View {
        VStack(spacing: 8) {
            ForEach(Chair.allCases) { chair in
                cruiseButton(
                    style: chair,
                    selected: conversation.chair == chair,
                    hot: conversation.chair == chair && speechManager.isListening,
                    enabled: true
                ) {
                    conversation.setChair(chair)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Driving mode")
    }

    /// Three tiers: idle (matte obsidian) → selected seat (KITT panel colour) →
    /// hot mic (brighter fill + radiant glow). Each seat keeps its own dash colour.
    private func cruiseButton(style: Chair, selected: Bool, hot: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        let colors = KitPalette.cruiseColors(for: style)
        let fill: Color = hot ? colors.hot : (selected ? colors.dim : KitPalette.consoleSlate)
        let stroke: Color = hot
            ? colors.glow
            : (selected ? colors.glow.opacity(0.55) : Color.white.opacity(0.10))
        let labelColor: Color = selected || hot
            ? Color.black.opacity(0.88)
            : colors.labelTint.opacity(0.34)

        return Button(action: action) {
            Text(style.modeLabel)
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                .tracking(2.4)
                .foregroundStyle(labelColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                )
                .shadow(color: colors.glow.opacity(hot ? 0.6 : 0), radius: 18)
                .shadow(color: colors.glow.opacity(hot ? 0.3 : 0), radius: 6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var endSessionButton: some View {
        Button {
            conversation.endSession()
            KitHaptics.success()
        } label: {
            Text("END SESSION")
                .font(.system(.headline, design: .monospaced, weight: .heavy))
                .tracking(2)
                .foregroundStyle(KitPalette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [KitPalette.endTop, KitPalette.endBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(KitPalette.ledRed.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: KitPalette.ledRed.opacity(endSessionDisabled ? 0 : 0.4), radius: 12)
        }
        .buttonStyle(.plain)
        .disabled(endSessionDisabled)
        .opacity(endSessionDisabled ? 0.32 : 1)
    }

    private var transcriptDrawer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LIVE SPEECH DRAWER")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2.6)
                    .foregroundStyle(KitPalette.faint)
                Spacer()
                Text(drawerStateLabel)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(speechManager.isListening ? KitPalette.ledRed : KitPalette.faint)
            }

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(drawerLines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(KitPalette.ledAmber)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                }
                .frame(minHeight: 108, maxHeight: 108)
                .onChange(of: drawerLines.count) { _, _ in
                    if let last = drawerLines.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .padding(16)
        .kitWell(radius: 18)
    }

    private func lampColumn(items: [ConsoleLampItem]) -> some View {
        VStack(spacing: lampSpacing) {
            ForEach(items) { item in
                VStack(spacing: 3) {
                    Text(item.label)
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(1)
                    if let sub = item.sub {
                        Text(sub)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                }
                .foregroundStyle(item.isOn ? KitPalette.bg : item.color.opacity(0.28))
                .frame(width: 48, height: lampButtonHeight)
                .background(
                    Capsule(style: .continuous)
                        .fill(item.isOn ? item.color : item.color.opacity(0.12))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(item.color.opacity(item.isOn ? 0.7 : 0.14), lineWidth: 1)
                )
                .shadow(color: item.isOn ? item.color.opacity(0.55) : .clear, radius: 10)
                .accessibilityLabel("\(item.label) \(item.isOn ? "on" : "off")")
            }
        }
        .padding(.vertical, lampVerticalPad)
        .padding(.horizontal, 7)
        .background(KitPalette.plasticDark)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(KitPalette.line, lineWidth: 1)
        )
    }

    private var recoveredSessionBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This walk is still open. File the tape, or keep talking.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(KitPalette.ledTeal)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("FILE TAPE") {
                    KitHaptics.success()
                    conversation.endSession()
                }
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(KitPalette.bg)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(KitPalette.ledTeal)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button("KEEP TALKING") {
                    conversation.dismissRecoveredNotice()
                }
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(KitPalette.ledTeal)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KitPalette.ledTeal.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(KitPalette.ledTeal.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func batteryNudgeBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Text(message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(KitPalette.ledOrange)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button("DISMISS") {
                batteryNudge.dismissNudge()
            }
            .font(.system(.caption2, design: .monospaced, weight: .bold))
            .foregroundStyle(KitPalette.ledOrange)
        }
        .padding(12)
        .background(KitPalette.ledOrange.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(KitPalette.ledOrange.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var leftLamps: [ConsoleLampItem] {
        _ = conversation.memoryRevision
        let groups = Dictionary(grouping: conversation.entries, by: { $0.tapeFamily.consoleGroup })
        let lastGroup = conversation.entries.first?.tapeFamily.consoleGroup
        return [
            ConsoleLampItem(label: "CRE", sub: pad(groups[.creative]?.count ?? 0), color: KitPalette.ledPink, isOn: lastGroup == .creative),
            ConsoleLampItem(label: "RFL", sub: pad(groups[.reflection]?.count ?? 0), color: KitPalette.ledOrange, isOn: lastGroup == .reflection),
            ConsoleLampItem(label: "ACT", sub: pad(groups[.action]?.count ?? 0), color: KitPalette.ledGreen, isOn: lastGroup == .action),
            ConsoleLampItem(label: "AUTO", sub: "AI", color: KitPalette.ledAmber, isOn: true)
        ]
    }

    private var rightLamps: [ConsoleLampItem] {
        [
            ConsoleLampItem(label: "MIC", color: KitPalette.ledAmber, isOn: speechManager.isListening),
            ConsoleLampItem(label: "REC", color: KitPalette.ledRed, isOn: speechManager.isListening),
            ConsoleLampItem(label: "AI", color: KitPalette.ledTeal, isOn: conversation.state == .thinking || conversation.state == .speaking),
            ConsoleLampItem(label: "SAV", color: KitPalette.ledGreen, isOn: conversation.state == .saved)
        ]
    }

    private var modeBlurb: String {
        switch conversation.chair {
        case .diane: return "SILENT LOGGING  •  NO VOICE REPLY"
        case .auto: return "LIGHT CHAT  •  KIT KEEPS IT SNAPPY"
        case .kit: return "FULL PURSUIT AI  •  KIT TALKS BACK"
        }
    }

    private var voiceCaption: String {
        if speechManager.permissionDenied || conversation.errorMessage != nil {
            return "CHECK THE DRAWER"
        }
        if conversation.state == .thinking {
            return "PROCESSING MEMORY"
        }
        if conversation.state == .speaking {
            return "KIT IS SPEAKING"
        }
        if speechManager.isListening {
            return "TAP TO STOP & SAVE"
        }
        if conversation.state == .saved {
            return "TAPE FILED"
        }
        return "TAP TO TALK. PAUSE TO STOP."
    }

    private var drawerStateLabel: String {
        if speechManager.permissionDenied || conversation.errorMessage != nil {
            return "ERROR"
        }
        if speechManager.isListening { return "LIVE" }
        switch conversation.state {
        case .thinking: return "THINKING"
        case .speaking: return "SPEAKING"
        case .saved: return "SAVED"
        case .idle: return "IDLE"
        }
    }

    private var drawerLines: [String] {
        if speechManager.permissionDenied {
            return ["> Microphone or Speech access denied. Enable it in Settings."]
        }
        if let errorMessage = conversation.errorMessage {
            return ["> \(errorMessage)"]
        }

        var lines: [String] = []
        let turns = conversation.sessionTurns.reversed()
        if turns.isEmpty && !speechManager.isListening && conversation.state == .idle {
            lines.append("> AWAITING INPUT_")
        }
        for turn in turns {
            if turn.isMarker {
                lines.append("> \(turn.text)")
            } else if conversation.chair == .diane || !turn.isFromAI {
                lines.append("> \(turn.text)")
            } else {
                lines.append("> Kit: \(turn.text)")
            }
        }
        if speechManager.isListening {
            let live = speechManager.liveTranscript.isEmpty ? "listening" : speechManager.liveTranscript
            lines.append("> Transcribing: \(live)_")
        } else if conversation.state == .thinking {
            lines.append("> Processing memory")
        } else if conversation.state == .speaking {
            lines.append("> Kit is speaking")
        } else if conversation.state == .saved {
            lines.append("> Tape filed. Racks Room.")
        }
        return lines
    }

    private var endSessionDisabled: Bool {
        conversation.sessionTurns.isEmpty
    }

    private func elapsed(at date: Date) -> TimeInterval {
        if let started = conversation.turnClockStartedAt {
            return date.timeIntervalSince(started)
        }
        return conversation.frozenTurnSeconds
    }

    private func pad(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}

private struct ConsoleLampItem: Identifiable {
    let label: String
    var sub: String? = nil
    let color: Color
    let isOn: Bool
    var id: String { label }
}
