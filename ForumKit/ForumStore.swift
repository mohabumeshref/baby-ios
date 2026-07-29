//
//  ForumStore.swift
//  ForumKit
//
//  Every Firestore read and write the forum performs.
//
//  In pt-ios this logic is spread through ForumVC, PostDetailVC and NewPostVC,
//  interleaved with view code. Isolating it here is the point of the port: the
//  schema contract lives in one auditable place, and the UI layer can be
//  rewritten without risking the shared data.
//
//  IMPORTANT: this type never sends a push notification. Forum pushes are
//  produced by Cloud Functions triggered on the writes below - creating an
//  answer IS the notification. See firebase/functions/index.js in pt-ios.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

public enum ForumError: Error {
    case notSignedIn
    case postNotFound
    /// Attempted to edit or delete content belonging to someone else.
    case notAuthor
    /// Firebase was never configured - see ForumKit.isConfigured.
    case notConfigured
}

/// One page of feed results plus the cursor needed to fetch the next.
public struct ForumPage {
    public let posts: [ForumPost]
    /// Pass back as `after:` to continue. Nil when the feed is exhausted.
    public let cursor: DocumentSnapshot?
    public var hasMore: Bool { cursor != nil }
}

public final class ForumStore {
    public static let shared = ForumStore()

    // Resolved on demand, never in init. `Firestore.firestore()` raises if
    // FirebaseApp.configure() has not run, and this type is constructed during
    // SwiftUI scene setup - evaluating it eagerly crashed the app before its
    // first frame whenever GoogleService-Info.plist was absent.
    private var db: Firestore { Firestore.firestore() }

    public var currentUid: String? {
        guard ForumKit.isConfigured else { return nil }
        return Auth.auth().currentUser?.uid
    }

    public init() {}

    private func requireConfigured() throws {
        guard ForumKit.isConfigured else { throw ForumError.notConfigured }
    }

    private var postsRef: CollectionReference {
        db.collection(ForumKit.Collection.posts)
    }

    // MARK: - Feed

    /// The shared feed, newest first.
    ///
    /// `status == true` is filtered CLIENT-side, matching pt-ios: combining it
    /// with the timestamp ordering in the query would require a composite
    /// index that does not exist on the project. The trade-off is that a page
    /// can come back partly empty when unapproved posts are in range, which is
    /// why `hasMore` follows the cursor rather than the filtered count.
    public func feed(pageSize: Int = 10, after cursor: DocumentSnapshot? = nil) async throws -> ForumPage {
        try requireConfigured()
        var query: Query = postsRef
            .order(by: ForumKit.Field.timestamp, descending: true)
            .limit(to: pageSize)

        if let cursor {
            query = query.start(afterDocument: cursor)
        }

        let snapshot = try await query.getDocuments()
        return ForumPage(
            posts: decodeApproved(snapshot.documents),
            cursor: snapshot.documents.count < pageSize ? nil : snapshot.documents.last
        )
    }

    /// A single post by id. Used by the detail screen, including when opened
    /// from a notification tap where the post was never in the feed.
    public func post(id: String) async throws -> ForumPost {
        try requireConfigured()
        let document = try await postsRef.document(id).getDocument()
        guard document.exists, var post = try? document.data(as: ForumPost.self) else {
            throw ForumError.postNotFound
        }
        post.docId = document.documentID
        return post
    }

    /// Posts written by one user (their profile / "منشوراتي").
    /// Includes their unapproved posts - the author should see their own.
    public func posts(byUser uid: String, pageSize: Int = 20) async throws -> [ForumPost] {
        try requireConfigured()
        let snapshot = try await postsRef
            .whereField(ForumKit.Field.uid, isEqualTo: uid)
            .order(by: ForumKit.Field.timestamp, descending: true)
            .limit(to: pageSize)
            .getDocuments()

        return snapshot.documents.compactMap(decode)
    }

