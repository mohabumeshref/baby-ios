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

    private let content = ContentStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let age = profile.age {
                    hero(age)
                    statsCard(age)

                    if let month = content.skills(forMonth: age.milestoneMonth) {
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
        .warmBackground()
    }

    // MARK: - Hero

    private func hero(_ age: BabyAge) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L.thisMonthsSkills)
                .font(WarmFont.eyebrow)
                .foregroundStyle(Warm.eyebrow)

            Text(L.monthHeadline(age.milestoneMonth))
                .font(WarmFont.display)
                .foregroundStyle(Warm.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

                HStack(spacing: 12) {
                    stat(value: age.days, label: L.dayUnit)
                    divider
                    stat(value: age.weeks, label: L.weekUnit)
                    divider
                    monthBadge(age.milestoneMonth)
                }
            }
        }
    }

    private func stat(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(String.number(value))
                .font(WarmFont.title)
                .foregroundStyle(Warm.brand)
            Text(label)
                .font(WarmFont.caption)
                .foregroundStyle(Warm.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Warm.chipOff)
            .frame(width: 1, height: 32)
    }

    private func monthBadge(_ month: Int) -> some View {
        VStack(spacing: 2) {
            Text(String.number(month + 1))
                .font(WarmFont.title)
                .foregroundStyle(.white)
            Text(L.monthUnit)
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
        .environment(\.layoutDirection, .rightToLeft)
}
