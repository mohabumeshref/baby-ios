//
//  MentionComposerTests.swift
//  BabyTrackerTests
//
//  Offset arithmetic for @mentions.
//
//  These matter more than most: mention offsets are UTF-16 positions shared
//  with Android and pt-ios. If they drift, the other apps highlight the wrong
//  words - which looks like a rendering bug in THEIR app, not ours, and nothing
//  about it fails loudly.
//

import XCTest
@testable import BabyTracker

final class MentionComposerTests: XCTestCase {

    // MARK: - Detecting the query

    func testDetectsQueryAtCaret() {
        let text = "مرحبا @سا"
        let ns = text as NSString
        let found = MentionComposer.activeQuery(in: text, caret: ns.length)

        XCTAssertEqual(found?.query, "سا")
        XCTAssertEqual(found?.range.location, ns.range(of: "@").location)
    }

    func testNoQueryAfterSpace() {
        // A completed mention followed by a space is no longer being typed.
        XCTAssertNil(MentionComposer.activeQuery(in: "@سارة ", caret: 6))
    }

    func testIgnoresAtInsideWord() {
        // Email addresses must not open the suggestion list.
        let text = "mail@host"
        XCTAssertNil(MentionComposer.activeQuery(in: text, caret: (text as NSString).length))
    }

    func testEmptyQueryRightAfterAt() {
        let found = MentionComposer.activeQuery(in: "hi @", caret: 4)
        XCTAssertEqual(found?.query, "")
    }

    // MARK: - Ranking

    func testMergeOrdersParticipantsFirstAndDedups() {
        let a = MentionCandidate(uid: "a", name: "Sara", image: "")
        let b = MentionCandidate(uid: "b", name: "Nour", image: "")
        let dupA = MentionCandidate(uid: "a", name: "Sara", image: "")

        let merged = MentionComposer.merge(
            participants: [a],
            follows: [dupA, b],
            global: [],
            excluding: "me"
        )
        XCTAssertEqual(merged.map(\.uid), ["a", "b"])
    }

    func testFilterExcludesSelfAndBlanks() {
        let pool = [
            MentionCandidate(uid: "me", name: "Me", image: ""),
            MentionCandidate(uid: "x", name: "", image: ""),
            MentionCandidate(uid: "s", name: "Sara", image: ""),
        ]
        let filtered = MentionComposer.filter(pool, query: "", excluding: "me")
        XCTAssertEqual(filtered.map(\.uid), ["s"])
    }

    func testFilterIsCaseInsensitive() {
        let pool = [MentionCandidate(uid: "s", name: "Sara", image: "")]
        XCTAssertEqual(MentionComposer.filter(pool, query: "sar", excluding: nil).count, 1)
    }

    // MARK: - Insertion offsets

    func testInsertProducesCorrectOffset() {
        let candidate = MentionCandidate(uid: "u1", name: "سارة", image: "")
        let text = "مرحبا @سا"
        let range = (text as NSString).range(of: "@سا")

        let result = MentionComposer.insert(
            candidate: candidate, into: text, replacing: range, existing: []
        )

        XCTAssertEqual(result.text, "مرحبا @سارة ")
        XCTAssertEqual(result.mentions.count, 1)

        // The recorded span must read back as exactly "@سارة".
        let mention = result.mentions[0]
        let ns = result.text as NSString
        XCTAssertEqual(
            ns.substring(with: NSRange(location: mention.start, length: mention.length)),
            "@سارة"
        )
    }

    /// The case where naive index maths breaks: an emoji is two UTF-16 units.
    func testOffsetsSurviveEmoji() {
        let candidate = MentionCandidate(uid: "u1", name: "Sara", image: "")
        let text = "👶 @Sa"
        let range = (text as NSString).range(of: "@Sa")

        let result = MentionComposer.insert(
            candidate: candidate, into: text, replacing: range, existing: []
        )

        let mention = result.mentions[0]
        let ns = result.text as NSString
        XCTAssertEqual(
            ns.substring(with: NSRange(location: mention.start, length: mention.length)),
            "@Sara"
        )
    }

    func testEarlierMentionsShiftWhenTextGrowsBeforeThem() {
        // "@A" already recorded, then a longer mention inserted before it.
        let text = "@Bo hello @A"
        let ns = text as NSString
        let existing = [Mention(uid: "a", name: "A", start: ns.range(of: "@A").location, length: 2)]

        let candidate = MentionCandidate(uid: "bob", name: "Bobby", image: "")
        let result = MentionComposer.insert(
            candidate: candidate,
            into: text,
            replacing: ns.range(of: "@Bo"),
            existing: existing
        )

        let out = result.text as NSString
        for mention in result.mentions {
            XCTAssertEqual(
                out.substring(with: NSRange(location: mention.start, length: mention.length)),
                "@" + mention.name,
                "mention \(mention.name) drifted"
            )
        }
    }

    func testOverlappedMentionIsDropped() {
        let text = "@Sara"
        let existing = [Mention(uid: "s", name: "Sara", start: 0, length: 5)]
        let candidate = MentionCandidate(uid: "n", name: "Nour", image: "")

        let result = MentionComposer.insert(
            candidate: candidate,
            into: text,
            replacing: NSRange(location: 0, length: 5),
            existing: existing
        )

        XCTAssertEqual(result.mentions.map(\.uid), ["n"])
    }

    // MARK: - Validation before save

    func testValidatedDropsStaleMentions() {
        let text = "hello world"
        let stale = [Mention(uid: "s", name: "Sara", start: 0, length: 5)]
        XCTAssertTrue(MentionComposer.validated(stale, against: text).isEmpty)
    }

    func testValidatedKeepsIntactMentions() {
        let text = "hi @Sara"
        let ns = text as NSString
        let good = [Mention(uid: "s", name: "Sara",
                            start: ns.range(of: "@Sara").location, length: 5)]
        XCTAssertEqual(MentionComposer.validated(good, against: text).count, 1)
    }
}
