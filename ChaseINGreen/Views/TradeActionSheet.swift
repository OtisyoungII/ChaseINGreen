//
//  TradeActionSheet.swift
//  ChaseINGreen
//

import SwiftUI

struct TradeActionSheet: View {
    let prompt: TradeActionPrompt
    let currentQuotePrice: Double?
    let accessToken: String
    let onComplete: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var valueText = ""
    @State private var noteText = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Trade") {
                    Text(prompt.trade.symbol)
                    Text(prompt.trade.direction.capitalized)
                    Text("Entry: \(format(prompt.trade.entryPrice))")
                }

                if prompt.needsValue {
                    Section(valueTitle) {
                        TextField(valuePlaceholder, text: $valueText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Note") {
                    TextField("Optional note", text: $noteText, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await submit()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(saveButtonTitle)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle(prompt.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                valueText = formatForInput(prompt.defaultValue(currentQuotePrice: currentQuotePrice))
            }
        }
    }

    private var valueTitle: String {
        switch prompt {
        case .brokerPrice: return "Broker Price"
        case .stopLoss: return "Stop Loss"
        case .takeProfit: return "Take Profit"
        case .quantity: return "Current Quantity"
        case .reduce: return "New Smaller Quantity"
        case .add: return "Quantity Added"
        case .close, .stopLossHit, .takeProfitHit: return "Exit Price"
        case .clearStopLoss, .clearTakeProfit: return ""
        }
    }

    private var valuePlaceholder: String {
        switch prompt {
        case .reduce: return "New quantity you still hold"
        case .add: return "Amount added"
        case .close: return "Broker fill price"
        case .stopLossHit: return "Stop fill price"
        case .takeProfitHit: return "Target fill price"
        default: return "Value"
        }
    }

    private var saveButtonTitle: String {
        switch prompt {
        case .close: return "Close Trade"
        case .stopLossHit: return "Mark Stop Hit"
        case .takeProfitHit: return "Mark Target Hit"
        case .clearStopLoss: return "Remove Stop Loss"
        case .clearTakeProfit: return "Remove Take Profit"
        default: return "Save"
        }
    }

    private func submit() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : noteText.trimmingCharacters(in: .whitespacesAndNewlines)

        let value = Double(valueText)

        do {
            switch prompt {
            case .brokerPrice(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid broker price.") }
                _ = try await APIService.shared.updateBrokerPrice(
                    tradeId: trade.id,
                    currentPrice: value,
                    notes: note ?? "Broker price manually updated.",
                    accessToken: accessToken
                )

            case .stopLoss(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid stop loss.") }
                _ = try await APIService.shared.updateTrade(
                    tradeId: trade.id,
                    stopLoss: value,
                    notes: note ?? "Stop loss set to \(value).",
                    accessToken: accessToken
                )

            case .clearStopLoss(let trade):
                _ = try await APIService.shared.updateTrade(
                    tradeId: trade.id,
                    clearStopLoss: true,
                    notes: note ?? "Stop loss removed.",
                    accessToken: accessToken
                )

            case .takeProfit(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid take profit.") }
                _ = try await APIService.shared.updateTrade(
                    tradeId: trade.id,
                    takeProfit: value,
                    notes: note ?? "Take profit set to \(value).",
                    accessToken: accessToken
                )

            case .clearTakeProfit(let trade):
                _ = try await APIService.shared.updateTrade(
                    tradeId: trade.id,
                    clearTakeProfit: true,
                    notes: note ?? "Take profit removed.",
                    accessToken: accessToken
                )

            case .quantity(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid quantity.") }
                _ = try await APIService.shared.updateTrade(
                    tradeId: trade.id,
                    quantity: value,
                    notes: note ?? "Quantity updated to \(value).",
                    accessToken: accessToken
                )

            case .reduce(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid reduced quantity.") }
                _ = try await APIService.shared.reduceTrade(
                    tradeId: trade.id,
                    newQuantity: value,
                    currentPrice: currentQuotePrice,
                    notes: note ?? "Position reduced. New quantity: \(value).",
                    accessToken: accessToken
                )

            case .add(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid add quantity.") }
                _ = try await APIService.shared.addToTrade(
                    tradeId: trade.id,
                    addQuantity: value,
                    currentPrice: currentQuotePrice,
                    notes: note ?? "Added \(value) to position.",
                    accessToken: accessToken
                )

            case .close(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid exit price.") }
                _ = try await APIService.shared.closeTrade(
                    tradeId: trade.id,
                    exitPrice: value,
                    closeReason: "manual_close",
                    notes: note ?? "Trade manually closed at \(value).",
                    accessToken: accessToken
                )

            case .stopLossHit(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid stop fill price.") }
                _ = try await APIService.shared.markStopLossHit(
                    tradeId: trade.id,
                    exitPrice: value,
                    notes: note ?? "Stop loss hit at \(value).",
                    accessToken: accessToken
                )

            case .takeProfitHit(let trade):
                guard let value else { throw TradeActionError.invalidValue("Invalid target fill price.") }
                _ = try await APIService.shared.markTakeProfitHit(
                    tradeId: trade.id,
                    exitPrice: value,
                    notes: note ?? "Take profit hit at \(value).",
                    accessToken: accessToken
                )
            }

            await onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func formatForInput(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.2f", value)
    }
}

private enum TradeActionError: LocalizedError {
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .invalidValue(let message):
            return message
        }
    }
}
