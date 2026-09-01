import SwiftUI

struct TapeDetailView: View {
    let entry: JournalEntry
    @ObservedObject var player: TapeVoice
    let onSave: (_ title: String, _ summary: String) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var summary: String
    @State private var confirmErase = false

    private var family: TapeFamily { entry.tapeFamily }
    private var isPlaying: Bool { player.playingID == entry.id }

    init(
        entry: JournalEntry,
        player: TapeVoice,
        onSave: @escaping (_ title: String, _ summary: String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.entry = entry
        self.player = player
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: entry.displayTitle)
        _summary = State(initialValue: entry.text)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(family.label)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(2.4)
                                .foregroundStyle(KitPalette.family(family))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(KitPalette.family(family).opacity(0.16))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            Text(title.isEmpty ? "Untitled tape" : title)
                                .font(.custom("MarkerFelt-Wide", size: 34))
                                .foregroundStyle(KitPalette.ink)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)

                            Text(metaLine)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .tracking(1.6)
                                .foregroundStyle(KitPalette.faint)
                        }

                        Spacer(minLength: 8)

                        Button {
                            dismissAfterSave()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(KitPalette.bg)
                                .frame(width: 40, height: 40)
                                .background(KitPalette.ledRed)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: KitPalette.ledRed.opacity(0.7), radius: 12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close tape")
                    }

                    Button {
                        var draft = entry
                        draft.title = title
                        draft.text = summary
                        player.toggle(entry: draft)
                    } label: {
                        Label(isPlaying ? "PAUSE TAPE" : "PLAY TAPE", systemImage: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(.subheadline, design: .monospaced, weight: .heavy))
                            .tracking(2)
                            .foregroundStyle(isPlaying ? KitPalette.ink : KitPalette.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isPlaying ? KitPalette.ledRed : KitPalette.ledAmber)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: KitPalette.ledAmber.opacity(isPlaying ? 0 : 0.35), radius: 10)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Reads the text on this tape. There is no audio file.")

                    Text("NO AUDIO ON THIS TAPE. PLAY READS THE WORDS.")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(KitPalette.faint)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("LABEL")
                            .kitFieldLabel()
                        TextField("Untitled tape", text: $title)
                            .textFieldStyle(.plain)
                            .font(.custom("MarkerFelt-Wide", size: 22))
                            .foregroundStyle(KitPalette.marker(family))
                            .padding(14)
                            .background(KitPalette.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("WORDS")
                            .kitFieldLabel()
                        TextEditor(text: $summary)
                            .scrollContentBackground(.hidden)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(KitPalette.ink)
                            .frame(minHeight: 180)
                            .padding(10)
                            .kitWell(radius: 16)
                    }

                    HStack(spacing: 12) {
                        Button {
                            KitHaptics.success()
                            dismissAfterSave()
                        } label: {
                            Text("SAVE EDIT")
                                .font(.system(.footnote, design: .monospaced, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(KitPalette.bg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(KitPalette.ledTeal)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            confirmErase = true
                        } label: {
                            Label("ERASE", systemImage: "trash")
                                .font(.system(.footnote, design: .monospaced, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(KitPalette.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(KitPalette.ledRed)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(KitPalette.bg.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .confirmationDialog("Erase this tape?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Erase tape", role: .destructive) {
                player.stop()
                onDelete()
                dismiss()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("The words leave this phone. This cannot be undone.")
        }
        .onDisappear {
            if player.playingID == entry.id {
                player.stop()
            }
        }
    }

    private var metaLine: String {
        let date = KitFormat.stamp(entry.timestamp).uppercased()
        let duration = entry.durationSeconds > 0 ? KitFormat.clock(TimeInterval(entry.durationSeconds)) : "TEXT TAPE"
        return "\(date)  •  \(duration)"
    }

    private func dismissAfterSave() {
        onSave(title, summary)
        dismiss()
    }
}

private extension Text {
    func kitFieldLabel() -> some View {
        self
            .font(.system(.caption2, design: .monospaced, weight: .bold))
            .tracking(2)
            .foregroundStyle(KitPalette.faint)
    }
}
