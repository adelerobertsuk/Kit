import Foundation
import UIKit
import Combine

/// Periodic in-session reminder to wrap up before the device runs out of battery mid-session.
/// Only relevant while unplugged — a charging or full device never nudges.
@MainActor
final class BatteryNudgeManager: ObservableObject {
    @Published var nudgeMessage: String?

    private var timer: Timer?
    private let checkInterval: TimeInterval = 300
    private let lowBatteryThreshold: Float = 0.2

    func startMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkBattery() }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        nudgeMessage = nil
    }

    func dismissNudge() {
        nudgeMessage = nil
    }

    private func checkBattery() {
        let device = UIDevice.current
        guard device.batteryState == .unplugged else { return }
        guard device.batteryLevel >= 0 else { return } // -1 = unknown, e.g. Simulator
        guard device.batteryLevel <= lowBatteryThreshold else { return }

        let percent = Int((device.batteryLevel * 100).rounded())
        nudgeMessage = "Battery's at \(percent)% — might be worth wrapping up this session soon."
    }
}
