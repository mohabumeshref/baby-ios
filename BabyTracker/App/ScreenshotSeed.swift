//
//  ScreenshotSeed.swift
//  BabyTracker
//
//  DEBUG-only launch-argument hooks used by .github/workflows/screenshots.yml.
//
//  The screenshot job has no way to tap through the UI, so it drives the app
//  with launch arguments instead: seed a birth date to get past onboarding,
//  and pick which tab opens. UserDefaults reads `-key value` launch arguments
//  automatically (the "argument domain"), so simctl can pass them directly.
//
//  The whole file compiles to nothing in Release - these must never be
//  reachable in a shipped build.
//

import Foundation
import FirebaseFirestore

enum ScreenshotSeed {

    #if DEBUG
    /// `-seed_baby_days_ago 90` - pretend the baby was born N days ago.
    static var birthDate: Date? {
        let days = UserDefaults.standard.integer(forKey: "seed_baby_days_ago")
        guard days > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: -days, to: Date())
    }

    /// `-seed_tab 1` - which tab to open (0 Home, 1 Weeks, 2 Community).
    static var tab: Int? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "seed_tab") != nil else { return nil }
        return defaults.integer(forKey: "seed_tab")
    }

    /// `-seed_demo 1` - App Store screenshot mode.
    ///
    /// Renders the community tab from local sample posts instead of the live
    /// forum, and silences ads and the ATT prompt so neither lands in a store
    /// screenshot. The sample content matters for more than tidiness: the real
    /// feed is other parents' personal posts, and putting those in marketing
    /// material would republish them outside the app they were written for.
    static var isDemo: Bool {
        UserDefaults.standard.bool(forKey: "seed_demo")
    }

    /// `-seed_email x -seed_password y` - signs in automatically so the
    /// screenshot job can capture the real forum feed.
    ///
    /// This exists because the author has no Mac: CI is the only way to see
    /// the app running against live Firebase at all. The credentials come from
    /// GitHub secrets and belong to a throwaway forum account - never a real
    /// user's, and never anything with admin rights.
    ///
    /// DEBUG only. Release builds compile this away entirely, so a shipped app
    /// cannot be made to sign itself in through launch arguments.
    static var credentials: (email: String, password: String)? {
        let defaults = UserDefaults.standard
        guard let email = defaults.string(forKey: "seed_email"),
              let password = defaults.string(forKey: "seed_password"),
              !email.isEmpty, !password.isEmpty else { return nil }
        return (email, password)
    }
    #else
    static var birthDate: Date? { nil }
    static var tab: Int? { nil }
    static var isDemo: Bool { false }
    static var credentials: (email: String, password: String)? { nil }
    #endif
}

#if DEBUG
extension ScreenshotSeed {
    /// Invented posts by invented people, for store screenshots only.
    static var demoPosts: [ForumPost] {
        func post(
            _ id: String,
            _ name: String,
            _ text: String,
            likes: Int,
            answers: Int,
            hoursAgo: Int
        ) -> ForumPost {
            ForumPost(
                docId: id,
                uid: "demo-\(id)",
                description: text,
                imageUrl: nil,
                personName: name,
                personImage: nil,
                status: true,
                timestamp: Timestamp(
                    date: Calendar.current.date(
                        byAdding: .hour, value: -hoursAgo, to: Date()
                    ) ?? Date()
                ),
                views: 0,
                likes: likes,
                answers: answers,
                array: Array(repeating: "demo", count: likes),
                notificationarray: []
            )
        }

        return [
            post("d1", "ريم",
                 "طفلي عمره ٤ أشهر وبدأ يتقلب من بطنه لظهره. متى بدأ أطفالكم بالجلوس؟",
                 likes: 12, answers: 5, hoursAgo: 2),
            post("d2", "مجهولة A1B2",
                 "أول مرة يضحك ابني بصوت عالي اليوم. أجمل شعور بالدنيا ❤️",
                 likes: 34, answers: 8, hoursAgo: 6),
            post("d3", "نور",
                 "نصيحة لكل أم جديدة: نامي وقت ما ينام طفلك، الغسيل بيستنى.",
                 likes: 27, answers: 11, hoursAgo: 20),
            post("d4", "سارة",
                 "بنتي عمرها ٧ شهور وما زالت ما طلعت أسنانها، هل هذا طبيعي؟",
                 likes: 9, answers: 6, hoursAgo: 30),
        ]
    }
}
#endif
