//
//  FollowListView.swift
//  BabyTracker
//
//  Followers / following list, the equivalent of pt-ios's FollowVC.
//

import SwiftUI

struct FollowListView: View {
    let uid: String
    let kind: ForumStore.FollowKind

    @Environment(\.dismiss) private var dismiss
    @State private var users: [ForumUser] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().tint(Warm.brand)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if users.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "person.2")
                            .font(.system(size: 34))
                            .foregroundStyle(Warm.muted)
                        Text(L.noneYet)
                            .font(WarmFont.body)
                            .foregroundStyle(Warm.mutedSub)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(users) { user in
                                NavigationLink {
                                    ProfileView(
                                        uid: user.uid ?? "",
                                        initialName: user.name,
                                        initialImage: user.image_url
                                    )
                                } label: {
                                    row(user)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, WarmMetrics.screenPadding)
                        .padding(.vertical, 12)
                    }
                }
            }
            .warmBackground()
            .navigationTitle(kind == .followers ? L.followers : L.following)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.close) { dismiss() }.tint(Warm.brand)
                }
            }
        }
        .task {
            users = (try? await ForumStore.shared.follows(uid: uid, kind: kind)) ?? []
            isLoading = false
        }
    }

    private func row(_ user: ForumUser) -> some View {
        WarmCard {
            HStack(spacing: 12) {
                Group {
                    if let image = user.image_url, !image.isEmpty, let url = URL(string: image) {
                        AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: {
                            Circle().fill(Warm.chipOff)
                        }
                    } else {
                        ZStack {
                            Circle().fill(Warm.chipOff)
                            Image(systemName: "person.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Warm.muted)
                        }
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())

                Text(user.displayName(anonymousLabel: L.anonymous))
                    .font(WarmFont.heading)
                    .foregroundStyle(Warm.ink)

                Spacer()
            }
        }
    }
}
