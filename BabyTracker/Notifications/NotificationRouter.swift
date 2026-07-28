//
//  NotificationRouter.swift
//  BabyTracker
//
//  Where a tapped push notification takes the user.
//
//  Payload keys are defined by the shared Cloud Functions
//  (firebase/functions/index.js in pt-ios) and are already consumed by the
//  Android baby app and the pregnancy tracker. They are the contract:
//
//    post_id           -> the post to open
//    post_image_url    -> image on that post, may be empty
//    type              -> "answer" | "post"
//    Ans_notification  -> "notificationAns" | "notificationChatReply"
//
//  `Ans_notification` is a legacy discriminator kept for Android's tray
//  handling; iOS routes on `type` and `post_id` but must not rely on the
//  legacy key being absent.
//

import Foundation
import SwiftUI

/// A destination derived from a notification payload.
enum NotificationDestination: Equatable {
    case post(id: String, imageUrl: String?)

    init?(userInfo: [AnyHashable: Any]) {
        guard let postId = userInfo["post_id"] as? String, !postId.isEmpty else {
            return nil
        }
        let image = (userInfo["post_image_url"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        self = .post(id: postId, imageUrl: image)
    }
}

/// Holds the destination of a tapped notification until the UI is ready to
/// consume it.
///
/// A tap can arrive before SwiftUI has anything on screen - from a cold launch,
/// the notification is delivered during `didFinishLaunching`. Storing it here
/// rather than navigating immediately means the forum can pick it up whenever
/// it appears, and the pending value survives the gap.
@MainActor
final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()

    /// Set when a notification is tapped; cleared once handled.
    @Published var pending: NotificationDestination?

    private init() {}

    func handle(userInfo: [AnyHashable: Any]) {
        guard let destination = NotificationDestination(userInfo: userInfo) else { return }
        pending = destination
    }

    /// Takes the pending destination, clearing it so it isn't handled twice.
    func consume() -> NotificationDestination? {
        defer { pending = nil }
        return pending
    }
}
