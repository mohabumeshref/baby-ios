//
//  InterstitialAdManager.swift
//  BabyTracker
//
//  Loads and presents interstitials, behind AdGate.
//
//  Every load waits for ATT to resolve. A request fired before the prompt is
//  answered carries the wrong consent state, which both hurts fill and
//  misreports to AdMob.
//

import Foundation
import UIKit
import GoogleMobileAds

@MainActor
final class InterstitialAdManager: NSObject, ObservableObject {
    static let shared = InterstitialAdManager()

    private var ad: GADInterstitialAd?
    private var isLoading = false

    private override init() { super.init() }

    /// Requests an ad if none is ready. Safe to call repeatedly.
    func preload() async {
        guard ad == nil, !isLoading else { return }
        guard await RemoteConfigGate.shared.bool(
            forKey: AdConfig.rcInterstitialEnabled, default: true
        ) else { return }

        // Never request before the user has answered ATT.
        await ATTGate.requestIfNeeded()

        isLoading = true
        defer { isLoading = false }

        do {
            ad = try await GADInterstitialAd.load(
                withAdUnitID: AdConfig.interstitial,
                request: GADRequest()
            )
        } catch {
            print("Interstitial load failed: \(error.localizedDescription)")
            ad = nil
        }
    }

    /// Presents an ad if one is loaded and the gate allows it. Returns whether
    /// it was shown, so callers can decide whether to wait.
    @discardableResult
    func showIfAllowed() async -> Bool {
        guard let ad, await AdGate.shared.canShow() else {
            // Nothing to show now, but warm one up for next time.
            await preload()
            return false
        }

        guard let root = Self.topViewController() else { return false }

        self.ad = nil
        AdGate.shared.recordShown()
        ad.fullScreenContentDelegate = self
        ad.present(fromRootViewController: root)
        return true
    }

    /// SwiftUI has no view controller to present from, so walk the active
    /// window scene to the topmost presented controller.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

extension InterstitialAdManager: GADFullScreenContentDelegate {
    // The delegate takes GADFullScreenPresentingAd - the protocol the ad
    // conforms to - not a concrete ad type.
    nonisolated func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        Task { @MainActor in await preload() }
    }

    nonisolated func ad(
        _ ad: any GADFullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        Task { @MainActor in
            self.ad = nil
            await preload()
        }
    }
}
