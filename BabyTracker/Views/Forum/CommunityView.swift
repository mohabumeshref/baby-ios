//
//  CommunityView.swift
//  BabyTracker
//
//  The community tab: auth gate, then the shared feed.
//
//  The body is split into small pieces on purpose. Written as one chain it
//  grew past what Swift's type checker will solve in reasonable time and the
//  build failed with "unable to type-check this expression" - which points at
//  the whole body rather than the offending line, so it is worth keeping the
//  parts small.
//

import SwiftUI

struct CommunityView: View {
    @EnvironmentObject private var auth: ForumAuth
    @EnvironmentObject private var router: NotificationRouter
    @StateObject private var model = ForumFeedModel()

    @State private var showingCompose = false
    @State private var editingPost: ForumPost?
    @State private var postPendingReport: ForumPost?
    @State private var fullScreenImage: String?

    /// `NavigationPath`, not `[String]`: this stack carries two destination
    /// types - a post id and a ProfileRoute - and a typed array can only hold
    /// one of them.
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            gatedContent
                .navigationTitle(L.community)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .navigationDestination(for: String.self) { PostDetailView(postId: $0) }
                .navigationDestination(for: ProfileRoute.self) { route in
                    ProfileView(
                        uid: route.uid,
                        initialName: route.name,
                        initialImage: route.image
                    )
                }
        }
        .modifier(CommunitySheets(
            showingCompose: $showingCompose,
            editingPost: $editingPost,
            fullScreenImage: $fullScreenImage,
            onPosted: { Task { await model.loadFirstPage() } }
        ))
        .modifier(CommunityDialogs(
            postPendingReport: $postPendingReport,
            onReport: { post in Task { await model.report(post) } }
        ))
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

    @ViewBuilder
    private var gatedContent: some View {
        if auth.isSignedIn {
            feed
        } else {
            AuthView()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if auth.isSignedIn {
            ToolbarItem(placement: .primaryAction) {
                Button { showingCompose = true } label: {
                    Image(systemName: "square.and.pencil")
                }
                .tint(Warm.brand)
            }
            // Own profile / my posts / sign out. Without this there is no
            // route to your own profile at all.
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
                        row(for: post)
                    }

                    // Fixed-height footer. Inserting and removing a spinner
                    // changes the content height mid-scroll, which shows up as
                    // a judder when paging during a fast scroll - the slot is
                    // permanent and only its contents toggle.
                    Color.clear
                        .frame(height: 44)
                        .overlay {
                            if model.isLoadingMore {
                                ProgressView().tint(Warm.brand)
                            }
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

    private func row(for post: ForumPost) -> some View {
        let isMine = post.uid == auth.uid

        return Button {
            guard let docId = post.docId else { return }
            // Opening a post is the interstitial moment, as in pt-ios. AdGate
            // decides whether one actually shows; navigation happens either way
            // and is never blocked waiting on an ad.
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
                onEdit: isMine ? { editingPost = post } : nil,
                onDelete: isMine ? { Task { await model.delete(post) } } : nil,
                onReport: isMine ? nil : { postPendingReport = post }
            )
        }
        .buttonStyle(.plain)
        .task { await model.loadMoreIfNeeded(currentItem: post) }
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

// MARK: - Presentation, split out to keep the body type-checkable

private struct CommunitySheets: ViewModifier {
    @Binding var showingCompose: Bool
    @Binding var editingPost: ForumPost?
    @Binding var fullScreenImage: String?
    let onPosted: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingCompose) {
                ComposePostView(onPosted: onPosted)
            }
            .sheet(item: $editingPost) { post in
                ComposePostView(editing: post, onPosted: onPosted)
            }
            .fullScreenCover(item: Binding(
                get: { fullScreenImage.map(IdentifiableURL.init) },
                set: { fullScreenImage = $0?.value }
            )) { item in
                FullScreenImageView(url: item.value)
            }
    }
}

private struct CommunityDialogs: ViewModifier {
    @Binding var postPendingReport: ForumPost?
    let onReport: (ForumPost) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                L.reportConfirm,
                // A real binding, not .constant() - the constant form is what
                // made these dialogs render in the wrong place on device.
                isPresented: Binding(
                    get: { postPendingReport != nil },
                    set: { if !$0 { postPendingReport = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(L.report, role: .destructive) {
                    if let post = postPendingReport { onReport(post) }
                    postPendingReport = nil
                }
                Button(L.cancel, role: .cancel) { postPendingReport = nil }
            }
    }
}
