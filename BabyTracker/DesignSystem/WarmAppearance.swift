//
//  WarmAppearance.swift
//  BabyTracker
//
//  Cairo on the chrome SwiftUI doesn't reach.
//
//  `.font()` styles SwiftUI's own text, but a navigation title, a toolbar
//  button and a tab bar label are UIKit views underneath, and they keep the
//  system font however the SwiftUI view is modified. The only way to change
//  them is the UIKit appearance proxies, applied once before any window
//  exists.
//
//  Note what is NOT here: the items inside a `Menu`. Those become a UIMenu,
//  and UIKit exposes no font on its elements at all - which is why the
//  community screen presents its own sheet instead.
//

import SwiftUI
import UIKit

enum WarmAppearance {

    private enum Face {
        static let medium = "Cairo-Medium"
        static let semibold = "Cairo-SemiBold"
        static let bold = "Cairo-Bold"
    }

    /// Falls back to the system font rather than crashing: a missing face is a
    /// packaging mistake, and shipping the system font is better than shipping
    /// a launch crash.
    private static func font(_ name: String, _ size: CGFloat, fallback: UIFont) -> UIFont {
        UIFont(name: name, size: size) ?? fallback
    }

    static func apply() {
        applyNavigationBar()
        applyTabBar()
    }

    // MARK: - Navigation bar

    private static func applyNavigationBar() {
        let title = font(Face.bold, 17, fallback: .boldSystemFont(ofSize: 17))
        let largeTitle = font(Face.bold, 28, fallback: .boldSystemFont(ofSize: 28))
        let button = font(Face.semibold, 16, fallback: .systemFont(ofSize: 16, weight: .semibold))

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: title,
            .foregroundColor: UIColor(Warm.ink),
        ]
        let largeTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: largeTitle,
            .foregroundColor: UIColor(Warm.ink),
        ]

        // Toolbar buttons keep their tint; only the font is stated, so a
        // destructive or disabled item still colours itself.
        let buttonAppearance = UIBarButtonItemAppearance()
        buttonAppearance.normal.titleTextAttributes = [.font: button]
        buttonAppearance.highlighted.titleTextAttributes = [.font: button]
        buttonAppearance.disabled.titleTextAttributes = [.font: button]

        func configured(_ appearance: UINavigationBarAppearance) -> UINavigationBarAppearance {
            appearance.titleTextAttributes = titleAttributes
            appearance.largeTitleTextAttributes = largeTitleAttributes
            appearance.buttonAppearance = buttonAppearance
            appearance.doneButtonAppearance = buttonAppearance
            appearance.backButtonAppearance = buttonAppearance
            return appearance
        }

        // Two appearances, because the bar has two states: a blurred
        // background once content scrolls under it, and nothing at all at the
        // top of a scroll view. Giving both the same font is the point; giving
        // both the same BACKGROUND would put a bar over the cream background.
        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()

        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()

        UINavigationBar.appearance().standardAppearance = configured(standard)
        UINavigationBar.appearance().compactAppearance = configured(standard)
        UINavigationBar.appearance().scrollEdgeAppearance = configured(scrollEdge)
    }

    // MARK: - Tab bar

    private static func applyTabBar() {
        let label = font(Face.medium, 11, fallback: .systemFont(ofSize: 11, weight: .medium))

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        // Colours are stated alongside the font because setting title
        // attributes at all replaces the whole dictionary, and TabView's
        // `.tint` no longer reaches the label once this appearance is in
        // place.
        for layout in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ] {
            layout.normal.titleTextAttributes = [
                .font: label,
                .foregroundColor: UIColor.secondaryLabel,
            ]
            layout.selected.titleTextAttributes = [
                .font: label,
                .foregroundColor: UIColor(Warm.brand),
            ]
            layout.normal.iconColor = .secondaryLabel
            layout.selected.iconColor = UIColor(Warm.brand)
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
