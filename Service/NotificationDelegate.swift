//
//  NotificationDelegate.swift
//  InvestPortfolio
//
//  Without a registered UNUserNotificationCenterDelegate, iOS only shows the banner/plays the
//  sound for a local notification when the app is backgrounded at the moment it fires. A deposit
//  or subscription reminder that happens to fire while the app is open would otherwise be
//  delivered silently into Notification Center history with no banner and no sound.
//

import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
