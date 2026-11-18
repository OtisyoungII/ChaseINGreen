import SwiftUI

struct AdminPendingActionsView: View {
    @State private var requests: [IBKRMachineClaimReview] = []
    @State private var error: String?
    @State private var more = false
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.orange) }
            if requests.isEmpty && error == nil { Text("No pending enrollment requests") }
            ForEach(requests) { request in
                NavigationLink { AdminEnrollmentReviewView(request: request, completed: { Task { await load() } }) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.connection_name).font(.headline)
                        Text("\(request.agent_label) · \(request.ownership_type.capitalized)").font(.subheadline)
                        Text("Pending approval · Review").font(.caption).foregroundStyle(AppTheme.gold)
                    }
                }
            }
            if more { Text("Showing the latest 50 requests. Review these, then refresh for remaining requests.") }
        }.navigationTitle("Pending Actions").task { await load() }.refreshable { await load() }
    }
    private func load() async {
        do { let page = try await APIService.shared.pendingIBKRClaims(); requests = page.requests; more = page.has_more; error = nil }
        catch { self.error = "Pending requests unavailable. This requires the updated owner-authorized service; no approval has occurred." }
    }
}

private struct AdminEnrollmentReviewView: View {
    let request: IBKRMachineClaimReview
    let completed: () -> Void
    @State private var choice: String?
    @State private var busy = false
    @State private var finished = false
    @State private var message: String?
    var body: some View {
        Form {
            Section("IBKR enrollment request") {
                LabeledContent("Name", value: request.connection_name)
                LabeledContent("Machine", value: request.agent_label)
                LabeledContent("Ownership requested", value: request.ownership_type.capitalized)
                LabeledContent("Potential duplicate", value: request.potential_duplicate.map { $0 ? "Yes — review existing connection" : "None found" } ?? "Unknown")
                LabeledContent("Expires", value: AdminNavigationPresentation.time(request.expires_at))
                Text("Machine labels are supplied by the requester. Confirm this is your request. Native accounts are not verified by enrollment approval.").font(.caption)
                DisclosureGroup("Verification details") {
                    Text("Request code: \(request.request_code)").textSelection(.enabled)
                    Text("Replacement: \(request.replacement_connection_id ?? "None requested")")
                }
            }
            if let message { Section { Text(message) } }
            Section {
                Button("Approve") { choice = "Approve" }.disabled(busy || finished)
                Button("Reject", role: .destructive) { choice = "Reject" }.disabled(busy || finished)
            }
        }.navigationTitle("Review enrollment")
        .confirmationDialog("\(choice ?? "Review") \(request.connection_name)?", isPresented: Binding(get: { choice != nil }, set: { if !$0 { choice = nil } })) {
            Button("Confirm \(choice ?? "action")") {
                guard let action = choice, !busy, !finished else { return }
                choice = nil; busy = true
                Task {
                    defer { busy = false }
                    do {
                        if action == "Approve" { _ = try await APIService.shared.approveIBKRMachineClaim(request) }
                        else { try await APIService.shared.rejectIBKRMachineClaim(request) }
                        finished = true; message = action == "Approve" ? "Approved. Machine claim and account qualification remain separate. No observer or trading enabled here." : "Request rejected. No broker connection changed."
                        completed()
                    } catch { finished = true; message = "Result not confirmed. Return to Pending Actions and refresh before any further action. No automatic retry." }
                }
            }
            Button("Cancel", role: .cancel) { choice = nil }
        }
    }
}
