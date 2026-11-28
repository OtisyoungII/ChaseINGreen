import XCTest
@testable import ChaseINGreenAuthorization

@MainActor
final class RetainedSnapshotStoreTests: XCTestCase {
    func testConcurrentForcedReadsCoalesce() async throws {
        let store = RetainedSnapshotStore<Int>()
        var reads = 0
        let fetch: @MainActor () async throws -> Int = {
            reads += 1
            try await Task.sleep(nanoseconds: 20_000_000)
            return 7
        }
        async let first = store.load("owner:active", force: true, fetch: fetch)
        async let second = store.load("owner:active", force: true, fetch: fetch)
        let values = try await [first, second]
        XCTAssertEqual(values, [7, 7]); XCTAssertEqual(reads, 1)
    }
    func testScopeIsolationAndRetainedFailure() async throws {
        let store = RetainedSnapshotStore<String>()
        _ = try await store.load("owner:active") { "original observation" }
        XCTAssertNil(store.cached("other:active"))
        XCTAssertNil(store.cached("owner:historical"))
        let value = try await store.load("owner:active", force: true) { throw URLError(.notConnectedToInternet) }
        XCTAssertEqual(value, "original observation")
        store.clear()
        XCTAssertNil(store.cached("owner:active"))
    }
    func testLogoutCannotRepopulateFromLateResponse() async throws {
        let store = RetainedSnapshotStore<Int>()
        let task = Task { try await store.load("owner") {
            try? await Task.sleep(nanoseconds: 30_000_000)
            return 1
        } }
        await Task.yield()
        store.clear()
        do { _ = try await task.value; XCTFail("Late owner response accepted") } catch {}
        XCTAssertNil(store.cached("owner"))
    }
}
