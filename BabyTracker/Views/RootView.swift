//
//  RootView.swift
//  BabyTracker
//
//  Decides between onboarding and the main app.
//
//  The tab shell (Home / Weeks / Community) lands with the Weeks tab; for now
//  this hosts Home directly.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var profile: BabyProfile

    var body: some View {
        Group {
            if profile.isOnboarded {
                HomeView()
            } else {
                BirthDateOnboardingView()
            }
        }
    }
}

/// Minimal first-run screen: the app derives everything from the birth date,
/// so this is the only thing it must ask for.
struct BirthDateOnboardingView: View {
    @EnvironmentObject private var profile: BabyProfile
    @State private var selected = Date()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("أهلاً بكِ")
                    .font(WarmFont.display)
                    .foregroundStyle(Warm.ink)
                Text("متى وُلد طفلك؟")
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
            } label: {
                Text("متابعة")
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
        .environment(\.layoutDirection, .rightToLeft)
}
