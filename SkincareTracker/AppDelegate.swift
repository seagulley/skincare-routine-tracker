//
//  AppDelegate.swift
//  SkincareTracker
//
//  Handles notification taps to open the Today tab.
//

import UIKit
import UserNotifications

extension Notification.Name {
    static let openTodayTab = Notification.Name("openTodayTab")
    static let openCycleTab = Notification.Name("openCycleTab")
}

let openTodayTabKey = "com.skincaretracker.openTodayTab"
let openCycleTabKey = "com.skincaretracker.openCycleTab"

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let isNoRoutine = (response.notification.request.content.userInfo["noRoutine"] as? Bool) == true
        if isNoRoutine {
            UserDefaults.standard.set(true, forKey: openCycleTabKey)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openCycleTab, object: nil)
            }
        } else {
            UserDefaults.standard.set(true, forKey: openTodayTabKey)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openTodayTab, object: nil)
            }
        }
        completionHandler()
    }
}
