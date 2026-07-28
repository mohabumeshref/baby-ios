//
//  ScreenshotSeed.swift
//  BabyTracker
//
//  DEBUG-only launch-argument hooks used by .github/workflows/screenshots.yml.
//
//  The screenshot job has no way to tap through the UI, so it drives the app
//  with launch arguments instead: seed a birth date to get past onboarding,
//  and pick which tab opens. UserDefaults reads `-key value` launch arguments
//  automatically (the "argument domain"), so simctl can pass them directly.
//
//  The whole file compiles to nothing in Release - these must never be
//  reachable in a shipped build.
//

import Foundation

enum ScreenshotSeed {

    #if DEBUG
    /// `-seed_baby_days_ago 90` - pretend the baby was born N days ago.
    static var birthDate: Date? {
        let days = UserDefaults.standard.integer(forKey: "seed_baby_days_ago")
        guard days > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: -days, to: Date())
    }

    /// `-seed_tab 1` - which tab to open (0 Home, 1 Weeks, 2 Community).
    static var tab: Int? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "seed_tab") != nil else { return nil }
        return defaults.integer(forKey: "seed_tab")
    }
    #else
    static var birthDate: Date? { nil }
    static var tab: Int? { nil }
    #endif
}
