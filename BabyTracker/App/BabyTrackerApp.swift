//
//  BabyTrackerApp.swift
//  BabyTracker
//
//  أنا و طفلي - Arabic-first, RTL baby development tracker.
//

import SwiftUI

@main
struct BabyTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var profile = BabyProfile()
    @StateObject private var milestones = MilestoneStore()
    @StateObject private var notifications = NotificationManager.shared
    @StateObject private var router = NotificationRouter.shared

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profile)
                .environmentObject(milestones)
                .environmentObject(notifications)
                .environmentObject(router)
                // The warm palette is a fixed identity - inverting it for dark
                // mode produces something that reads as a different product,
                // so the colour scheme is pinned rather than duplicated.
                .preferredColorScheme(.light)
                .task {
                    await notifications.refreshAuthorizationStatus()
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    Task {
                        // Android rewrites its FCM token every time the main
                        // screen opens; the single User/{uid}.token slot tracks
                        // whichever device is in active use. Doing the same on
                        // foreground keeps this app in contention for the slot.
                        await notifications.syncFCMToken()
                        await notifications.refreshWeeklyReminder(birthDate: profile.birthDate)
                    }
                }
        }
    }
}
