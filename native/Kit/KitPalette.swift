import SwiftUI
import UIKit

enum KitPalette {
    static let bg = Color(red: 0.035, green: 0.035, blue: 0.04)
    static let card = Color(red: 0.16, green: 0.15, blue: 0.17)
    static let cardDeep = Color(red: 0.10, green: 0.10, blue: 0.11)
    static let well = Color(red: 0.055, green: 0.055, blue: 0.06)
    static let ink = Color.white.opacity(0.94)
    static let muted = Color.white.opacity(0.45)
    static let faint = Color.white.opacity(0.32)
    static let line = Color.white.opacity(0.10)

    static let ledRed = Color(red: 0.90, green: 0.16, blue: 0.10)
    static let ledHot = Color(red: 1.00, green: 0.22, blue: 0.10)
    static let ledAmber = Color(red: 0.98, green: 0.72, blue: 0.22)
    static let ledTeal = Color(red: 0.22, green: 0.88, blue: 0.90)
    static let ledPink = Color(red: 0.93, green: 0.34, blue: 0.58)
    static let ledGreen = Color(red: 0.32, green: 0.84, blue: 0.44)
    static let ledOrange = Color(red: 0.98, green: 0.55, blue: 0.16)

    static let cruiseLitTop = Color(red: 0.78, green: 0.22, blue: 0.16)
    static let cruiseLitBottom = Color(red: 0.42, green: 0.08, blue: 0.06)
    static let cruiseDimTop = Color(red: 0.22, green: 0.07, blue: 0.06)
    static let cruiseDimBottom = Color(red: 0.13, green: 0.04, blue: 0.04)

    /// Cruise buttons, three tiers: matte obsidian (idle) → seat colour (selected,
    /// mic off) → hot glow (selected AND recording). Colours match the KITT dash.
    static let consoleSlate = Color(red: 0.106, green: 0.118, blue: 0.149)   // #1B1E26
    static let consoleRedDim = Color(red: 0.545, green: 0.118, blue: 0.118)  // #8B1E1E
    static let consoleRedLED = Color(red: 1.0, green: 0.165, blue: 0.165)    // #FF2A2A

    /// Auto Cruise — dark burgundy panel, red glow when hot.
    static let cruiseAutoDim = Color(red: 0.38, green: 0.06, blue: 0.06)
    static let cruiseAutoHot = Color(red: 0.55, green: 0.12, blue: 0.10)
    static let cruiseAutoGlow = consoleRedLED

    /// Normal Cruise — olive chartreuse panel.
    static let cruiseNormalDim = Color(red: 0.33, green: 0.35, blue: 0.19)
    static let cruiseNormalHot = Color(red: 0.58, green: 0.62, blue: 0.28)
    static let cruiseNormalGlow = Color(red: 0.78, green: 0.82, blue: 0.35)

    /// Pursuit — vivid blue-violet panel.
    static let cruisePursuitDim = Color(red: 0.29, green: 0.27, blue: 0.90)
    static let cruisePursuitHot = Color(red: 0.35, green: 0.42, blue: 0.98)
    static let cruisePursuitGlow = Color(red: 0.45, green: 0.55, blue: 1.0)

    struct CruiseButtonColors {
        let dim: Color
        let hot: Color
        let glow: Color
        let labelTint: Color
    }

    static func cruiseColors(for chair: Chair) -> CruiseButtonColors {
        switch chair {
        case .auto:
            return CruiseButtonColors(
                dim: cruiseAutoDim,
                hot: cruiseAutoHot,
                glow: cruiseAutoGlow,
                labelTint: cruiseAutoGlow
            )
        case .diane:
            return CruiseButtonColors(
                dim: cruiseNormalDim,
                hot: cruiseNormalHot,
                glow: cruiseNormalGlow,
                labelTint: cruiseNormalHot
            )
        case .kit:
            return CruiseButtonColors(
                dim: cruisePursuitDim,
                hot: cruisePursuitHot,
                glow: cruisePursuitGlow,
                labelTint: cruisePursuitHot
            )
        }
    }
    static let endTop = Color(red: 0.82, green: 0.16, blue: 0.12)
    static let endBottom = Color(red: 0.48, green: 0.05, blue: 0.04)
    static let printTop = Color(red: 0.99, green: 0.78, blue: 0.18)
    static let printBottom = Color(red: 0.86, green: 0.56, blue: 0.08)

    static let paper = Color(red: 0.95, green: 0.91, blue: 0.82)
    static let paperAlt = Color(red: 0.91, green: 0.86, blue: 0.74)
    static let receipt = Color(red: 0.96, green: 0.94, blue: 0.88)
    static let receiptRule = Color(red: 0.93, green: 0.90, blue: 0.82)

    static let plastic = Color(red: 0.18, green: 0.17, blue: 0.19)
    static let plasticDark = Color(red: 0.11, green: 0.10, blue: 0.12)

    static func group(_ group: ConsoleLampGroup) -> Color {
        switch group {
        case .creative: return ledPink
        case .reflection: return ledAmber
        case .action: return ledGreen
        }
    }

    static func family(_ family: TapeFamily) -> Color {
        switch family {
        case .creative: return ledPink
        case .appIdea: return Color(red: 0.72, green: 0.28, blue: 0.92)
        case .running: return ledTeal
        case .people: return Color(red: 0.45, green: 0.48, blue: 0.95)
        case .reflection: return ledAmber
        case .morningPages: return ledOrange
        case .shopping: return Color(red: 0.95, green: 0.82, blue: 0.22)
        case .tasks: return ledGreen
        }
    }

    static func marker(_ family: TapeFamily) -> Color {
        switch family {
        case .creative: return Color(red: 0.72, green: 0.16, blue: 0.38)
        case .appIdea: return Color(red: 0.42, green: 0.12, blue: 0.58)
        case .running: return Color(red: 0.08, green: 0.42, blue: 0.48)
        case .people: return Color(red: 0.22, green: 0.22, blue: 0.55)
        case .reflection: return Color(red: 0.62, green: 0.38, blue: 0.08)
        case .morningPages: return Color(red: 0.62, green: 0.28, blue: 0.06)
        case .shopping: return Color(red: 0.48, green: 0.36, blue: 0.04)
        case .tasks: return Color(red: 0.16, green: 0.48, blue: 0.28)
        }
    }
}

enum KitHaptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

enum KitFormat {
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    static func longClock(_ seconds: TimeInterval) -> String {
        let clamped = max(0, seconds)
        let minutes = Int(clamped) / 60
        let secs = Int(clamped) % 60
        let cents = Int((clamped * 100).truncatingRemainder(dividingBy: 100))
        return String(format: "%02d:%02d.%02d", minutes, secs, cents)
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).year(.twoDigits))
    }

    static func stamp(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}

struct KitCard: ViewModifier {
    var radius: CGFloat = 20
    var glow: Color? = nil

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [KitPalette.card, KitPalette.cardDeep],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(KitPalette.line, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .blendMode(.overlay)
                    .padding(.top, -1)
                    .clipped()
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
            .shadow(color: (glow ?? .clear).opacity(glow == nil ? 0 : 0.42), radius: 16)
    }
}

struct KitWell: ViewModifier {
    var radius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(KitPalette.well)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(KitPalette.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.55), radius: 8, y: 4)
    }
}

extension View {
    func kitCard(radius: CGFloat = 20, glow: Color? = nil) -> some View {
        modifier(KitCard(radius: radius, glow: glow))
    }

    func kitWell(radius: CGFloat = 20) -> some View {
        modifier(KitWell(radius: radius))
    }
}
