//
//  MentionText.swift
//  BabyTracker
//
//  Renders text with @mentions highlighted and tappable.
//
//  This is a port of MentionRender in pt-ios/Utils/Mentions.swift. It matters
//  for more than parity: mention metadata is already stored on posts and
//  comments written from the pregnancy tracker and Android, so without this the
//  same content renders as flat unstyled text here while it's highlighted
//  everywhere else.
//
//  Offset handling follows pt-ios exactly - stored offsets are UTF-16 and can
//  be stale if a post was edited by a client that doesn't maintain them, so
//  each range is validated against the text, then falls back to searching for
//  the literal "@Name", and is skipped entirely if that fails too. A wrong
//  range would highlight the wrong words rather than fail loudly.
//

import SwiftUI

struct MentionText: View {
    let text: String
    let mentions: [Mention]?
    var font: Font = WarmFont.body
    var color: Color = Warm.bodyInk
    var lineSpacing: CGFloat = 4
    /// Called with (uid, name) when a mention is tapped.
    var onTapMention: ((String, String) -> Void)?

    /// Custom scheme so mention taps can be intercepted without leaving the app.
    private static let scheme = "babymention"

    var body: some View {
        Text(attributed)
            .font(font)
            .foregroundStyle(color)
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == Self.scheme else { return .systemAction }
                let uid = url.host ?? ""
                let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "name" })?.value ?? ""
                onTapMention?(uid, name)
                return .handled
            })
    }

    private var attributed: AttributedString {
        guard let mentions, !mentions.isEmpty else { return AttributedString(text) }

        let ns = text as NSString
        let result = NSMutableAttributedString(string: text)
        var didStyleAny = false

        for mention in mentions {
            let expected = "@" + mention.name
            var range = NSRange(location: mention.start, length: mention.length)

            let valid = range.location >= 0
                && range.length > 0
                && NSMaxRange(range) <= ns.length
                && ns.substring(with: range) == expected

            if !valid {
                // Offsets were stale - locate the literal text instead.
                range = ns.range(of: expected)
            }

            guard range.location != NSNotFound, NSMaxRange(range) <= ns.length else { continue }

            var attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor(Warm.brand),
            ]
            if !mention.uid.isEmpty,
               let url = URL(string: "\(Self.scheme)://\(mention.uid)?name=\(mention.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                attrs[.link] = url
            }
            result.addAttributes(attrs, range: range)
            didStyleAny = true
        }

        guard didStyleAny, var converted = try? AttributedString(result, including: \.uiKit) else {
            return AttributedString(text)
        }
        // The link attribute alone would render in the system tint; force the
        // brand colour back over the whole string's styled runs.
        for run in converted.runs where run.link != nil {
            converted[run.range].foregroundColor = Warm.brand
        }
        return converted
    }
}
