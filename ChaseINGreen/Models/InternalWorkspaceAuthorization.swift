//
//  InternalWorkspaceAuthorization.swift
//  ChaseINGreen
//

import Foundation

/// Stable, server-issued product capabilities for the current authenticated
/// session. Provider/account selection is deliberately not part of this type.
struct SessionCapabilityProfile: Equatable {
    let plan: String
    let isGold: Bool
    let isSecret: Bool
    let isAdmin: Bool
    let isBanned: Bool

    init(
        plan: String,
        isGold: Bool,
        isSecret: Bool,
        isAdmin: Bool,
        isBanned: Bool
    ) {
        self.plan = plan
        self.isGold = isGold
        self.isSecret = isSecret
        self.isAdmin = isAdmin
        self.isBanned = isBanned
    }

    var hasGold: Bool { !isBanned && isGold }
    var canAccessBatCave: Bool { !isBanned && (isSecret || isAdmin) }
    var canUseAdvancedAI: Bool { canAccessBatCave }
    var canUseQuantChartWorkbench: Bool { canAccessBatCave }
}

/// Server-issued capabilities used to protect the internal trading workspace.
/// Subscription labels and broker availability are intentionally absent: they
/// are product/display state, not authorization.
struct InternalWorkspaceAuthorization: Equatable {
    let isGold: Bool
    let isSecret: Bool
    let isAdmin: Bool
    let isBanned: Bool

    var canAccessInternalWorkspace: Bool {
        !isBanned && (isSecret || isAdmin)
    }
}

enum InternalWorkspaceEntryPoint: CaseIterable {
    case tradeHome
    case groupedProfitAndLoss
    case accountSelection
    case tradingCalendar
    case notification
    case deepLink
    case restoredNavigation
    case dashboard
    case marketDetail
    case brokerActivity
}

/// All entry points share one fail-closed decision. The entry point is kept in
/// the signature so a new route cannot silently invent a different policy.
struct InternalWorkspaceRoutePolicy {
    static func permits(
        _ entryPoint: InternalWorkspaceEntryPoint,
        authorization: InternalWorkspaceAuthorization?
    ) -> Bool {
        _ = entryPoint
        return authorization?.canAccessInternalWorkspace == true
    }

    static func mustReturnToAuthorizedScreen(
        afterRefresh authorization: InternalWorkspaceAuthorization?
    ) -> Bool {
        authorization?.canAccessInternalWorkspace != true
    }
}

/// Customer room access is not internal-workspace authority. Never use this
/// policy to authorize research, Auto Trader, diagnostics, or execution.
enum BrokerRoomAccessPolicy {
    static func permits(_ profile: SessionCapabilityProfile?) -> Bool {
        guard let profile, !profile.isBanned else { return false }
        return profile.hasGold || profile.canAccessBatCave
    }
}

/// Presentation rules only; no broker capability or execution authority.
enum BrokerRoomEvidencePolicy {
    static func retainedSelection(_ selected: UUID?, available: [UUID]) -> UUID? {
        if let selected, available.contains(selected) { return selected }
        return available.count == 1 ? available.first : nil
    }

    static func isFresh(observedAt: String?, maxAge: Double?, providerFresh: Bool?, stale: Bool?, now: Date = Date()) -> Bool {
        guard providerFresh == true, stale != true, let observedAt,
              let maxAge, maxAge > 0, maxAge.isFinite else { return false }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = parser.date(from: observedAt) ?? ISO8601DateFormatter().date(from: observedAt) else { return false }
        let age = now.timeIntervalSince(date)
        return age >= 0 && age <= maxAge
    }

    static func isManual(sourceMode: String?, connectionMode: String?) -> Bool {
        sourceMode?.lowercased() == "manual" || connectionMode?.lowercased() == "manual"
    }
}
