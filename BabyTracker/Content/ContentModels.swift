//
//  ContentModels.swift
//  BabyTracker
//
//  Typed models for the content ported out of the Android app's
//  res/raw/months.xml and res/raw/skills.xml by tools/port_content.py.
//
//  The Android originals stored HTML blobs in misleadingly named XML fields
//  (<MonthInfo> held the baby-growth article, <ImageUrl> held the parent
//  article) and rebuilt the milestone tiers at runtime by string-matching
//  Arabic text. That parsing now happens once, offline, so the app just
//  decodes structure.
//

import Foundation

/// One rendered piece of an article. Replaces the inline `<b>` / `<br>` markup
/// the Android app fed to `Html.fromHtml`, so headings can be styled with the
/// design system instead of the system's HTML renderer.
struct ContentBlock: Decodable, Hashable, Identifiable {
    enum Kind: String, Decodable {
        case heading
        case body
        case bullet
    }

    let kind: Kind
    let text: String

    var id: Int { hashValue }
}

/// One entry of the Weeks tab. There are 45: indices 0...43 are four weeks per
/// month across the first eleven months, and index 44 is the standalone
/// "طفلك في عامه الأول" entry (Android renders it with a single week dot).
struct WeekContent: Decodable, Identifiable {
    let index: Int
    let title: String
    let month: Int
    let weekOfMonth: Int
    let weeksInMonth: Int

    /// "كيف ينمو طفلك" - the baby-development article.
    let babyGrowth: [ContentBlock]
    /// The parent-focused article ("جسمك" and related guidance).
    let parentBody: [ContentBlock]

    var id: Int { index }

    var isFinalEntry: Bool { weeksInMonth == 1 }
}

/// One achievement tier on the Home screen. Three per month.
struct SkillTier: Decodable, Identifiable {
    /// e.g. "مهارات تمّ إتقانها"
    let title: String
    /// The parenthetical qualifier, e.g. "يقوم بها معظم الأطفال الرضّع"
    let subtitle: String
    /// The individual skills, each shown as a tappable chip.
    let items: [String]

    var id: String { title }
}

/// The three tiers for a given month of the baby's life (0...11).
struct MonthSkills: Decodable, Identifiable {
    let month: Int
    let tiers: [SkillTier]

    var id: Int { month }
}
