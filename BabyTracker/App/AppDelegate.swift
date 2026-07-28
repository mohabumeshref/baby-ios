//
//  AppDelegate.swift
//  BabyTracker
//
//  SwiftUI lifecycle needs a UIApplicationDelegate only for Firebase Messaging
//  and APNs.
//
//  IMPORTANT: this app deliberately sends no push notifications. Forum pushes
//  are produced server-side by the Cloud Functions in the shared
//  pregnancy-tracker-57bf7 project (onAnswerCreated / onPostCreated /
//  onReplyAdded), which fire on Firestore writes and are app-agnostic. All
//  this app does is keep its FCM token in User/{uid}.token and handle taps.
//  Adding a client-side sender would produce duplicate notifications - which
//  is what the Android baby app currently does.
//

import UIKit
import FirebaseCore
import FirebaseMessaging

final class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate,
                         UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // GoogleService-Info.plist is supplied per-environment and is absent on
        // a fresh checkout. Configuring without it raises, which would take the
        // simulator screenshot job down with it, so probe for it first.
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            print("⚠️ GoogleService-Info.plist not bundled — Firebase is disabled for this run.")
            return true
        }

        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // NOTE: no requestAuthorization here, and no registerForRemoteNotifications.
        // Both happen after onboarding via NotificationManager, so the system
        // prompt appears when the user has context for it rather than on the
        // very first launch.

        return true
    }

    // MARK: - APNs

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Permission can be granted in a build with no GoogleService-Info.plist
        // (CI, screenshots), and Messaging.messaging() raises when Firebase was
        // never configured.
        guard ForumKit.isConfigured else { return }
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    // MARK: - FCM token

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }
        Task { @MainActor in
            try? await ForumStore.shared.saveFCMToken(fcmToken)
        }
    }

    // MARK: - Taps and foreground presentation

    /// Notifications that arrive while the app is open still get shown. The
    /// forum feed does not live-update from a push, so suppressing these would
    /// silently drop the only signal that a reply arrived.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            NotificationRouter.shared.handle(userInfo: userInfo)
        }
    }
}
