import SwiftUI
import UIKit

struct SmartKitView: View {
    let entries: [JournalEntry]
    let chair: Chair
    var memoryRevision: Int = 0
    var onSelect: (JournalEntry) -> Void
    var onTearOff: (_ image: UIImage?, _ text: String) -> Void

    @State private var printed = false

    private var weekEntries: [JournalEntry] {
        entries.filter { Calendar.current.isDate($0.timestamp, equalTo: .now, toGranularity: .weekOfYear) }
    }

    private var groupCounts: [ConsoleLampGroup: Int] {
        _ = memoryRevision
        var counts: [ConsoleLampGroup: Int] = [:]
        for entry in entries {
            counts[entry.tapeFamily.consoleGroup, default: 0] += 1
        }
        return counts
    }

    private var totalSeconds: Int {
        entries.reduce(0) { $0 + $1.durationSeconds }
    }

    private var topSignal: String {
        groupCounts.max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.rawValue > rhs.key.rawValue
            }
            return lhs.value < rhs.value
        }?.key.reportLabel ?? "NONE"
    }

    private var topics: [(word: String, count: Int)] {
        SmartKitTopics.top(from: entries, limit: 6)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Smart Kit")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(KitPalette.ink)

                    Text("AI ANALYTICS  •  SIGNAL  •  TEAR OFF")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(2.4)
                        .foregroundStyle(KitPalette.faint)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    metricCard(title: "TAPES", value: pad(entries.count))
                    metricCard(title: "THIS WEEK", value: pad(weekEntries.count))
                    metricCard(title: "TOTAL TIME", value: KitFormat.clock(TimeInterval(totalSeconds)))
                    metricCard(title: "TOP SIGNAL", value: topSignal)
                }

                categoryMix
                topicSignal

                Button {
                    KitHaptics.tap()
                    if printed {
                        tearOff()
                    } else {
                        withAnimation(.easeOut(duration: 0.25)) {
                            printed = true
                        }
                    }
                } label: {
                    Label(printed ? "TEAR OFF" : "PRINT DOT-MATRIX SUMMARY", systemImage: "printer.fill")
                        .font(.system(.subheadline, design: .monospaced, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(KitPalette.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [KitPalette.printTop, KitPalette.printBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: KitPalette.ledAmber.opacity(0.35), radius: 12)
                }
                .buttonStyle(.plain)

                if printed {
                    reportReceipt
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LATEST TAPES")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(2.2)
                            .foregroundStyle(KitPalette.faint)

                        ForEach(Array(entries.prefix(3))) { entry in
                            Button {
                                KitHaptics.soft()
                                onSelect(entry)
                            } label: {
                                summaryRow(entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(2.2)
                .foregroundStyle(KitPalette.faint)

            Text(value)
                .font(.system(size: 24, weight: .light, design: .monospaced))
                .foregroundStyle(KitPalette.ledAmber)
                .shadow(color: KitPalette.ledAmber.opacity(0.4), radius: 8)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(16)
        .kitCard(radius: 18)
    }

    private func pad(_ value: Int) -> String {
        String(format: "%02d", value)
    }

    private var categoryMix: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CATEGORY MIX")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(KitPalette.faint)

            ForEach(ConsoleLampGroup.allCases) { group in
                let count = groupCounts[group] ?? 0
                let pct = entries.isEmpty ? 0 : Int(round((Double(count) / Double(entries.count)) * 100))
                let color = KitPalette.group(group)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(group.mixLabel)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(KitPalette.muted)
                        Spacer()
                        Text("\(pct)%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(KitPalette.muted)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(color)
                                .frame(width: max(geo.size.width * CGFloat(pct) / 100, pct == 0 ? 0 : 8))
                                .shadow(color: color.opacity(0.65), radius: 8)
                        }
                    }
                    .frame(height: 10)
                }
            }
        }
        .padding(18)
        .kitCard(radius: 20)
    }

    private var topicSignal: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOPIC SIGNAL")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(KitPalette.faint)

            if topics.isEmpty {
                Text("> NO TOPICS YET")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(KitPalette.ledAmber)
            } else {
                ChipFlow(spacing: 8) {
                    ForEach(topics, id: \.word) { topic in
                        Text("\(topic.word.uppercased()) ×\(topic.count)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(KitPalette.ledTeal)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(KitPalette.line, lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(18)
        .kitCard(radius: 20)
    }

    private var reportReceipt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("*  *  *  K I T   S Y S T E M   R E P O R T  *  *  *")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
            Text(reportText)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Color.black.opacity(0.78))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(ReceiptPaper())
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }

    private func summaryRow(_ entry: JournalEntry) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(KitPalette.family(entry.tapeFamily))
                .frame(width: 4)
                .shadow(color: KitPalette.family(entry.tapeFamily).opacity(0.6), radius: 6)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.displayTitle.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(KitPalette.ink)
                        .lineLimit(1)
                    Spacer()
                    Text(entry.tapeFamily.lampCode)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(KitPalette.ledAmber)
                }
                Text(entry.text)
                    .font(.system(.footnote, weight: .medium))
                    .foregroundStyle(KitPalette.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(14)
        .kitCard(radius: 16)
    }

    private var reportText: String {
        let topicLine = topics.map(\.word).joined(separator: ", ").uppercased()
        var lines = [
            "PRINTED : \(KitFormat.stamp(.now).uppercased())",
            "TAPES   : \(String(format: "%03d", entries.count))",
            "7-DAY   : \(String(format: "%03d", weekEntries.count))",
            "RUNTIME : \(KitFormat.clock(TimeInterval(totalSeconds)))",
            "SIGNAL  : \(topSignal)",
            "MODE    : \(chair.modeLabel)",
            "------------------------------------------"
        ]
        for group in ConsoleLampGroup.allCases {
            let n = String(format: "%03d", groupCounts[group] ?? 0)
            let pad = String(repeating: ".", count: max(1, 20 - group.reportLabel.count))
            lines.append("\(group.reportLabel) \(pad) \(n)")
        }
        lines.append(contentsOf: [
            "------------------------------------------",
            "TOPICS  : \(topicLine.isEmpty ? "N/A" : topicLine)",
            "------------------------------------------",
            "END OF FEED >> KIT SIGNING OFF"
        ])
        return lines.joined(separator: "\n")
    }

    private func tearOff() {
        let export = reportReceipt.padding(20).background(KitPalette.bg)
        let renderer = ImageRenderer(content: export)
        renderer.scale = 3
        onTearOff(renderer.uiImage, reportText)
    }

}

private struct ReceiptPaper: View {
    var body: some View {
        GeometryReader { geo in
            let row: CGFloat = 20
            let count = max(1, Int(ceil(geo.size.height / row)))
            VStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { index in
                    Rectangle()
                        .fill(index.isMultiple(of: 2) ? KitPalette.receipt : KitPalette.receiptRule)
                        .frame(height: row)
                }
            }
        }
    }
}

private struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height),
            subviews: subviews
        )
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        let width = maxWidth.isFinite ? maxWidth : maxX
        return (origins, CGSize(width: width, height: y + rowHeight))
    }
}

enum SmartKitTopics {
    private static let stopwords: Set<String> = [
        "about", "after", "again", "being", "could", "doing", "every", "from",
        "have", "just", "like", "that", "this", "with", "would", "there",
        "their", "what", "when", "where", "which", "while", "your", "them",
        "then", "than", "some", "really", "think", "going", "still", "other"
    ]

    static func top(from entries: [JournalEntry], limit: Int) -> [(word: String, count: Int)] {
        var counts: [String: Int] = [:]
        for entry in entries {
            let words = entry.text.lowercased().split { !$0.isLetter }
            for word in words where word.count >= 5 && !stopwords.contains(String(word)) {
                counts[String(word), default: 0] += 1
            }
        }
        return counts
            .sorted {
                if $0.value == $1.value { return $0.key < $1.key }
                return $0.value > $1.value
            }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }
}
