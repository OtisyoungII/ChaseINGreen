import Foundation

/// Content constraints, not device dimensions. Width is the safe-area container
/// proposal after outer padding/navigation chrome has consumed its space.
struct WorkspaceLayoutPolicy {
    static let spacing: CGFloat = 16
    static let minimumCardWidth: CGFloat = 340
    static let maximumColumns = 3

    static func columns(availableWidth: CGFloat, accessibilityText: Bool) -> Int {
        guard availableWidth.isFinite, availableWidth > 0, !accessibilityText else { return 1 }
        return min(maximumColumns, max(1, Int((availableWidth + spacing) / (minimumCardWidth + spacing))))
    }

    static func cardWidth(availableWidth: CGFloat, accessibilityText: Bool) -> CGFloat {
        let width = availableWidth.isFinite ? max(0, availableWidth) : minimumCardWidth
        let count = columns(availableWidth: width, accessibilityText: accessibilityText)
        return max(0, (width - CGFloat(count - 1) * spacing) / CGFloat(count))
    }
}
