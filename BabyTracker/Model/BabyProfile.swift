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

    @Published var birthDate: Date? {
        didSet {
            if let birthDate {
                defaults.set(birthDate.timeIntervalSince1970, forKey: Keys.birthDate)
            } else {
                defaults.removeObject(forKey: Keys.birthDate)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.double(forKey: Keys.birthDate)
        // A seeded date (DEBUG screenshot runs only) wins, so the job can skip
        // onboarding without persisting anything.
        self.birthDate = ScreenshotSeed.birthDate
            ?? (stored > 0 ? Date(timeIntervalSince1970: stored) : nil)
    }

    var isOnboarded: Bool { birthDate != nil }

    /// Derived age, or nil until a birth date is set.
    var age: BabyAge? {
        birthDate.map { BabyAge(birthDate: $0) }
    }
}
