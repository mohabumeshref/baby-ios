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
import SwiftUI

enum L {

    /// The one language the app ships in.
    ///
    /// Set this to nil to go back to following the device, which is what an
    /// English release will want. Until then the app is Arabic on every
    /// device, because its CONTENT is: the weeks, the milestones and the
    /// vaccine names are Arabic only, so English chrome around them read as
    /// a half-translated app rather than an English one.
    ///
    /// Why a constant and not the bundle: `CFBundleLocalizations` lists `ar`
    /// alone, but `Locale.preferredLanguages` reports the DEVICE's language
    /// list, not the app's resolved localization - so on an English phone it
    /// still answers "en" and every label came out English. Only
    /// `Bundle.main.preferredLocalizations` is the intersection, and pinning
    /// the value is clearer than relying on that distinction.
    static let forcedLanguage: String? = "ar"

    /// Two-letter code of the language the app is running in.
    static var langCode: String {
        forcedLanguage
            ?? String(Locale.preferredLanguages.first?.prefix(2) ?? "ar")
    }

    static var isArabic: Bool { langCode == "ar" }

    /// Layout direction to pin the whole app to, for as long as it is
    /// single-language. Nil once `forcedLanguage` is nil, so SwiftUI goes back
    /// to deciding for itself.
    static var forcedLayoutDirection: LayoutDirection? {
        guard let forcedLanguage else { return nil }
        return forcedLanguage == "ar" ? .rightToLeft : .leftToRight
    }

    private static func localized(ar: String, en: String) -> String {
        isArabic ? ar : en
    }

    // MARK: - App

    static var appName: String { localized(ar: "أنا و طفلي", en: "My Baby & I") }

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

    /// Sits under the skills section heading, telling the parent the chips
    /// are tappable. Addressed to the mother, like the Android copy.
    static var tapSkillsHint: String {
        localized(
            ar: "اضغطي على المهارات التي يتقنها طفلكِ",
            en: "Tap the skills your baby has mastered"
        )
    }
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
    /// Header for the stats card, so the three numbers below it read as one
    /// fact in three units rather than three separate statistics.
    static var babyAge: String { localized(ar: "عمر طفلك", en: "Your baby's age") }
    // Unit labels sit ABOVE each figure, so they read as "in days: 90" rather
    // than leaving three bare numbers to be re-read.
    static var inDays: String { localized(ar: "بالأيام", en: "In days") }
    static var inWeeks: String { localized(ar: "بالأسابيع", en: "In weeks") }
    static var inMonths: String { localized(ar: "بالأشهر", en: "In months") }

    // Bare units. Note شهر, not الشهر - the definite article reads as "THE
    // month" next to a number, which is wrong for a unit label.
    static var dayUnit: String { localized(ar: "يوم", en: "days") }
    static var weekUnit: String { localized(ar: "أسبوع", en: "weeks") }
    static var monthUnit: String { localized(ar: "شهر", en: "months") }
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

    // MARK: - Notifications
    //
    // Android's copy is in TimeAlarm.java. The title there is written
    // "انـا و طفلي" with a decorative tatweel; this uses the clean app name so
    // it matches CFBundleDisplayName and the App Store listing.

    static var weeklyReminderTitle: String {
        localized(ar: "أنا و طفلي - أسبوع جديد", en: "My Baby & I - a new week")
    }
    static var weeklyReminderBody: String {
        localized(
            ar: "لقد بدأ طفلك اسبوعا جديدا من عامه الاول",
            en: "Your baby has started a new week of their first year"
        )
    }
    static var weeklyReminderSetting: String {
        localized(ar: "تنبيه أسبوع جديد", en: "New week reminder")
    }

    // MARK: - Community
    //
    // Arabic copy matches the Android app's res/values/strings.xml so the two
    // read identically for a user who has both installed.

    static var community: String { localized(ar: "مجتمعي", en: "Community") }

    // Auth
    static var signIn: String { localized(ar: "تسجيل الدخول", en: "Sign in") }
    static var register: String { localized(ar: "تسجيل", en: "Register") }
    static var signOut: String { localized(ar: "تسجيل الخروج", en: "Sign out") }
    static var fieldName: String { localized(ar: "الإسم", en: "Name") }
    static var fieldEmail: String { localized(ar: "البريد الإلكتروني", en: "Email") }
    static var fieldPassword: String { localized(ar: "كلمة السر", en: "Password") }
    static var forgotPassword: String { localized(ar: "نسيت كلمة السر", en: "Forgot password") }
    static var resetPassword: String {
        localized(ar: "إسترجاع كلمة السر", en: "Reset password")
    }
    static var resetEmailSent: String {
        localized(
            ar: "تم إرسال رابط تجديد كلمة المرور إلى بريدك الإلكتروني",
            en: "A password reset link has been sent to your email"
        )
    }
    static var signInRequired: String {
        localized(ar: "الرجاء تسجيل الدخول", en: "Please sign in first")
    }
    static var noAccountYet: String {
        localized(ar: "ليس لديك حساب؟ سجّلي الآن", en: "No account yet? Register")
    }
    static var haveAccount: String {
        localized(ar: "لديك حساب؟ تسجيل الدخول", en: "Have an account? Sign in")
    }
    static var sharedAccountNote: String {
        localized(
            ar: "إذا كنت تستخدمين تطبيق دليل حملي، يمكنك الدخول بنفس الحساب",
            en: "If you use My Pregnancy Guide, sign in with the same account"
        )
    }

