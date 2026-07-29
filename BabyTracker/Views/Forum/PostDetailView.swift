//
//  PostDetailView.swift
//  BabyTracker
//
//  A post with its answers, replies, and the box to add one.
//
//  Adding an answer is what triggers the push to everyone in the post's
//  notificationarray - the Cloud Function fires on the write. There is no
//  send-notification call anywhere in this file, and there must not be.
//

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct PostDetailView: View {
    let postId: String

    @EnvironmentObject private var auth: ForumAuth
    @StateObject private var model = PostDetailModel()
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    @State private var draftMentions: [Mention] = []
    @State private var isSending = false
    @State private var commentPickerItem: PhotosPickerItem?
    @State private var commentImageData: Data?
    @FocusState private var composerFocused: Bool

    /// Non-nil while composing a reply to a specific answer.
    @State private var replyTarget: ForumAnswer?

    // Post actions
    @State private var showDeletePostConfirm = false
    @State private var showReportConfirm = false
    @State private var showEditPost = false

    // Answer actions
    @State private var answerPendingDelete: ForumAnswer?
    @State private var answerBeingEdited: ForumAnswer?
    @State private var editDraft = ""

    @State private var toast: String?

    private var isMyPost: Bool {
        guard let uid = auth.uid, let post = model.post else { return false }
        return post.uid == uid
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let post = model.post {
                        PostCard(
                            post: post,
                            currentUid: auth.uid,
                            onLike: { Task { await model.toggleLike(uid: auth.uid) } }
                        )
                    } else if model.isLoading {
                        ProgressView().tint(Warm.brand)
                            .padding(.top, 40)
                            .frame(maxWidth: .infinity)
                    }

                    if !model.answers.isEmpty {
                        Text(L.comments)
                            .font(WarmFont.heading)
                            .foregroundStyle(Warm.ink)
                            .padding(.top, 4)

                        ForEach(model.answers) { answer in
                            AnswerRow(
                                answer: answer,
                                isMine: answer.uid == auth.uid,
                                onReply: {
                                    replyTarget = answer
                                    composerFocused = true
                                },
                                onEdit: {
                                    answerBeingEdited = answer
                                    editDraft = answer.answer
                                },
                                onDelete: { answerPendingDelete = answer }
                            )
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if isMyPost {
                        Button { showEditPost = true } label: {
                            Label(L.edit, systemImage: "pencil")
                        }
                        Button(role: .destructive) { showDeletePostConfirm = true } label: {
                            Label(L.delete, systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive) { showReportConfirm = true } label: {
                            Label(L.report, systemImage: "flag")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .tint(Warm.brand)
            }
        }
        .task { await model.start(postId: postId) }
        .onDisappear { model.stop() }

        // MARK: Post actions

        .confirmationDialog(L.deletePostConfirm, isPresented: $showDeletePostConfirm,
                            titleVisibility: .visible) {
            Button(L.delete, role: .destructive) {
                Task {
                    if await model.deletePost() { dismiss() }
                }
            }
            Button(L.cancel, role: .cancel) {}
        }
        .confirmationDialog(L.reportConfirm, isPresented: $showReportConfirm,
                            titleVisibility: .visible) {
            Button(L.report, role: .destructive) {
                Task {
                    await model.report()
                    toast = L.reportSent
                }
            }
            Button(L.cancel, role: .cancel) {}
        }
        .sheet(isPresented: $showEditPost) {
            if let post = model.post {
                ComposePostView(editing: post) {
                    Task { await model.reloadPost() }
                }
            }
        }

        // MARK: Answer actions

        .confirmationDialog(L.deleteCommentConfirm, isPresented: .constant(answerPendingDelete != nil),
                            titleVisibility: .visible) {
            Button(L.delete, role: .destructive) {
                if let answer = answerPendingDelete {
                    Task { await model.deleteAnswer(answer) }
                }
                answerPendingDelete = nil
            }
            Button(L.cancel, role: .cancel) { answerPendingDelete = nil }
        }
        .alert(L.editComment, isPresented: .constant(answerBeingEdited != nil)) {
            TextField(L.commentHint, text: $editDraft)
            Button(L.save) {
                if let answer = answerBeingEdited {
                    Task { await model.updateAnswer(answer, text: editDraft) }
                }
                answerBeingEdited = nil
            }
            Button(L.cancel, role: .cancel) { answerBeingEdited = nil }
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(WarmFont.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Warm.brand))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        withAnimation { self.toast = nil }
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: toast)
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 6) {
            // Reply context, so it's obvious the next message is a reply and
            // not a new top-level comment.
            if let replyTarget {
                HStack(spacing: 6) {
                    Text(L.replyingTo(replyTarget.personName ?? L.anonymous))
                        .font(WarmFont.caption)
                        .foregroundStyle(Warm.mutedSub)
                    Spacer()
                    Button {
                        self.replyTarget = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Warm.muted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }

            if let commentImageData, let ui = UIImage(data: commentImageData) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: ui)
                        .resizable().scaledToFill()
                        .frame(height: 90)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Button {
                        self.commentImageData = nil
                        self.commentPickerItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white, Color.black.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }
            }

            HStack(spacing: 8) {
                PhotosPicker(selection: $commentPickerItem, matching: .images) {
                    Image(systemName: "photo")
                        .foregroundStyle(Warm.brand)
                        .frame(width: 34, height: 42)
                }
                .onChange(of: commentPickerItem) { item in
                    Task { commentImageData = try? await item?.loadTransferable(type: Data.self) }
                }

                MentionInputField(
                    placeholder: replyTarget == nil ? L.commentHint : L.replyHint,
                    text: $draft,
                    mentions: $draftMentions,
                    participants: model.participants,
                    focus: $composerFocused
                )

                Button {
                    Task { await send() }
                } label: {
                    ZStack {
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle().fill(
                            canSend ? AnyShapeStyle(Warm.brandGradient)
                                    : AnyShapeStyle(Warm.brandBright.opacity(0.28))
                        )
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, WarmMetrics.screenPadding)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        guard !isSending else { return false }
        return !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || commentImageData != nil
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || commentImageData != nil else { return }

        isSending = true
        defer { isSending = false }

        // Drop any mention the user typed over before it reaches Firestore -
        // a stale offset would highlight the wrong words in the other apps.
        let mentions = MentionComposer.validated(draftMentions, against: text)
        let imageUrl = await model.uploadCommentImage(commentImageData)

        if let target = replyTarget {
            await model.addReply(
                to: target,
                text: text,
                personName: auth.profile?.name,
                personImage: auth.profile?.image_url,
                imageUrl: imageUrl,
                mentions: mentions
            )
            replyTarget = nil
        } else {
            await model.addAnswer(
                text: text,
                personName: auth.profile?.name,
                personImage: auth.profile?.image_url,
                imageUrl: imageUrl,
                mentions: mentions
            )
        }
        draft = ""
        draftMentions = []
        commentImageData = nil
        commentPickerItem = nil
        // Drop the keyboard so the comment that was just posted is visible
        // rather than hidden behind it.
        composerFocused = false
    }
}

// MARK: - Answer row

private struct AnswerRow: View {
    let answer: ForumAnswer
    let isMine: Bool
    let onReply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(answer.personName ?? L.anonymous)
                        .font(WarmFont.heading)
                        .foregroundStyle(Warm.ink)

                    Spacer()

                    if isMine {
                        Menu {
                            Button { onEdit() } label: {
                                Label(L.edit, systemImage: "pencil")
                            }
                            Button(role: .destructive) { onDelete() } label: {
                                Label(L.delete, systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(Warm.muted)
                                .frame(width: 32, height: 28)
                        }
                    }
                }

                MentionText(text: answer.answer, mentions: answer.mentions)

                // pt-ios allows a photo on a comment; without this those
                // comments render as text-only here and look truncated.
                if let image = answer.image, !image.isEmpty {
                    AsyncImage(url: URL(string: image)) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Warm.chipOff)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                // Replies live in the answer's own `answers` array, not as
                // separate documents - that shape is what onReplyAdded watches.
                if let replies = answer.answers, !replies.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(replies.enumerated()), id: \.offset) { _, reply in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reply.personName ?? L.anonymous)
                                    .font(WarmFont.caption)
                                    .foregroundStyle(Warm.mutedSub)
                                MentionText(
                                    text: reply.answer,
                                    mentions: reply.mentions,
                                    font: WarmFont.caption,
                                    lineSpacing: 2
                                )
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

                Button(action: onReply) {
                    Label(L.reply, systemImage: "arrowshape.turn.up.left")
                        .font(WarmFont.caption)
                        .foregroundStyle(Warm.brand)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
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

        await reloadPost()
        try? await store.incrementViews(postId: postId)
        isLoading = false
    }

    func reloadPost() async {
        guard let postId else { return }
        do {
            post = try await store.post(id: postId)
        } catch {
            errorMessage = L.somethingWentWrong
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    /// Everyone already in this thread: the post author plus each commenter.
    /// Costs nothing - it's built from data already on screen - and these are
    /// far likelier mention targets than a global name match, which is why
    /// pt-ios ranks them first too.
    var participants: [MentionCandidate] {
        var pool: [MentionCandidate] = []
        if let post {
            pool.append(MentionCandidate(
                uid: post.uid,
                name: post.personName ?? "",
                image: post.personImage ?? ""
            ))
        }
        for answer in answers {
            pool.append(MentionCandidate(
                uid: answer.uid,
                name: answer.personName ?? "",
                image: answer.personImage ?? ""
            ))
        }
        return pool
    }

    // MARK: Answers

    func uploadCommentImage(_ data: Data?) async -> String? {
        guard let data else { return nil }
        return try? await store.uploadImage(data, folder: "comments")
    }

    func addAnswer(
        text: String,
        personName: String?,
        personImage: String?,
        imageUrl: String? = nil,
        mentions: [Mention] = []
    ) async {
        guard let postId else { return }
        do {
            try await store.addAnswer(
                postId: postId, text: text,
                imageUrl: imageUrl,
                personName: personName, personImage: personImage,
                mentions: mentions.isEmpty ? nil : mentions
            )
            // Mentioned users join the thread so the Cloud Function includes
            // them in future reply pushes - same as Android and pt-ios.
            try? await store.registerMentioned(postId: postId, mentions: mentions)
        } catch {
            errorMessage = L.somethingWentWrong
        }
    }

    func addReply(
        to answer: ForumAnswer,
        text: String,
        personName: String?,
        personImage: String?,
        imageUrl: String? = nil,
        mentions: [Mention] = []
    ) async {
        guard let postId, let answerId = answer.id else { return }
        do {
            try await store.addReply(
                postId: postId,
                answerId: answerId,
                text: text,
                personName: personName,
                personImage: personImage,
                imageUrl: imageUrl,
                // Recorded so the reply can say who it addresses, matching
                // what pt-ios writes.
                replyToName: answer.personName,
                mentions: mentions.isEmpty ? nil : mentions
            )
            try? await store.registerMentioned(postId: postId, mentions: mentions)
        } catch {
            errorMessage = L.somethingWentWrong
        }
    }

    func updateAnswer(_ answer: ForumAnswer, text: String) async {
        guard let postId, let answerId = answer.id else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await store.updateAnswer(postId: postId, answerId: answerId, text: trimmed)
        } catch {
            errorMessage = L.somethingWentWrong
        }
    }

    func deleteAnswer(_ answer: ForumAnswer) async {
        guard let postId, let answerId = answer.id else { return }
        do {
            // Replies each incremented the post's total when written, so they
            // have to come off with their parent.
            try await store.deleteAnswer(
                postId: postId,
                answerId: answerId,
                replyCount: answer.answers?.count ?? 0
            )
        } catch {
            errorMessage = L.somethingWentWrong
        }
    }

    // MARK: Post

    /// Returns whether the delete succeeded, so the caller can pop the screen.
    func deletePost() async -> Bool {
        guard let postId else { return false }
        do {
            try await store.deletePost(postId: postId)
            return true
        } catch {
            errorMessage = L.somethingWentWrong
            return false
        }
    }

    func report() async {
        guard let postId else { return }
        try? await store.reportPost(postId: postId)
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
            if wasLiked { current.array.append(uid) } else { current.array.removeAll { $0 == uid } }
            post = current
            errorMessage = L.somethingWentWrong
        }
    }
}
