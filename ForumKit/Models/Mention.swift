//
//  Mention.swift
//  ForumKit
//
//  @mention metadata attached to a post description or an answer.
//
//  SCHEMA CONTRACT: `{uid, name, start, length}` with offsets in UTF-16 code
//  units, matching Android and pt-ios. UTF-16 matters - Arabic text and emoji
//  make Swift's Character offsets disagree with the Java/Kotlin string indices
//  the other apps write, so ranges must be converted through NSString, never
//  through String.Index arithmetic.
//

import Foundation

public struct Mention: Codable, Hashable {
    public let uid: String
    public let name: String
    /// UTF-16 offset of the mention within the plain text.
    public let start: Int
    /// Length in UTF-16 code units.
    public let length: Int

    public init(uid: String, name: String, start: Int, length: Int) {
        self.uid = uid
        self.name = name
        self.start = start
        self.length = length
    }

    /// The range this mention covers, or nil if it falls outside `text`
    /// (possible when a post was edited by another client).
    public func range(in text: String) -> NSRange? {
        let bounds = NSRange(location: 0, length: (text as NSString).length)
        let range = NSRange(location: start, length: length)
        guard range.location >= 0,
              range.length > 0,
              NSMaxRange(range) <= NSMaxRange(bounds) else { return nil }
        return range
    }
}

public enum MentionHelper {
    /// Cap enforced by both platforms and by the chat Cloud Function.
    public static let maxMentions = 5

    /// Placeholder uid used by seeded/sample content; never a real recipient.
    private static let sampleUid = "adummyuid987"

    /// Distinct mentioned uids, excluding self, blanks, and sample data.
    /// Ported from pt-ios/Utils/Mentions.swift.
    public static func mentionedUids(
        _ mentions: [Mention]?,
        excluding selfUid: String?
    ) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for mention in mentions ?? [] {
            let uid = mention.uid
            guard !uid.isEmpty,
                  uid != selfUid,
                  uid != sampleUid,
                  !seen.contains(uid) else { continue }
            seen.insert(uid)
            out.append(uid)
        }
        return out
    }
}
