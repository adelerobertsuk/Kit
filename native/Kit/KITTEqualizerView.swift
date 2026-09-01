import SwiftUI

enum KITTEqualizerStyle {
    /// Bounces with live mic input while KIT is listening.
    case reactive
    /// Scanner sweep across the columns while Kit is speaking — decorative, not audio-driven.
    case scanner
}

struct KITTEqualizerView: View {
    let level: Float
    let isActive: Bool
    var style: KITTEqualizerStyle = .reactive
    /// When false, only the LED bars render so the console can sit them in its own well.
    var showsChrome: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var columnLevels: [Float] = [0, 0, 0]
    @State private var scannerTask: Task<Void, Never>?

    // Center column runs a few segments taller than the sides — the "hero" column.
    private var barWidth: CGFloat { showsChrome ? 28 : 24 }
    private var barHeight: CGFloat { showsChrome ? 6 : 5 }
    private var barGap: CGFloat { showsChrome ? 3 : 2.4 }
    private var columnGap: CGFloat { showsChrome ? 12 : 10 }
    private let scannerPattern: [[Float]] = [
        [1.0, 0.35, 0.15],
        [0.5, 1.0, 0.5],
        [0.15, 0.35, 1.0],
        [0.5, 1.0, 0.5]
    ]

    var body: some View {
        Group {
            if showsChrome {
                barStack(counts: [16, 20, 16])
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(height: 154)
                    .background(KitPalette.well)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(KitPalette.line, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: KitPalette.ledRed.opacity(isActive ? 0.2 : 0), radius: 18)
            } else {
                GeometryReader { geo in
                    barStack(counts: segmentCounts(forHeight: geo.size.height))
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isActive ? "Kit voice activity" : "Kit voice box idle")
        .accessibilityValue(isActive ? "Active" : "Inactive")
        .onAppear { refreshAnimation(active: isActive) }
        .onChange(of: level) { _, newLevel in
            guard style == .reactive else { return }
            updateColumns(for: newLevel)
        }
        .onChange(of: isActive) { _, active in
            refreshAnimation(active: active)
        }
        .onChange(of: style) { _, _ in
            refreshAnimation(active: isActive)
        }
        .onDisappear { scannerTask?.cancel() }
    }

    private func barStack(counts: [Int]) -> some View {
        HStack(alignment: .bottom, spacing: columnGap) {
            ForEach(0..<3, id: \.self) { index in
                ledColumn(level: columnLevels[index], segmentCount: counts[index])
            }
        }
    }

    private func segmentCounts(forHeight height: CGFloat) -> [Int] {
        let unit = barHeight + barGap
        let center = max(10, Int(floor((height + barGap) / unit)))
        let side = max(8, center - 3)
        return [side, center, side]
    }

    private func refreshAnimation(active: Bool) {
        scannerTask?.cancel()
        scannerTask = nil

        guard active else {
            animate { columnLevels = [0, 0, 0] }
            return
        }

        switch style {
        case .reactive:
            updateColumns(for: max(level, 0.08))
        case .scanner:
            startScannerLoop()
        }
    }

    private func startScannerLoop() {
        scannerTask = Task { @MainActor in
            var phase = 0
            while !Task.isCancelled {
                animate { columnLevels = scannerPattern[phase % scannerPattern.count] }
                phase += 1
                try? await Task.sleep(nanoseconds: 260_000_000)
            }
        }
    }

    private func ledColumn(level: Float, segmentCount: Int) -> some View {
        let litCount = isActive ? max(1, Int(ceil(level * Float(segmentCount)))) : 0

        return VStack(spacing: barGap) {
            ForEach(Array((0..<segmentCount).reversed()), id: \.self) { segment in
                let isLit = segment < litCount
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(segmentFill(isLit: isLit))
                    .frame(width: barWidth, height: barHeight)
                    .shadow(color: KitPalette.ledRed.opacity(isLit ? 0.75 : 0), radius: isLit ? 4 : 0)
            }
        }
    }

    private func segmentFill(isLit: Bool) -> LinearGradient {
        LinearGradient(
            colors: isLit
                ? [KitPalette.ledHot, KitPalette.ledRed]
                : [KitPalette.ledRed.opacity(0.18), KitPalette.ledRed.opacity(0.08)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func updateColumns(for level: Float) {
        guard isActive else { return }
        animate {
            columnLevels = [
                min(1, level * Float.random(in: 0.62...0.92) + 0.06),
                min(1, level * Float.random(in: 0.96...1.22) + 0.12),
                min(1, level * Float.random(in: 0.62...0.92) + 0.06)
            ]
        }
    }

    private func animate(_ changes: () -> Void) {
        if reduceMotion {
            changes()
        } else {
            withAnimation(.easeOut(duration: 0.08), changes)
        }
    }
}

#Preview {
    ZStack {
        Color.black
        KITTEqualizerView(level: 0.6, isActive: true)
    }
}