    /// Keyword search, same query shape as Android's `searchPosts`.
    /// Results are ranked client-side by token overlap, then recency.
    public func search(_ text: String, limit: Int = 25) async throws -> [ForumPost] {
        try requireConfigured()
        let tokens = KeywordHelper.forQuery(text)
        guard !tokens.isEmpty else { return [] }

        let snapshot = try await postsRef
            .whereField(ForumKit.Field.keywords, arrayContainsAny: tokens)
            .limit(to: limit)
            .getDocuments()

        return decodeApproved(snapshot.documents)
            .sorted {
                let a = KeywordHelper.overlap($0.keywords, tokens)
                let b = KeywordHelper.overlap($1.keywords, tokens)
                if a != b { return a > b }
                return $0.timestamp.dateValue() > $1.timestamp.dateValue()
            }
    }

    // MARK: - Answers

    /// Live answers for a post, oldest first. Returns a registration the caller
    /// must retain and remove.
    public func observeAnswers(
        postId: String,
        onChange: @escaping ([ForumAnswer]) -> Void
    ) -> ListenerRegistration {
        // Can't throw here without changing every call site, so hand back an
        // inert registration instead. The caller removes it as normal.
        guard ForumKit.isConfigured else { return InertListener() }

        return postsRef.document(postId)
            .collection(ForumKit.Collection.answers)
            .order(by: ForumKit.Field.timestamp, descending: false)
            .addSnapshotListener { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                onChange(documents.compactMap { document in
                    guard var answer = try? document.data(as: ForumAnswer.self) else { return nil }
                    answer.id = document.documentID
                    return answer
                })
            }
    }

    // MARK: - Writing

    /// Creates a post and returns its document id.
    ///
    /// `notificationarray` seeds with the author plus anyone mentioned, so the
    /// Cloud Function notifies them about later answers. `keywords` must be
    /// written here - a post without them is invisible to search on every app.
    @discardableResult
    public func createPost(
        text: String,
        imageUrl: String?,
        personName: String?,
        personImage: String?,
        autoApprove: Bool,
        mentions: [Mention]?
    ) async throws -> String {
        try requireConfigured()
        guard let uid = currentUid else { throw ForumError.notSignedIn }

        let mentionedUids = MentionHelper.mentionedUids(mentions, excluding: uid)
        let post = ForumPost(
            uid: uid,
            description: text,
            imageUrl: imageUrl,
            personName: personName,
            personImage: personImage,
            status: autoApprove,
            timestamp: Timestamp(date: Date()),
            source: ForumKit.postSource,
            array: [],
            notificationarray: [uid] + mentionedUids,
            mentions: (mentions?.isEmpty ?? true) ? nil : mentions,
            keywords: KeywordHelper.forDocument(text)
        )

        let ref = postsRef.document()
        try ref.setData(from: post)
        return ref.documentID
    }

    /// Adds an answer, then registers the author for future notifications on
    /// the post. Both writes matter: the first triggers `onAnswerCreated` for
    /// everyone already in `notificationarray`, the second means this author is
    /// included next time.
    public func addAnswer(
        postId: String,
        text: String,
        imageUrl: String? = nil,
        personName: String?,
        personImage: String?,
        mentions: [Mention]? = nil
    ) async throws {
        try requireConfigured()
        guard let uid = currentUid else { throw ForumError.notSignedIn }

        let answer = ForumAnswer(
            uid: uid,
            answer: text,
            image: imageUrl,
            personImage: personImage,
            personName: personName,
            timestamp: Timestamp(date: Date()),
            mentions: (mentions?.isEmpty ?? true) ? nil : mentions
        )

        let postRef = postsRef.document(postId)
        try postRef.collection(ForumKit.Collection.answers).document().setData(from: answer)

        try await postRef.updateData([
            ForumKit.Field.notificationArray: FieldValue.arrayUnion([uid]),
            ForumKit.Field.answers: FieldValue.increment(Int64(1)),
        ])
    }

