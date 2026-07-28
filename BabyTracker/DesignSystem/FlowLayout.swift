//
//  FlowLayout.swift
//  BabyTracker
//
//  Wrapping row layout for the milestone chips - the SwiftUI equivalent of the
//  FlexboxLayout the Android app fills with hand-built TextViews.
//
//  Written against the iOS 16 `Layout` protocol so the chips participate in
//  normal SwiftUI sizing and animation rather than being measured manually.
//

import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = WarmMetrics.chipSpacing
    var lineSpacing: CGFloat = WarmMetrics.chipSpacing
    var alignment: HorizontalAlignment = .leading

    /// Passed in rather than read from the environment: `Layout` conformances
    /// are value types resolved outside the view's environment, so mirroring
    /// has to be explicit.
    var layoutDirection: LayoutDirection = .leftToRight

    // MARK: - Measurement

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)

        let height = rows.reduce(into: CGFloat.zero) { total, row in
            total += row.height
        } + lineSpacing * CGFloat(max(rows.count - 1, 0))

        // Report the widest row, not the proposal, so the layout doesn't claim
        // more width than it uses when it sits inside a leading-aligned stack.
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: min(width, maxWidth), height: height)
    }

    // MARK: - Placement

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            // Leading edge depends on both the requested alignment and the
            // reading direction.
            var x: CGFloat
            switch alignment {
            case .center: x = bounds.minX + (bounds.width - row.width) / 2
            case .trailing: x = bounds.maxX - row.width
            default: x = bounds.minX
            }

            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                // In RTL the first chip belongs at the right edge, so mirror
                // each placement across the row's own span.
                let originX = layoutDirection == .rightToLeft
                    ? bounds.maxX - (x - bounds.minX) - size.width
                    : x

                subviews[index].place(
                    at: CGPoint(x: originX, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }

            y += row.height + lineSpacing
        }
    }

    // MARK: - Row packing

    private struct Row {
        var indices: [Subviews.Index] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width

            if needed > maxWidth && !current.indices.isEmpty {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }

        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
