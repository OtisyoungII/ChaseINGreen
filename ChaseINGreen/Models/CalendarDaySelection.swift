import Foundation

/// Presentation identity is the requested date, including dates with no activity.
/// Superseded completions cannot replace or dismiss a newer selection.
struct CalendarDaySelection<Value> {
    private(set) var requestID = UUID()
    private(set) var date: String?
    private var loadedDate: String?
    private var loadedDetail: Value?

    var detail: Value? { date == loadedDate ? loadedDetail : nil }

    mutating func begin(_ date: String) -> UUID {
        requestID = UUID()
        self.date = date
        return requestID
    }

    mutating func complete(_ value: Value, request: UUID) {
        guard request == requestID else { return }
        loadedDate = date
        loadedDetail = value
    }

    mutating func cancel(request: UUID) {
        guard request == requestID else { return }
        date = loadedDate
    }

    mutating func clear() {
        requestID = UUID()
        date = nil
        loadedDate = nil
        loadedDetail = nil
    }

    static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as NSError).domain == NSURLErrorDomain
            && (error as NSError).code == NSURLErrorCancelled
    }
}
