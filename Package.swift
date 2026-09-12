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
                "IBKREnrollmentHandoff.swift",
                "BrokerInstrumentContext.swift",
                "AquaProtectionBatchPolicy.swift",
                "AquaLoginCredentialPolicy.swift",
                "AquaSessionReadinessPolicy.swift",
                "AquaHealthRequestCoalescer.swift",
                "InternalWorkspaceAuthorization.swift",
                "KrakenConnectionSelectionPolicy.swift",
                "KrakenConnectionSyncPolicy.swift",
                "AdminModels.swift",
                "MarketQuoteCacheReplacementPolicy.swift",
                "ProviderRefreshPolicy.swift",
                "TradeHomeRefreshPolicy.swift",
                "SafeServerErrorResponse.swift",
                "TradePresentationPolicy.swift",
                "TraderOS.swift",
                "PreTradeContext.swift",
                "BatCaveModels.swift",
                "MarketDecisionPresentationPolicy.swift",
            ]
        ),
        .testTarget(
            name: "ChaseINGreenAuthorizationTests",
            dependencies: ["ChaseINGreenAuthorization"],
            path: "AuthorizationTests",
            resources: [.copy("Fixtures")]
        )
    ]
)