    /// Appends a reply into an answer's own `answers` array. This shape is what
    /// the `onReplyAdded` Cloud Function watches - it compares the array length
    /// before and after the update - so replies must NOT become documents.
    ///
    /// The dictionary is written key-by-key rather than encoded from
    /// `ForumAnswer`, because the stored shape carries two fields the model
    /// does not: a generated `id`, and `type: 2` which is how pt-ios
    /// distinguishes a reply from a top-level comment when it flattens them
    /// into rows. Encoding the struct would silently drop both and pt-ios would
    /// render our replies wrongly.
    @discardableResult
    public func addReply(
        postId: String,
        answerId: String,
        text: String,
        personName: String?,
        personImage: String?,
        imageUrl: String? = nil,
        replyToName: String? = nil,
        mentions: [Mention]? = nil
    ) async throws -> String {
        try requireConfigured()
        guard let uid = currentUid else { throw ForumError.notSignedIn }

        let replyId = UUID().uuidString
        var reply: [String: Any] = [
            "id": replyId,
            "uid": uid,
            "answer": text,
            "image": imageUrl ?? "",
            "personImage": personImage ?? "",
            "personName": personName ?? "",
            "timestamp": Timestamp(date: Date()),
            "parentAnswerId": answerId,
            "type": 2,
        ]
        if let replyToName, !replyToName.isEmpty {
            reply["replyToName"] = replyToName
        }
        if let mentions, !mentions.isEmpty {
            reply["mentions"] = mentions.map {
                ["uid": $0.uid, "name": $0.name, "start": $0.start, "length": $0.length] as [String: Any]
            }
        }

        let postRef = postsRef.document(postId)
        try await postRef.collection(ForumKit.Collection.answers).document(answerId)
            .updateData([ForumKit.Field.answers: FieldValue.arrayUnion([reply])])

        // Replies count toward the post's comment total, same as pt-ios.
        try await postRef.updateData([
            ForumKit.Field.answers: FieldValue.increment(Int64(1)),
            ForumKit.Field.notificationArray: FieldValue.arrayUnion([uid]),
        ])

        return replyId
    }

    // MARK: - Editing and moderation

    /// Edits a post's text. `keywords` MUST be recomputed - leaving the old
    /// tokens behind makes the post findable by words it no longer contains and
    /// invisible under its new ones, on all three apps.
    public func updatePost(postId: String, text: String, imageUrl: String?) async throws {
        try requireConfigured()
        guard let uid = currentUid else { throw ForumError.notSignedIn }

        let post = try await post(id: postId)
        guard post.uid == uid else { throw ForumError.notAuthor }

        var data: [String: Any] = [
            "description": text,
            ForumKit.Field.keywords: KeywordHelper.forDocument(text),
        ]
        // Only touch the image when one is supplied; passing nil must not wipe
        // an existing attachment the user didn't intend to remove.
        if let imageUrl { data["imageUrl"] = imageUrl }

        try await postsRef.document(postId).updateData(data)
    }

    /// Deletes a post. Answers live in a subcollection and are NOT removed by
    /// this - Firestore doesn't cascade. They become orphaned, which matches
    /// what the Android app does today.
    public func deletePost(postId: String) async throws {
        try requireConfigured()
        guard let uid = currentUid else { throw ForumError.notSignedIn }

        let post = try await post(id: postId)
        guard post.uid == uid else { throw ForumError.notAuthor }

        try await postsRef.document(postId).delete()
    }

    /// Reports a post for moderation.
    ///
    /// Schema quirk inherited from Android: the document id is the POST id, and
    /// the post id is also written into the `uid` field. That means a second
    /// reporter overwrites the first - one report doc per post. Kept as-is so
    /// whatever reads these keeps working; `reportedBy` is added alongside so a
    /// moderator can at least see who raised it.
    public func reportPost(postId: String) async throws {
        try requireConfigured()
        guard let uid = currentUid else { throw ForumError.notSignedIn }

        try await db.collection(ForumKit.Collection.reports).document(postId).setData([
            "answer": "REPORT",
            "uid": postId,
            "image": "",
            "personName": "",
            "personImage": "",
            "timestamp": Timestamp(date: Date()),
            "source": ForumKit.postSource,
            "reportedBy": uid,
        ])
    }

    /// Edits an answer's text. Matches Android, which updates only `answer`.
    public func updateAnswer(postId: String, answerId: String, text: String) async throws {
        try requireConfigured()
        guard currentUid != nil else { throw ForumError.notSignedIn }

        try await postsRef.document(postId)
            .collection(ForumKit.Collection.answers).document(answerId)
            .updateData(["answer": text])
    }

