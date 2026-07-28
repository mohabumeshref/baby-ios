//
//  WarmType.swift
//  BabyTracker
//
//  Cairo type scale.
//
//  Every face is declared `relativeTo:` a system text style so the app still
//  responds to Dynamic Type. The pregnancy tracker swaps fonts through a
//  UIAppearance proxy, which pins sizes and silently opts the whole app out of
//  accessibility sizing; SwiftUI lets us avoid that.
//

import SwiftUI

enum WarmFont {
    private enum Face {
        static let light = "Cairo-Light"
        static let regular = "Cairo-Regular"
        static let medium = "Cairo-Medium"
        static let semibold = "Cairo-SemiBold"
        static let bold = "Cairo-Bold"
    }

    // MARK: - Scale

    /// Screen title, e.g. the baby's age headline.
    static let display = Font.custom(Face.bold, size: 28, relativeTo: .largeTitle)
    static let title = Font.custom(Face.bold, size: 22, relativeTo: .title2)
    /// Card headings, tier titles.
    static let heading = Font.custom(Face.semibold, size: 17, relativeTo: .headline)
    /// Article section headings.
    static let articleHeading = Font.custom(Face.semibold, size: 16, relativeTo: .headline)
    static let body = Font.custom(Face.regular, size: 15, relativeTo: .body)
    /// Long-form article text - slightly larger for sustained reading.
    static let articleBody = Font.custom(Face.regular, size: 16, relativeTo: .body)
    /// Milestone chips.
    static let chip = Font.custom(Face.semibold, size: 14, relativeTo: .subheadline)
    static let caption = Font.custom(Face.regular, size: 13, relativeTo: .caption)
    /// The small uppercase-ish label above a card title.
    static let eyebrow = Font.custom(Face.medium, size: 12, relativeTo: .caption2)
    /// Tier counters ("3/4") and other numerics.
    static let counter = Font.custom(Face.bold, size: 14, relativeTo: .subheadline)
}

// MARK: - Numerals

extension String {
    /// Arabic UI, Western digits.
    ///
    /// The Android app renders counts and ages in Western digits even in
    /// Arabic, and the pregnancy tracker had a crash caused by locale-dependent
    /// digit handling. Formatting numbers through a pinned `en_US_POSIX`
    /// formatter keeps both apps consistent and parsing predictable.
    static func number(_ value: Int) -> String {
        Self.westernFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let westernFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.groupingSeparator = ""
        return f
    }()
}
