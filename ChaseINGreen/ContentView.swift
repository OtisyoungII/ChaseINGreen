//
//  ContentView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 8/6/25.
//

import SwiftUI
import Auth0

struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var accessToken: String?
    @State private var path: [String] = []
    @State private var authMessage: String?
    @State private var glowPulse = false
    @State private var pressedButton: String?
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack(path: $path) {
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
            .onAppear {
                glowPulse = true
            }
            .sheet(isPresented: $showingPaywall) {
                SubscriptionPaywallView()
            }
            .navigationDestination(for: String.self) { route in
                if route == "dashboard", let token = accessToken {
                    DashboardView(accessToken: token)
                        .toolbar {
                            ToolbarItem(placement: .automatic) {
                                Button("Logout") {
                                    logout()
                                }
                                .foregroundStyle(AppTheme.danger)
                            }
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
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Powered by Otis Execution Systems")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.softGold.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: 14) {
            if isLoggedIn {
                glassButton(
                    id: "dashboard",
                    title: "Go to Dashboard",
                    subtitle: "Open live market view",
                    systemImage: "chart.line.uptrend.xyaxis",
                    tint: AppTheme.gold
                ) {
                    path.append("dashboard")
                }

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
                    title: "OES Secure Login",
                    subtitle: "Access your dashboard",
                    systemImage: "lock.shield.fill",
                    tint: AppTheme.gold
                ) {
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
            .lineLimit(2)
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
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
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
            .scope("openid profile email")
            .start { result in
                switch result {
                case .success(let credentials):
                    DispatchQueue.main.async {
                        accessToken = credentials.accessToken
                        isLoggedIn = true
                        authMessage = "Logged in through OES Secure Access."
                    }
                    print("✅ Login succeeded")

                case .failure(let error):
                    DispatchQueue.main.async {
                        authMessage = "Login failed: \(error.localizedDescription)"
                    }
                    print("❌ Login failed: \(error)")
                }
            }
    }

    private func logout() {
        authMessage = "Logging out..."

        DispatchQueue.main.async {
            accessToken = nil
            isLoggedIn = false
            path.removeAll()
        }

        Auth0
            .webAuth()
            .clearSession { result in
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
}

#Preview {
    ContentView()
}
