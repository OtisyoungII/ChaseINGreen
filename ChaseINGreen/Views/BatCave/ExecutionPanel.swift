//
//  ExecutionPanel.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// ✅ Bat Cave execution preview panel
// ✅ Sends symbol/side/account context to backend
// ✅ Uses /execution/analyze
// ✅ Preview only — no live order placed
// --------------------------------------------------------------

import SwiftUI

struct ExecutionPanel: View {

    @Bindable var vm: BatCaveViewModel

    let accessToken: String

    @State private var side: String = "buy"
    @State private var quantityText: String = ""
    @State private var orderType: String = "market"
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var execution: ExecutionAnalyzeResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            symbolRow

            sidePicker

            quantityRow

            analyzeButton

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let execution {
                executionResult(execution)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var header: some View {
        HStack {
            Image(systemName: "paperplane.circle.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.softGold)

            Text("Execution Preview")
                .font(.title2.bold())

            Spacer()
        }
    }

    private var symbolRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Symbol")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("AAPL", text: $vm.selectedSymbol)
                .textInputAutocapitalization(.characters)
                .padding()
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var sidePicker: some View {
        Picker("Side", selection: $side) {
            Text("Buy").tag("buy")
            Text("Sell").tag("sell")
        }
        .pickerStyle(.segmented)
    }

    private var quantityRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quantity")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Optional", text: $quantityText)
                .keyboardType(.decimalPad)
                .padding()
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var analyzeButton: some View {
        Button {
            Task {
                await analyze()
            }
        } label: {
            HStack {
                if isAnalyzing {
                    ProgressView()
                }

                Text("Analyze Execution")
                    .font(.headline)

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
            }
            .padding()
            .background(AppTheme.softGold.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(isAnalyzing)
    }

    private func executionResult(_ result: ExecutionAnalyzeResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Text(result.message)
                .font(.headline)

            Text(result.portfolioAI.headline)
                .font(.subheadline.bold())

            Text(result.portfolioAI.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                metric("Approval", result.approval.approvalStatus)
                metric("Route", result.route.routeStatus)
            }

            if !result.approval.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Warnings")
                        .font(.caption.bold())

                    ForEach(result.approval.warnings, id: \.self) {
                        Text("• \($0)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func analyze() async {
        isAnalyzing = true
        errorMessage = nil

        let quantity = Double(quantityText)

        let payload = ExecutionAnalyzeRequest(
            symbol: vm.selectedSymbol.uppercased(),
            side: side,
            quantity: quantity,
            orderType: orderType,
            broker: vm.selectedBroker,
            accountId: vm.selectedAccountId,
            accountGroup: vm.selectedAccountGroup,
            selectionMode: nil,
            estimatedCost: nil,
            estimatedRisk: nil,
            maxRiskPercent: nil,
            userIntent: "bat_cave_preview",
            holdingStyle: nil,
            riskPreference: nil,
            notes: "Preview from Bat Cave execution panel.",
            requestAutoExecution: false
        )

        do {
            execution = try await APIService.shared.analyzeExecution(
                payload,
                accessToken: accessToken
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isAnalyzing = false
    }
}
