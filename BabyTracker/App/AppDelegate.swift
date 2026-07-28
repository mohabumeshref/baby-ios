//
//  AppDelegate.swift
//  BabyTracker
//
//  SwiftUI lifecycle needs a UIApplicationDelegate only for Firebase
//  Messaging and APNs registration.
//
//  IMPORTANT: this app deliberately sends no push notifications itself.
//  Forum pushes are produced server-side by the Cloud Functions in the shared
//  pregnancy-tracker-57bf7 project (onAnswerCreated / onPostCreated /
//  onReplyAdded), which fire on Firestore writes and are app-agnostic. All
//  this app has to do is keep its FCM token in User/{uid}.token and handle
//  taps. Adding a client-side sender would produce duplicate notifications -
//  which is what the Android baby app currently does.
//

import UIKit
import FirebaseCore
import FirebaseMessaging

final class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // GoogleService-Info.plist is supplied per-environment and is absent on
        // a fresh checkout. Configuring without it raises, which would take the
        // simulator screenshot job down with it, so probe for it first.
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
        } else {
            print("⚠️ GoogleService-Info.plist not bundled — Firebase is disabled for this run.")
        }

        return true
    }

    // MARK: - Push token

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // Persisting the token to Firestore lands with the notifications work;
        // it needs the auth session that the forum layer sets up.
        print("FCM registration token: \(fcmToken ?? "nil")")
    }
}