    // Feed
    static var newPost: String { localized(ar: "نشر", en: "Post") }
    static var writeSomething: String {
        localized(ar: "شاركينا ما يجول في خاطرك...", en: "Share what's on your mind...")
    }
    static var addImage: String { localized(ar: "إضافة صورة", en: "Add image") }
    static var anonymous: String { localized(ar: "مجهولة", en: "Anonymous") }
    static var postAnonymously: String {
        localized(
            ar: "لا أرغب بإظهار إسمي في هذا المنشور",
            en: "Don't show my name on this post"
        )
    }
    /// PT parity: anonymous commenters get a stable pseudonym - the anonymous
    /// label plus the last four characters of their uid - so two anonymous
    /// people in the same thread stay distinguishable, while the Cloud
    /// Function's prefix check still treats them as anonymous.
    static func anonymousName(uid: String) -> String {
        anonymous + " " + String(uid.suffix(4)).uppercased()
    }
    static var blockUser: String {
        localized(ar: "حظر هذا المستخدم", en: "Block this user")
    }
    static var blockUserConfirm: String {
        localized(
            ar: "لن تظهر لكِ منشورات وتعليقات هذا المستخدم بعد الآن.",
            en: "You will no longer see this user's posts or comments."
        )
    }
    static var block: String { localized(ar: "حظر", en: "Block") }
    static var blockedUsers: String {
        localized(ar: "المستخدمون المحظورون", en: "Blocked users")
    }
    static var unblock: String { localized(ar: "إلغاء الحظر", en: "Unblock") }
    static var noBlockedUsers: String {
        localized(ar: "لا يوجد مستخدمون محظورون", en: "No blocked users")
    }

    static var commentAnonymously: String {
        localized(ar: "لا أرغب بإظهار إسمي", en: "Don't show my name")
    }
    static var comments: String { localized(ar: "التعليقات", en: "Comments") }
    static var addComment: String { localized(ar: "إضافة تعليق", en: "Add comment") }
    static var commentHint: String { localized(ar: "شاركينا بتعليق...", en: "Add a comment...") }
    static var awaitingApproval: String {
        localized(ar: "الرجاء إنتظار موافقة الأدمن", en: "Awaiting admin approval")
    }
    static var emptyFeed: String {
        localized(ar: "لا توجد منشورات بعد", en: "No posts yet")
    }
    static var search: String { localized(ar: "بحث", en: "Search") }
    static var textRequired: String {
        localized(ar: "الرجاء إضافة النص", en: "Please add some text")
    }
    static var somethingWentWrong: String {
        localized(ar: "حدث خطأ ما، الرجاء المحاولة لاحقاً", en: "Something went wrong, try again later")
    }
    static var retry: String { localized(ar: "إعادة المحاولة", en: "Retry") }
    static var cancel: String { localized(ar: "إلغاء", en: "Cancel") }

    // MARK: - Post / comment actions
    // Arabic wording matches the Android app's strings.xml.

    static var edit: String { localized(ar: "تعديل", en: "Edit") }
    static var delete: String { localized(ar: "حذف", en: "Delete") }
    static var save: String { localized(ar: "حفظ", en: "Save") }
    static var report: String { localized(ar: "إبلاغ", en: "Report") }
    static var reply: String { localized(ar: "رد", en: "Reply") }
    static var replyHint: String { localized(ar: "اكتبي ردك...", en: "Write your reply...") }
    static var more: String { localized(ar: "المزيد", en: "More") }

    static var deletePostConfirm: String {
        localized(ar: "سيتم حذف المنشور، هل أنت متأكد؟", en: "This post will be deleted. Are you sure?")
    }
    static var deleteCommentConfirm: String {
        localized(ar: "سيتم حذف التعليق، هل أنت متأكد؟", en: "This comment will be deleted. Are you sure?")
    }
    static var deletedSuccessfully: String {
        localized(ar: "تم الحذف بنجاح", en: "Deleted successfully")
    }
    static var reportConfirm: String {
        localized(ar: "سيتم الإبلاغ عن هذا المنشور", en: "This post will be reported")
    }
    static var reportSent: String {
        localized(ar: "تم الإبلاغ، شكراً لك", en: "Reported — thank you")
    }
    static var editPost: String { localized(ar: "تعديل المنشور", en: "Edit post") }
    static var editComment: String { localized(ar: "تعديل التعليق", en: "Edit comment") }
    static var follow: String { localized(ar: "متابعة", en: "Follow") }
    static var following: String { localized(ar: "أتابعها", en: "Following") }
    static var followers: String { localized(ar: "المتابعون", en: "Followers") }
    static var profile: String { localized(ar: "الملف الشخصي", en: "Profile") }
    static var myPosts: String { localized(ar: "منشوراتي", en: "My posts") }
    static var noneYet: String { localized(ar: "لا يوجد بعد", en: "None yet") }
    static var close: String { localized(ar: "إغلاق", en: "Close") }

