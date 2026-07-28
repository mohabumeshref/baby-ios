//
//  ForumUser.swift
//  ForumKit
//
//  The shared `User` document.
//
//  SCHEMA CONTRACT - ported from pt-ios/Models/User.swift. Note `image_url` is
//  snake_case while every other field is not; that inconsistency is on disk and
//  read by three apps, so it stays.
//

import Foundation

public struct ForumUser: Codable, Identifiable, Equatable {
    public let uid: String?
    public let name: String?
    public let email: String?
    public let image_url: String?

    /// The single FCM token slot. See ForumStore.saveFCMToken for why one slot
    /// is a problem once more than one of these apps is installed.
    public let token: String?

    public var id: String { uid ?? UUID().uuidString }

    public init(
        uid: String?,
        name: String?,
        email: String?,
        image_url: String?,
        token: String?
    ) {
        self.uid = uid
        self.name = name
        self.email = email
        self.image_url = image_url
        self.token = token
    }

    /// Display name falling back to the anonymous label, so the UI never shows
    /// an empty author.
    public func displayName(anonymousLabel: String) -> String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? anonymousLabel : trimmed
    }
}
