//
//  WarmPalette.swift
//  BabyTracker
//
//  The "Warm & Refined" palette, ported 1:1 from the Android redesign
//  (res/values/colors.xml). Names are kept identical to the Android tokens so
//  the two apps can be compared side by side without a translation table.
//
//  These are deliberately fixed values rather than an asset catalog with dark
//  variants: the identity is a warm cream-and-orange surface, and inverting it
//  produces something that reads as a different product. Dark mode is handled
//  by keeping the palette constant - see `WarmTheme` for how the app pins the
//  colour scheme.
//

import SwiftUI

extension Color {
    /// Hex convenience matching the Android `#rrggbb` literals exactly.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Warm {

    // MARK: - Background

    static let bgTop = Color(hex: 0xFFE9D7)
    static let bgMid = Color(hex: 0xFBE8DB)
    static let bgBottom = Color(hex: 0xF4F0EC)

    /// The app-wide backdrop. Three stops, not two - the midpoint is what
    /// keeps the fade from looking grey through the middle.
    static let backgroundGradient = LinearGradient(
        colors: [bgTop, bgMid, bgBottom],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Text

    static let ink = Color(hex: 0x3A2A20)
    static let muted = Color(hex: 0xA78B78)
    static let mutedSub = Color(hex: 0x9A7358)
    static let mutedChip = Color(hex: 0x8A6A54)
    static let eyebrow = Color(hex: 0xB07A52)
    static let bodyInk = Color(hex: 0x5A4638)

    // MARK: - Brand

    static let brand = Color(hex: 0xC25E28)
    static let brandBright = Color(hex: 0xEF7B3A)
    static let brandDeep = Color(hex: 0xD9611F)

    /// Used for the month badge on the stats card.
    static let brandGradient = LinearGradient(
        colors: [brandBright, brandDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Surfaces

    static let card = Color.white
    static let chipOff = Color(hex: 0xFBEEE3)
    static let monthLabel = Color(hex: 0xFFE3CF)
    static let tabInactive = Color(hex: 0xB09A8C)
    /// #8CFFFFFF - 55% white, from wr_bg_icon_tile.
    static let iconTile = Color.white.opacity(Double(0x8C) / 255)

    // MARK: - Milestone tiers
    //
    // Three tiers, in the order the content is authored:
    //   0  مهارات تمّ إتقانها   (mastered)
    //   1  مهارات بارزة          (emerging)
    //   2  مهارات متطوّرة        (advanced)

    struct Tier {
        let accent: Color
        let tint: Color
        let title: Color
    }

    static let tiers: [Tier] = [
        Tier(accent: Color(hex: 0xE8722E), tint: Color(hex: 0xFBE6D6), title: Color(hex: 0xC25E28)),
        Tier(accent: Color(hex: 0xE0785F), tint: Color(hex: 0xF8E5DF), title: Color(hex: 0xC15C44)),
        Tier(accent: Color(hex: 0xC98A2E), tint: Color(hex: 0xF3E8CF), title: Color(hex: 0xA9781F)),
    ]

    static func tier(_ index: Int) -> Tier {
        tiers[min(max(index, 0), tiers.count - 1)]
    }

    // MARK: - Weeks screen

    static let nowPillBackground = Color(hex: 0xFFF0E5)
    static let green = Color(hex: 0x3DA35D)
    static let dotIdle = Color(hex: 0xEAD9C8)
    static let articleInk = Color(hex: 0x7A3E15)

    static let articleHeaderGradient = LinearGradient(
        colors: [Color(hex: 0xF7C9A0), Color(hex: 0xF4B483)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Metrics

enum WarmMetrics {
    /// Corner radii, taken from the Android drawables rather than the design
    /// summary - the summary rounds these to "~20" and "~14-16".
    static let cardRadius: CGFloat = 20        // wr_bg_tier_card
    static let statCardRadius: CGFloat = 18    // wr_bg_stat_card
    static let chipRadius: CGFloat = 14        // wr_bg_chip_off / _on_*
    static let nowPillRadius: CGFloat = 20     // wr_bg_now_pill
    static let iconTileRadius: CGFloat = 12    // wr_bg_icon_tile
    static let dotRadius: CGFloat = 3          // wr_bg_dot_*

    /// Week dots: the selected one is wider, not just recoloured.
    static let dotActiveWidth: CGFloat = 34
    static let dotIdleWidth: CGFloat = 22
    static let dotHeight: CGFloat = 6

    /// Chips must stay tappable; Android sets a 44dp minimum height.
    static let chipMinHeight: CGFloat = 44
    static let chipSpacing: CGFloat = 8
    static let cardPadding: CGFloat = 16
    static let screenPadding: CGFloat = 16
}
