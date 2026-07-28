//
//  BabyAge.swift
//  BabyTracker
//
//  Age arithmetic, ported from PregnancyHelper / MainBabyActivity.getAge.
//
//  One quirk is carried over deliberately. The app has two different notions
//  of "week":
//
//    * the age in weeks SHOWN to the parent   -> days / 7   (a real week)
//    * the index into the 45 article entries  -> days / 8.111…
//
//  The second is not a week at all: it spreads 365 days evenly across the 45
//  entries in weeks.json. Changing it to a true week count would desynchronise
//  the "حالياً" indicator from the article the parent is reading, and would
//  disagree with the Android app for the same baby. It stays as-is.
//

import Foundation

struct BabyAge: Equatable {
    /// Whole days since birth. Never zero - Android clamps to a minimum of 1.
    let days: Int
    /// Age in whole weeks, for display.
    let weeks: Int
    /// Completed months since birth (0...). Milestones exist for 0...11.
    let months: Int
    /// Index into `weeks.json` (0...44) for the entry covering today.
    let contentWeekIndex: Int

    /// Android's odd divisor: 45 content entries across a ~365 day year.
    private static let daysPerContentWeek = 8.111111111111111

    static let maxContentWeekIndex = 44

    init(birthDate: Date, now: Date = Date()) {
        let calendar = Calendar.current
        let birthDay = calendar.startOfDay(for: birthDate)
        let today = calendar.startOfDay(for: now)

        // Android takes the absolute difference and clamps zero up to one, so a
        // baby born today reads as one day old rather than zero.
        let rawDays = calendar.dateComponents([.day], from: birthDay, to: today).day ?? 0
        days = max(abs(rawDays), 1)

        weeks = days / 7

        // Calendar's month component already declines to count the current
        // month until the birth day-of-month is reached, which is what
        // getAge()'s `if (a > 0 && _day > d) a -= 1` was doing by hand.
        let rawMonths = calendar.dateComponents([.month], from: birthDay, to: today).month ?? 0
        months = max(rawMonths, 0)

        let index = Int(Double(days) / Self.daysPerContentWeek)
        contentWeekIndex = min(max(index, 0), Self.maxContentWeekIndex)
    }

    /// Milestones only exist for the first twelve months.
    var hasMilestones: Bool { months >= 0 && months < 12 }

    /// Clamped month for milestone lookup.
    var milestoneMonth: Int { min(max(months, 0), 11) }
}

// MARK: - Arabic ordinals

enum ArabicOrdinal {
    /// Ported from PregnancyHelper.getArabicMonthNumber - the ordinal used in
    /// the hero headline ("الشهر الثالث").
    private static let names = [
        "الأول", "الثاني", "الثالث", "الرابع", "الخامس", "السادس",
        "السابع", "الثامن", "التاسع", "العاشر", "الحادي عشر", "الثاني عشر",
    ]

    static func month(_ index: Int) -> String {
        guard index >= 0 && index < names.count else { return String.number(index + 1) }
        return names[index]
    }
}
