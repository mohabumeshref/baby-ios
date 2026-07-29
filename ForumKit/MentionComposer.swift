//
//  MentionComposer.swift
//  ForumKit
//
//  Turns typing into @mention metadata.
//
//  Ported from pt-ios's Mentions.swift (the model half - the UIKit dropdown and
//  tap-handling don't carry over to SwiftUI). Three responsibilities:
//
//    1. Detect an in-progress "@query" at the caret
//    2. Rank candidates: thread participants first, then people you follow,
//       then a global name search
//    3. On insert, rewrite the text and recompute every mention's UTF-16 offset
//
//  Offsets are the fragile part. They are UTF-16 code-unit positions because
//  that is what Android and pt-ios write, and Arabic plus emoji make Swift's
//  Character offsets disagree. Every mutation here goes through NSString so the
//  numbers stay compatible.
//

import Foundation

public struct MentionCandidate: Identifiable, Equatable {
    public let uid: String
    public let name: String
    public let image: String

    public var id: String { uid }

    public init(uid: String, name: String, image: String) {
        self.uid = uid
        self.name = name
        self.image = image
    }

    public init(user: ForumUser) {
        self.uid = user.uid ?? ""
        self.name = user.name ?? ""
        self.image = user.image_url ?? ""
    }
}

public enum MentionComposer {

    /// Minimum characters after "@" before a global search is worth issuing.
    public static let globalSearchFloor = 2

    // MARK: - Detecting the query at the caret

    /// The "@query" being typed immediately before `caret`, or nil.
    ///
    /// Returns the query text and the range of "@query" itself, so an insert
    /// can replace exactly that span. A space ends a mention, so "@sara m" is
    /// no longer an active query.
    public static func activeQuery(in text: String, caret: Int) -> (query: String, range: NSRange)? {
        let ns = text as NSString
        guard caret >= 0, caret <= ns.length else { return nil }

        var index = caret - 1
        while index >= 0 {
            let ch = ns.substring(with: NSRange(location: index, length: 1))

            if ch == "@" {
                let start = index
                let length = caret - start
                let query = ns.substring(with: NSRange(location: start + 1, length: length - 1))
                // An "@" glued to the end of a word ("email@host") isn't a mention.
                if start > 0 {
                    let before = ns.substring(with: NSRange(location: start - 1, length: 1))
                    if !before.isEmpty, before.rangeOfCharacter(from: .whitespacesAndNewlines) == nil {
                        return nil
                    }
                }
                return (query, NSRange(location: start, length: length))
            }

            // Whitespace or newline ends the candidate span.
            if ch.rangeOfCharacter(from: .whitespacesAndNewlines) != nil { return nil }
            index -= 1
        }
        return nil
    }

    // MARK: - Ranking

    /// Case-insensitive contains filter, excluding self, blanks and duplicates.
    public static func filter(
        _ pool: [MentionCandidate],
        query: String,
        excluding selfUid: String?
    ) -> [MentionCandidate] {
        let q = query.trimmingCharacters(in: .whitespaces)
        var seen = Set<String>()
        var out: [MentionCandidate] = []

        for candidate in pool {
            guard !candidate.uid.isEmpty,
                  candidate.uid != selfUid,
                  !candidate.name.isEmpty,
                  !seen.contains(candidate.uid) else { continue }

            if q.isEmpty || candidate.name.range(of: q, options: .caseInsensitive) != nil {
                seen.insert(candidate.uid)
                out.append(candidate)
            }
        }
        return out
    }

    /// Participants first, then follows, then global results - the order
    /// pt-ios uses. Someone already in the thread is far more likely to be who
    /// you meant than a name-match from the whole user base.
    public static func merge(
        participants: [MentionCandidate],
        follows: [MentionCandidate],
        global: [MentionCandidate],
        excluding selfUid: String?,
        limit: Int = 8
    ) -> [MentionCandidate] {
        var seen = Set<String>()
        var out: [MentionCandidate] = []

        for group in [participants, follows, global] {
            for candidate in group {
                guard !candidate.uid.isEmpty,
                      candidate.uid != selfUid,
                      !candidate.name.isEmpty,
                      seen.insert(candidate.uid).inserted else { continue }
                out.append(candidate)
                if out.count >= limit { return out }
            }
        }
        return out
    }

    // MARK: - Inserting

    /// Replaces the active "@query" with "@Name " and returns the new text plus
    /// the updated mention list.
    ///
    /// Existing mentions after the edit point shift by the length delta; ones
    /// that overlap the replaced span are dropped. Recomputing rather than
    /// patching would be safer still, but the stored name is the only anchor we
    /// have, and duplicate names would then attach to the wrong span.
    public static func insert(
        candidate: MentionCandidate,
        into text: String,
        replacing range: NSRange,
        existing: [Mention]
    ) -> (text: String, mentions: [Mention], caret: Int) {
        let ns = NSMutableString(string: text)
        let replacement = "@\(candidate.name) "
        let replacementLength = (replacement as NSString).length

        ns.replaceCharacters(in: range, with: replacement)

        let delta = replacementLength - range.length
        var mentions: [Mention] = []

        for mention in existing {
            let mRange = NSRange(location: mention.start, length: mention.length)

            // Dropped: the edit overwrote it.
            if NSIntersectionRange(mRange, range).length > 0 { continue }

            if mention.start >= NSMaxRange(range) {
                mentions.append(Mention(
                    uid: mention.uid,
                    name: mention.name,
                    start: mention.start + delta,
                    length: mention.length
                ))
            } else {
                mentions.append(mention)
            }
        }

        // The new mention covers "@Name" but not the trailing space.
        mentions.append(Mention(
            uid: candidate.uid,
            name: candidate.name,
            start: range.location,
            length: replacementLength - 1
        ))

        return (ns as String, mentions.sorted { $0.start < $1.start }, range.location + replacementLength)
    }

    /// Drops mentions whose stored span no longer reads "@Name" - the user
    /// edited over them. Call before saving so nothing stale is written.
    public static func validated(_ mentions: [Mention], against text: String) -> [Mention] {
        let ns = text as NSString
        return mentions.filter { mention in
            let range = NSRange(location: mention.start, length: mention.length)
            guard range.location >= 0, NSMaxRange(range) <= ns.length else { return false }
            return ns.substring(with: range) == "@" + mention.name
        }
    }
}
