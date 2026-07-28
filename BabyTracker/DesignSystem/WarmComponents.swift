//
//  WarmComponents.swift
//  BabyTracker
//
//  The shared building blocks of the Warm & Refined surface: cards, milestone
//  chips, and the per-tier progress bar.
//

import SwiftUI

// MARK: - Card

/// White rounded surface used for every grouped block on the home screen.
struct WarmCard<Content: View>: View {
    var radius: CGFloat = WarmMetrics.cardRadius
    var padding: CGFloat = WarmMetrics.cardPadding
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Warm.card)
            )
            // A warm-tinted shadow rather than neutral black: on a cream
            // background a grey shadow reads as dirt.
            .shadow(color: Warm.brand.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Milestone chip

/// A single skill the parent checks off. Toggling is the primary interaction
/// on the home screen, so the whole chip is the hit target and it carries an
/// explicit accessibility state rather than relying on the checkmark glyph.
struct MilestoneChip: View {
    let label: String
    let isChecked: Bool
    let tier: Warm.Tier
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
                Text(label)
                    .font(WarmFont.chip)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isChecked ? Color.white : Warm.mutedChip)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .frame(minHeight: WarmMetrics.chipMinHeight)
            .background(
                RoundedRectangle(cornerRadius: WarmMetrics.chipRadius, style: .continuous)
                    .fill(isChecked ? tier.accent : Warm.chipOff)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChecked ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(label)
        .animation(.easeOut(duration: 0.15), value: isChecked)
    }
}

// MARK: - Tier progress

/// Slim progress bar shown in each tier header. Mirrors Android's 150ms
/// animated ObjectAnimator.
struct TierProgressBar: View {
    let completed: Int
    let total: Int
    let tier: Warm.Tier

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(tier.tint)
                Capsule()
                    .fill(tier.accent)
                    .frame(width: max(0, geo.size.width * fraction))
            }
        }
        .frame(height: 6)
        .animation(.easeOut(duration: 0.15), value: fraction)
        .accessibilityElement()
        .accessibilityLabel(Text("التقدّم"))
        .accessibilityValue(Text("\(String.number(completed)) من \(String.number(total))"))
    }
}

// MARK: - Screen background

/// The app-wide gradient backdrop.
struct WarmBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Warm.backgroundGradient.ignoresSafeArea())
    }
}

extension View {
    func warmBackground() -> some View { modifier(WarmBackground()) }
}
