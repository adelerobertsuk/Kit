import SwiftUI

/// A compact, phone-first interpretation of the Penny bento reference.
/// The semantic hierarchy stays the same in every skin; this first pass uses
/// the existing Interceptor palette until the app-level skin switch is wired.
struct MemoryBankBentoView: View {
    let entries: [JournalEntry]
    var onSelect: (JournalEntry) -> Void = { _ in }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM · HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 10) {
            if let latest = entries.first {
                heroCard(latest)
            }

            if entries.count > 1 {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(entries.dropFirst())) { entry in
                        compactCard(entry)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Memory Bank")
    }

    private func heroCard(_ entry: JournalEntry) -> some View {
        Button(action: { onSelect(entry) }) {
            heroCardContent(entry)
        }
        .buttonStyle(.plain)
    }

    private func heroCardContent(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("PRIVATE", systemImage: "lock.fill")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(.cyan.opacity(0.8))

                Spacer()

                if entry.isBasicFallback {
                    needsReviewBadge
                }

                Text(dateFormatter.string(from: entry.timestamp).uppercased())
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Text("LATEST MEMORY")
                .font(.system(.headline, design: .monospaced, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.white)

            Text(entry.text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(heroBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.cyan.opacity(0.28), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func compactCard(_ entry: JournalEntry) -> some View {
        Button(action: { onSelect(entry) }) {
            compactCardContent(entry)
        }
        .buttonStyle(.plain)
    }

    private func compactCardContent(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "memorychip")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.orange)

                if entry.isBasicFallback {
                    Spacer()
                    needsReviewBadge
                }
            }

            Text(entry.text)
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(5)
                .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)

            Text(dateFormatter.string(from: entry.timestamp).uppercased())
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.42))
        }
        .padding(14)
        .background(Color.white.opacity(0.055))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var needsReviewBadge: some View {
        Label("NEEDS REVIEW", systemImage: "exclamationmark.triangle.fill")
            .font(.system(.caption2, design: .monospaced, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(.yellow)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.yellow.opacity(0.12))
            .overlay(
                Capsule().stroke(.yellow.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Capsule())
    }

    private var heroBackground: some View {
        ZStack {
            Color(red: 0.025, green: 0.07, blue: 0.085)
            RadialGradient(
                colors: [.cyan.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 8,
                endRadius: 260
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ScrollView {
            MemoryBankBentoView(entries: [
                JournalEntry(text: "Noticed how quiet the streets felt and decided to keep tomorrow morning free for writing.", isFromAI: true),
                JournalEntry(text: "Pick up coffee, oat milk and Lola's treats.", isFromAI: true),
                JournalEntry(text: "A voice-first card review could make the end of a session feel complete.", isFromAI: true)
            ])
            .padding()
        }
    }
}
