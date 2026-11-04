import Foundation

/// PATCH carries only intentional quantity edits, never the unchanged snapshot.
enum TradeQuantityEditPolicy {
    static func changedQuantity(edited: Double?, initial: Double?) -> Double? {
        edited == initial ? nil : edited
    }
}
