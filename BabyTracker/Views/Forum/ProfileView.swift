//
//  ProfileView.swift
//  BabyTracker
//
//  A user's forum profile: avatar, name, follower counts, and their posts.
//
//  Serves both "my profile" and "someone else's" - the only differences are the
//  follow button (hidden for yourself) and that you can see your own posts that
//  are still awaiting approval.
//

import SwiftUI

struct ProfileView: View {
    let uid: String
    /// Falls back to the loaded profile when not supplied by the caller.
    var initialName: String?
    var initialImage: String?

    @EnvironmentObject private var auth: ForumAuth
    @StateObject private var model = ProfileModel()

    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var fullScreenImage: String?

    private var isMe: Bool { uid == auth.uid }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if !isMe { followButton }
                posts
            }
            .padding(.horizontal, WarmMetrics.screenPadding)
            .padding(.vertical, 16)
        }
        .warmBackground()
        .navigationTitle(model.name ?? initialName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(uid: uid) }
        .sheet(isPresented: $showFollowers) {
            FollowListView(uid: uid, kind: .followers)
        }
        .sheet(isPresented: $showFollowing) {
            FollowListView(uid: uid, kind: .following)
        }
        .fullScreenCover(item: Binding(
            get: { fullScreenImage.map(IdentifiableURL.init) },
            set: { fullScreenImage = $0?.value }
        )) { item in
            FullScreenImageView(url: item.value)
        }
    }

    // MARK: - Header

    private var header: some View {
        WarmCard {
            VStack(spacing: 12) {
                avatar
                Text(model.name ?? initialName ?? L.anonymous)
                    .font(WarmFont.title)
                    .foregroundStyle(Warm.ink)

                HStack(spacing: 28) {
                    countButton(model.followers, L.followers) { showFollowers = true }
                    countButton(model.following, L.following) { showFollowing = true }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var avatar: some View {
        let image = model.image ?? initialImage
        return Group {
            if let image, !image.isEmpty, let url = URL(string: image) {
                AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: {
                    avatarPlaceholder
                }
                .onTapGesture { fullScreenImage = image }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(Circle())
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle().fill(Warm.chipOff)
            Image(systemName: "person.fill")
                .font(.system(size: 32))
                .foregroundStyle(Warm.muted)
        }
    }

    private func countButton(_ value: Int, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(String.number(value))
                    .font(WarmFont.heading)
                    .foregroundStyle(Warm.brand)
                Text(label)
                    .font(WarmFont.caption)
                    .foregroundStyle(Warm.muted)
            }
        }
        .buttonStyle(.plain)
    }

    private var followButton: some View {
        Button {
            Task { await model.toggleFollow() }
        } label: {
            Text(model.isFollowing ? L.following : L.follow)
                .font(WarmFont.heading)
                .foregroundStyle(model.isFollowing ? Warm.brand : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: WarmMetrics.chipRadius, style: .continuous)
                        .fill(model.isFollowing
                              ? AnyShapeStyle(Warm.chipOff)
                              : AnyShapeStyle(Warm.brandGradient))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Posts

    @ViewBuilder
    private var posts: some View {
        if model.isLoading {
            ProgressView().tint(Warm.brand).padding(.top, 30)
        } else if model.posts.isEmpty {
            Text(L.emptyFeed)
                .font(WarmFont.body)
                .foregroundStyle(Warm.mutedSub)
                .padding(.top, 30)
        } else {
            ForEach(model.posts) { post in
                NavigationLink(value: post.docId ?? "") {
                    PostCard(post: post, currentUid: auth.uid, onLike: {})
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Distinguishes a profile push from a post-id push on the same NavigationStack
/// path - both would otherwise be plain Strings and collide.
struct ProfileRoute: Hashable {
    let uid: String
    var name: String?
    var image: String?
}

/// `fullScreenCover(item:)` needs an Identifiable, and String isn't one.
struct IdentifiableURL: Identifiable {
    let value: String
    var id: String { value }
    init(_ value: String) { self.value = value }
}

// MARK: - Model

@MainActor
final class ProfileModel: ObservableObject {
    @Published private(set) var name: String?
    @Published private(set) var image: String?
    @Published private(set) var followers = 0
    @Published private(set) var following = 0
    @Published private(set) var posts: [ForumPost] = []
    @Published private(set) var isFollowing = false
    @Published private(set) var isLoading = false

    private var uid: String?
    private let store = ForumStore.shared

    func load(uid: String) async {
        guard self.uid == nil else { return }
        self.uid = uid
        isLoading = true
        defer { isLoading = false }

        async let profile = try? await store.user(uid: uid)
        async let counts = try? await store.followCounts(uid: uid)
        async let userPosts = try? await store.posts(byUser: uid)
        async let following = try? await store.isFollowing(authorUid: uid)

        if let profile = await profile {
            name = profile.name
            image = profile.image_url
        }
        if let counts = await counts {
            followers = counts.followers
            self.following = counts.following
        }
        posts = await userPosts ?? []
        isFollowing = await following ?? false
    }

    func toggleFollow() async {
        guard let uid else { return }
        let target = !isFollowing
        isFollowing = target   // optimistic
        followers += target ? 1 : -1

        do {
            try await store.setFollowing(authorUid: uid, following: target)
        } catch {
            isFollowing = !target
            followers += target ? -1 : 1
        }
    }
}
