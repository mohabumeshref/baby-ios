//
//  PostDetailView.swift
//  BabyTracker
//
//  A post with its answers, and the box to add one.
//
//  Adding an answer is what triggers the push to everyone in the post's
//  notificationarray - the Cloud Function fires on the write. There is no
//  send-notification call anywhere in this file, and there must not be.
//

import SwiftUI
import FirebaseFirestore

struct PostDetailView: View {
    let postId: String

    @EnvironmentObject private var auth: ForumAuth
    @StateObject private var model = PostDetailModel()

    @State private var draft = ""
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let post = model.post {
                        PostCard(
                            post: post,
                            currentUid: auth.uid,
                            onLike: {
                                Task { await model.toggleLike(uid: auth.uid) }
                            }
                        )
                    } else if model.isLoading {
                        ProgressView().tint(Warm.brand).padding(.top, 40)
                            .frame(maxWidth: .infinity)
                    }

                    if !model.answers.isEmpty {
                        Text(L.comments)
                            .font(WarmFont.heading)
                            .foregroundStyle(Warm.ink)
                            .padding(.top, 4)

                        ForEach(model.answers) { answer in
                            AnswerRow(answer: answer)
                        }
                    }
                }
                .padding(.horizontal, WarmMetrics.screenPadding)
                .padding(.vertical, 12)
            }

            composer
        }
        .warmBackground()
        .navigationTitle(L.community)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.start(postId: postId) }
        .onDisappear { model.stop() }
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(spacing: 8) {
            TextField(L.commentHint, text: $draft, axis: .vertical)
                .font(WarmFont.body)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: WarmMetrics.chipRadius, style: .continuous)
                        .fill(Warm.chipOff)
                )

            Button {
                Task { await send() }
            } label: {
                ZStack {
                    if isSending {
                        ProgressView().tint(.white)
                    } else {
                        // An explicit arrow, not chevron - SF arrows mirror in
                        // RTL, which is what we want for a directional "send".
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(
                    Circle().fill(
                        canSend ? AnyShapeStyle(Warm.brandGradient)
                                : AnyShapeStyle(Warm.muted.opacity(0.4))
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, WarmMetrics.screenPadding)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSending = true
        defer { isSending = false }

        await model.addAnswer(
            text: text,
            personName: auth.profile?.name,
            personImage: auth.profile?.image_url
        )
        draft = ""
    }
}

// MARK: - Answer row

private struct AnswerRow: View {
    let answer: ForumAnswer

    var body: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(answer.personName ?? L.anonymous)
                    .font(WarmFont.heading)
                    .foregroundStyle(Warm.ink)

                Text(answer.answer)
                    .font(WarmFont.body)
                    .foregroundStyle(Warm.bodyInk)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Replies live in the answer's own `answers` array, not as
                // separate documents - that shape is what onReplyAdded watches.
                if let replies = answer.answers, !replies.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(replies.enumerated()), id: \.offset) { _, reply in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reply.personName ?? L.anonymous)
                                    .font(WarmFont.caption)
                                    .foregroundStyle(Warm.mutedSub)
                                Text(reply.answer)
                                    .font(WarmFont.caption)
                                    .foregroundStyle(Warm.bodyInk)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Warm.chipOff)
                            )
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Model

@MainActor
final class PostDetailModel: ObservableObject {
    @Published private(set) var post: ForumPost?
    @Published private(set) var answers: [ForumAnswer] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var postId: String?
    private var listener: ListenerRegistration?
    private let store = ForumStore.shared

    func start(postId: String) async {
        guard self.postId == nil else { return }
        self.postId = postId
        isLoading = true

        // Answers stream live so a reply arriving while the screen is open
        // appears without a manual refresh.
        listener = store.observeAnswers(postId: postId) { [weak self] answers in
            Task { @MainActor in self?.answers = answers }
        }

        do {
            post = try await store.post(id: postId)
            try? await store.incrementViews(postId: postId)
        } catch {
            errorMessage = L.somethingWentWrong
        }
        isLoading = false
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    func addAnswer(text: String, personName: String?, personImage: String?) async {
        guard let postId else { return }
        do {
            try await store.addAnswer(
                postId: postId,
                text: text,
                personName: personName,
                personImage: personImage
            )
        } catch {
            errorMessage = L.somethingWentWrong
        }
    }

    func toggleLike(uid: String?) async {
        guard let postId, let uid, var current = post else { return }
        let wasLiked = current.array.contains(uid)

        if wasLiked {
            current.array.removeAll { $0 == uid }
        } else {
            current.array.append(uid)
        }
        post = current

        do {
            try await store.setLike(postId: postId, liked: !wasLiked)
        } catch {
            // Roll back the optimistic change.
            if wasLiked { current.array.append(uid) } else { current.array.removeAll { $0 == uid } }
            post = current
            errorMessage = L.somethingWentWrong
        }
    }
}