    /// Deletes an answer and corrects the post's denormalised comment count.
    ///
    /// The decrement is `1 + replies`, not 1: replies live inside the deleted
    /// answer's `answers` array and each one incremented the post total when it
    /// was written, so removing the parent removes them too. pt-ios does the
    /// same. Decrementing by 1 would leave the count permanently inflated.
    public func deleteAnswer(postId: String, answerId: String, replyCount: Int = 0) async throws {
        try requireConfigured()
        guard currentUid != nil else { throw ForumError.notSignedIn }

        try await postsRef.document(postId)
            .collection(ForumKit.Collection.answers).document(answerId).delete()

        try await postsRef.document(postId).updateData([
            ForumKit.Field.answers: FieldValue.increment(Int64(-(1 + replyCount)))
        ])
    }

    // MARK: - Reactions

    /// Likes are stored as the uid list in `array`; `likes` is a denormalised
    /// count kept in step with it.
    public func setLike(postId: String, liked: Bool) async throws {
        try requireConfigured()
        guard let uid = currentUid else { throw ForumError.notSignedIn }

        try await postsRef.document(postId).updateData([
            ForumKit.Field.likedBy: liked
                ? FieldValue.arrayUnion([uid])
                : FieldValue.arrayRemove([uid]),
            ForumKit.Field.likes: FieldValue.increment(Int64(liked ? 1 : -1)),
        ])
    }

    public func incrementViews(postId: String) async throws {
        try requireConfigured()
        try await postsRef.document(postId).updateData([
            ForumKit.Field.views: FieldValue.increment(Int64(1))
        ])
    }

    // MARK: - Follow

    /// Followers live at `Follow/{authorUid}/Followers/{followerUid}` with the
    /// follower's uid as the document id - that is what `onPostCreated` reads.
    public func setFollowing(authorUid: String, following: Bool) async throws {
        try requireConfigured()
        guard let uid = currentUid else { throw ForumError.notSignedIn }

        let ref = db.collection(ForumKit.Collection.follow)
            .document(authorUid)
            .collection(ForumKit.Collection.followers)
            .document(uid)

        if following {
            try await ref.setData(["since": Timestamp(date: Date())])
        } else {
            try await ref.delete()
        }
    }

    public func isFollowing(authorUid: String) async throws -> Bool {
        try requireConfigured()
        guard let uid = currentUid else { return false }
        let doc = try await db.collection(ForumKit.Collection.follow)
            .document(authorUid)
            .collection(ForumKit.Collection.followers)
            .document(uid)
            .getDocument()
        return doc.exists
    }

    // MARK: - Push token

    /// Writes THIS device's FCM token into the single `User/{uid}.token` slot.
    ///
    /// A merge, never a full write: `setData(from:)` on a whole user object
    /// would null out name/email/image for accounts where those are unset.
    ///
    /// KNOWN LIMITATION, shared with pt-ios and Android: one slot per account.
    /// A user signed into two of these apps on one device has two FCM tokens
    /// (they are per bundle id) competing for it, and whichever app launched
    /// last wins - the other silently receives nothing. Fixing it means moving
    /// to a `User/{uid}/tokens/{token}` subcollection in all three apps plus
    /// the Cloud Functions.
    public func saveFCMToken(_ token: String) async throws {
        try requireConfigured()
        guard let uid = currentUid, !token.isEmpty else { return }
        try await db.collection(ForumKit.Collection.users).document(uid)
            .setData([ForumKit.Field.token: token], merge: true)
    }

    // MARK: - Decoding

    private func decode(_ document: QueryDocumentSnapshot) -> ForumPost? {
        guard var post = try? document.data(as: ForumPost.self) else { return nil }
        post.docId = document.documentID
        return post
    }

    private func decodeApproved(_ documents: [QueryDocumentSnapshot]) -> [ForumPost] {
        documents.compactMap(decode).filter(\.status)
    }
}

/// A ListenerRegistration that was never attached to anything. Returned when
/// Firebase is unconfigured so callers can hold and remove it as usual.
private final class InertListener: NSObject, ListenerRegistration {
    func remove() {}
}
