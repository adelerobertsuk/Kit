import Foundation
import UserNotifications

/// Reminds Adele that a walk is still open. iPhone will not let Kit ask
/// "are you sure?" when the app is swiped away, so this is the close-enough.
enum KitSessionReminder {
    static let requestID = "kit.open-walk"
    static let categoryID = "KIT_OPEN_WALK"
    static let fileActionID = "FILE_TAPE"
    static let quietBeforeNudge: TimeInterval = 60 * 60

    static func setup() {
        let file = UNNotificationAction(
            identifier: fileActionID,
            title: "File tape",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [file],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().delegate = KitNotificationCenter.shared
    }

    static func reschedule(lastActivity: Date) {
        cancel()
        let fireDate = lastActivity.addingTimeInterval(quietBeforeNudge)
        let delay = fireDate.timeIntervalSinceNow
        guard delay > 5 else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Walk still open"
            content.body = "File the tape, or keep talking. Kit files it after four quiet hours."
            content.sound = .default
            content.categoryIdentifier = categoryID

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        center.removeDeliveredNotifications(withIdentifiers: [requestID])
    }
}

final class KitNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = KitNotificationCenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == KitSessionReminder.fileActionID {
            KitLaunch.requestFileTape()
        }
        completionHandler()
    }
}
