//
//  ForumAnswer.swift
//  ForumKit
//
//  A document in `Post/{postId}/Answers`.
//
//  SCHEMA CONTRACT - see ForumPost. Ported from pt-ios/Models/Comment.swift.
//
//  Note the unusual shape: replies to an answer are NOT their own documents.
//  They are appended into the answer's own `answers` array via arrayUnion,
//  which is what the `onReplyAdded` Cloud Function watches for (it compares
//  array length before and after an update).
//

import Foundation
import FirebaseFirestore

public struct ForumAnswer: Codable, Identifiable {
    /// Firestore document id. Not stored in the document.
    public var id: String?

    /// Replies nested inside this answer.
    public var answers: [ForumAnswer]?

    public let uid: String
    public var answer: String
    public let image: String?
    public let personImage: String?
    public let personName: String?
    public let timestamp: Timestamp

    public var parentAnswerId: String?
    public var type: Int?

    /// Display name of the reply author being addressed. Set only when
    /// replying to another reply; nil for plain answers.
    public var replyToName: String?

    /// @mention metadata over `answer`, in UTF-16 offsets.
    public var mentions: [Mention]?

    public init(
        id: String? = nil,
        answers: [ForumAnswer]? = nil,
        uid: String,
        answer: String,
        image: String? = nil,
        personImage: String? = nil,
        personName: String? = nil,
        timestamp: Timestamp,
        parentAnswerId: String? = nil,
        type: Int? = nil,
        replyToName: String? = nil,
        mentions: [Mention]? = nil
    ) {
        self.id = id
        self.answers = answers
        self.uid = uid
        self.answer = answer
        self.image = image
        self.personImage = personImage
        self.personName = personName
        self.timestamp = timestamp
        self.parentAnswerId = parentAnswerId
        self.type = type
        self.replyToName = replyToName
        self.mentions = mentions
    }

    private enum CodingKeys: String, CodingKey {
        case answers, uid, answer, image, personImage, personName
        case timestamp, parentAnswerId, type, replyToName, mentions
    }
}
