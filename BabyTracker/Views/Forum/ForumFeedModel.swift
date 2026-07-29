//
//  ForumFeedModel.swift
//  BabyTracker
//
//  Paging state for the community feed.
//

import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
final class ForumFeedModel: ObservableObject {
    @Published private(set) var posts: [ForumPost] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?

    /// Search results replace the feed while a query is active; the feed is
    /// kept so clearing the query restores it without another fetch.
    @Published var query = ""
    @Published private(set) var isSearching = false

    private var cursor: DocumentSnapshot?
    private var hasMore = true
    private let store: ForumStore

    init(store: ForumStore = .shared) {
        self.store = store
    }

    var displayedPosts: [ForumPost] { posts }

    // MARK: - Feed

    func loadFirstPage() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let page = try await store.feed()
            posts = page.posts
            cursor = page.cursor
            hasMore = page.hasMore
        } catch {
            errorMessage = L.somethingWentWrong
        }
    }

    /// Called when the last visible row appears.
    func loadMoreIfNeeded(currentItem: ForumPost) async {
        guard !isSearching,
              hasMore,
              !isLoadingMore,
              currentItem.docId == posts.last?.docId else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await store.feed(after: cursor)
            // A page can arrive empty even with more to come, because
            // unapproved posts are filtered client-side - so trust the cursor,
            // not the count.
            posts.append(contentsOf: page.posts)
            cursor = page.cursor
            hasMore = page.hasMore
        } catch {
            errorMessage = L.somethingWentWrong
        }
    }

    // MARK: - Search

    func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await clearSearch()
            return
        }

        isSearching = true
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            posts = try await store.search(trimmed)
        } catch {
            errorMessage = L.somethingWentWrong
        }
    }

    func clearSearch() async {
        query = ""
        isSearching = false
        await loadFirstPage()
    }

    // MARK: - Moderation

    func delete(_ post: ForumPost) async {
        guard let docId = post.docId else { return }
        do {
            try await store.deletePost(postId: docId)
            posts.removeAll { $0.docId == docId }
        } catch {
            errorMessage = L.somethingWentWrong
        }
    }

    func report(_ post: ForumPost) async {
        guard let docId = post.docId else { return }
        try? await store.reportPost(postId: docId)
    }

    // MARK: - Reactions

    /// Optimistic like toggle - the row reflects the tap immediately and rolls
    /// back if the write fails.
    func toggleLike(on post: ForumPost, uid: String) async {
        guard let docId = post.docId,
              let index = posts.firstIndex(where: { $0.docId == docId }) else { return }

        let wasLiked = posts[index].array.contains(uid)
        apply(liked: !wasLiked, uid: uid, at: index)

        do {
            try await store.setLike(postId: docId, liked: !wasLiked)
        } catch {
            apply(liked: wasLiked, uid: uid, at: index)
            errorMessage = L.somethingWentWrong
        }
    }

    private func apply(liked: Bool, uid: String, at index: Int) {
        if liked {
            if !posts[index].array.contains(uid) { posts[index].array.append(uid) }
        } else {
            posts[index].array.removeAll { $0 == uid }
        }
    }
}
