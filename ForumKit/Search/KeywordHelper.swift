//
//  KeywordHelper.swift
//  ForumKit
//
//  Keyword search tokenizer for forum posts.
//
//  ⚠️ BYTE-IDENTICAL PORT. This mirrors Android's KeywordHelper.kt, the Node
//  backfill script, and pt-ios/Utils/Keywords.swift. Every app writes the
//  `keywords` array on the SAME Post documents and queries them with
//  array-contains-any, so any behavioural change here - a different stopword,
//  a different normalisation rule, a different cap - makes posts written by
//  one app stop matching another app's searches. Change it in all four places
//  or not at all.
//

import Foundation

public enum KeywordHelper {
    /// Cap on tokens stored per document.
    public static let maxDocKeywords = 30
    /// Firestore's array-contains-any limit.
    public static let maxQueryKeywords = 10

    private static let stopwords: Set<String> = [
        // Arabic (already in normalized form)
        "في", "من", "علي", "عن", "الي", "ما", "هل", "انا", "انت", "انتي",
        "هي", "هو", "مع", "او", "ان", "لا", "نعم", "كل", "يا", "اذا",
        "لكن", "بعد", "قبل", "عند", "كيف", "ماذا", "لماذا", "متي", "اين",
        "هذا", "هذه", "ذلك", "التي", "الذي", "شي", "شيء", "ايضا", "جدا",
        // Latin
        "the", "and", "for", "with", "what", "how", "are", "you", "this", "that",
    ]

    /// \p{L} ∪ \p{Nd} - anything else splits tokens (same as Android's SPLITTER).
    private static let tokenScalars = CharacterSet.letters.union(.decimalDigits)

    /// U+064B–U+0652 Arabic diacritics, plus U+0640 tatweel.
    private static let diacritics = CharacterSet(
        charactersIn: Unicode.Scalar(0x064B)!...Unicode.Scalar(0x0652)!
    ).union(CharacterSet(charactersIn: "\u{0640}"))

    private static func normalize(_ word: String) -> String {
        var scalars: [Unicode.Scalar] = []
        for scalar in word.lowercased().unicodeScalars {
            if diacritics.contains(scalar) { continue }
            switch scalar {
            case "أ", "إ", "آ", "ٱ": scalars.append("ا")
            case "ة": scalars.append("ه")
            case "ى": scalars.append("ي")
            case "ؤ": scalars.append("و")
            case "ئ": scalars.append("ي")
            default: scalars.append(scalar)
            }
        }
        var out = String(String.UnicodeScalarView(scalars))
        // Strip the most common attached prefixes (once each, order matters).
        if out.hasPrefix("و") && out.count > 3 { out.removeFirst(1) }
        if out.hasPrefix("لل") && out.count > 3 { out.removeFirst(2) }
        if out.hasPrefix("ال") && out.count > 3 { out.removeFirst(2) }
        return out
    }

    private static func tokens(_ text: String, cap: Int) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        var current = ""

        func flush() {
            guard !current.isEmpty else { return }
            let raw = current
            current = ""
            let token = normalize(raw)
            guard token.count >= 2,
                  !stopwords.contains(token),
                  !token.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }),
                  !seen.contains(token) else { return }
            seen.insert(token)
            out.append(token)
        }

        for scalar in text.unicodeScalars {
            if tokenScalars.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else {
                flush()
                if out.count >= cap { return out }
            }
        }
        flush()
        return Array(out.prefix(cap))
    }

    /// Keywords stored on a Post document.
    public static func forDocument(_ text: String) -> [String] {
        tokens(text, cap: maxDocKeywords)
    }

    /// Keywords used to query (array-contains-any allows at most 10).
    public static func forQuery(_ text: String) -> [String] {
        tokens(text, cap: maxQueryKeywords)
    }

    /// Client-side relevance: how many of the query tokens the post shares.
    public static func overlap(_ postKeywords: [String]?, _ queryTokens: [String]) -> Int {
        guard let postKeywords else { return 0 }
        return queryTokens.filter { postKeywords.contains($0) }.count
    }
}
