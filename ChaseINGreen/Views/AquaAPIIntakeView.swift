import SwiftUI

struct AquaAPIIntakeView: View {
    @State private var key = ""
    @State private var intakeID = UUID()
    @State private var rows: [AquaAPIIntake] = []
    @State private var busy = false
    @State private var allowed = false
    @State private var message: String?
    @State private var disconnectTarget: UUID?

    var body: some View {
        Form {
            Section("Aqua / Match-Trader — private read-only connection") {
                Text("Secret/Admin access only. Use your official Trader API key, never your Aqua password. Chase execution remains disabled regardless of token permissions.")
                if allowed {
                    SecureField("Official API key", text: $key)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    Button("Save encrypted key") { submit() }
                        .disabled(busy || key.isEmpty)
                    Text("A new key creates a separate intake. A replacement is not active until its exact account and read access are verified. No automatic validation or retry.")
                        .font(.caption)
                }
                if let message { Text(message).foregroundStyle(.secondary) }
                Button("Refresh saved intake status") { Task { await refresh() } }.disabled(busy)
            }
            ForEach(rows) { row in
                Section(row.native_account_id.map { "Aqua account \($0)" } ?? "Pending account identification") {
                    Text(row.state.replacingOccurrences(of: "_", with: " "))
                    Text(row.explanation)
                    if let resources = row.capabilities.read_resources, !resources.isEmpty {
                        Text("Verified reads: \(resources.joined(separator: ", "))")
                    }
                    Text("Token trading permissions: unknown. Account access rights do not establish token permissions.").font(.caption)
                    if let failure = row.failure { Text(failure).foregroundStyle(.orange) }
                    if row.credential_retained, let deadline = row.pending_until { Text("Pending key retention deadline: \(deadline)").font(.caption) }
                    Text("Updated: \(row.updated_at)").font(.caption)
                    Text("Execution disabled · \(row.observation_active ? "Observation active" : "Observation not activated")")
                    if row.canValidate {
                        Button("Validate saved key — read-only") { action(row.id, disconnect: false) }.disabled(busy)
                    }
                    if row.state != "DISCONNECTED" {
                        Button("Disconnect / discard this intake", role: .destructive) { disconnectTarget = row.id }.disabled(busy)
                    }
                }.textSelection(.enabled)
            }
        }
        .navigationTitle("Aqua API connection")
        .task { await refresh() }
        .onDisappear { key = "" }
        .confirmationDialog("Disconnect this intake? Broker positions and history will not be changed.",
            isPresented: Binding(get: { disconnectTarget != nil }, set: { if !$0 { disconnectTarget = nil } })) {
            Button("Disconnect", role: .destructive) {
                if let id = disconnectTarget { action(id, disconnect: true) }; disconnectTarget = nil
            }
        }
    }
    private func refresh() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { rows = try await APIService.shared.aquaIntakes(); if rows.contains(where: { $0.id == intakeID }) { intakeID = UUID() }; allowed = true; message = nil }
        catch { allowed = false; message = "Secure intake is unavailable or access was denied. No key was submitted." }
    }
    private func submit() {
        guard !busy, allowed, !key.isEmpty else { return }
        busy = true
        let submitted = key; key = ""
        Task {
            defer { busy = false }
            do {
                let row = try await APIService.shared.saveAquaAPIKey(submitted, intakeID: intakeID)
                rows.removeAll { $0.id == row.id }; rows.insert(row, at: 0)
                intakeID = UUID(); message = "Encrypted intake saved. Select validation when ready."
            } catch {
                message = "Submission was not confirmed. Refresh saved status before retrying. Do not generate another key."
            }
        }
    }
    private func action(_ id: UUID, disconnect: Bool) {
        guard !busy else { return }; busy = true
        Task {
            defer { busy = false }
            do {
                let row = try await APIService.shared.aquaIntakeAction(id, disconnect: disconnect)
                rows.removeAll { $0.id == row.id }; rows.insert(row, at: 0); message = nil
            } catch { message = "Operation not confirmed. Refresh saved status; no automatic retry was made." }
        }
    }
}
