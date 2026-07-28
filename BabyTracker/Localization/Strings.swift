//
//  Strings.swift
//  BabyTracker
//
//  UI strings, in code rather than .strings files.
//
//  This follows the pregnancy tracker's proven approach: both languages sit on
//  one line, so a translation can never silently go missing and there is no
//  key indirection to chase. Arabic values are taken verbatim from the Android
//  app's res/values/strings.xml where an equivalent exists.
//
//  Note this covers UI chrome only. The article and milestone CONTENT is
//  Arabic-only - see ContentStore.
//

import Foundation

enum L {

    /// Two-letter code of the language the app is actually running in.
    static var langCode: String {
        String(Locale.preferredLanguages.first?.prefix(2) ?? "ar")
    }

    static var isArabic: Bool { langCode == "ar" }

    private static func localized(ar: String, en: String) -> String {
        isArabic ? ar : en
    }

    // MARK: - App

    static var appName: String { localized(ar: "أنا و طفلي", en: "Me & My Baby") }

    // MARK: - Tabs (Android: preg_tab / weeks_tab / forum_tab)

    static var tabHome: String { localized(ar: "الرئيسية", en: "Home") }
    static var tabWeeks: String { localized(ar: "الأسابيع", en: "Weeks") }
    static var tabCommunity: String { localized(ar: "مجتمعي", en: "Community") }

    // MARK: - Onboarding

    static var welcome: String { localized(ar: "أهلاً بكِ", en: "Welcome") }
    static var whenWasBabyBorn: String {
        localized(ar: "متى وُلد طفلك؟", en: "When was your baby born?")
    }
    static var continueAction: String { localized(ar: "متابعة", en: "Continue") }
    static var noBirthDateYet: String {
        localized(ar: "لم يتم تحديد تاريخ الميلاد بعد", en: "No birth date set yet")
    }

    // MARK: - Home

    static var thisMonthsSkills: String {
        localized(ar: "مهارات هذا الشهر", en: "This month's skills")
    }
    /// Hero headline. Arabic spells the ordinal ("الشهر الثالث"); English uses
    /// a numeral, since "Month the third" reads badly.
    static func monthHeadline(_ index: Int) -> String {
        localized(
            ar: "الشهر \(ArabicOrdinal.month(index))",
            en: "Month \(String.number(index + 1))"
        )
    }
    static var dayUnit: String { localized(ar: "يوم", en: "days") }
    static var weekUnit: String { localized(ar: "أسبوع", en: "weeks") }
    static var monthUnit: String { localized(ar: "الشهر", en: "month") }
    static var progress: String { localized(ar: "التقدّم", en: "Progress") }
    /// "3 من 4"
    static func ofTotal(_ done: Int, _ total: Int) -> String {
        localized(
            ar: "\(String.number(done)) من \(String.number(total))",
            en: "\(String.number(done)) of \(String.number(total))"
        )
    }

    // MARK: - Weeks

    static var howBabyGrows: String {
        localized(ar: "كيف ينمو طفلك", en: "How your baby grows")
    }
    static var yourBody: String { localized(ar: "جسمكِ", en: "Your body") }
    /// Android: current_week
    static var currentWeek: String { localized(ar: "الأسبوع الحالي", en: "Current week") }
    static var now: String { localized(ar: "حالياً", en: "Now") }
    static var backToCurrent: String {
        localized(ar: "العودة للحالي", en: "Back to current")
    }
    static var previousWeek: String { localized(ar: "الأسبوع السابق", en: "Previous week") }
    static var nextWeek: String { localized(ar: "الأسبوع التالي", en: "Next week") }

    // MARK: - Community (placeholder until ForumKit lands)

    static var communityComingSoon: String {
        localized(ar: "المجتمع قيد الإعداد", en: "Community coming soon")
    }
}
