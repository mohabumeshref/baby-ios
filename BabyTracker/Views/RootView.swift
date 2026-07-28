//
//  RootView.swift
//  BabyTracker
//
//  Decides between onboarding and the tab shell.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var profile: BabyProfile

    var body: some View {
        if profile.isOnboarded {
            MainTabView()
        } else {
            BirthDateOnboardingView()
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

            CommunityPlaceholderView()
                .tag(2)
                .tabItem {
                    Label(L.tabCommunity, systemImage: "bubble.left.and.bubble.right.fill")
                }
        }
        .tint(Warm.brand)
    }
}

/// Stands in until ForumKit lands.
struct CommunityPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(Warm.muted)
            Text(L.communityComingSoon)
                .font(WarmFont.body)
                .foregroundStyle(Warm.mutedSub)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .warmBackground()
    }
}

/// Minimal first-run screen: the app derives everything from the birth date,
/// so this is the only thing it must ask for.
struct BirthDateOnboardingView: View {
    @EnvironmentObject private var profile: BabyProfile
    @EnvironmentObject private var notifications: NotificationManager
    @State private var selected = Date()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text(L.welcome)
                    .font(WarmFont.display)
                    .foregroundStyle(Warm.ink)
                Text(L.whenWasBabyBorn)
                    .font(WarmFont.body)
                    .foregroundStyle(Warm.mutedSub)
            }

            WarmCard {
                DatePicker(
                    "",
                    selection: $selected,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Warm.brand)
                .labelsHidden()
            }

            Button {
                profile.birthDate = selected
                Task {
                    // Ask for notifications here, not at launch: by this point
                    // the user has told us about their baby, so a "new week"
                    // reminder is an obvious benefit rather than an
                    // unexplained system prompt on a cold first run.
                    await notifications.requestAuthorizationIfNeeded()
                    await notifications.scheduleWeeklyReminder(birthDate: selected)
                }
            } label: {
                Text(L.continueAction)
                    .font(WarmFont.heading)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: WarmMetrics.chipRadius, style: .continuous)
                            .fill(Warm.brandGradient)
                    )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, WarmMetrics.screenPadding)
        .warmBackground()
    }
}

#Preview("Onboarding") {
    BirthDateOnboardingView()
        .environmentObject(BabyProfile(defaults: UserDefaults(suiteName: "preview")!))
        .environmentObject(NotificationManager.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
