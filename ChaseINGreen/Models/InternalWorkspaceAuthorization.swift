//
//  InternalWorkspaceAuthorization.swift
//  ChaseINGreen
//

import Foundation

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
