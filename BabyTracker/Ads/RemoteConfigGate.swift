//
//  RemoteConfigGate.swift
//  BabyTracker
//
//  A single place to read Firebase Remote Config.
//
//  Fetches once per launch and caches. Every caller gets a safe default when
//  the fetch fails or hasn't finished, so a network problem can never flip a
//  flag to its dangerous side - notably `autoApprovePosts`, where defaulting
//  to true would publish unmoderated posts into a forum shared with two other
//  apps.
//

import Foundation
import FirebaseRemoteConfig

actor RemoteConfigGate {
    static let shared = RemoteConfigGate()

    private let remoteConfig = RemoteConfig.remoteConfig()
    private var fetchTask: Task<Void, Never>?
    private var hasFetched = false

    private init() {
        remoteConfig.setDefaults([
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
        remoteConfig.configSettings = settings
    }

    /// Fetches once; concurrent callers await the same task.
    private func ensureFetched() async {
        if hasFetched { return }

        if let fetchTask {
            await fetchTask.value
            return
        }

        let task = Task { [remoteConfig] in
            _ = try? await remoteConfig.fetchAndActivate()
        }
        fetchTask = task
        await task.value
        hasFetched = true
        fetchTask = nil
    }

    func bool(forKey key: String, default fallback: Bool) async -> Bool {
        await ensureFetched()
        guard hasFetched else { return fallback }
        return remoteConfig.configValue(forKey: key).boolValue
    }

    func double(forKey key: String, default fallback: Double) async -> Double {
        await ensureFetched()
        let value = remoteConfig.configValue(forKey: key).numberValue.doubleValue
        return value > 0 ? value : fallback
    }

    func int(forKey key: String, default fallback: Int) async -> Int {
        await ensureFetched()
        let value = remoteConfig.configValue(forKey: key).numberValue.intValue
        return value > 0 ? value : fallback
    }

    /// Warm the cache at launch so the first real read doesn't block.
    func prefetch() async {
        await ensureFetched()
    }
}
