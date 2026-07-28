//
//  WeeksView.swift
//  BabyTracker
//
//  Weeks tab - the article reader.
//
//  Mirrors the Android screen: a prev/next stepper across the 45 content
//  entries, a "حالياً" pill when the selected entry is the one covering today,
//  week dots for the entry's position within its month, and the two article
//  sections.
//

import SwiftUI

struct WeeksView: View {
    @EnvironmentObject private var profile: BabyProfile
    @State private var selectedIndex: Int = 0
    /// Which article sections are open. Both start open, matching Android,
    /// where the bodies are always visible.
    @State private var expanded: Set<Section> = [.babyGrowth, .parentBody]

    private let content = ContentStore.shared

    enum Section: Hashable {
        case babyGrowth
        case parentBody
    }

    /// The entry covering today, or nil before onboarding.
    private var currentIndex: Int? { profile.age?.contentWeekIndex }

    private var week: WeekContent? { content.week(at: selectedIndex) }

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView {
                VStack(spacing: 16) {
                    // Anchor for resetting reading position on week change.
                    Color.clear.frame(height: 0).id(topAnchor)

                    if let week {
                        header(week)
                        stepper
                        dots(week)

                        articleSection(
                            .babyGrowth,
                            title: L.howBabyGrows,
                            blocks: week.babyGrowth
                        )

                        if !week.parentBody.isEmpty {
                            articleSection(
                                .parentBody,
                                title: L.yourBody,
                                blocks: week.parentBody
                            )
                        }
                    }
                }
                .padding(.horizontal, WarmMetrics.screenPadding)
                .padding(.vertical, 20)
            }
            .onChange(of: selectedIndex) { _ in
                // Android calls weekScroll.scrollTo(0, 0) on every change.
                withAnimation(.easeOut(duration: 0.2)) {
                    scroller.scrollTo(topAnchor, anchor: .top)
                }
            }
        }
        .warmBackground()
        .onAppear {
            if let currentIndex { selectedIndex = currentIndex }
        }
    }

    private let topAnchor = "weeks-top"

    // MARK: - Header

    private func header(_ week: WeekContent) -> some View {
        VStack(spacing: 8) {
            // Android replaces the comma in "الشهر الثاني، الأسبوع الأول"
            // with a middot separator.
            Text(week.title.replacingOccurrences(of: "، ", with: " · "))
                .font(WarmFont.title)
                .foregroundStyle(Warm.ink)
                .multilineTextAlignment(.center)

            if currentIndex == week.index {
                nowPill
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.2), value: week.index)
    }

    private var nowPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Warm.green)
                .frame(width: 7, height: 7)
            Text(L.now)
                .font(WarmFont.caption)
                .foregroundStyle(Warm.brand)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Warm.nowPillBackground)
        )
        .accessibilityLabel(Text(L.currentWeek))
    }

    // MARK: - Stepper

    private var stepper: some View {
        HStack(spacing: 16) {
            stepButton(systemName: "chevron.backward", enabled: selectedIndex > 0) {
                selectedIndex = max(selectedIndex - 1, 0)
            }
            .accessibilityLabel(Text(L.previousWeek))

            Spacer()

            if currentIndex != selectedIndex, let currentIndex {
                Button {
                    selectedIndex = currentIndex
                } label: {
                    Text(L.backToCurrent)
                        .font(WarmFont.caption)
                        .foregroundStyle(Warm.brand)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            stepButton(
                systemName: "chevron.forward",
                enabled: selectedIndex < BabyAge.maxContentWeekIndex
            ) {
                selectedIndex = min(selectedIndex + 1, BabyAge.maxContentWeekIndex)
            }
            .accessibilityLabel(Text(L.nextWeek))
        }
    }

    private func stepButton(
        systemName: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(enabled ? Warm.brand : Warm.muted.opacity(0.4))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: WarmMetrics.chipRadius, style: .continuous)
                        .fill(Warm.chipOff)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Week dots

    /// One dot per week of the selected entry's month; the selected one is
    /// wider as well as recoloured. In RTL the first dot sits at the right,
    /// which SwiftUI handles for a plain HStack.
    private func dots(_ week: WeekContent) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<week.weeksInMonth, id: \.self) { position in
                let active = position == week.weekOfMonth
                RoundedRectangle(cornerRadius: WarmMetrics.dotRadius, style: .continuous)
                    .fill(active ? Warm.brandBright : Warm.dotIdle)
                    .frame(
                        width: active ? WarmMetrics.dotActiveWidth : WarmMetrics.dotIdleWidth,
                        height: WarmMetrics.dotHeight
                    )
            }
        }
        .animation(.easeOut(duration: 0.2), value: week.weekOfMonth)
        .accessibilityHidden(true)
    }

    // MARK: - Article

    private func articleSection(
        _ section: Section,
        title: String,
        blocks: [ContentBlock]
    ) -> some View {
        let isOpen = expanded.contains(section)

        return WarmCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        if isOpen { expanded.remove(section) } else { expanded.insert(section) }
                    }
                } label: {
                    HStack {
                        Text(title)
                            .font(WarmFont.articleHeading)
                            .foregroundStyle(Warm.articleInk)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Warm.articleInk)
                            .rotationEffect(.degrees(isOpen ? 0 : -90))
                    }
                    .padding(.horizontal, WarmMetrics.cardPadding)
                    .padding(.vertical, 14)
                    .background(Warm.articleHeaderGradient)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOpen ? [.isButton, .isSelected] : .isButton)

                if isOpen {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(blocks) { block in
                            blockView(block)
                        }
                    }
                    .padding(WarmMetrics.cardPadding)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: WarmMetrics.cardRadius, style: .continuous))
    }

    @ViewBuilder
    private func blockView(_ block: ContentBlock) -> some View {
        switch block.kind {
        case .heading:
            Text(block.text)
                .font(WarmFont.articleHeading)
                .foregroundStyle(Warm.ink)
                .padding(.top, 4)

        case .body:
            Text(block.text)
                .font(WarmFont.articleBody)
                .foregroundStyle(Warm.bodyInk)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

        case .bullet:
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(WarmFont.articleBody)
                    .foregroundStyle(Warm.brandBright)
                Text(block.text)
                    .font(WarmFont.articleBody)
                    .foregroundStyle(Warm.bodyInk)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    WeeksView()
        .environmentObject({ () -> BabyProfile in
            let p = BabyProfile(defaults: UserDefaults(suiteName: "preview")!)
            p.setBirthDate(Calendar.current.date(byAdding: .day, value: -81, to: Date()))
            return p
        }())
        .environment(\.layoutDirection, .rightToLeft)
}
