//
//  HomeView.swift
//  BabyTracker
//
//  Home / Milestones - the app's primary screen.
//
//  Layout mirrors the Android redesign: an age headline, a stats card, then
//  three tier cards whose chips the parent taps to check off, each with a live
//  progress bar and count.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var profile: BabyProfile

    @EnvironmentObject private var vaccines: VaccineStore

    private let content = ContentStore.shared

    /// Android divides elapsed days by 30.44; same divisor, so a dose reads as
    /// due on the same day in both apps.
    private var babyMonths: Double {
        guard let birth = profile.birthDate else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: birth, to: Date()).day ?? 0
        return Double(days) / 30.44
    }

    var body: some View {
        NavigationStack {
            scrollContent
                .warmBackground()
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: VaccinesRoute.self) { _ in
                    VaccinesView()
                }
                .task { await vaccines.refineCountryFromIP() }
        }
    }

    /// Marker for the push - the destination takes no parameters, but
    /// `navigationDestination` needs a value type to key on.
    struct VaccinesRoute: Hashable {}

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let age = profile.age {
                    hero(age)
                    statsCard(age)
                    vaccinesCard

                    // In the scroll content directly under the card, not
                    // pinned to the screen edge, and sized to the same width
                    // as the cards it sits between.
                    BannerAdView(
                        width: UIScreen.main.bounds.width
                            - WarmMetrics.screenPadding * 2
                    )

                    if let month = content.skills(forMonth: age.milestoneMonth) {
                        skillsSectionHeader

                        ForEach(Array(month.tiers.enumerated()), id: \.offset) { index, tier in
                            TierCard(
                                tier: tier,
                                tierIndex: index,
                                month: age.milestoneMonth
                            )
                        }
                    }
                } else {
                    Text(L.noBirthDateYet)
                        .font(WarmFont.body)
                        .foregroundStyle(Warm.muted)
                        .padding(.top, 60)
                }
            }
            .padding(.horizontal, WarmMetrics.screenPadding)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Vaccines

    /// The one filled card on an otherwise white-on-cream screen, because it
    /// is the new feature and the screen's current call to action.
    private var vaccinesCard: some View {
        NavigationLink(value: VaccinesRoute()) {
            HStack(spacing: 14) {
                Text("💉")
                    .font(.system(size: 28))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Warm.vaxIconCircle))

                VStack(alignment: .leading, spacing: 3) {
                    Text(L.vaxEntry)
                        .font(WarmFont.title)
                        .foregroundStyle(.white)

                    Text(vaccines.summary(babyMonths: babyMonths))
                        .font(WarmFont.caption)
                        .foregroundStyle(Warm.vaxCardSubtitle)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                // Last, so it sits on the trailing edge - the left in Arabic.
                // `chevron.forward` rather than `.right`: the direction-aware
                // symbol mirrors itself, so it points the way the reader
                // travels in either layout direction.
                Image(systemName: "chevron.forward")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: WarmMetrics.statCardRadius, style: .continuous)
                    .fill(Warm.vaxCardGradient)
            )
            .shadow(color: Warm.brand.opacity(0.22), radius: 10, x: 0, y: 5)
            // The badge overhangs the card's top edge, so it is drawn as an
            // overlay with a negative offset and the card carries top padding
            // to make room for it.
            .overlay(alignment: .topLeading) {
                Text(L.vaxNewBadge)
                    .font(WarmFont.eyebrow)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Warm.green))
                    .shadow(color: Warm.green.opacity(0.35), radius: 4, x: 0, y: 2)
                    .offset(x: 18, y: -9)
            }
            .padding(.top, 9)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.vaxEntry + ". " + L.vaxNewBadge)
    }

    // MARK: - Hero

    private func hero(_ age: BabyAge) -> some View {
        // The age headline alone. "مهارات هذا الشهر" used to sit above it as an
        // eyebrow; it now names the skills section further down the screen,
        // where the chips it refers to actually are.
        Text(L.monthHeadline(age.milestoneMonth))
            .font(WarmFont.display)
            .foregroundStyle(Warm.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Skills section

    /// Titles the skills cards and says what to do with them. The chips look
    /// like labels until you know they are tappable, so the instruction earns
    /// its line.
    private var skillsSectionHeader: some View {
        VStack(spacing: 6) {
            Text(L.thisMonthsSkills)
                .font(WarmFont.sectionHeading)
                .foregroundStyle(Warm.brand)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(L.tapSkillsHint)
                .font(WarmFont.caption)
                .foregroundStyle(Warm.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }

    // MARK: - Stats

    /// Three numbers side by side read as three unrelated stats - testers
    /// couldn't tell whether the card was showing age, or progress, or
    /// something else. The header names what the row is; the numbers are then
    /// obviously the same fact in three units.
    private func statsCard(_ age: BabyAge) -> some View {
        WarmCard(radius: WarmMetrics.statCardRadius) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Warm.eyebrow)
                    Text(L.babyAge)
                        .font(WarmFont.eyebrow)
                        .foregroundStyle(Warm.eyebrow)
                }

                HStack(spacing: 10) {
                    statBox(heading: L.inDays, value: age.days, unit: L.dayUnit)
                    statBox(heading: L.inWeeks, value: age.weeks, unit: L.weekUnit)
                    statBox(heading: L.inMonths, value: age.milestoneMonth + 1, unit: L.monthUnit)
                }
            }
        }
    }

    /// All three cells share the month badge's orange box, per design
    /// feedback - one visual weight for the whole age row.
    private func statBox(heading: String, value: Int, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(heading)
                .font(WarmFont.caption)
                .foregroundStyle(Warm.monthLabel)
            Text(String.number(value))
                .font(WarmFont.title)
                .foregroundStyle(.white)
            Text(unit)
                .font(WarmFont.caption)
                .foregroundStyle(Warm.monthLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: WarmMetrics.statCardRadius, style: .continuous)
                .fill(Warm.brandGradient)
        )
    }
}

