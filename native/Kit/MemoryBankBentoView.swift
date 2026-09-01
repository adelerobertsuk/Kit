import SwiftUI

struct MemoryBankBentoView: View {
    let entries: [JournalEntry]
    @ObservedObject var player: TapeVoice
    var onSelect: (JournalEntry) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 8) {
                    Button {
                        KitHaptics.soft()
                        onSelect(entry)
                    } label: {
                        tapeSpine(entry, index: index)
                    }
                    .buttonStyle(.plain)

                    playButton(for: entry)
                }
                .padding(.leading, CGFloat(index % 3) * 4)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Racks Room")
    }

    private func tapeSpine(_ entry: JournalEntry, index: Int) -> some View {
        let family = entry.tapeFamily
        let color = KitPalette.family(family)
        let paper = index.isMultiple(of: 2) ? KitPalette.paper : KitPalette.paperAlt

        return HStack(spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(width: 7)
                .shadow(color: color.opacity(0.7), radius: 8)

            Text(entry.seatLabel)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(entry.chair?.talksBack == true ? KitPalette.ledRed : KitPalette.ledAmber)
                .multilineTextAlignment(.center)
                .rotationEffect(.degrees(-90))
                .frame(width: 52, height: 64)
                .background(Color.black.opacity(0.45))

            Text(entry.displayTitle)
                .font(.custom("MarkerFelt-Wide", size: 20))
                .foregroundStyle(KitPalette.marker(family))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(paper)
                .rotationEffect(.degrees(index.isMultiple(of: 3) ? -0.6 : 0.4))

            VStack(alignment: .trailing, spacing: 4) {
                Text(KitFormat.shortDate(entry.timestamp))
                Text(entry.durationSeconds > 0 ? KitFormat.clock(TimeInterval(entry.durationSeconds)) : "TEXT")
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(KitPalette.muted)
            .frame(width: 58, alignment: .trailing)
            .padding(.trailing, 10)
        }
        .frame(minHeight: 72)
        .background(
            LinearGradient(
                colors: [KitPalette.plastic, KitPalette.plasticDark],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.displayTitle), \(entry.seatLabel), \(family.label)")
    }

    private func playButton(for entry: JournalEntry) -> some View {
        let isPlaying = player.playingID == entry.id
        return Button {
            player.toggle(entry: entry)
        } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isPlaying ? KitPalette.ledRed : KitPalette.ledAmber)
                .frame(width: 44, height: 72)
                .kitCard(radius: 12, glow: isPlaying ? KitPalette.ledRed : nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause tape" : "Play tape. Reads the text.")
    }
}

#Preview {
    ZStack {
        KitPalette.bg.ignoresSafeArea()
        ScrollView {
            MemoryBankBentoView(
                entries: [
                    JournalEntry(text: "Noticed how quiet the streets felt and decided to keep tomorrow morning free for writing.", isFromAI: true, title: "Evening walk"),
                    JournalEntry(text: "Pick up coffee, oat milk and Lola's treats.", isFromAI: true, title: "Kitchen run"),
                    JournalEntry(text: "A voice-first card review could make the end of a session feel complete.", isFromAI: true, title: "Product thought")
                ],
                player: TapeVoice()
            )
            .padding()
        }
    }
}
