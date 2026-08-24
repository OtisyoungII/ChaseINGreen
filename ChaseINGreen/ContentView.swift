//  ContentView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 8/6/25.
//

import SwiftUI
import Auth0

struct ContentView: View {
    private static let auth0APIAudience =
        "https://myapi.ChaseINGreen.com"

    private static let credentialsManager = CredentialsManager(
        authentication: Auth0.authentication(),
        storeKey: "chaseingreen.auth0.credentials"
    )

    @State private var isLoggedIn = false
    @State private var accessToken: String?
    @State private var path = NavigationPath()
    @ObservedObject private var alertNavigation =
        TradeAlertNavigationStore.shared
    @State private var authMessage: String?
    @State private var glowPulse = false
    @State private var pressedButton: String?
    @State private var showingPaywall = false
    @State private var showingAccountSettings = false
    @State private var isCheckingAccess = false
    @State private var didAttemptSessionRestore = false
    @State private var isAlertWorkspaceActive = false
    @State private var canOpenTradingWorkspace = false
    @State private var authorizationRequestID = UUID()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if isLoggedIn, let token = accessToken {
                    DashboardView(accessToken: token)
                        .toolbar {
                            ToolbarItem(placement: .automatic) {
                                Button("Logout") {
                                    logout()
                                }
                                .foregroundStyle(AppTheme.danger)
                            }
                        }
                        .onAppear {
                            print("[Navigation] from=authenticated-shell to=trade-home reason=root")
                        }
                } else {
                    AppBackground {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 20) {
                                oesBrandBar
                                heroSection

                                if let authMessage {
                                    statusMessage(authMessage)
                                }

                                actionSection
                                footerSection
                            }
                            .padding(.horizontal, 22)
                            .padding(.top, 24)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
            .onAppear {
                glowPulse = true
            }
            .task {
                restoreSessionIfAvailable()
            }
            .onChange(of: alertNavigation.pendingRoute) {
                routePendingTradeAlertIfPossible()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                print("[Lifecycle] scene=background-or-inactive->active")
                Task {
                    await refreshInternalWorkspaceAuthorization()
                }
            }
            .sheet(isPresented: $showingPaywall) {
                SubscriptionPaywallView(accessToken: accessToken)
            }
            .sheet(isPresented: $showingAccountSettings) {
                if let token = accessToken {
                    AccountSettingsView(accessToken: token) {
                        showingAccountSettings = false
                        completeDeletedAccountSignOut()
                    }
                }
            }
            .navigationDestination(
                for: TradeNotificationRoute.self
            ) { route in
                if let token = accessToken,
                   canOpenTradingWorkspace {
                    TradingWorkspaceView(
                        accessToken: token,
                        symbol: route.symbol,
                        direction: route.side,
                        broker: route.broker,
                        accountKey: route.accountId,
                        focusedPositionID: route.positionId,
                        followsTradeAlerts: true
                    )
                    .onAppear {
                        isAlertWorkspaceActive = true
                    }
                    .onDisappear {
                        isAlertWorkspaceActive = false
                    }
                }
            }
        }
    }

    private var oesBrandBar: some View {
        HStack(spacing: 10) {
            Image("OESystemsLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Otis Execution Systems")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(AppTheme.softGold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text("OES Secure Access")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.gold)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.07))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.gold.opacity(0.22), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.gold.opacity(glowPulse ? 0.32 : 0.12))
                    .frame(width: 170, height: 170)
                    .blur(radius: 18)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: glowPulse)

                RoundedRectangle(cornerRadius: 34)
                    .fill(.white.opacity(0.08))
                    .frame(width: 150, height: 150)
                    .overlay {
                        RoundedRectangle(cornerRadius: 34)
                            .stroke(AppTheme.gold.opacity(0.65), lineWidth: 1.4)
                    }
                    .shadow(color: AppTheme.gold.opacity(0.24), radius: 18, x: 0, y: 10)

                Image("ChaseINGreenIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 104, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 7)
            }

            VStack(spacing: 7) {
                Text("ChaseINGreen")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, AppTheme.softGold, AppTheme.gold],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.75), radius: 1, x: 1, y: 2)
                    .shadow(color: AppTheme.gold.opacity(0.35), radius: 12, x: 0, y: 5)

                Text("Trade smarter. Protect profits.")
                    .font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.secondaryText)

                Text("Powered by Otis Execution Systems")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.softGold.opacity(0.9))
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: 14) {
            if !didAttemptSessionRestore || isCheckingAccess {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(AppTheme.gold)
                    Text("Restoring secure session...")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.vertical, 14)
            } else if isLoggedIn {
                glassButton(
                    id: "upgrade",
                    title: "Subscriptions",
                    subtitle: "Manage Premium and Gold access",
                    systemImage: "crown.fill",
                    tint: AppTheme.gold
                ) {
                    showingPaywall = true
                }

                glassButton(
                    id: "account",
                    title: "Account & Settings",
                    subtitle: "Privacy, subscriptions, and account deletion",
                    systemImage: "person.crop.circle",
                    tint: AppTheme.gold
                ) {
                    showingAccountSettings = true
                }

                glassButton(
                    id: "logout",
                    title: "Logout",
                    subtitle: "Switch account or clear session",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    tint: AppTheme.danger
                ) {
                    logout()
                }
            } else {
                glassButton(
                    id: "login",
                    title: isCheckingAccess ? "Checking Access..." : "OES Secure Login",
                    subtitle: "Access your dashboard",
                    systemImage: "lock.shield.fill",
                    tint: AppTheme.gold
                ) {
                    guard !isCheckingAccess else { return }
                    login()
                }
            }
        }
        .padding(.top, 4)
    }

    private var footerSection: some View {
        VStack(spacing: 6) {
            Text("Version 1")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.softGold)

            Text("An Otis Execution Systems product.")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)

            Text("Cleaner context before every trade decision.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.mutedText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func statusMessage(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white.opacity(0.08))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func glassButton(
        id: String,
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                pressedButton = id
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    pressedButton = nil
                }
                action()
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.22))
                        .frame(width: 46, height: 46)

                    Image(systemName: systemImage)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(tint.opacity(0.9))
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [
                        .white.opacity(0.16),
                        .white.opacity(0.06),
                        tint.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(AppTheme.gold.opacity(0.18), lineWidth: 1.2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .scaleEffect(pressedButton == id ? 0.97 : 1.0)
            .shadow(color: tint.opacity(0.18), radius: pressedButton == id ? 5 : 14, x: 0, y: pressedButton == id ? 3 : 8)
        }
        .buttonStyle(.plain)
    }

    private func login() {
        authMessage = "Opening OES secure login..."

        Auth0
            .webAuth()
            .audience(Self.auth0APIAudience)
            .scope("openid profile email offline_access")
            .parameters([
                "prompt": "select_account"
            ])
            .start { result in
                switch result {
                case .success(let credentials):
                    validateAndActivate(
                        credentials,
                        persistAfterValidation: true,
                        allowOfflineRestore: false
                    )

                case .failure(let error):
                    DispatchQueue.main.async {
                        isCheckingAccess = false
                        authMessage = "Login failed: \(error.localizedDescription)"
                    }
                    print("❌ Login failed: \(error)")
                }
            }
    }

    private func logout() {
        authorizationRequestID = UUID()
        authMessage = "Logging out..."
        if let accessToken {
            APIService.shared.clearMatchTraderLocalCache(
                accessToken: accessToken
            )
        }
        APIRefreshGate.shared.resetAll()
        TradeAlertNavigationStore.shared.clear()
        _ = Self.credentialsManager.clear()

        DispatchQueue.main.async {
            accessToken = nil
            isLoggedIn = false
            canOpenTradingWorkspace = false
            path = NavigationPath()
        }

        Auth0
            .webAuth()
            .clearSession(federated: true) { result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        authMessage = "Logged out."
                    }
                    print("✅ Auth0 session cleared")

                case .failure(let error):
                    DispatchQueue.main.async {
                        authMessage = "Local logout complete. OES session clear failed: \(error.localizedDescription)"
                    }
                    print("❌ Auth0 logout failed: \(error)")
                }
            }
    }

    private func completeDeletedAccountSignOut() {
        authorizationRequestID = UUID()
        UserDefaults.standard.removeObject(
            forKey: "chaseingreen.custom.watchlist.v1"
        )
        authMessage = "Your ChaseINGreen account was deleted."
        logout()
    }

    private func restoreSessionIfAvailable() {
        guard !didAttemptSessionRestore else {
            return
        }

        didAttemptSessionRestore = true
        print("[Lifecycle] session-restore=start")
        isCheckingAccess = true
        authMessage = "Restoring secure session..."

        Self.credentialsManager.credentials(minTTL: 60) { result in
            switch result {
            case .success(let credentials):
                validateAndActivate(
                    credentials,
                    persistAfterValidation: false,
                    allowOfflineRestore: true
                )

            case .failure:
                DispatchQueue.main.async {
                    isCheckingAccess = false
                    authMessage = nil
                }
            }
        }
    }

    @MainActor
    private func routePendingTradeAlertIfPossible() {
        guard isLoggedIn,
              accessToken != nil,
              canOpenTradingWorkspace,
              let route = alertNavigation.pendingRoute else {
            return
        }

        if !isAlertWorkspaceActive {
            path.append(route)
        }
        alertNavigation.pendingRoute = nil
    }

    @MainActor
    private func refreshInternalWorkspaceAuthorization() async {
        guard isLoggedIn, let accessToken else {
            canOpenTradingWorkspace = false
            return
        }

        let requestID = UUID()
        authorizationRequestID = requestID
        let requestedToken = accessToken

        do {
            let user = try await APIService.shared.fetchCurrentUser(
                accessToken: accessToken,
                forceRefresh: true
            )
            guard authorizationRequestID == requestID,
                  self.accessToken == requestedToken,
                  isLoggedIn else {
                return
            }
            canOpenTradingWorkspace = InternalWorkspaceRoutePolicy.permits(
                .notification,
                authorization: user.internalWorkspaceAuthorization
            )

            if canOpenTradingWorkspace {
                routePendingTradeAlertIfPossible()
            } else {
                // A notification is not an authorization grant. Discard an
                // internal destination that the current server state denies.
                alertNavigation.pendingRoute = nil
            }
        } catch {
            guard authorizationRequestID == requestID,
                  self.accessToken == requestedToken else {
                return
            }
            let nsError = error as NSError
            let isAuthoritativeDenial = nsError.domain == "APIService"
                && (nsError.code == 401 || nsError.code == 403)
            if isAuthoritativeDenial {
                canOpenTradingWorkspace = false
                alertNavigation.pendingRoute = nil
            }
            print(
                "[AuthState] old=authenticated new=\(isAuthoritativeDenial ? "denied" : "authenticated") "
                + "reason=foreground-revalidation-\(isAuthoritativeDenial ? "rejected" : "transient-failure")"
            )
        }
    }

    private func validateAndActivate(
        _ credentials: Credentials,
        persistAfterValidation: Bool,
        allowOfflineRestore: Bool
    ) {
        Task {
            await MainActor.run {
                isCheckingAccess = true
                authMessage = "Verifying account access..."
            }

            do {
                let user = try await APIService.shared.fetchCurrentUser(
                    accessToken: credentials.accessToken,
                    forceRefresh: true
                )

                await MainActor.run {
                    isCheckingAccess = false

                    if user.isBanned {
                        _ = Self.credentialsManager.clear()
                        accessToken = nil
                        isLoggedIn = false
                        canOpenTradingWorkspace = false
                        path = NavigationPath()
                        authMessage = "Account access is blocked."
                        return
                    }

                    if persistAfterValidation {
                        _ = Self.credentialsManager.store(
                            credentials: credentials
                        )
                    }

                    accessToken = credentials.accessToken
                    isLoggedIn = true
                    path = NavigationPath()
                    print("[AuthState] old=restoring new=authenticated reason=validated-session")
                    canOpenTradingWorkspace = InternalWorkspaceRoutePolicy.permits(
                        .restoredNavigation,
                        authorization: user.internalWorkspaceAuthorization
                    )
                    authMessage = "Logged in through OES Secure Access."
                    routePendingTradeAlertIfPossible()
                }

                print("✅ Login and access check succeeded")
            } catch {
                await MainActor.run {
                    isCheckingAccess = false

                    let error = error as NSError
                    let isAuthenticationFailure =
                        error.domain == "APIService"
                        && error.code == 401
                    let isBlockedAccount =
                        error.domain == "APIService"
                        && error.code == 403
                    let isServerFailure =
                        error.domain == "APIService"
                        && (500...599).contains(error.code)
                    let isNetworkFailure =
                        error.domain == NSURLErrorDomain

                    if isAuthenticationFailure {
                        // A token rejected by the API must never be restored
                        // as an offline session. This also clears legacy
                        // Keychain credentials minted without the API audience.
                        _ = Self.credentialsManager.clear()
                        accessToken = nil
                        isLoggedIn = false
                        canOpenTradingWorkspace = false
                        path = NavigationPath()
                        authMessage = (
                            "Your secure session expired or is incompatible. "
                            + "Please sign in again."
                        )
                    } else if isBlockedAccount {
                        _ = Self.credentialsManager.clear()
                        accessToken = nil
                        isLoggedIn = false
                        canOpenTradingWorkspace = false
                        path = NavigationPath()
                        authMessage = "Account access is blocked."
                    } else if allowOfflineRestore
                                && (isNetworkFailure || isServerFailure) {
                        // Backend authorization still protects every API call.
                        // Keep a valid Auth0 session available through a brief
                        // network interruption instead of forcing a new login.
                        accessToken = credentials.accessToken
                        isLoggedIn = true
                        canOpenTradingWorkspace = false
                        path = NavigationPath()
                        print("[AuthState] old=restoring new=authenticated reason=offline-session-preserved")
                        authMessage = (
                            "Session restored. Account services are " +
                            "temporarily unavailable."
                        )
                        routePendingTradeAlertIfPossible()
                    } else {
                        accessToken = nil
                        isLoggedIn = false
                        canOpenTradingWorkspace = false
                        path = NavigationPath()
                        authMessage = (
                            "Account services are temporarily unavailable. "
                            + "Please try again."
                        )
                    }
                }

                print(
                    "❌ Access check failed: "
                    + error.localizedDescription
                )
            }
        }
    }
}

