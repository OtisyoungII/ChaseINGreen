import Foundation

/// Descriptive trade-path evidence only. These types never grant trading authority.
enum TradePathEvidenceAuthority: String, Equatable {
    case authoritative
    case observational
    case unavailable
}

enum TradePathDirection: String, Equatable {
    case long
    case short
}

struct TradePathEvidenceSnapshot: Equatable {
    let timeframe: String?
    let directionalState: String?
    let confirmationState: String?
    let candleCloseProximity: TimeInterval?
    let sessionIdentifier: String?
    let observedAt: Date?
    let authority: TradePathEvidenceAuthority
}

struct TradePathPriceObservation: Equatable {
    let price: Double
    let timestamp: Date?
    let authority: TradePathEvidenceAuthority
    let evidence: TradePathEvidenceSnapshot?
}

struct TradePathInstrumentEconomics: Equatable {
    let quantity: Double
    let monetaryValuePerPriceUnit: Double
    let currencyCode: String?
}

enum ExcursionKind: String, Equatable {
    case maximumAdverseExcursion
    case maximumFavorableExcursion
}

struct TradePathExcursion: Equatable {
    let kind: ExcursionKind
    let absolutePrice: Double
    let percentage: Double
    let monetary: Double?
    let currencyCode: String?
    let extremeTimestamp: Date?
    let evidence: TradePathEvidenceSnapshot?

    /// Produces an excursion only from authoritative entry and path observations.
    /// Monetary excursion remains unavailable unless instrument economics are known.
    static func measure(
        kind: ExcursionKind,
        direction: TradePathDirection,
        entry: TradePathPriceObservation?,
        extreme: TradePathPriceObservation?,
        economics: TradePathInstrumentEconomics? = nil
    ) -> TradePathExcursion? {
        guard let entry, let extreme,
              entry.authority == .authoritative,
              extreme.authority == .authoritative,
              entry.price.isFinite, entry.price > 0,
              extreme.price.isFinite, extreme.price >= 0 else {
            return nil
        }

        let signedMovement = extreme.price - entry.price
        let directionalMovement = direction == .long ? signedMovement : -signedMovement
        let excursion: Double
        switch kind {
        case .maximumAdverseExcursion:
            excursion = max(-directionalMovement, 0)
        case .maximumFavorableExcursion:
            excursion = max(directionalMovement, 0)
        }

        let monetary: Double?
        if let economics,
           economics.quantity.isFinite, economics.quantity > 0,
           economics.monetaryValuePerPriceUnit.isFinite,
           economics.monetaryValuePerPriceUnit > 0 {
            monetary = excursion * economics.quantity * economics.monetaryValuePerPriceUnit
        } else {
            monetary = nil
        }

        return TradePathExcursion(
            kind: kind,
            absolutePrice: excursion,
            percentage: excursion / entry.price * 100,
            monetary: monetary,
            currencyCode: monetary == nil ? nil : economics?.currencyCode,
            extremeTimestamp: extreme.timestamp,
            evidence: extreme.evidence
        )
    }
}

enum ThesisOutcomeState: String, Equatable {
    case unknown
    case active
    case succeeded
    case failed
    case invalidated
}

enum EntryQualityState: String, Equatable {
    case unknown
    case favorable
    case mixed
    case unfavorable
}

enum PathQualityState: String, Equatable {
    case unknown
    case orderly
    case volatile
    case adverseBeforeFavorable
}

enum AccountCompatibilityState: String, Equatable {
    case unknown
    case compatible
    case incompatible
}

struct TradePathAssessment: Equatable {
    let thesisOutcome: ThesisOutcomeState
    let entryQuality: EntryQualityState
    let pathQuality: PathQualityState
    let accountCompatibility: AccountCompatibilityState

    let decisionAuthority = false
    let automaticExecution = false
}

struct EntryStopInvalidationMetadata: Equatable {
    let stopPrice: Double?
    let invalidationPrice: Double?
    let rationale: String?
    let evidence: TradePathEvidenceSnapshot?
}

struct TradeEntryPathRecord: Equatable, Identifiable {
    let id: String
    let thesisIdentifier: String
    let entryTimestamp: Date
    let entryPrice: Double
    let size: Double?
    let rationale: String?
    let riskBudget: Double?
    let stopInvalidation: EntryStopInvalidationMetadata?
    let mae: TradePathExcursion?
    let mfe: TradePathExcursion?
    let entryEvidence: TradePathEvidenceSnapshot?
    let realizedOutcome: Double?

    let decisionAuthority = false
    let automaticExecution = false
}

struct GroupedTradePathRecord: Equatable {
    let thesisIdentifier: String
    let entries: [TradeEntryPathRecord]
    let combinedExposure: Double?
    let authoritativeAverageEntryPrice: Double?
    let aggregateMAE: TradePathExcursion?
    let aggregateMFE: TradePathExcursion?
    let thesisOutcome: ThesisOutcomeState
    let accountImpact: Double?

    let decisionAuthority = false
    let automaticExecution = false
}

struct ExitBeforeExpansionObservation: Equatable {
    let entryIdentifier: String
    let exit: TradePathPriceObservation
    let subsequentExpansion: TradePathPriceObservation
    let exitEvidence: TradePathEvidenceSnapshot?
    let expansionEvidence: TradePathEvidenceSnapshot?

    /// This fact does not judge the earlier decision or recommend a new action.
    let classifiesExitAsMistake = false
    let impliesTraderShouldHaveHeld = false
    let authorizesReopening = false
    let decisionAuthority = false
    let automaticExecution = false

    static func observed(
        entryIdentifier: String,
        exit: TradePathPriceObservation?,
        subsequentExpansion: TradePathPriceObservation?,
        exitEvidence: TradePathEvidenceSnapshot? = nil,
        expansionEvidence: TradePathEvidenceSnapshot? = nil
    ) -> ExitBeforeExpansionObservation? {
        guard let exit, let subsequentExpansion,
              exit.authority == .authoritative,
              subsequentExpansion.authority == .authoritative,
              let exitTimestamp = exit.timestamp,
              let expansionTimestamp = subsequentExpansion.timestamp,
              expansionTimestamp > exitTimestamp else {
            return nil
        }
        return ExitBeforeExpansionObservation(
            entryIdentifier: entryIdentifier,
            exit: exit,
            subsequentExpansion: subsequentExpansion,
            exitEvidence: exitEvidence,
            expansionEvidence: expansionEvidence
        )
    }
}
