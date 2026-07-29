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
    var onTapMention: ((String, String) -> Void)? = nil
    var onTapAuthor: (() -> Void)? = nil
    var onTapImage: ((String) -> Void)? = nil
    /// Shown as a "..." menu when supplied - the feed uses this so a post can
    /// be edited, deleted or reported without opening it first, as in pt-ios.
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onReport: (() -> Void)? = nil

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

            if hasMenu {
                Menu {
                    if let onEdit {
                        Button { onEdit() } label: { Label(L.edit, systemImage: "pencil") }
                    }
                    if let onDelete {
                        Button(role: .destructive) { onDelete() } label: {
                            Label(L.delete, systemImage: "trash")
                        }
                    }
                    if let onReport {
                        Button(role: .destructive) { onReport() } label: {
                            Label(L.report, systemImage: "flag")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Warm.muted)
                        .frame(width: 30, height: 28)
                }
            }
        }
        // Anonymous authors have no profile to open.
        .contentShape(Rectangle())
        .onTapGesture { if !post.isAnonymous { onTapAuthor?() } }
    }

    private var hasMenu: Bool { onEdit != nil || onDelete != nil || onReport != nil }

    private var avatar: some View {
        Group {
            if !post.isAnonymous,
               let urlString = post.personImage, !urlString.isEmpty {
                CachedAsyncImage(url: urlString)
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
        // Mentions are stored on posts written by every app, so they must be
        // rendered here or PT-authored posts look unstyled in this app.
        MentionText(
            text: post.description,
            mentions: post.mentions,
            onTapMention: onTapMention
        )
    }

    private func attachment(_ urlString: String) -> some View {
        CachedAsyncImage(url: urlString)
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: WarmMetrics.chipRadius, style: .continuous))
        .onTapGesture { onTapImage?(urlString) }
    }

    // MARK: - Stats

    /// PT's action pills, matched to its stylePillButton NUMBERS, not just its
    /// shape: 24pt heart / 23pt bubble.right, bold 14 count with a 7pt gap,
    /// min height 44, corner radius 22, soft surface fill.
    private var stats: some View {
        HStack(spacing: 10) {
            Button(action: onLike) {
                statPill(
                    systemName: isLiked ? "heart.fill" : "heart",
                    iconSize: 24,
                    value: post.array.count,
                    tint: isLiked ? Warm.brandDeep : Warm.mutedChip
                )
            }
            .buttonStyle(.plain)

            statPill(
                systemName: "bubble.right",
                iconSize: 23,
                value: post.answers,
                tint: Warm.mutedChip
            )

            Spacer()
        }
    }

    private func statPill(systemName: String, iconSize: CGFloat, value: Int, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemName)
                .font(.system(size: iconSize))
            Text(String.number(value))
                .font(WarmFont.counter)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Warm.chipOff)
        )
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

        if days >= 2 && days <= 7 {
            return "Last \(Self.weekdayFormatter.string(from: date))"
        }
        return Self.dateFormatter.string(from: date)
    }

    // Static: DateFormatter construction is expensive, and this used to run
    // inside every row's body - one of the fast-scroll hitch sources.
    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd MMM, yyyy"
        return f
    }()
}
