//
//  PostCard.swift
//  BabyTracker
//
//  One post in the community feed.
//

import SwiftUI

struct PostCard: View {
    let post: ForumPost
    let currentUid: String?
    let onLike: () -> Void

    private var isLiked: Bool {
        guard let currentUid else { return false }
        return post.array.contains(currentUid)
    }

    var body: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 10) {
                author
                body_
                if let imageUrl = post.imageUrl, !imageUrl.isEmpty {
                    attachment(imageUrl)
                }
                stats
            }
        }
    }

    // MARK: - Author

    private var author: some View {
        HStack(spacing: 10) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(post.isAnonymous ? L.anonymous : (post.personName ?? L.anonymous))
                    .font(WarmFont.heading)
                    .foregroundStyle(Warm.ink)
                Text(relativeTime)
                    .font(WarmFont.caption)
                    .foregroundStyle(Warm.muted)
                    // Latin relative time ("4 h") must not mirror inside RTL text.
                    .environment(\.layoutDirection, .leftToRight)
            }

            Spacer()

            // The author's own unapproved posts are visible to them alone;
            // saying so avoids "my post vanished" confusion.
            if !post.status {
                Text(L.awaitingApproval)
                    .font(WarmFont.caption)
                    .foregroundStyle(Warm.mutedSub)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Warm.chipOff))
            }
        }
    }

    private var avatar: some View {
        Group {
            if !post.isAnonymous,
               let urlString = post.personImage,
               let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    avatarPlaceholder
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(Circle())
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle().fill(Warm.chipOff)
            Image(systemName: "person.fill")
                .font(.system(size: 16))
                .foregroundStyle(Warm.muted)
        }
    }

    // MARK: - Body

    private var body_: some View {
        Text(post.description)
            .font(WarmFont.body)
            .foregroundStyle(Warm.bodyInk)
            .lineSpacing(4)
            .lineLimit(6)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func attachment(_ urlString: String) -> some View {
        AsyncImage(url: URL(string: urlString)) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            RoundedRectangle(cornerRadius: WarmMetrics.chipRadius, style: .continuous)
                .fill(Warm.chipOff)
                .overlay(ProgressView().tint(Warm.muted))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: WarmMetrics.chipRadius, style: .continuous))
    }

    // MARK: - Stats

    private var stats: some View {
        HStack(spacing: 18) {
            Button(action: onLike) {
                statLabel(
                    systemName: isLiked ? "heart.fill" : "heart",
                    value: post.array.count,
                    tint: isLiked ? Warm.brandDeep : Warm.muted
                )
            }
            .buttonStyle(.plain)

            statLabel(systemName: "bubble.left", value: post.answers, tint: Warm.muted)

            Spacer()
        }
    }

    private func statLabel(systemName: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemName)
                .font(.system(size: 13))
            Text(String.number(value))
                .font(WarmFont.caption)
        }
        .foregroundStyle(tint)
    }

    /// Short Latin relative time, matching Android's Post.getPostDate and
    /// pt-ios's Constants.getPostRelativeTime so all three apps agree.
    private var relativeTime: String {
        let date = post.timestamp.dateValue()
        let now = Date()
        let seconds = now.timeIntervalSince(date)
        let minutes = Int(seconds / 60)
        let hours = Int(seconds / 3600)
        let days = Int(seconds / 86400)

        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) {
            if hours > 0 { return "\(hours) h" }
            if minutes > 0 { return "\(minutes) m" }
            return "just now"
        }
        if days == 1 { return "Yesterday" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if days >= 2 && days <= 7 {
            formatter.dateFormat = "EEEE"
            return "Last \(formatter.string(from: date))"
        }
        formatter.dateFormat = "dd MMM, yyyy"
        return formatter.string(from: date)
    }
}
