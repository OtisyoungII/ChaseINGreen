//
//  TradeLogViewModel.swift
//  ChaseINGreen
//
//  Created by Otis Young on 5/18/26.
//

import Foundation

@MainActor
final class TradeLogViewModel: ObservableObject {
    @Published var isSubmitting = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    func submitSampleTradeLog(accessToken: String? = nil) async {
        isSubmitting = true
        successMessage = nil
        errorMessage = nil

        let payload = TradeLogCreateRequest(
            symbol: "NQ",
            broker: "aqua_funded",
            accountType: "prop_firm",
            accountSize: 100000,
            direction: "buy",
            intent: "enter",
            entryPrice: 21500,
            exitPrice: nil,
            stopLoss: nil,
            takeProfit: nil,
            positionSize: 0.25,
            riskAmount: nil,
            setupType: nil,
            marketPhase: nil,
            timeframe: "15m",
            reasons: ["4H bullish", "15M confirmation"],
            warnings: [],
            emotions: [],
            mistakes: [],
            confidence: "medium",
            outcome: "open",
            notes: nil,
            instructionsCompleted: true,
            bypassInstructions: false,
            allowInstructionReplay: false,
            userConfirmedUnderstanding: false
        )

        do {
            let response = try await APIService.shared.createTradeLog(
                payload,
                accessToken: accessToken
            )

            successMessage = response.success
                ? "Trade log sent."
                : "Trade log response was not successful."
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}
