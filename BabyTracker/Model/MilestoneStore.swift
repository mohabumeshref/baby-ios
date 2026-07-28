//
//  MilestoneStore.swift
//  BabyTracker
//
//  Persistence for the milestone chips the parent checks off.
//
//  Scope matches Android exactly: local to the device, one baby, keyed by
//  (month, tier, index). The key format is kept byte-identical to Android's
//  TinyDB keys ("WR_SKILL_3_1_2") - nothing syncs between the platforms today,
//  but an identical shape makes any future migration or support diagnosis
//  trivial, and costs nothing now.
//
//  Note the consequence, inherited from Android: progress is tied to the
//  chip's ORDER within its tier, not to the skill's text. Reordering or
//  inserting a skill in weeks/skills.json would silently shift existing
//  check-offs. Content changes must therefore be append-only per tier.
//

import Foundation
import SwiftUI

@MainActor
final class MilestoneStore: ObservableObject {
    private let defaults: UserDefaults

    /// Bumped whenever a chip toggles, so views observing this object refresh.
    @Published private(set) var revision = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(month: Int, tier: Int, index: Int) -> String {
        "WR_SKILL_\(month)_\(tier)_\(index)"
    }

    func isChecked(month: Int, tier: Int, index: Int) -> Bool {
        defaults.bool(forKey: key(month: month, tier: tier, index: index))
    }

    func toggle(month: Int, tier: Int, index: Int) {
        let k = key(month: month, tier: tier, index: index)
        defaults.set(!defaults.bool(forKey: k), forKey: k)
        revision &+= 1
    }

    /// How many chips in a tier are checked.
    func completedCount(month: Int, tier: Int, total: Int) -> Int {
        (0..<total).reduce(into: 0) { count, index in
            if isChecked(month: month, tier: tier, index: index) { count += 1 }
        }
    }
}
