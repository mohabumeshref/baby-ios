//
//  RemoteConfigGate.swift
//  BabyTracker
//
//  A single place to read Firebase Remote Config.
//
//  Fetches once per launch and caches. Every caller gets a safe default when
//  the fetch fails, hasn't finished, or Firebase isn't configured at all - so a
//  network problem can never flip a flag to its dangerous side. Notably
//  `autoApprovePosts`, where defaulting to true would publish unmoderated posts
//  into a forum shared with two other apps.
//

import Foundation
import FirebaseRemoteConfig

actor RemoteConfigGate {
    static let shared = RemoteConfigGate()

    private var defaultsApplied = false
    private var fetchTask: Task<Void, Never>?
    private var hasFetched = false

    private init() {}

    /// `RemoteConfig.remoteConfig()` raises when FirebaseApp was never
    /// configured, so it is resolved on first use rather than stored - the same
    /// trap that crashed the app through Firestore. Nil when Firebase is
    /// absent, and every read then falls back to its supplied default.
    private var remoteConfig: RemoteConfig? {
        guard ForumKit.isConfigured else { return nil }

        let config = RemoteConfig.remoteConfig()
        guard !defaultsApplied else { return config }
        defaultsApplied = true

        config.setDefaults([
            "autoApprovePosts": false as NSObject,
            AdConfig.rcInterstitialEnabled: true as NSObject,
            AdConfig.rcAppOpenEnabled: true as NSObject,
            AdConfig.rcInterstitialMinInterval:
                AdConfig.defaultInterstitialMinInterval as NSObject,
            AdConfig.rcMaxInterstitialsPerSession:
                AdConfig.defaultMaxInterstitialsPerSession as NSObject,
        ])

        let settings = RemoteConfigSettings()
        // Zero means "always ask" - fine here because the fetch happens once
        // per launch, not per read.
        settings.minimumFetchInterval = 0
        config.configSettings = settings

        return config
    }

    /// Fetches once; concurrent callers await the same task.
    private func ensureFetched() async {
        if hasFetched { return }

        if let fetchTask {
            await fetchTask.value
            return
        }

        guard let config = remoteConfig else { return }

        let task = Task {
            _ = try? await config.fetchAndActivate()
        }
        fetchTask = task
        await task.value
        hasFetched = true
        fetchTask = nil
    }

    func bool(forKey key: String, default fallback: Bool) async -> Bool {
        await ensureFetched()
        guard hasFetched, let config = remoteConfig else { return fallback }
        return config.configValue(forKey: key).boolValue
    }

    func double(forKey key: String, default fallback: Double) async -> Double {
        await ensureFetched()
        guard hasFetched, let config = remoteConfig else { return fallback }
        let value = config.configValue(forKey: key).numberValue.doubleValue
        return value > 0 ? value : fallback
    }

    func int(forKey key: String, default fallback: Int) async -> Int {
        await ensureFetched()
        guard hasFetched, let config = remoteConfig else { return fallback }
        let value = config.configValue(forKey: key).numberValue.intValue
        return value > 0 ? value : fallback
    }

    /// Warm the cache at launch so the first real read doesn't block.
    func prefetch() async {
        await ensureFetched()
    }
}