private struct AccountSettingsView: View {
    let accessToken: String
    let onAccountDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deletionError: String?

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Account")
                                .font(.largeTitle.bold())
                                .foregroundStyle(AppTheme.primaryText)
                            Text("Manage your ChaseINGreen account and privacy controls.")
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        NavigationLink {
                            SubscriptionPaywallView(accessToken: accessToken)
                        } label: {
                            Label("Manage Gold Subscription", systemImage: "crown.fill")
                                .font(.headline.bold())
                                .foregroundStyle(AppTheme.gold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(AppTheme.cardBlack)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Delete ChaseINGreen Account")
                                .font(.title3.bold())
                                .foregroundStyle(AppTheme.danger)
                            Text("Deleting your account permanently removes your ChaseINGreen account and associated user data. Your saved trading history, journal information, watchlists, broker connections, preferences, and subscription association will no longer be recoverable.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)

                            if let deletionError {
                                Text(deletionError)
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.danger)
                            }

                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                if isDeleting {
                                    ProgressView().frame(maxWidth: .infinity)
                                } else {
                                    Label("Delete Account", systemImage: "trash")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.danger)
                            .disabled(isDeleting)
                        }
                        .padding()
                        .background(AppTheme.cardBlack)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .padding()
                }
            }
            .navigationTitle("Account & Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(isDeleting)
                }
            }
            .alert(
                "Permanently Delete Account?",
                isPresented: $showingDeleteConfirmation
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Account", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("This cannot be undone. ChaseINGreen will permanently delete your account and associated app data, then sign you out.")
            }
        }
    }

    @MainActor
    private func deleteAccount() async {
        guard !isDeleting else { return }
        isDeleting = true
        deletionError = nil
        defer { isDeleting = false }

        do {
            let response = try await APIService.shared
                .deleteCurrentUserAccount(accessToken: accessToken)
            guard response.success, response.accountDeleted else {
                deletionError = "The server did not confirm account deletion. Your account remains active."
                return
            }
            APIService.shared.clearMatchTraderLocalCache(accessToken: accessToken)
            APIRefreshGate.shared.resetAll()
            TradeAlertNavigationStore.shared.clear()
            onAccountDeleted()
        } catch {
            deletionError = "Account deletion failed. Your account remains active. \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
