//
//  RootView.swift
//  BabyTracker
//
//  Decides between onboarding and the tab shell.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var profile: BabyProfile

    /// Skipped entirely for screenshot runs - a 1.4s splash in every capture
    /// would just waste the job's time.
    @State private var showSplash = ScreenshotSeed.tab == nil

    var body: some View {
        ZStack {
            if profile.isOnboarded {
                MainTabView()
            } else {
                OnboardingView()
            }

            if showSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}

/// Home / Weeks / Community.
///
/// A native `TabView` rather than the Android layout's custom header buttons:
/// a bottom tab bar is the iOS convention, and it mirrors correctly in RTL
/// without any work.
struct MainTabView: View {
    @State private var selection = ScreenshotSeed.tab ?? 0

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tag(0)
                .tabItem {
                    Label(L.tabHome, systemImage: "house.fill")
                }

            WeeksView()
                .tag(1)
                .tabItem {
                    Label(L.tabWeeks, systemImage: "calendar")
                }

            CommunityView()
                .tag(2)
                .tabItem {
                    Label(L.tabCommunity, systemImage: "bubble.left.and.bubble.right.fill")
                }
        }
        .tint(Warm.brand)
    }
}
