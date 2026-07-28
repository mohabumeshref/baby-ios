//
//  BannerAdView.swift
//  BabyTracker
//
//  Adaptive banner, wrapped for SwiftUI.
//
//  Uses an anchored adaptive size rather than the fixed 320x50: adaptive
//  banners fill the device width and earn materially better than the legacy
//  size. The height is asked for up front so layout doesn't jump when the ad
//  arrives, and the view reserves nothing at all when ads are disabled.
//

import SwiftUI
import GoogleMobileAds

struct BannerAdView: View {
    @State private var isLoaded = false
    @State private var isEnabled = true

    private var adSize: GADAdSize {
        let width = UIScreen.main.bounds.width
        return GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
    }

    var body: some View {
        Group {
            if isEnabled {
                BannerRepresentable(adSize: adSize, isLoaded: $isLoaded)
                    .frame(height: adSize.size.height)
                    // Keep the slot reserved but blank until fill arrives, so
                    // content doesn't shift under the reader mid-sentence.
                    .opacity(isLoaded ? 1 : 0)
            }
        }
        .task {
            // Ads only exist once Firebase supplied Remote Config; without it
            // the default keeps them on, which is the intended shipping state.
            isEnabled = await RemoteConfigGate.shared.bool(
                forKey: AdConfig.rcInterstitialEnabled, default: true
            )
        }
    }
}

private struct BannerRepresentable: UIViewRepresentable {
    let adSize: GADAdSize
    @Binding var isLoaded: Bool

    func makeUIView(context: Context) -> GADBannerView {
        let view = GADBannerView(adSize: adSize)
        view.adUnitID = AdConfig.banner
        view.delegate = context.coordinator
        view.rootViewController = context.coordinator.rootViewController

        Task { @MainActor in
            // Consent must be resolved before the request goes out.
            await ATTGate.requestIfNeeded()
            view.load(GADRequest())
        }
        return view
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(isLoaded: $isLoaded) }

    final class Coordinator: NSObject, GADBannerViewDelegate {
        private let isLoaded: Binding<Bool>

        init(isLoaded: Binding<Bool>) {
            self.isLoaded = isLoaded
        }

        var rootViewController: UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }?
                .windows.first(where: \.isKeyWindow)?
                .rootViewController
        }

        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            isLoaded.wrappedValue = true
        }

        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("Banner failed: \(error.localizedDescription)")
            isLoaded.wrappedValue = false
        }
    }
}
