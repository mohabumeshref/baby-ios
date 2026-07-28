//
//  BabyProfile.swift
//  BabyTracker
//
//  The baby's birth date - the single input the whole app derives from.
//

import Foundation
import SwiftUI

@MainActor
final class BabyProfile: ObservableObject {
    private enum Keys {
        /// Stored as a timestamp, never as a formatted string. The pregnancy
        /// tracker stored a locale-formatted date and crashed on Arabic devices
        /// when it could not parse its own output back.
        static let birthDate = "baby_birth_date"
    }

    private let defaults: UserDefaults

    /// Read-only from outside; changes go through `setBirthDate`.
    ///
    /// This used to be a settable `@Published` with a `didSet` that persisted.
    /// Assigning through the property wrapper in `init` fires that observer, so
    /// the DEBUG screenshot seed was writing a fake birth date into UserDefaults
    /// - which then survived into later launches and skipped onboarding
    /// entirely. Persisting explicitly instead of as a side effect makes
    /// "load" and "save" impossible to confuse.
    @Published private(set) var birthDate: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // A seeded date (DEBUG screenshot runs only) wins for this launch but
        // is deliberately never written back.
        if let seeded = ScreenshotSeed.birthDate {
            self.birthDate = seeded
            return
        }

        let stored = defaults.double(forKey: Keys.birthDate)
        self.birthDate = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    /// Sets and persists the birth date. The only path that writes to disk.
    func setBirthDate(_ date: Date?) {
        birthDate = date
        if let date {
            defaults.set(date.timeIntervalSince1970, forKey: Keys.birthDate)
        } else {
            defaults.removeObject(forKey: Keys.birthDate)
        }
    }

    var isOnboarded: Bool { birthDate != nil }

    /// Derived age, or nil until a birth date is set.
    var age: BabyAge? {
        birthDate.map { BabyAge(birthDate: $0) }
    }
}
