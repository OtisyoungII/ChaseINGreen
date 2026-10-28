import SwiftUI

/// A single Layout keeps the same subviews alive across column-count changes.
/// It owns no broker state, tasks, drafts, selection or authorization.
struct WorkspaceCardLayout: Layout {
    var accessibilityText = false
    var layoutDirection: LayoutDirection = .leftToRight

    private func metrics(width: CGFloat, subviews: Subviews) -> (Int, CGFloat, [CGFloat]) {
        let columns = WorkspaceLayoutPolicy.columns(availableWidth: width, accessibilityText: accessibilityText)
        let cardWidth = WorkspaceLayoutPolicy.cardWidth(availableWidth: width, accessibilityText: accessibilityText)
        var rows: [CGFloat] = []
        for index in subviews.indices {
            let row = index / columns
            if row == rows.count { rows.append(0) }
            rows[row] = max(rows[row], subviews[index].sizeThatFits(.init(width: cardWidth, height: nil)).height)
        }
        return (columns, cardWidth, rows)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? max(0, $0) : nil } ?? WorkspaceLayoutPolicy.minimumCardWidth
        let (_, _, rows) = metrics(width: width, subviews: subviews)
        return CGSize(width: width, height: rows.reduce(0, +) + CGFloat(max(0, rows.count - 1)) * WorkspaceLayoutPolicy.spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (columns, width, rows) = metrics(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for index in subviews.indices {
            let column = index % columns
            if index > 0 && column == 0 { y += rows[index / columns - 1] + WorkspaceLayoutPolicy.spacing }
            let offset = CGFloat(column) * (width + WorkspaceLayoutPolicy.spacing)
            let x = layoutDirection == .rightToLeft ? bounds.maxX - width - offset : bounds.minX + offset
            subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                                 proposal: .init(width: width, height: nil))
        }
    }
}

/// Wraps existing header labels without duplicating their view hierarchy.
struct WorkspaceFlowLayout: Layout {
    var spacing: CGFloat = 10
    var layoutDirection: LayoutDirection = .leftToRight

    private func arrangement(width: CGFloat, subviews: Subviews) -> ([CGRect], CGFloat) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.init(width: width, height: nil))
            let itemWidth = min(width, size.width)
            if x > 0 && x + itemWidth > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: itemWidth, height: size.height))
            x += itemWidth + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (frames, y + rowHeight)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = max(0, proposal.width ?? WorkspaceLayoutPolicy.minimumCardWidth)
        return CGSize(width: width, height: arrangement(width: width, subviews: subviews).1)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrangement(width: bounds.width, subviews: subviews).0
        for index in subviews.indices {
            let frame = frames[index]
            let x = layoutDirection == .rightToLeft ? bounds.maxX - frame.maxX : bounds.minX + frame.minX
            subviews[index].place(at: CGPoint(x: x, y: bounds.minY + frame.minY), anchor: .topLeading,
                                 proposal: .init(width: frame.width, height: frame.height))
        }
    }
}
