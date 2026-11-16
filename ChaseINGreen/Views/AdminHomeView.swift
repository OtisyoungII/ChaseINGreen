//
//  AdminHomeView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 5/28/26.
//



import SwiftUI

struct AdminHomeView: View {
    let accessToken: String

    @State private var product: ProductIntelligenceResponse?
    @State private var productError: String?
    @State private var productWindow = "30d"

    @State private var dashboard: AdminDashboardResponse?
    @State private var users: [AdminUserResponse] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var visibleUserCounts: AdminDashboardUserCounts? {
        guard !users.isEmpty else { return dashboard?.users }
        return AdminDashboardUserCounts(
            total: users.count,
            free: users.filter { $0.plan.lowercased() == "free" }.count,
            premium: users.filter { $0.plan.lowercased() == "premium" }.count,
            gold: users.filter { $0.isGold && !$0.isAdmin }.count,
            secret: users.filter { $0.isSecret && !$0.isAdmin }.count,
            secretAccessCount: users.filter { $0.isSecret }.count,
            secretNonAdminCount: users.filter { $0.isSecret && !$0.isAdmin }.count,
            admin: users.filter { $0.isAdmin }.count,
            banned: users.filter { $0.isBanned }.count
        )
    }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    NavigationLink {
                        AdminAutoTraderView(accessToken: accessToken)
                    } label: {
                        Label("Broker Observation", systemImage: "waveform.path.ecg")
                    }
                    intelligenceSection
                    mlLearningSection
                    productIntelligenceSection
                    dashboardSection
                    usersSection
                }
                .padding()
            }
        }
        .task(id: productWindow) { await loadProductIntelligence() }
        .navigationTitle("Admin")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadAdminData()
        }
        .refreshable {
            await loadAdminData()
        }
    }

    private var productIntelligenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Product Intelligence")
            Picker("Time range (UTC)", selection: $productWindow) {
                Text("Today").tag("today")
                Text("7 days").tag("7d")
                Text("30 days").tag("30d")
                Text("90 days").tag("90d")
                Text("Retained history").tag("all")
            }
            .pickerStyle(.menu)
            Button("Refresh product metrics") { Task { await loadProductIntelligence() } }
            if let productError { Text(productError).font(.caption).foregroundStyle(.secondary) }
            if let p = product {
                Text("Activity available since: \(p.available_since ?? "not collected") · UTC")
                    .font(.caption)
                if !p.collection_enabled { Text("Event collection is disabled.").foregroundStyle(.orange) }
                if p.sample_truncated { Text("Partial sample: results are not complete totals.").foregroundStyle(.orange) }
                metricRows("Customer activity", ["DAU (24h)": p.overview.dau, "WAU (7d)": p.overview.wau,
                    "MAU (30d)": p.overview.mau, "Active accounts": p.overview.active_accounts,
                    "Returning accounts": p.overview.returning_accounts,
                    "Inferred authenticated sessions": p.overview.authenticated_sessions])
                metricRows("Current account records", ["Total": p.overview.total_accounts, "New in window": p.overview.new_accounts])
                metricRows("Daily active accounts", p.daily_active)
                metricRows("New accounts by day", p.new_accounts_by_day)
                metricRows("Feature events", p.features)
                metricRows("Persisted workflow events", p.workflow_completions)
                metricRows("Platform events", p.platform_event_counts)
                metricRows("Device class events", p.device_event_counts)
                metricRows("OS version events", p.os_event_counts)
                metricRows("Active accounts by release", p.release_active_accounts)
                metricRows("Current entitlement categories", p.plan_accounts)
                Text("Current account inventory").font(.headline)
                ForEach(Array(p.account_inventory.enumerated()), id: \.offset) { _, item in
                    Text("\(item.provider) · \(item.source_mode): \(item.count)").font(.caption)
                }
                Text("Current connection inventory").font(.headline)
                ForEach(Array(p.connection_inventory.enumerated()), id: \.offset) { _, item in
                    Text("\(item.provider) · \(item.active ? "active" : "inactive"): \(item.count)").font(.caption)
                }
                ForEach(p.brokers.keys.sorted(), id: \.self) { provider in
                    if let broker = p.brokers[provider] {
                        metricRows("Broker: \(provider)", broker.counts)
                        Text("Last success: \(broker.last_success_at ?? "not collected")").font(.caption)
                        Text("Mean latency: \(broker.average_latency_ms.map { String(format: "%.0f ms", $0) } ?? "not collected")").font(.caption)
                        Text("p50 / p95: \(broker.p50_latency_ms.map { String(format: "%.0f", $0) } ?? "insufficient samples") / \(broker.p95_latency_ms.map { String(format: "%.0f ms", $0) } ?? "insufficient samples")").font(.caption)
                    }
                }
                metricRows("Pipeline observations", p.pipeline_event_counts)
                metricRows("Broker outcomes by release", p.broker_outcomes_by_release)
                metricRows("Failure categories", p.reliability_categories)
                Text("Same-operation mark/P&L disagreements: \(p.same_request_mark_pl_disagreements)")
                ForEach(p.limitations, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .padding()
        .background(AppTheme.cardBlack)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func metricRows(_ title: String, _ values: [String: Int]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            if values.isEmpty { Text("No observations collected").font(.caption) }
            ForEach(values.keys.sorted(), id: \.self) { key in
                HStack { Text(key.replacingOccurrences(of: "_", with: " ")); Spacer(); Text("\(values[key] ?? 0)") }
                    .font(.caption)
            }
        }
    }

    private func loadProductIntelligence() async {
        let requestedWindow = productWindow
        do {
            let result = try await APIService.shared.fetchProductIntelligence(accessToken: accessToken, window: requestedWindow)
            guard requestedWindow == productWindow else { return }
            product = result
            productError = nil
        } catch {
            guard requestedWindow == productWindow else { return }
            product = nil
            productError = "Product metrics unavailable. Account management remains available."
        }
    }

    private var intelligenceSection: some View {
        NavigationLink {
            TradeIntelligenceCenterView(accessToken: accessToken)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "brain.head.profile")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.gold)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trade Intelligence Center")
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Review aggregate recommendation outcomes, market context, failure evidence, and dataset readiness.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding()
            .background(AppTheme.cardBlack)
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(AppTheme.cardStroke) }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var mlLearningSection: some View {
        NavigationLink {
            MLLearningLabView(accessToken: accessToken)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "brain.filled.head.profile").font(.title2.bold()).foregroundStyle(AppTheme.gold)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ML Learning Lab").font(.headline.bold()).foregroundStyle(AppTheme.primaryText)
                    Text("Audit shadow models, historical experience, learned patterns, uncertainty, and explicit training runs.")
                        .font(.caption).foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(AppTheme.secondaryText)
            }
            .padding().background(AppTheme.cardBlack)
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(AppTheme.cardStroke) }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Admin Control")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text("Manage testers, tiers, bans, aliases, and rollout groups.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }
        }
    }

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Overview")

            if let dashboard, let counts = visibleUserCounts {
                HStack(spacing: 12) {
                    statCard("Users", "\(counts.total)")
                    statCard("Banned", "\(counts.banned)")
                }

                HStack(spacing: 12) {
                    statCard("Free", "\(counts.free)")
                    statCard("Premium", "\(counts.premium)")
                }

                HStack(spacing: 12) {
                    statCard("Gold", "\(counts.gold)")
                    statCard("Secret Users", "\(counts.secretNonAdminCount ?? counts.secret)")
                }

                HStack(spacing: 12) {
                    statCard("Open Trades", "\(dashboard.trades.open)")
                    statCard("Closed Trades", "\(dashboard.trades.closed)")
                }
            } else if isLoading {
                ProgressView()
                    .tint(AppTheme.gold)
            } else {
                unavailableCard("No admin data loaded.")
            }
        }
    }

    private var usersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Users")

            if users.isEmpty && !isLoading {
                unavailableCard("No users found yet. Users appear after logging in.")
            }

            ForEach(users) { user in
                NavigationLink {
                    AdminUserDetailView(
                        accessToken: accessToken,
                        user: user
                    ) { updatedUser in
                        replaceUser(updatedUser)
                    }
                } label: {
                    userRow(user)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func userRow(_ user: AdminUserResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(user.bestAdminIdentity)
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.primaryText)

                    Text(user.alias?.isEmpty == false ? "Alias: \(user.alias!)" : "Account ID: \(user.auth0UserId)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                badgeRow(user.adminBadges)
            }

            HStack {
                Text("Chase profile created: \(shortDate(user.createdAt))")
                Spacer()
                Text(user.isBanned ? "BANNED" : "Not banned")
                    .foregroundStyle(user.isBanned ? .red : .green)
            }
            .font(.caption2.bold())
            .foregroundStyle(AppTheme.secondaryText)
            VStack(alignment: .leading, spacing: 4) {
                Text("Last authenticated API activity: \(user.lastAuthenticatedApiAt ?? "Unknown")")
                Text("Last observed app activity: \(user.lastObservedAppActivityAt ?? "Unknown")")
                Text("Last login: \(user.lastLoginAt ?? "Unavailable") · Login count: \(user.loginCount.map(String.init) ?? "Unavailable")")
                Text("Recently active: \(user.recentlyActive.map { $0 ? "Yes" : "No" } ?? "Unknown")")
                Text(user.activityDefinition ?? "Observed qualifying app event within 24 hours; not online presence. Missing evidence is unknown.")
            }
            .font(.caption2)
            .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(rowAccent(user).opacity(0.60), lineWidth: user.rosterAccent == .free ? 1 : 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func badgeRow(_ badges: [AdminUserBadgeKind]) -> some View {
        HStack(spacing: 5) {
            ForEach(badges, id: \.rawValue) { badge in
                Text(badge.label)
                    .font(.caption2.bold())
                    .foregroundStyle(badgeForeground(badge))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(badgeBackground(badge))
                    .clipShape(Capsule())
            }
        }
    }

    private func rowAccent(_ user: AdminUserResponse) -> Color {
        switch user.rosterAccent {
        case .banned: return .red
        case .admin: return AppTheme.gold
        case .secret: return .indigo
        case .gold: return AppTheme.softGold
        default: return AppTheme.cardStroke
        }
    }

    private func badgeBackground(_ badge: AdminUserBadgeKind) -> Color {
        switch badge {
        case .gold, .admin: return AppTheme.gold
        case .secret: return .indigo
        case .banned: return .red
        case .apple: return .gray.opacity(0.35)
        case .tester: return .blue.opacity(0.28)
        case .free: return AppTheme.cardStroke.opacity(0.55)
        }
    }

    private func badgeForeground(_ badge: AdminUserBadgeKind) -> Color {
        switch badge {
        case .gold, .admin: return AppTheme.deepBlack
        default: return AppTheme.primaryText
        }
    }

    private func loadAdminData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            errorMessage = nil
            async let dashboardResponse = APIService.shared.fetchAdminDashboard(accessToken: accessToken)
            async let usersResponse = APIService.shared.fetchAdminUsers(accessToken: accessToken)

            dashboard = try await dashboardResponse
            users = try await usersResponse
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replaceUser(_ updatedUser: AdminUserResponse) {
        if let index = users.firstIndex(where: { $0.id == updatedUser.id }) {
            users[index] = updatedUser
        }
    }

    private func statCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.softGold)
    }

    private func unavailableCard(_ message: String) -> some View {
        AppUnavailableView(
            title: "Unavailable",
            systemImage: "tray",
            message: message
        )
    }

    private func shortDate(_ raw: String) -> String {
        String(raw.prefix(10))
    }
}

#Preview {
    NavigationStack {
        AdminHomeView(accessToken: "dummy")
    }
}
