//
//  TradeEntrySheet.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/16/26.
//

import SwiftUI

enum TradeDirectionOption: String, CaseIterable, Identifiable {
    case long
    case short

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

struct TradeEntryDraft {
    var symbol: String
    var direction: TradeDirectionOption = .long
    var entryPriceText: String = ""
    var currentPriceText: String = ""
    var stopLossText: String = ""
    var takeProfitText: String = ""
    var quantityText: String = ""
    var accountSizeText: String = "5000"
    var platformText: String = ""
    var notes: String = ""
}

struct TradeEntrySheet: View {
    let symbol: String
    let currentPrice: Double?
    let onSave: (LoggedTradeCreateRequest) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var draft: TradeEntryDraft

    private let quickSizes: [Double] = [0.01, 1, 5, 10, 25, 50, 100]

    init(
        symbol: String,
        currentPrice: Double?,
        onSave: @escaping (LoggedTradeCreateRequest) -> Void
    ) {
        self.symbol = symbol
        self.currentPrice = currentPrice
        self.onSave = onSave

        var initialDraft = TradeEntryDraft(symbol: symbol.uppercased())
        if let currentPrice {
            initialDraft.entryPriceText = String(format: "%.2f", currentPrice)
            initialDraft.currentPriceText = String(format: "%.2f", currentPrice)
        }
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trade") {
                    HStack {
                        Text("Symbol")
                        Spacer()
                        Text(draft.symbol)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Direction", selection: $draft.direction) {
                        ForEach(TradeDirectionOption.allCases) { direction in
                            Text(direction.title).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Entry Price", text: $draft.entryPriceText)
                        .keyboardType(.decimalPad)

                    if let currentPrice {
                        Button("Use Current Price (\(currentPrice, specifier: "%.2f"))") {
                            let formatted = String(format: "%.2f", currentPrice)
                            draft.entryPriceText = formatted
                            draft.currentPriceText = formatted
                        }
                    }
                }

                Section("Risk / Size") {
                    TextField("Current Price (optional)", text: $draft.currentPriceText)
                        .keyboardType(.decimalPad)

                    TextField("Stop Loss (optional)", text: $draft.stopLossText)
                        .keyboardType(.decimalPad)

                    TextField("Take Profit (optional)", text: $draft.takeProfitText)
                        .keyboardType(.decimalPad)

                    TextField("Quantity / Shares / Lots", text: $draft.quantityText)
                        .keyboardType(.decimalPad)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(quickSizes, id: \.self) { size in
                                Button {
                                    draft.quantityText = formatQuickSize(size)
                                } label: {
                                    Text(formatQuickSize(size))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.secondarySystemBackground))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    TextField("Account Size", text: $draft.accountSizeText)
                        .keyboardType(.decimalPad)
                }

                Section("Platform") {
                    TextField("Platform (optional)", text: $draft.platformText)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Quick Trade Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveTrade()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        Double(draft.entryPriceText) != nil
    }

    private func saveTrade() {
        guard let entryPrice = Double(draft.entryPriceText) else {
            return
        }

        let payload = LoggedTradeCreateRequest(
            userId: nil,
            symbol: draft.symbol.uppercased(),
            direction: draft.direction.rawValue,
            entryPrice: entryPrice,
            currentPrice: doubleOrNil(draft.currentPriceText),
            stopLoss: doubleOrNil(draft.stopLossText),
            takeProfit: doubleOrNil(draft.takeProfitText),
            quantity: doubleOrNil(draft.quantityText),
            accountSize: doubleOrNil(draft.accountSizeText),
            platform: draft.platformText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.platformText,
            notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.notes
        )

        onSave(payload)
        dismiss()
    }

    private func doubleOrNil(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : Double(trimmed)
    }

    private func formatQuickSize(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}

#Preview {
    TradeEntrySheet(
        symbol: "TQQQ",
        currentPrice: 72.42
    ) { _ in }
}
