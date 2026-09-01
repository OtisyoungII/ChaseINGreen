// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ChaseINGreenAuthorization",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(
            name: "ChaseINGreenAuthorization",
            targets: ["ChaseINGreenAuthorization"]
        )
    ],
    targets: [
        .target(
            name: "ChaseINGreenAuthorization",
            path: "ChaseINGreen/Models",
            sources: [
                "BrokerPositionIdentity.swift",
                "AquaProtectionBatchPolicy.swift",
                "AquaLoginCredentialPolicy.swift",
                "AquaHealthRequestCoalescer.swift",
                "InternalWorkspaceAuthorization.swift",
                "MarketQuoteCacheReplacementPolicy.swift",
                "SafeServerErrorResponse.swift",
                "TradePresentationPolicy.swift",
            ]
        ),
        .testTarget(
            name: "ChaseINGreenAuthorizationTests",
            dependencies: ["ChaseINGreenAuthorization"],
            path: "AuthorizationTests"
        )
    ]
)
