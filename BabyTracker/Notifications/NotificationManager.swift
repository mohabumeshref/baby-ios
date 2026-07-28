//
//  NotificationManager.swift
//  BabyTracker
//
//  Notification permission, the FCM token, and the weekly local reminder.
//
//  This app sends NO push notifications. Forum pushes come from the shared
//  Cloud Functions, triggered by Firestore writes. All that happens here is:
//  ask for permission at a sensible moment, keep User/{uid}.token current, and
//  schedule one local reminder.
//

import Foundation
import UIKit
import UserNotifications
import FirebaseMessaging

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    private enum Keys {
        /// Stored INVERTED, matching Android's MY_PREF_WEEKLY_DISABLED: a bool
        /// defaults to false on both platforms, so storing "disabled" makes the
        /// reminder default to ON without needing registered defaults.
        static let weeklyDisabled = "weekly_reminder_disabled"
    }

    private enum Identifier {
        static let weekly = "weekly-new-week"
    }

    private let defaults: UserDefaults
    private let center = UNUserNotificationCenter.current()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isWeeklyReminderEnabled: Bool {
        get { !defaults.bool(forKey: Keys.weeklyDisabled) }
        set { defaults.set(!newValue, forKey: Keys.weeklyDisabled) }
    }

    // MARK: - Permission

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    /// Asks for notification permission.
    ///
    /// Deliberately NOT called at launch. The pregnancy tracker requests
    /// authorization inside didFinishLaunching, which shows the system prompt
    /// before the user has any idea what the app notifies about - the reliable
    /// way to get denied. This is called once onboarding completes, when the
    /// weekly reminder is about to become useful.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .notDetermined else {
            return authorizationStatus == .authorized || authorizationStatus == .provisional
        }

        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound]))
            ?? false
        await refreshAuthorizationStatus()

        if granted {
            // Only register for remote notifications once the user has agreed;
            // registering earlier gets a token the user can't receive on.
            UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    }

    // MARK: - Weekly reminder

    /// Weekly "new week" reminder at 19:00 on the baby's birth weekday,
    /// matching WeeklyAlarmScheduler on Android.
    ///
    /// Note this is a true 7-day cadence, whereas the Weeks tab advances every
    /// ~8.11 days (45 entries across a year). So the reminder and the content
    /// index drift apart over the year - the same drift Android has. Matching
    /// it is deliberate; the alternative would have iOS and Android nudging the
    /// same parent on different days.
    func scheduleWeeklyReminder(birthDate: Date) async {
        await cancelWeeklyReminder()

        guard isWeeklyReminderEnabled else { return }
        await refreshAuthorizationStatus()
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            return
        }

        var components = DateComponents()
        // Calendar.weekday is 1 = Sunday on both platforms, so the birth
        // weekday maps across directly.
        components.weekday = Calendar.current.component(.weekday, from: birthDate)
        components.hour = 19
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = L.weeklyReminderTitle
        content.body = L.weeklyReminderBody
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Identifier.weekly,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )

        try? await center.add(request)
    }

    func cancelWeeklyReminder() async {
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.weekly])
    }

    /// Re-applies the reminder after the setting or the birth date changes.
    func refreshWeeklyReminder(birthDate: Date?) async {
        guard let birthDate else {
            await cancelWeeklyReminder()
            return
        }
        await scheduleWeeklyReminder(birthDate: birthDate)
    }

    // MARK: - FCM token

    /// Pushes the current token into `User/{uid}.token`.
    ///
    /// Android rewrites its token every time the main screen opens, because the
    /// single slot tracks whichever device is in active use. Doing the same on
    /// foreground keeps this app competitive for the slot instead of losing it
    /// permanently to whichever app launched last.
    func syncFCMToken() async {
        guard ForumStore.shared.currentUid != nil else { return }
        guard let token = try? await Messaging.messaging().token(), !token.isEmpty else { return }
        try? await ForumStore.shared.saveFCMToken(token)
    }
}
