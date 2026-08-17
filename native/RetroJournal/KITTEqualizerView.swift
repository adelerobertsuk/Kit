import SwiftUI

enum KITTEqualizerStyle {
    /// Bounces with live mic input while KIT is listening.
    case reactive
    /// KITT-style scanner sweep across the columns while KITT is speaking — decorative, not audio-driven.
    case scanner
}

struct KITTEqualizerView: View {
    let level: Float
    let isActive: Bool
    var style: KITTEqualizerStyle = .reactive

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var columnLevels: [Float] = [0, 0, 0]
    @State private var scannerTask: Task<Void, Never>?

    // Center column runs a few segments taller than the sides — the "hero" column.
    private let segmentCounts = [13, 16, 13]
    private let scannerPattern: [[Float]] = [
        [1.0, 0.35, 0.15],
        [0.5, 1.0, 0.5],
        [0.15, 0.35, 1.0],
        [0.5, 1.0, 0.5]
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(0..<3, id: \.self) { index in
                ledColumn(level: columnLevels[index], segmentCount: segmentCounts[index])
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(height: 154)
        .background(Color(red: 0.035, green: 0.035, blue: 0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .red.opacity(isActive ? 0.2 : 0), radius: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isActive ? "KITT voice activity" : "KITT voice box idle")
        .accessibilityValue(isActive ? "Active" : "Inactive")
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
        scannerTask = Task {
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

        return VStack(spacing: 3) {
            ForEach(Array((0..<segmentCount).reversed()), id: \.self) { segment in
                let isLit = segment < litCount
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(segmentFill(isLit: isLit))
                    .frame(width: 28, height: 7)
                    .shadow(color: .red.opacity(isLit ? 0.75 : 0), radius: isLit ? 4 : 0)
            }
        }
    }

    private func segmentFill(isLit: Bool) -> LinearGradient {
        LinearGradient(
            colors: isLit
                ? [Color(red: 1, green: 0.08, blue: 0.03), Color(red: 0.72, green: 0.01, blue: 0)]
                : [Color.red.opacity(0.16), Color.red.opacity(0.07)],
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
