//
//  ForumPost.swift
//  ForumKit
//
//  The shared `Post` document.
//
//  SCHEMA CONTRACT: these field names are written and read by three apps -
//  the Android baby app, the pregnancy tracker (iOS + Android), and this one -
//  against the same Firestore collection in project pregnancy-tracker-57bf7.
//  Renaming or retyping any property here silently breaks interoperability for
//  the other apps. The shape is a direct port of pt-ios/Models/Post.swift and
//  baby-android/model/Post.java.
//

import Foundation
import FirebaseFirestore

public struct ForumPost: Codable, Identifiable {
    /// Firestore document id. Not part of the stored document.
    public var docId: String?

    /// Author's Firebase Auth uid.
    public let uid: String
    public let description: String
    public let imageUrl: String?
    public let personName: String?
    public let personImage: String?

    /// Approval flag. `false` means awaiting admin approval and the post must
    /// not appear in the feed. Controlled by the `autoApprovePosts` Remote
    /// Config key at creation time.
    public var status: Bool

    public let timestamp: Timestamp
    public let views: Int
    public let likes: Int
    public let answers: Int

    /// Which app created the post: 2 = Android baby, 3 = pregnancy tracker iOS,
    /// 4 = this app. Recorded for analytics only - the feed query is
    /// deliberately unfiltered so all three apps share one conversation.
    public var source: Int?

    /// uids that liked the post. Named `array` in the stored document; the
    /// name is meaningless but it is the on-disk contract.
    public var array: [String]

    /// uids to notify when a new answer arrives. The Cloud Function
    /// `onAnswerCreated` reads exactly this field.
    public let notificationarray: [String]

    /// @mention metadata over `description`, in UTF-16 offsets. Absent on
    /// posts written before mentions shipped.
    public var mentions: [Mention]?

    /// Normalized search tokens. Both platforms write this on create and edit;
    /// older posts were backfilled server-side.
    public var keywords: [String]?

    public var id: String { docId ?? UUID().uuidString }

    public init(
        docId: String? = nil,
        uid: String,
        description: String,
        imageUrl: String?,
        personName: String?,
        personImage: String?,
        status: Bool,
        timestamp: Timestamp,
        views: Int = 0,
        likes: Int = 0,
        answers: Int = 0,
        source: Int? = ForumKit.postSource,
        array: [String] = [],
        notificationarray: [String],
        mentions: [Mention]? = nil,
        keywords: [String]? = nil
    ) {
        self.docId = docId
        self.uid = uid
        self.description = description
        self.imageUrl = imageUrl
        self.personName = personName
        self.personImage = personImage
        self.status = status
        self.timestamp = timestamp
        self.views = views
        self.likes = likes
        self.answers = answers
        self.source = source
        self.array = array
        self.notificationarray = notificationarray
        self.mentions = mentions
        self.keywords = keywords
    }

    /// `docId` is a client-side handle, never part of the stored document.
    private enum CodingKeys: String, CodingKey {
        case uid, description, imageUrl, personName, personImage
        case status, timestamp, views, likes, answers, source
        case array, notificationarray, mentions, keywords
    }
}

public extension ForumPost {
    /// The Cloud Functions treat these author names as anonymous and suppress
    /// follower pushes for them. Kept in sync with `ANONYMOUS_NAMES` in
    /// firebase/functions/index.js.
    static let anonymousNames = ["مجهولة", "مجهول", "Anonymous", "Anónimo"]

    var isAnonymous: Bool {
        let name = (personName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty || Self.anonymousNames.contains { name.hasPrefix($0) }
    }

    func isLiked(by uid: String) -> Bool { array.contains(uid) }
}
