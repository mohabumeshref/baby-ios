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
    /// One instance app-wide: the home card's summary and the schedule
    /// screen are two views of the same state, and two stores would each
    /// cache their own copy of it.
    @StateObject private var vaccines = VaccineStore()
    @StateObject private var notifications = NotificationManager.shared
    @StateObject private var router = NotificationRouter.shared
    @StateObject private var auth = ForumAuth.shared

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profile)
                .environmentObject(milestones)
                .environmentObject(vaccines)
                .environmentObject(notifications)
                .environmentObject(router)
                .environmentObject(auth)
                // The warm palette is a fixed identity - inverting it for dark
                // mode produces something that reads as a different product,
                // so the colour scheme is pinned rather than duplicated.
                .preferredColorScheme(.light)
                // Arabic is the only language the app ships in, so the whole
                // tree is pinned RTL rather than left to follow the device.
                .modifier(PinnedLayoutDirection())
                .task {
                    auth.start()
                    // DEBUG-only, screenshot job only. Compiles away in Release.
                    if let seed = ScreenshotSeed.credentials {
                        await auth.signInIfNeeded(email: seed.email, password: seed.password)
                    }
                    await notifications.refreshAuthorizationStatus()
                    await RemoteConfigGate.shared.prefetch()
                    await VaccineReminders.reschedule(
                        store: vaccines, birthDate: profile.birthDate
                    )
                }
                // Any vaccine write bumps `revision`, including a country
                // switch and every overlay change, so one observer here covers
                // ticking a dose, re-dating it, and adding, editing or
                // removing a custom vaccine - wherever in the app it happened.
                .onChange(of: vaccines.revision) { _ in
                    Task {
                        await VaccineReminders.reschedule(
                            store: vaccines, birthDate: profile.birthDate
                        )
                    }
                }
                .onChange(of: profile.birthDate) { date in
                    Task {
                        await VaccineReminders.reschedule(store: vaccines, birthDate: date)
                    }
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
                        // Dates move while the app is backgrounded: yesterday's
                        // "in 3 days" is today's "due today".
                        await VaccineReminders.reschedule(
                            store: vaccines, birthDate: profile.birthDate
                        )
                    }
                }
        }
    }
}

/// Pins layout direction to `L.forcedLayoutDirection` while the app is
/// single-language, and steps out of the way once that is nil.
///
/// Deliberately NOT `UIView.appearance().semanticContentAttribute`: that
/// mirrors every UIKit view in the process, including the date-picker wheels
/// that are pinned LTR on purpose and the ad banners, whose contents are not
/// ours to flip.
private struct PinnedLayoutDirection: ViewModifier {
    @Environment(\.layoutDirection) private var systemDirection

    func body(content: Content) -> some View {
        content.environment(
            \.layoutDirection, L.forcedLayoutDirection ?? systemDirection
        )
    }
}
