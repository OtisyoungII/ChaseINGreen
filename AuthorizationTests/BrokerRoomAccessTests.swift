import XCTest
@testable import ChaseINGreenAuthorization

final class BrokerRoomAccessTests: XCTestCase {
    func testRoomDoesNotGrantInternalAuthority() {
        for gold in [false, true] {
            for secret in [false, true] {
                for admin in [false, true] {
                    for banned in [false, true] {
                        let profile = SessionCapabilityProfile(plan: "ignored", isGold: gold, isSecret: secret, isAdmin: admin, isBanned: banned)
                        XCTAssertEqual(BrokerRoomAccessPolicy.permits(profile), !banned && (gold || secret || admin))
                        XCTAssertEqual(profile.canAccessBatCave, !banned && (secret || admin))
                        XCTAssertEqual(profile.canUseAdvancedAI, !banned && (secret || admin))
                    }
                }
            }
        }
        XCTAssertFalse(BrokerRoomAccessPolicy.permits(nil))
    }
}