    /// Shown under a reply to say who it addresses.
    static func replyingTo(_ name: String) -> String {
        localized(ar: "رداً على \(name)", en: "Replying to \(name)")
    }

    // MARK: - Vaccines (Android: vax_* in res/values/strings.xml)

    static var vaxTitle: String {
        localized(ar: "جدول التطعيمات", en: "Vaccine schedule")
    }
    static var vaxCountry: String { localized(ar: "الدولة", en: "Country") }
    static var vaxChangeCountry: String { localized(ar: "تغيير", en: "Change") }
    static var vaxPickCountry: String {
        localized(ar: "اختاري الدولة", en: "Choose your country")
    }
    static var vaxCountryPurpose: String {
        localized(
            ar: "لعرض جدول التطعيمات المناسب لطفلكِ",
            en: "So we can show the right vaccine schedule for your baby"
        )
    }
    static var vaxSearchCountry: String {
        localized(ar: "ابحثي عن دولة…", en: "Search for a country…")
    }
    static var vaxSelectedCountry: String {
        localized(ar: "المختارة", en: "Selected")
    }

    /// Home card.
    static var vaxEntry: String { localized(ar: "مطاعيم طفلك", en: "Your baby's vaccines") }
    static var vaxNewBadge: String { localized(ar: "جديد", en: "NEW") }
    static var vaxCardHint: String {
        localized(ar: "اضغطي لعرض الجدول وتسجيل ما تم", en: "Tap to view and tick off doses")
    }

    static var vaxDueNow: String { localized(ar: "حان موعده", en: "Due now") }
    /// Home-card prefix before a vaccine name ("حان موعد: اسم"), where the row
    /// subtitle above stands alone and so carries the pronoun.
    static var vaxDueLabel: String { localized(ar: "حان موعد", en: "Due") }
    static var vaxNextDose: String {
        localized(ar: "التطعيم القادم", en: "Next vaccine")
    }
    static var vaxAllDone: String {
        localized(ar: "اكتملت التطعيمات", en: "All vaccines done")
    }
    static var vaxCustomRow: String { localized(ar: "مخصص", en: "Custom") }
    static var vaxAdd: String { localized(ar: "إضافة مطعوم", en: "Add a vaccine") }
    static var vaxEditVaccine: String {
        localized(ar: "تعديل المطعوم", en: "Edit vaccine")
    }
    static var vaxNameHint: String { localized(ar: "اسم التطعيم", en: "Vaccine name") }
    static var vaxAgeHint: String {
        localized(
            ar: "العمر (مثال: شهر 2 ، أسبوع 6 ، عند الولادة)",
            en: "Age (e.g. month 2, week 6, at birth)"
        )
    }
    static var vaxDeleteTitle: String { localized(ar: "حذف التطعيم", en: "Delete vaccine") }
    static func vaxDeleteMessage(_ name: String) -> String {
        localized(
            ar: "هل تريدين حذف \"\(name)\" من الجدول؟",
            en: "Remove \"\(name)\" from the schedule?"
        )
    }
    static var vaxLongPressHint: String {
        localized(
            ar: "اضغطي مطوّلاً على أي تطعيم للتعديل أو الحذف",
            en: "Press and hold a vaccine to edit or delete it"
        )
    }
    static var vaxEditDate: String { localized(ar: "تعديل", en: "Edit") }
    static var vaxDateTitle: String {
        localized(ar: "تاريخ أخذ التطعيم", en: "Date the dose was given")
    }

    /// "جرعة 2" - only shown for multi-dose vaccines.
    static func doseNumber(_ round: Int) -> String {
        localized(ar: "جرعة \(String.number(round))", en: "dose \(round)")
    }

    /// "3 / 12  تطعيم مكتمل"
    static func vaxProgress(done: Int, total: Int) -> String {
        let counts = "\(String.number(done)) / \(String.number(total))"
        return localized(ar: "\(counts)  تطعيم مكتمل", en: "\(counts) doses complete")
    }

    // MARK: - Onboarding steps

    static var onboardingWelcomeTitle: String {
        localized(ar: "أهلاً بكِ في أنا و طفلي", en: "Welcome to My Baby & I")
    }
    static var onboardingWelcomeBody: String {
        localized(
            ar: "تابعي مهارات طفلك، وجدول تطعيماته، ونموّه أسبوعاً بأسبوع.",
            en: "Follow your baby's milestones, vaccine schedule, and week-by-week growth."
        )
    }
    static var onboardingBirthDateTitle: String {
        localized(ar: "تاريخ ميلاد طفلك", en: "Your baby's birth date")
    }
    static var onboardingTapToChangeDate: String {
        localized(ar: "اضغطي لتغيير التاريخ", en: "Tap to change the date")
    }
    static var next: String { localized(ar: "التالي", en: "Next") }
    static var previous: String { localized(ar: "السابق", en: "Back") }
    static var done: String { localized(ar: "تم", en: "Done") }
}
