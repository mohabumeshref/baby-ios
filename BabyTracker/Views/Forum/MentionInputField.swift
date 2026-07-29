//
//  MentionInputField.swift
//  BabyTracker
//
//  Text input with an @mention suggestion list.
//
//  KNOWN LIMITATION, stated rather than hidden: SwiftUI's TextField does not
//  expose the caret position, so the "@query" is detected from the END of the
//  text. Typing "@sa" while composing works, which is how mentions are used in
//  practice; moving the cursor back into the middle of an existing sentence and
//  typing "@" there will not open the list. pt-ios tracks the real caret
//  because UITextField gives it one. Fixing this properly means wrapping
//  UITextView in a UIViewRepresentable - worth doing if it ever bites, not
//  worth the surface area up front.
//

import SwiftUI

struct MentionInputField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var mentions: [Mention]

    /// People already in this thread - suggested first, and free to compute.
    var participants: [MentionCandidate] = []
    var lineLimit: ClosedRange<Int> = 1...4

    @EnvironmentObject private var auth: ForumAuth

    @State private var suggestions: [MentionCandidate] = []
    @State private var activeRange: NSRange?
    @State private var follows: [MentionCandidate] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !suggestions.isEmpty {
                suggestionList
            }

            WarmTextField(
                placeholder: placeholder,
                text: $text,
                axis: .vertical,
                lineLimit: lineLimit
            )
            .onChange(of: text) { _ in refreshSuggestions() }
        }
        .task {
            // Cached for the screen's lifetime; the follow list rarely changes
            // mid-compose and re-reading it per keystroke would be wasteful.
            guard let uid = auth.uid else { return }
            let users = (try? await ForumStore.shared.follows(uid: uid, kind: .following)) ?? []
            follows = users.map(MentionCandidate.init(user:))
        }
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { candidate in
                Button {
                    insert(candidate)
                } label: {
                    HStack(spacing: 10) {
                        avatar(candidate)
                        Text(candidate.name)
                            .font(WarmFont.body)
                            .foregroundStyle(Warm.ink)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if candidate.id != suggestions.last?.id {
                    Divider().overlay(Warm.chipOff)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Warm.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Warm.dotIdle, lineWidth: 1)
        )
        .shadow(color: Warm.brand.opacity(0.08), radius: 10, y: 4)
        .frame(maxHeight: 220)
    }

    private func avatar(_ candidate: MentionCandidate) -> some View {
        Group {
            if let url = URL(string: candidate.image), !candidate.image.isEmpty {
                AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: {
                    Circle().fill(Warm.chipOff)
                }
            } else {
                ZStack {
                    Circle().fill(Warm.chipOff)
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Warm.muted)
                }
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(Circle())
    }

    // MARK: - Query handling

    private func refreshSuggestions() {
        searchTask?.cancel()

        // Caret assumed at end of text - see the note at the top of this file.
        let caret = (text as NSString).length
        guard let found = MentionComposer.activeQuery(in: text, caret: caret) else {
            suggestions = []
            activeRange = nil
            return
        }

        activeRange = found.range
        showLocal(query: found.query)

        guard found.query.trimmingCharacters(in: .whitespaces).count
                >= MentionComposer.globalSearchFloor else { return }

        // Debounced, matching pt-ios's 0.35s, so typing doesn't fire a query
        // per keystroke.
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }

            let users = (try? await ForumStore.shared.searchUsers(matching: found.query)) ?? []
            guard !Task.isCancelled else { return }

            let global = users.map(MentionCandidate.init(user:))
            await MainActor.run { showLocal(query: found.query, global: global) }
        }
    }

    private func showLocal(query: String, global: [MentionCandidate] = []) {
        suggestions = MentionComposer.merge(
            participants: MentionComposer.filter(participants, query: query, excluding: auth.uid),
            follows: MentionComposer.filter(follows, query: query, excluding: auth.uid),
            global: global,
            excluding: auth.uid
        )
    }

    private func insert(_ candidate: MentionCandidate) {
        guard let range = activeRange else { return }
        let result = MentionComposer.insert(
            candidate: candidate,
            into: text,
            replacing: range,
            existing: mentions
        )
        text = result.text
        mentions = result.mentions
        suggestions = []
        activeRange = nil
    }
}
