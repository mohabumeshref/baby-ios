//
//  BlockList.swift
//  ForumKit
//
//  Users this device has blocked.
//
//  App Review guideline 1.2 requires an app with user-generated content to let
//  people block abusive users, not only report them. Reporting existed; this is
//  the other half.
//
//  Deliberately device-local rather than a Firestore collection. The forum
//  schema and its security rules are shared with the pregnancy-tracker app and
//  the Android app, and adding a collection means editing rules that all three
//  depend on. What the guideline actually asks for is that the blocking user
//  stops seeing the blocked user's content, and local state delivers that
//  immediately, offline, with no cross-app risk. The trade-off is that blocks
//  don't follow the account to another device.
//

import Foundation
import Combine

@MainActor
public final class BlockList: ObservableObject {
    public static let shared = BlockList()

    private static let key = "blocked_uids"

    @Published public private(set) var blocked: Set<String> = []

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: Self.key) ?? []
        self.blocked = Set(stored)
    }

    public func isBlocked(_ uid: String?) -> Bool {
        guard let uid, !uid.isEmpty else { return false }
        return blocked.contains(uid)
    }

    public func block(_ uid: String) {
        guard !uid.isEmpty else { return }
        blocked.insert(uid)
        persist()
    }

    public func unblock(_ uid: String) {
        blocked.remove(uid)
        persist()
    }

    private func persist() {
        defaults.set(Array(blocked), forKey: Self.key)
    }
}
