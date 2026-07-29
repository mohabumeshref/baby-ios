//
//  SplashView.swift
//  BabyTracker
//
//  Launch screen.
//
//  The static UILaunchScreen in Info.plist only paints the background colour -
//  it can't show the logo or wordmark, because a launch screen has no code.
//  This is the animated hand-off that follows it: same background, so the
//  transition from system launch screen to app is seamless rather than a flash.
//
//  Deliberately brief. The Android app pauses on its splash; here it only stays
//  long enough for the mark to register, and never blocks content that is
//  already loaded.
//

import SwiftUI

struct SplashView: View {
    /// Called once the splash has had its moment.
    var onFinished: () -> Void

    @State private var appeared = false

    /// Short enough not to feel like a stall.
    private let duration: TimeInterval = 1.4

    var body: some View {
        ZStack {
            Warm.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 18) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 108, height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Warm.brand.opacity(0.18), radius: 18, y: 8)
                    .scaleEffect(appeared ? 1 : 0.86)
                    .opacity(appeared ? 1 : 0)

                Text(L.appName)
                    .font(WarmFont.title)
                    .foregroundStyle(Warm.ink)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .task {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                appeared = true
            }
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            onFinished()
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
