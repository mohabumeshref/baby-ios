//
//  ForumKit.swift
//
//  The shared community forum layer.
//
//  This lives in its own framework target on purpose. The forum is not a
//  feature of this app - it is a feature of the *account*, shared across the
//  Android baby app, the pregnancy tracker, and this app, all backed by the
//  same Firestore collections in the pregnancy-tracker-57bf7 project. Keeping
//  it free of app-specific code means pt-ios can adopt it later rather than
//  the two iOS apps maintaining separate copies of the same schema.
//
//  Schema contract (must not drift):
//    Post/{postId}                     - the feed
//    Post/{postId}/Answers/{answerId}  - answers, with replies in an `answers` array
//    User/{uid}.token                  - single FCM token slot, read by Cloud Functions
//    Follow/{authorUid}/Followers/{followerUid}
//
//  Content is filled in by the ForumKit port task.

import Foundation

public enum ForumKit {
    /// Identifies which app created a post. The Android baby app writes 2 and
    /// the pregnancy tracker's iOS app writes 3; this app takes the next value.
    /// The feed query is deliberately unfiltered - all apps see all posts.
    public static let postSource = 4
}
