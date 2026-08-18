import SwiftUI

/// The Interceptor-skin Memory Card — the only template in v1 (Penny's card ships with
/// Penny becoming a real selectable skin, not before). Used both on-screen in the review
/// sheet and rendered off-screen to a shareable image, so it must not depend on interaction.
struct MemoryCardView: View {
    let title: String
    let summary: String
    let date: Date
    let isBasicFallback: Bool
    let showsSignature: Bool

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("K I T")
                    .font(.system(.callout, design: .monospaced, weight: .bold))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Label(isBasicFallback ? "NEEDS REVIEW" : "PRIVATE", systemImage: isBasicFallback ? "exclamationmark.triangle.fill" : "lock.fill")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .tracking(1)
                    .foregroundColor(isBasicFallback ? .yellow : .cyan)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 14) {
                Text(dateFormatter.string(from: date).uppercased())
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(.orange.opacity(0.85))

                Text(title)
                    .font(.system(.title, design: .monospaced, weight: .heavy))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(summary)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if showsSignature {
                HStack {
                    Spacer()
                    Text("Made with Kit")
                        .font(.system(.caption2, design: .monospaced, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(28)
        .frame(width: 360, height: 450, alignment: .leading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var cardBackground: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.045)
            RadialGradient(
                colors: [Color.cyan.opacity(0.16), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 320
            )
            RadialGradient(
                colors: [Color.red.opacity(0.08), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 260
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        MemoryCardView(
            title: "Evening walk, clear head",
            summary: "Noticed how quiet the streets felt and decided to keep tomorrow morning free for writing. Also want to pick up coffee and oat milk.",
            date: Date(),
            isBasicFallback: false,
            showsSignature: true
        )
    }
}
