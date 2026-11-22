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
                "ChartWorkbenchModels.swift",
                "MarketCandle.swift",
                "ReplayChartEvidence.swift",
                "EpisodeReplay.swift",
                "BrokerPositionIdentity.swift",
                "AquaAPIIntake.swift",
                "MarketNumberFormat.swift",
                "CandleCloseCountdown.swift",
                "MarketAccessibility.swift",
                "TradePathIntelligence.swift",
                "OpportunityScreenerModels.swift",
                "ProductAnalyticsPolicy.swift",
                "LogPrivacyPolicy.swift",
                "CustomerPresentation.swift",
                "MarketIntelligenceEducation.swift",
                "AppleEntitlementPolicy.swift",
                "AuthRequestRecoveryPolicy.swift",
                "AcceptedValuation.swift",
                "WorkspaceLayoutPolicy.swift",
                "CalendarDaySelection.swift",
                "LedgerTruthPolicy.swift",
                "TradeQuantityEditPolicy.swift",
                "ManualAccountIdentityPolicy.swift",
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
                "AdminOperations.swift",
                "AdminNavigationPresentation.swift",
                "AdminTraderCockpitModels.swift",
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
