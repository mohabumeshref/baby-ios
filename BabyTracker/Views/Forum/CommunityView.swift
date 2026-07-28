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
                }
            }
            .navigationDestination(for: String.self) { postId in
                PostDetailView(postId: postId)
            }
        }
        .sheet(isPresented: $showingCompose) {
            ComposePostView { Task { await model.loadFirstPage() } }
        }
        .task {
            auth.start()
            if auth.isSignedIn { await model.loadFirstPage() }
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
                            if let docId = post.docId { path.append(docId) }
                        } label: {
                            PostCard(
                                post: post,
                                currentUid: auth.uid,
                                onLike: {
                                    guard let uid = auth.uid else { return }
                                    Task { await model.toggleLike(on: post, uid: uid) }
                                }
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
