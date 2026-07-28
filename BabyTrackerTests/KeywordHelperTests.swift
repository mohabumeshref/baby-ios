//
//  KeywordHelperTests.swift
//  BabyTrackerTests
//
//  Cross-app parity vectors for the search tokenizer.
//
//  Ported from pt-ios/PregnancyTrackerTests/KeywordHelperTests.swift. These
//  pin the behaviour that three apps depend on: if this app tokenizes even
//  slightly differently, posts it writes stop matching searches made from the
//  pregnancy tracker or the Android baby app, and vice versa. A failure here
//  is a data-compatibility bug, not a style problem.
//

import XCTest
import ForumKit

final class KeywordHelperTests: XCTestCase {

    func testSpecVector() {
        // "وألم" → normalize → "والم" → strip "و" → "الم" (len 3, "ال" needs >3 so kept)
        // "الظهر" → "ظهر", "في" stopword, "الشهر" → "شهر", "الخامس" → "خامس"
        XCTAssertEqual(
            KeywordHelper.forDocument("وألم الظهر في الشهر الخامس"),
            ["الم", "ظهر", "شهر", "خامس"]
        )
    }

    func testDiacriticsAndCharMap() {
        // fathatan etc. removed; ة→ه ؛ ى→ي ؛ أ→ا
        XCTAssertEqual(KeywordHelper.forDocument("حَامِلٌ"), ["حامل"])
        XCTAssertEqual(KeywordHelper.forDocument("حكاية"), ["حكايه"])
        XCTAssertEqual(KeywordHelper.forDocument("مستشفى"), ["مستشفي"])
        XCTAssertEqual(KeywordHelper.forDocument("أسبوع"), ["اسبوع"])
    }

    func testPrefixStripOrderAndLengthGuards() {
        XCTAssertEqual(KeywordHelper.forDocument("للحمل"), ["حمل"])   // لل stripped (len 5 > 3)
        XCTAssertEqual(KeywordHelper.forDocument("والحمل"), ["حمل"])  // و then ال
        XCTAssertEqual(KeywordHelper.forDocument("الم"), ["الم"])     // len 3: ال kept
        XCTAssertEqual(KeywordHelper.forDocument("ولد"), ["ولد"])     // len 3: و kept
    }

    func testLatinLowercaseAndStopwords() {
        XCTAssertEqual(
            KeywordHelper.forDocument("The Baby And YOU are Sleeping"),
            ["baby", "sleeping"]
        )
    }

    func testDigitsAndShortTokensDiscarded() {
        XCTAssertEqual(KeywordHelper.forDocument("40 اسبوع 12 a"), ["اسبوع"])
    }

    func testDedupePreservingOrderAndQueryCap() {
        let text = Array(repeating: "حمل ولاده", count: 20).joined(separator: " ")
            + " توأم غثيان صداع دوخه تعب ارق حرقه انتفاخ املاح سكري"
        let query = KeywordHelper.forQuery(text)
        XCTAssertEqual(query.count, 10)                          // array-contains-any cap
        XCTAssertEqual(Array(query.prefix(2)), ["حمل", "ولاده"])  // first-occurrence order
        XCTAssertEqual(Set(query).count, query.count)             // deduped
    }

    func testOverlap() {
        XCTAssertEqual(KeywordHelper.overlap(["حمل", "ظهر", "الم"], ["الم", "راس"]), 1)
        XCTAssertEqual(KeywordHelper.overlap(nil, ["الم"]), 0)
    }

    // MARK: - Baby-app vocabulary
    //
    // The vectors above come from pregnancy content. These cover terms this
    // app's users actually search for, to catch a normalisation rule that
    // happens to be safe for one vocabulary and not the other.

    func testBabyVocabulary() {
        XCTAssertEqual(KeywordHelper.forDocument("الرضاعة الطبيعية"), ["رضاعه", "طبيعيه"])
        XCTAssertEqual(KeywordHelper.forDocument("التسنين"), ["تسنين"])
        XCTAssertEqual(KeywordHelper.forDocument("نوم الطفل"), ["نوم", "طفل"])
    }

    func testDocumentCapIsThirty() {
        let text = (1...60).map { "كلمه\($0)" }.joined(separator: " ")
        XCTAssertEqual(KeywordHelper.forDocument(text).count, KeywordHelper.maxDocKeywords)
    }
}

// MARK: - Mentions

final class MentionHelperTests: XCTestCase {

    func testExcludesSelfBlanksAndDuplicates() {
        let mentions = [
            Mention(uid: "a", name: "A", start: 0, length: 2),
            Mention(uid: "me", name: "Me", start: 3, length: 3),
            Mention(uid: "a", name: "A", start: 7, length: 2),
            Mention(uid: "", name: "", start: 9, length: 1),
        ]
        XCTAssertEqual(MentionHelper.mentionedUids(mentions, excluding: "me"), ["a"])
    }

    func testHandlesNil() {
        XCTAssertEqual(MentionHelper.mentionedUids(nil, excluding: "me"), [])
    }

    /// Offsets are UTF-16, matching Android and pt-ios. Arabic plus an emoji is
    /// the case where Swift's Character count disagrees with UTF-16 length.
    func testRangeUsesUTF16Offsets() {
        let text = "مرحبا 👶 سارة"
        let nsText = text as NSString
        let start = nsText.range(of: "سارة").location
        let mention = Mention(uid: "u", name: "سارة", start: start, length: 4)

        let range = mention.range(in: text)
        XCTAssertNotNil(range)
        XCTAssertEqual(nsText.substring(with: range!), "سارة")
    }

    func testRangeOutsideTextIsRejected() {
        let mention = Mention(uid: "u", name: "x", start: 900, length: 4)
        XCTAssertNil(mention.range(in: "short"))
    }
}
