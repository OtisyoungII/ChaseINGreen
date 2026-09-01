import XCTest
@testable import ChaseINGreenAuthorization

final class AquaHealthRequestCoalescerTests: XCTestCase {
    actor Counter {
        private(set) var value = 0
        func increment() { value += 1 }
    }

    func testConcurrentCallersShareOneRequest() async throws {
        let coalescer = AquaHealthRequestCoalescer<String>()
        let counter = Counter()
        async let first = coalescer.value(for: "owner") {
            await counter.increment()
            try await Task.sleep(for: .milliseconds(50))
            return "healthy"
        }
        try await Task.sleep(for: .milliseconds(5))
        async let second = coalescer.value(for: "owner") {
            await counter.increment()
            return "duplicate"
        }

        let results = try await [first, second]
        let requestCount = await counter.value
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(results.map(\.value), ["healthy", "healthy"])
        XCTAssertEqual(results.map(\.source), [.network, .joinedInflight])
    }

    func testCompletedRequestDoesNotRemainInflight() async throws {
        let coalescer = AquaHealthRequestCoalescer<Int>()
        let first = try await coalescer.value(for: "owner") { 1 }
        let second = try await coalescer.value(for: "owner") { 2 }
        XCTAssertEqual(first.value, 1)
        XCTAssertEqual(second.value, 2)
        XCTAssertEqual(first.source, .network)
        XCTAssertEqual(second.source, .network)
    }
}
