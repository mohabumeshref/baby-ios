//
//  ForumAuth.swift
//  ForumKit
//
//  Firebase Auth for the shared forum.
//
//  Accounts are shared across all three apps in this Firebase project: a
//  parent who registered in the pregnancy tracker signs into this app with the
//  same credentials and keeps their posts, follows and history. So this must
//  read and write `User` documents exactly as the other apps do.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
public final class ForumAuth: ObservableObject {
    public static let shared = ForumAuth()

    private let db: Firestore
    private var handle: AuthStateDidChangeListenerHandle?

    /// The signed-in Firebase user, or nil.
    @Published public private(set) var user: User?
    /// The corresponding Firestore profile, loaded lazily after sign-in.
    @Published public private(set) var profile: ForumUser?

    public var isSignedIn: Bool { user != nil }
    public var uid: String? { user?.uid }

    public init(db: Firestore = .firestore()) {
        self.db = db
    }

    /// Starts observing auth state. Safe to call more than once.
    public func start() {
        guard handle == nil else { return }
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                if user != nil {
                    await self?.loadProfile()
                } else {
                    self?.profile = nil
                }
            }
        }
    }

    // MARK: - Sign in / register

    public func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        user = result.user
        await loadProfile()
    }

    /// Creates the account, sets the display name, then writes the `User`
    /// document. The order matters: the document stores the display name, so
    /// the profile change has to commit first or the document records nil.
    public func register(name: String, email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)

        let change = result.user.createProfileChangeRequest()
        change.displayName = name
        try await change.commitChanges()

        user = result.user
        try await writeProfile(
            ForumUser(
                uid: result.user.uid,
                name: name,
                email: email,
                image_url: nil,
                token: nil
            )
        )
        await loadProfile()
    }

    public func signOut() throws {
        try Auth.auth().signOut()
        user = nil
        profile = nil
    }

    public func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    /// Deletes the account. The user's posts are deliberately left in place -
    /// removing them would tear holes in conversations the other apps' users
    /// are still reading.
    public func deleteAccount() async throws {
        guard let user else { throw ForumError.notSignedIn }
        try await db.collection(ForumKit.Collection.users).document(user.uid).delete()
        try await user.delete()
        self.user = nil
        self.profile = nil
    }

    // MARK: - Profile

    private func loadProfile() async {
        guard let uid = user?.uid else { return }
        let snapshot = try? await db.collection(ForumKit.Collection.users)
            .document(uid).getDocument()
        profile = try? snapshot?.data(as: ForumUser.self)
    }

    /// Full write, used only at registration. Everywhere else must merge -
    /// a full write here would null out fields the other apps set.
    private func writeProfile(_ profile: ForumUser) async throws {
        guard let uid = profile.uid else { return }
        try db.collection(ForumKit.Collection.users).document(uid)
            .setData(from: profile, merge: true)
    }
}
