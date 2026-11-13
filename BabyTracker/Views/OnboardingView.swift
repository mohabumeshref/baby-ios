//
//  OnboardingView.swift
//  BabyTracker
//
//  First run: welcome, country, birth date.
//
//  Three steps with text navigation ("السابق" / "التالي" / "تم") and step dots,
//  mirroring the Android intro. Android persists a default birth date as soon
//  as the intro opens; this does not, because `RootView` switches away from
//  onboarding the moment a date exists - writing one up front would eject the
//  parent from the flow at step 1. The effect the Android behaviour was after
//  is kept: the date defaults to today, so finishing without touching step 3
//  still saves something sensible.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var profile: BabyProfile
    @EnvironmentObject private var notifications: NotificationManager
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var vaccines: VaccineStore
    @State private var step = 0
    @State private var birthDate = Date()
    @State private var showDatePicker = false

    private static let stepCount = 3

    /// Someone who already has a birth date is revisiting, so they get a way
    /// out that doesn't require finishing.
    private var isRevisiting: Bool { profile.isOnboarded }

    var body: some View {
        VStack(spacing: 0) {
            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            navigationBar
        }
        .warmBackground()
        .overlay(alignment: .topLeading) {
            if isRevisiting {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Warm.mutedSub)
                        .padding(12)
                }
                .buttonStyle(.plain)
            }
        }
        .task { await vaccines.refineCountryFromIP() }
        .sheet(isPresented: $showDatePicker) {
            BirthDateSheet(initial: birthDate) { birthDate = $0 }
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var stage: some View {
        switch step {
        case 1:  countryStep
        case 2:  birthDateStep
        default: welcomeStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 14) {
            Spacer()

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text(L.onboardingWelcomeTitle)
                .font(WarmFont.display)
                .foregroundStyle(Warm.ink)
                .multilineTextAlignment(.center)

            Text(L.onboardingWelcomeBody)
                .font(WarmFont.body)
                .foregroundStyle(Warm.mutedSub)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, WarmMetrics.screenPadding)
    }

    private var countryStep: some View {
        VStack(spacing: 10) {
            VStack(spacing: 6) {
                Text(L.vaxPickCountry)
                    .font(WarmFont.title)
                    .foregroundStyle(Warm.brand)

                Text(L.vaxCountryPurpose)
                    .font(WarmFont.caption)
                    .foregroundStyle(Warm.mutedSub)
                    .multilineTextAlignment(.center)

                Text("\(L.vaxSelectedCountry): \(vaccines.countryName)")
                    .font(WarmFont.chip)
                    .foregroundStyle(Warm.green)
            }
            .padding(.top, 20)
            .padding(.horizontal, WarmMetrics.screenPadding)

            CountryPickerView(
                countries: vaccines.countries,
                selected: vaccines.countryIso,
                onSelect: { vaccines.selectCountry($0) },
                showsChrome: false
            )
        }
    }

    private var birthDateStep: some View {
        VStack(spacing: 14) {
            Spacer()

            Text(L.onboardingBirthDateTitle)
                .font(WarmFont.title)
                .foregroundStyle(Warm.brand)

            Button { showDatePicker = true } label: {
                VStack(spacing: 6) {
                    Text(Self.fieldFormatter.string(from: birthDate))
                        .font(WarmFont.display)
                        .foregroundStyle(Warm.ink)
                        // A date is read left-to-right in both languages.
                        .environment(\.layoutDirection, .leftToRight)

                    Text(L.onboardingTapToChangeDate)
                        .font(WarmFont.caption)
                        .foregroundStyle(Warm.mutedSub)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(
                    RoundedRectangle(cornerRadius: WarmMetrics.cardRadius, style: .continuous)
                        .fill(Warm.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: WarmMetrics.cardRadius, style: .continuous)
                        .stroke(Warm.dotIdle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, WarmMetrics.screenPadding)
    }

    /// "dd / MM / yyyy", western digits in both languages so the field reads
    /// the same as the picker that edits it.
    static let fieldFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "dd / MM / yyyy"
        return f
    }()

    // MARK: - Navigation

    private var navigationBar: some View {
        HStack {
            Button(L.previous) { if step > 0 { withAnimation { step -= 1 } } }
                .font(WarmFont.heading)
                .foregroundStyle(Warm.mutedSub)
                .buttonStyle(.plain)
                .opacity(step > 0 ? 1 : 0)
                .disabled(step == 0)

            Spacer()

            HStack(spacing: 8) {
                ForEach(0..<Self.stepCount, id: \.self) { index in
                    Circle()
                        .fill(index == step ? Warm.brand : Warm.dotIdle)
                        .frame(width: 7, height: 7)
                }
            }

            Spacer()

            Button(step == Self.stepCount - 1 ? L.done : L.next) {
                if step < Self.stepCount - 1 {
                    withAnimation { step += 1 }
                } else {
                    finish()
                }
            }
            .font(WarmFont.heading)
            .foregroundStyle(Warm.brand)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, WarmMetrics.screenPadding)
        .padding(.vertical, 14)
    }

    private func finish() {
        profile.setBirthDate(birthDate)
        Task {
            // Asked here, not at launch: by now the parent has told us about
            // their baby, so a weekly reminder is an obvious benefit rather
            // than an unexplained prompt on a cold first run.
            await notifications.requestAuthorizationIfNeeded()
            await notifications.scheduleWeeklyReminder(birthDate: birthDate)
        }
        if isRevisiting { dismiss() }
    }
}

/// Spinner-style picker, matching the Android date dialog.
private struct BirthDateSheet: View {
    let onSave: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    init(initial: Date, onSave: @escaping (Date) -> Void) {
        self.onSave = onSave
        _date = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.layoutDirection, .leftToRight)
                Spacer()
            }
            .padding(WarmMetrics.screenPadding)
            .warmBackground()
            .navigationTitle(L.onboardingBirthDateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                        .tint(Warm.mutedSub)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.done) {
                        onSave(date)
                        dismiss()
                    }
                    .tint(Warm.brand)
                }
            }
        }
    }
}

#Preview("Onboarding") {
    OnboardingView()
        .environmentObject(BabyProfile(defaults: UserDefaults(suiteName: "preview")!))
        .environmentObject(NotificationManager.shared)
        .environmentObject(VaccineStore(defaults: UserDefaults(suiteName: "preview")!))
        .environment(\.layoutDirection, .rightToLeft)
}
