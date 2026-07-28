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

    var body: some Scene {
        WindowGroup {
            RootView()
                // Arabic is the development language and the app is RTL-first.
                // SwiftUI derives direction from the active locale, so this only
                // needs stating where a view must not mirror (numerals, dates).
                .environment(\.layoutDirection,
                             Locale.preferredLanguages.first?.hasPrefix("ar") == true
                                ? .rightToLeft : .leftToRight)
        }
    }
}
