//
//  CommunityView.swift
//  BabyTracker
//
//  The community tab: auth gate, then the shared feed.
//

import SwiftUI

struct CommunityView: View {
    @EnvironmentObject private var auth: ForumAuth
    @EnvironmentObject private var router: NotificationRouter
    @StateObject private var model = ForumFeedModel()

    @State private var showingCompose = false
    @State private var editingPost: ForumPost?
    @State private var postPendingDelete: ForumPost?
    @State private var postPendingReport: ForumPost?
    @State private var fullScreenImage: String?
    @State private var profileUid: String?
    /// Navigation path holding post ids. A path plus
    /// `navigationDestination(for:)` is the iOS 16 form; the `item:` overload
    /// is iOS 17+.
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if auth.isSignedIn {
                    feed
                } else {
                    AuthView()
                }
            }
            .navigationTitle(L.community)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if auth.isSignedIn {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingCompose = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .tint(Warm.brand)
                    }
                    // Own profile / my posts / sign out. Without this there is
                    // no route to your own profile at all.
                    ToolbarItem(placement: .cancellationAction) {
                        Menu {
                            Button {
                                guard let uid = auth.uid else { return }
                                path.append(ProfileRoute(
                                    uid: uid,
                                    name: auth.profile?.name,
                                    image: auth.profile?.image_url
                                ))
                            } label: {
                                Label(L.myPosts, systemImage: "person.crop.circle")
                            }
                            Button(role: .destructive) {
                                try? auth.signOut()
                            } label: {
                                Label(L.signOut, systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                        .tint(Warm.brand)
                    }
                }
            }
            .navigationDestination(for: String.self) { postId in
                PostDetailView(postId: postId)
            }
            .navigationDestination(for: ProfileRoute.self) { route in
                ProfileView(uid: route.uid, initialName: route.name, initialImage: route.image)
            }
        }
        .sheet(isPresented: $showingCompose) {
            ComposePostView { Task { await model.loadFirstPage() } }
        }
        .sheet(item: $editingPost) { post in
            ComposePostView(editing: post) { Task { await model.loadFirstPage() } }
        }
        .fullScreenCover(item: Binding(
            get: { fullScreenImage.map(IdentifiableURL.init) },
            set: { fullScreenImage = $0?.value }
        )) { item in
            FullScreenImageView(url: item.value)
        }
        .confirmationDialog(L.deletePostConfirm,
                            isPresented: .constant(postPendingDelete != nil),
                            titleVisibility: .visible) {
            Button(L.delete, role: .destructive) {
                if let post = postPendingDelete { Task { await model.delete(post) } }
                postPendingDelete = nil
            }
            Button(L.cancel, role: .cancel) { postPendingDelete = nil }
        }
        .confirmationDialog(L.reportConfirm,
                            isPresented: .constant(postPendingReport != nil),
                            titleVisibility: .visible) {
            Button(L.report, role: .destructive) {
                if let post = postPendingReport { Task { await model.report(post) } }
                postPendingReport = nil
            }
            Button(L.cancel, role: .cancel) { postPendingReport = nil }
        }
        .task {
            auth.start()
            if auth.isSignedIn { await model.loadFirstPage() }
            await InterstitialAdManager.shared.preload()
        }
        .onChange(of: auth.isSignedIn) { signedIn in
            guard signedIn else { return }
            Task { await model.loadFirstPage() }
        }
        // A tapped notification stores its destination rather than navigating
        // immediately, because a cold-launch tap arrives before this view
        // exists. Consume whatever is pending once we're on screen.
        .onChange(of: router.pending) { _ in consumePendingNotification() }
        .onAppear { consumePendingNotification() }
    }

    private func consumePendingNotification() {
        guard auth.isSignedIn,
              case let .post(id, _)? = router.consume() else { return }
        path.append(id)
    }

    // MARK: - Feed

    private var feed: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if model.isLoading && model.displayedPosts.isEmpty {
                    ProgressView()
                        .tint(Warm.brand)
                        .padding(.top, 60)
                } else if model.displayedPosts.isEmpty {
                    emptyState
                } else {
                    ForEach(model.displayedPosts) { post in
                        Button {
                            guard let docId = post.docId else { return }
                            // Opening a post is the interstitial moment, as in
                            // pt-ios. AdGate decides whether one actually shows;
                            // navigation happens either way and is never
                            // blocked waiting on an ad.
                            Task { await InterstitialAdManager.shared.showIfAllowed() }
                            path.append(docId)
                        } label: {
                            PostCard(
                                post: post,
                                currentUid: auth.uid,
                                onLike: {
                                    guard let uid = auth.uid else { return }
                                    Task { await model.toggleLike(on: post, uid: uid) }
                                },
                                onTapAuthor: {
                                    path.append(ProfileRoute(
                                        uid: post.uid,
                                        name: post.personName,
                                        image: post.personImage
                                    ))
                                },
                                onTapImage: { fullScreenImage = $0 },
                                onEdit: post.uid == auth.uid ? { editingPost = post } : nil,
                                onDelete: post.uid == auth.uid ? { postPendingDelete = post } : nil,
                                onReport: post.uid == auth.uid ? nil : { postPendingReport = post }
                            )
                        }
                        .buttonStyle(.plain)
                        .task { await model.loadMoreIfNeeded(currentItem: post) }
                    }

                    if model.isLoadingMore {
                        ProgressView().tint(Warm.brand).padding()
                    }
                }
            }
            .padding(.horizontal, WarmMetrics.screenPadding)
            .padding(.vertical, 12)
        }
        .refreshable { await model.loadFirstPage() }
        .searchable(text: $model.query, prompt: L.search)
        .onSubmit(of: .search) { Task { await model.runSearch() } }
        .onChange(of: model.query) { newValue in
            if newValue.isEmpty { Task { await model.clearSearch() } }
        }
        .warmBackground()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(Warm.muted)
            Text(L.emptyFeed)
                .font(WarmFont.body)
                .foregroundStyle(Warm.mutedSub)
        }
        .padding(.top, 60)
    }
}
