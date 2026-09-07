//
//  AdminHomeView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 5/28/26.
//



import SwiftUI

struct AdminHomeView: View {
    let accessToken: String

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
                    intelligenceSection
                    mlLearningSection
                    dashboardSection
                    usersSection
                }
                .padding()
            }
        }
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
                Text("Created: \(shortDate(user.createdAt))")
                Spacer()
                Text(user.isBanned ? "BANNED" : "Active")
                    .foregroundStyle(user.isBanned ? .red : .green)
            }
            .font(.caption2.bold())
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
