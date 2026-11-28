import Foundation

struct WorkstationInstrumentItem: Identifiable, Equatable {
    let id: String // Provider-native identifier, never a fuzzy search key.
    let label: String
    let symbol: String
    var assetClass: String = "Unclassified"
    var detail: String = ""
}

enum WorkstationInstrumentSearch {
    static func key(_ value: String) -> String {
        value.uppercased().filter { $0.isLetter || $0.isNumber }
    }
    static func results(_ items: [WorkstationInstrumentItem], query: String,
                        assetClass: String? = nil, recent: [String] = [],
                        owned: Set<String> = [], watched: Set<String> = []) -> [WorkstationInstrumentItem] {
        let q = key(query)
        return items.compactMap { item -> (WorkstationInstrumentItem, Int, Int)? in
            guard assetClass == nil || item.assetClass == assetClass else { return nil }
            let keys = [item.id, item.label, item.symbol].map(key)
            let rank: Int
            if q.isEmpty { rank = 3 }
            else if keys.contains(q) { rank = 0 }
            else if keys.contains(where: { $0.hasPrefix(q) }) { rank = 1 }
            else if keys.contains(where: { $0.contains(q) }) || key(item.detail).contains(q) { rank = 2 }
            else { return nil }
            let boost = recent.firstIndex(of: item.id).map { 100 - $0 }
                ?? (owned.contains(key(item.symbol)) ? 50 : watched.contains(key(item.symbol)) ? 25 : 0)
            return (item, rank, boost)
        }.sorted {
            if $0.1 != $1.1 { return $0.1 < $1.1 }
            if $0.2 != $1.2 { return $0.2 > $1.2 }
            if $0.0.label != $1.0.label { return $0.0.label < $1.0.label }
            return $0.0.id < $1.0.id
        }.map(\.0)
    }
}
