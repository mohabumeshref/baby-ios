//
//  AdConfig.swift
//  BabyTracker
//
//  AdMob identifiers for أنا و طفلي.
//
//  Same publisher account as the pregnancy tracker, but its own app and its
//  own units - none of these are shared with pt-ios.
//
//  The App ID lives in Info.plist under GADApplicationIdentifier; AdMob reads
//  it there at SDK start, not from this file.
//

import Foundation

enum AdConfig {

    /// Google's public test units. Selected automatically in DEBUG so a
    /// development run can never register a real impression - filing real
    /// impressions from a dev build is the fastest way to get an AdMob account
    /// flagged for invalid traffic.
    private enum Test {
        static let banner = "ca-app-pub-3940256099942544/2934735716"
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"
        static let appOpen = "ca-app-pub-3940256099942544/5662855259"
    }

    private enum Live {
        static let banner = "ca-app-pub-6789336355455489/6498272348"
        static let interstitial = "ca-app-pub-6789336355455489/7288875768"
        static let appOpen = "ca-app-pub-6789336355455489/4598987459"
    }

    #if DEBUG
    static let useTestAds = true
    #else
    static let useTestAds = false
    #endif

    static var banner: String { useTestAds ? Test.banner : Live.banner }
    static var interstitial: String { useTestAds ? Test.interstitial : Live.interstitial }
    static var appOpen: String { useTestAds ? Test.appOpen : Live.appOpen }

    // MARK: - Remote Config keys
    //
    // The pregnancy tracker shipped with no way to turn ads off without an
    // App Store release. These keys exist from day one so frequency and the
    // kill switch stay tunable live.

    /// Master on/off for interstitials.
    static let rcInterstitialEnabled = "babyInterstitialEnabled"
    /// Minimum seconds between two interstitials.
    static let rcInterstitialMinInterval = "babyInterstitialMinIntervalSeconds"
    /// Hard cap on interstitials per app session.
    static let rcMaxInterstitialsPerSession = "babyMaxInterstitialsPerSession"
    /// On/off for the app-open ad.
    static let rcAppOpenEnabled = "babyAppOpenEnabled"

    // Defaults applied before the first Remote Config fetch returns.
    static let defaultInterstitialMinInterval: TimeInterval = 60
    static let defaultMaxInterstitialsPerSession = 2
}
