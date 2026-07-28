//
//  ComposePostView.swift
//  BabyTracker
//
//  Writing a new post.
//
//  Image attachment uses SwiftUI's PhotosPicker, which runs out of process and
//  needs NO photo-library permission - the user picks one item and only that
//  item is handed over. This is why Info.plist has no
//  NSPhotoLibraryUsageDescription; the Android app asks for broad storage
//  access, and iOS should not.
//

import SwiftUI
import PhotosUI
import FirebaseStorage

struct ComposePostView: View {
    /// Called after a successful post so the feed can refresh.
    var onPosted: () -> Void

    @EnvironmentObject private var auth: ForumAuth
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var isAnonymous = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isPosting = false
    @State private var errorMessage: String?

    private var canPost: Bool {
        !isPosting && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    editor
                    attachment
                    anonymousToggle

                    if let errorMessage {
                        Text(errorMessage)
                            .font(WarmFont.caption)
                            .foregroundStyle(Warm.brandDeep)
                    }
                }
                .padding(WarmMetrics.screenPadding)
            }
            .warmBackground()
            .navigationTitle(L.newPost)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                        .tint(Warm.mutedSub)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.newPost) { Task { await post() } }
                        .tint(Warm.brand)
                        .disabled(!canPost)
                }
            }
            .overlay {
                if isPosting {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        ProgressView().tint(Warm.brand)
                    }
                }
            }
        }
    }

    // MARK: - Pieces

    private var editor: some View {
        WarmCard {
            TextField(L.writeSomething, text: $text, axis: .vertical)
                .font(WarmFont.body)
                .lineLimit(6...14)
        }
    }

    private var attachment: some View {
        VStack(alignment: .leading, spacing: 8) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(L.addImage, systemImage: "photo")
                    .font(WarmFont.chip)
                    .foregroundStyle(Warm.brand)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: WarmMetrics.chipRadius, style: .continuous)
                            .fill(Warm.chipOff)
                    )
            }
            .onChange(of: pickerItem) { item in
                Task { imageData = try? await item?.loadTransferable(type: Data.self) }
            }

            if let imageData, let uiImage = UIImage(data: imageData) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(
                            RoundedRectangle(cornerRadius: WarmMetrics.chipRadius, style: .continuous)
                        )

                    Button {
                        self.imageData = nil
                        self.pickerItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white, Color.black.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }
        }
    }

    private var anonymousToggle: some View {
        Toggle(isOn: $isAnonymous) {
            Text(L.postAnonymously)
                .font(WarmFont.caption)
                .foregroundStyle(Warm.mutedSub)
        }
        .tint(Warm.brand)
    }

    // MARK: - Posting

    private func post() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = L.textRequired
            return
        }

        isPosting = true
        errorMessage = nil
        defer { isPosting = false }

        do {
            var imageUrl: String?
            if let imageData {
                imageUrl = try await upload(imageData)
            }

            // Anonymous posts must carry the anonymous label as personName -
            // that exact string is what the Cloud Function checks to suppress
            // follower pushes, and what the other apps render.
            try await ForumStore.shared.createPost(
                text: trimmed,
                imageUrl: imageUrl,
                personName: isAnonymous ? L.anonymous : auth.profile?.name,
                personImage: isAnonymous ? nil : auth.profile?.image_url,
                autoApprove: await autoApprovePosts(),
                mentions: nil
            )

            onPosted()
            dismiss()
        } catch {
            errorMessage = L.somethingWentWrong
        }
    }

    private func upload(_ data: Data) async throws -> String {
        let path = "posts/\(UUID().uuidString).jpg"
        let ref = Storage.storage().reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        return try await ref.downloadURL().absoluteString
    }

    /// Mirrors pt-ios: the `autoApprovePosts` Remote Config flag decides whether
    /// a new post is visible immediately or waits for admin approval. Defaults
    /// to false so a fetch failure can't accidentally publish unmoderated posts.
    private func autoApprovePosts() async -> Bool {
        await RemoteConfigGate.shared.bool(forKey: "autoApprovePosts", default: false)
    }
}
