//
//  AdGate.swift
//  BabyTracker
//
//  Client-side frequency capping for interstitials.
//
//  AdMob's own capping is unreliable, so every "show an interstitial" call goes
//  through here. Two limits, both tunable live via Remote Config:
//
//    * minimum seconds between interstitials, persisted so it survives a
//      relaunch (otherwise force-quitting resets the cap)
//    * a hard cap per app session
//
//  Context worth keeping in mind: the pregnancy tracker's AdMob review flagged
//  a high click-through rate, which is the pattern that precedes an invalid
//  traffic strike. Interstitials that arrive too often are how that happens, so
//  these defaults are intentionally conservative and the remote keys exist from
//  day one rather than being retrofitted after a problem.
//

import Foundation

@MainActor
final class AdGate {
    static let shared = AdGate()

    private let defaults = UserDefaults.standard
    private var sessionCount = 0   // resets each launch

    private enum Keys {
        static let lastShownAt = "last_interstitial_at"
    }

    private init() {}

    /// Whether an interstitial may be shown right now.
    func canShow() async -> Bool {
        guard await RemoteConfigGate.shared.bool(
            forKey: AdConfig.rcInterstitialEnabled, default: true
        ) else {
            return false
        }

        let maxPerSession = await RemoteConfigGate.shared.int(
            forKey: AdConfig.rcMaxInterstitialsPerSession,
            default: AdConfig.defaultMaxInterstitialsPerSession
        )
        guard sessionCount < maxPerSession else { return false }

        let minInterval = await RemoteConfigGate.shared.double(
            forKey: AdConfig.rcInterstitialMinInterval,
            default: AdConfig.defaultInterstitialMinInterval
        )
        if let last = defaults.object(forKey: Keys.lastShownAt) as? Date,
           Date().timeIntervalSince(last) < minInterval {
            return false
        }

        return true
    }

    /// Record that one was actually presented.
    func recordShown() {
        defaults.set(Date(), forKey: Keys.lastShownAt)
        sessionCount += 1
    }
}
