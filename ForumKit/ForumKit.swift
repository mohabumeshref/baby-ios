//
//  ForumKit.swift
//
//  The shared community forum layer.
//
//  The forum is not a feature of this app - it is a feature of the *account*,
//  shared across the Android baby app, the pregnancy tracker, and this app,
//  all backed by the same Firestore collections in the pregnancy-tracker-57bf7
//  project.
//
//  Nothing in this directory may import app code. It compiles into the app
//  target (a separate framework target forced Firebase to link dynamically and
//  broke the build - see project.yml), but the isolation is enforced by
//  convention so lifting it into a shared Swift package stays mechanical.
//
//  Schema contract (must not drift):
//    Post/{postId}                     - the feed
//    Post/{postId}/Answers/{answerId}  - answers; replies live in an `answers` array
//    User/{uid}.token                  - single FCM token slot, read by Cloud Functions
//    Follow/{authorUid}/Followers/{followerUid}
//

import Foundation
import FirebaseCore

public enum ForumKit {

    /// Whether Firebase has been configured.
    ///
    /// `GoogleService-Info.plist` is not in the repo, so CI and the screenshot
    /// job run without it and `FirebaseApp.configure()` is skipped. Touching
    /// Firestore or Auth in that state raises FIRIllegalStateException and
    /// kills the process, so every entry point into this layer checks here
    /// first. In a real build the plist is present and this is always true.
    public static var isConfigured: Bool { FirebaseApp.app() != nil }

    /// Identifies which app created a post. The Android baby app writes 2 and
    /// the pregnancy tracker's iOS app writes 3; this app takes the next value.
    /// The feed query is deliberately unfiltered - all apps see all posts.
    public static let postSource = 4

    // MARK: - Collection names
    //
    // Centralised so a typo can't silently write to a parallel collection that
    // the other apps never read.

    public enum Collection {
        public static let posts = "Post"
        public static let answers = "Answers"
        public static let users = "User"
        public static let follow = "Follow"
        public static let followers = "Followers"
        public static let reports = "Reports"
    }

    public enum Field {
        public static let timestamp = "timestamp"
        public static let status = "status"
        public static let uid = "uid"
        public static let keywords = "keywords"
        /// uids that liked the post.
        public static let likedBy = "array"
        public static let likes = "likes"
        public static let views = "views"
        public static let answers = "answers"
        public static let notificationArray = "notificationarray"
        /// The single FCM token slot on a User document.
        public static let token = "token"
    }
}
