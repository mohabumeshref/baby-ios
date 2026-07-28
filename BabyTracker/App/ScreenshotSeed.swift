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

    /// `-seed_email x -seed_password y` - signs in automatically so the
    /// screenshot job can capture the real forum feed.
    ///
    /// This exists because the author has no Mac: CI is the only way to see
    /// the app running against live Firebase at all. The credentials come from
    /// GitHub secrets and belong to a throwaway forum account - never a real
    /// user's, and never anything with admin rights.
    ///
    /// DEBUG only. Release builds compile this away entirely, so a shipped app
    /// cannot be made to sign itself in through launch arguments.
    static var credentials: (email: String, password: String)? {
        let defaults = UserDefaults.standard
        guard let email = defaults.string(forKey: "seed_email"),
              let password = defaults.string(forKey: "seed_password"),
              !email.isEmpty, !password.isEmpty else { return nil }
        return (email, password)
    }
    #else
    static var birthDate: Date? { nil }
    static var tab: Int? { nil }
    static var credentials: (email: String, password: String)? { nil }
    #endif
}
