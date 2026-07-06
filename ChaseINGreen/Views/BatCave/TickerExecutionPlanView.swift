//
//  TickerExecutionPlanView.swift
//  ChaseINGreen
//
//  By: Otis Young II
// --------------------------------------------------------------
// ✅ Tap ticker → best execution plan
// ✅ Runs TraderOS + Position Size + Portfolio AI + Execution Preview
// ✅ Shows direction, size, risk, account context, stop/target plan
// ✅ Preview only — no live trade is placed
// --------------------------------------------------------------

import SwiftUI

struct TickerExecutionPlanView: View {

    let symbol: String
    let accessToken: String

    @Bindable var vm: BatCaveViewModel

    @State private var traderOS: TraderOSResponse?
    @State private var positionSize: PositionSizeResponse?
    @State private var portfolioAI: PortfolioAIResponse?
    @State private var execution: ExecutionAnalyzeResponse?

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header

                if isLoading {
                    ProgressView("Building best plan...")
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .padding()
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                recommendationCard

                accountContextCard

                sizeCard

                executionPlanCard

                warningsCard

                actionsCard
            }
            .padding()
        }
        .navigationTitle(symbol.uppercased())
        .task {
            await buildPlan()
        }
        .refreshable {
            await buildPlan()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Best Execution Plan")
                .font(.largeTitle.bold())

            Text("TraderOS will decide direction, size, account fit, and risk before execution.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var recommendationCard: some View {
        panel(title: "Recommendation", icon: "brain.head.profile") {
            let rec = traderOS?.ai?.finalRecommendation
                ?? traderOS?.decision?.decision
                ?? traderOS?.executionPlan?.side
                ?? "WAIT"

            Text(rec.uppercased())
                .font(.title.bold())
                .foregroundStyle(recommendationColor(rec))

            Text(traderOS?.ai?.summary ?? traderOS?.decision?.explanation ?? traderOS?.summary ?? "No AI summary yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                metric("Confidence", "\(traderOS?.ai?.confidence ?? traderOS?.decision?.confidence ?? 0)%")
                metric("Risk", "\(traderOS?.ai?.riskScore ?? traderOS?.executionPlan?.riskScore ?? 0)")
                metric("Probability", "\(traderOS?.probability?.bestProbability ?? 0)%")
            }
        }
    }

    private var accountContextCard: some View {
        panel(title: "Account Context", icon: "building.columns") {
            Text(portfolioAI?.selection.headline ?? "No account selected")
                .font(.headline)

            Text(portfolioAI?.selection.summary ?? "Using current Bat Cave workspace.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                metric("Equity", (portfolioAI?.selection.selectedEquity ?? 0).currency)
                metric("Buying Power", (portfolioAI?.selection.selectedBuyingPower ?? 0).currency)
            }
        }
    }

    private var sizeCard: some View {
        panel(title: "Position Size", icon: "scalemass.fill") {
            Text(positionSizeSummary)
                .font(.headline)

            Text("Size should respect selected account, risk, confidence, and broker type.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var executionPlanCard: some View {
        panel(title: "Execution Plan", icon: "paperplane.circle.fill") {
            Text(execution?.message ?? "Execution preview not loaded yet.")
                .font(.headline)

            if let plan = traderOS?.executionPlan {
                VStack(alignment: .leading, spacing: 8) {
                    row("Trade Type", plan.tradeType)
                    row("Side", plan.side)
                    row("Entry", plan.entryCondition)
                    row("Stop", plan.stopPlan)
                    row("Target", plan.targetPlan)
                    row("Priority", plan.priority)
                }
            }

            if let execution {
                Divider()
                row("Approval", execution.approval.approvalStatus)
                row("Route", execution.route.routeStatus)
            }
        }
    }

    private var warningsCard: some View {
        let warnings =
            (traderOS?.warnings ?? [])
            + (portfolioAI?.warnings ?? [])
            + (execution?.approval.warnings ?? [])
            + (execution?.route.warnings ?? [])

        return panel(title: "Warnings", icon: "exclamationmark.triangle.fill") {
            if warnings.isEmpty {
                Text("No major warnings.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(Set(warnings)).sorted(), id: \.self) {
                    Text("• \($0)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var actionsCard: some View {
        let actions =
            (traderOS?.actions ?? [])
            + (portfolioAI?.actions ?? [])
            + (execution?.approval.actions ?? [])
            + (execution?.route.actions ?? [])

        return panel(title: "Actions", icon: "bolt.fill") {
            if actions.isEmpty {
                Text("No required actions.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(Set(actions)).sorted(), id: \.self) {
                    Text("• \($0)")
                        .font(.caption)
                }
            }
        }
    }

    private func buildPlan() async {
        isLoading = true
        errorMessage = nil

        do {
            let os = try await APIService.shared.runTraderOS(
                symbol: symbol,
                direction: nil,
                broker: vm.selectedBroker,
                accountKey: vm.selectedAccountId,
                accessToken: accessToken
            )

            traderOS = os

            async let sizeTask = APIService.shared.fetchPositionSize(
                symbol: symbol,
                broker: vm.selectedBroker,
                accountKey: vm.selectedAccountId,
                accountBalance: vm.selection?.selectedEquity,
                accountEquity: vm.selection?.selectedEquity,
                buyingPower: vm.selection?.selectedBuyingPower,
                bestProbability: os.probability?.bestProbability,
                riskScore: os.ai?.riskScore ?? os.executionPlan?.riskScore,
                sizeProfile: os.executionPlan?.sizeProfile,
                accessToken: accessToken
            )

            async let aiTask = APIService.shared.fetchPortfolioAI(
                symbol: symbol,
                broker: vm.selectedBroker,
                accountId: vm.selectedAccountId,
                accountGroup: vm.selectedAccountGroup,
                accessToken: accessToken
            )

            let side = os.executionPlan?.side
                ?? os.decision?.decision
                ?? os.ai?.finalRecommendation
                ?? "wait"

            let executionPayload = ExecutionAnalyzeRequest(
                symbol: symbol,
                side: side,
                quantity: nil,
                orderType: "market",
                broker: vm.selectedBroker,
                accountId: vm.selectedAccountId,
                accountGroup: vm.selectedAccountGroup,
                selectionMode: nil,
                estimatedCost: nil,
                estimatedRisk: nil,
                maxRiskPercent: nil,
                userIntent: "ticker_execution_plan",
                holdingStyle: os.executionPlan?.executionStyle,
                riskPreference: os.executionPlan?.sizeProfile,
                notes: "Ticker tapped from Bat Cave.",
                requestAutoExecution: false
            )

            async let executionTask = APIService.shared.analyzeExecution(
                executionPayload,
                accessToken: accessToken
            )

            positionSize = try await sizeTask
            portfolioAI = try await aiTask
            execution = try await executionTask

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private var positionSizeSummary: String {
        guard let block = positionSize?.positionSize else {
            return "No size recommendation yet."
        }

        return block.summary ?? block.headline ?? "Position size loaded."
    }

    private func row(_ title: String, _ value: String?) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value ?? "—")
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func panel<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)

            content()
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func recommendationColor(_ value: String) -> Color {
        let clean = value.uppercased()

        if clean.contains("BUY") || clean.contains("LONG") || clean.contains("CALL") {
            return .green
        }

        if clean.contains("SELL") || clean.contains("SHORT") || clean.contains("PUT") {
            return .red
        }

        if clean.contains("WAIT") || clean.contains("AVOID") {
            return .orange
        }

        return AppTheme.softGold
    }
}

private extension Double {
    var currency: String {
        formatted(.currency(code: "USD"))
    }
}
