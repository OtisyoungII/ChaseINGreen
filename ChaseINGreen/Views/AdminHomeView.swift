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

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
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

            if let dashboard {
                HStack(spacing: 12) {
                    statCard("Users", "\(dashboard.users.total)")
                    statCard("Banned", "\(dashboard.users.banned)")
                }

                HStack(spacing: 12) {
                    statCard("Free", "\(dashboard.users.free)")
                    statCard("Premium", "\(dashboard.users.premium)")
                }

                HStack(spacing: 12) {
                    statCard("Gold", "\(dashboard.users.gold)")
                    statCard("Secret", "\(dashboard.users.secret)")
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
                    Text(user.alias?.isEmpty == false ? user.alias! : user.email ?? "No Email")
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.primaryText)

                    Text(user.email ?? user.auth0UserId)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Text(user.plan.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(user.isBanned ? .red : AppTheme.gold)
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
                .stroke(user.isBanned ? .red.opacity(0.55) : AppTheme.cardStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
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