// MARK: - Tier card

private struct TierCard: View {
    let tier: SkillTier
    let tierIndex: Int
    let month: Int

    @EnvironmentObject private var milestones: MilestoneStore
    @Environment(\.layoutDirection) private var layoutDirection

    private var palette: Warm.Tier { Warm.tier(tierIndex) }

    private var completed: Int {
        milestones.completedCount(month: month, tier: tierIndex, total: tier.items.count)
    }

    var body: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 12) {
                header
                progress

                FlowLayout(layoutDirection: layoutDirection) {
                    ForEach(Array(tier.items.enumerated()), id: \.offset) { index, item in
                        MilestoneChip(
                            label: item,
                            isChecked: milestones.isChecked(
                                month: month, tier: tierIndex, index: index
                            ),
                            tier: palette
                        ) {
                            milestones.toggle(month: month, tier: tierIndex, index: index)
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tier.title)
                    .font(WarmFont.heading)
                    .foregroundStyle(palette.title)
                Text(tier.subtitle)
                    .font(WarmFont.caption)
                    .foregroundStyle(Warm.muted)
            }

            Spacer(minLength: 8)

            Text("\(String.number(completed))/\(String.number(tier.items.count))")
                .font(WarmFont.counter)
                .foregroundStyle(palette.accent)
                // The count is a ratio, not Arabic prose - keep it unmirrored.
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private var progress: some View {
        TierProgressBar(
            completed: completed,
            total: tier.items.count,
            tier: palette
        )
    }
}

#Preview {
    HomeView()
        .environmentObject({ () -> BabyProfile in
            let p = BabyProfile(defaults: UserDefaults(suiteName: "preview")!)
            p.setBirthDate(Calendar.current.date(byAdding: .month, value: -3, to: Date()))
            return p
        }())
        .environmentObject(MilestoneStore(defaults: UserDefaults(suiteName: "preview")!))
        .environmentObject(VaccineStore(defaults: UserDefaults(suiteName: "preview")!))
        .environment(\.layoutDirection, .rightToLeft)
}
