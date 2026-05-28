//
//  AdminUserDetailView.swift
//  ChaseINGreen
//

import SwiftUI

struct AdminUserDetailView: View {
    let accessToken: String
    let user: AdminUserResponse
    let onSave: (AdminUserResponse) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var alias: String
    @State private var selectedPlan: String
    @State private var testerGroup: String
    @State private var appVersionLabel: String
    @State private var notes: String
    @State private var isBanned: Bool

    @State private var isSaving = false
    @State private var errorMessage: String?

    private let plans = [
        "free",
        "premium",
        "gold",
        "secret",
        "admin",
    ]

    init(
        accessToken: String,
        user: AdminUserResponse,
        onSave: @escaping (AdminUserResponse) -> Void
    ) {
        self.accessToken = accessToken
        self.user = user
        self.onSave = onSave

        _alias = State(initialValue: user.alias ?? "")
        _selectedPlan = State(initialValue: user.plan)
        _testerGroup = State(initialValue: user.testerGroup ?? "")
        _appVersionLabel = State(initialValue: user.appVersionLabel ?? "")
        _notes = State(initialValue: user.notes ?? "")
        _isBanned = State(initialValue: user.isBanned)
    }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    editSection
                    dangerSection
                    saveButton

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("User Control")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(user.email ?? "No Email")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.primaryText)

            Text(user.auth0UserId)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            Text("Created: \(String(user.createdAt.prefix(10)))")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.softGold)
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var editSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Tester Settings")

            TextField("Alias ex: mom", text: $alias)
                .appTextField()

            Picker("Plan", selection: $selectedPlan) {
                ForEach(plans, id: \.self) { plan in
                    Text(plan.capitalized)
                        .tag(plan)
                }
            }
            .pickerStyle(.segmented)

            TextField("Tester Group ex: beta-a", text: $testerGroup)
                .appTextField()
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Version Label ex: gold-test-v1", text: $appVersionLabel)
                .appTextField()
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Notes", text: $notes, axis: .vertical)
                .appTextField()
                .lineLimit(3...6)
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Access Control")

            Toggle(isOn: $isBanned) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isBanned ? "User Banned" : "User Active")
                        .font(.headline.bold())
                        .foregroundStyle(isBanned ? .red : .green)

                    Text("Ban/unban takes effect on the user’s next API request.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .tint(.red)
        }
        .padding()
        .background(AppTheme.cardBlack)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(isBanned ? .red.opacity(0.65) : AppTheme.cardStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var saveButton: some View {
        Button {
            Task {
                await saveChanges()
            }
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .tint(AppTheme.deepBlack)
                }

                Text(isSaving ? "Saving..." : "Save Admin Changes")
                    .font(.headline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.deepBlack)
        .background(AppTheme.gold)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .disabled(isSaving)
        .opacity(isSaving ? 0.6 : 1)
    }

    private func saveChanges() async {
        isSaving = true
        defer { isSaving = false }

        let payload = AdminUserUpdateRequest(
            alias: clean(alias),
            plan: selectedPlan,
            isPremium: nil,
            isGold: nil,
            isSecret: nil,
            isAdmin: nil,
            testerGroup: clean(testerGroup),
            appVersionLabel: clean(appVersionLabel),
            notes: clean(notes),
            isBanned: isBanned
        )

        do {
            errorMessage = nil

            let updatedUser = try await APIService.shared.updateAdminUser(
                userId: user.id,
                payload: payload,
                accessToken: accessToken
            )

            onSave(updatedUser)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clean(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.softGold)
    }
}

#Preview {
    NavigationStack {
        AdminUserDetailView(
            accessToken: "dummy",
            user: AdminUserResponse(
                id: UUID(),
                auth0UserId: "auth0|demo",
                email: "tester@example.com",
                alias: "mom",
                plan: "gold",
                isPremium: true,
                isGold: true,
                isSecret: false,
                isAdmin: false,
                testerGroup: "beta-a",
                appVersionLabel: "gold-test-v1",
                notes: "Good tester",
                isBanned: false,
                createdAt: "2026-05-28T00:00:00",
                updatedAt: "2026-05-28T00:00:00"
            )
        ) { _ in }
    }
}