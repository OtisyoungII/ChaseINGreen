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

    var body: some View {
        NavigationStack(path: $path) {
            AppBackground {
                VStack(spacing: 24) {
                    Spacer(minLength: 20)

                    oesBrandBar

                    heroSection

                    if let authMessage {
                        statusMessage(authMessage)
                    }

                    actionSection

                    Spacer(minLength: 20)

                    footerSection
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 28)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
            .onAppear {
                glowPulse = true
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

                Text("OES Secure Access")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
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
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(AppTheme.gold.opacity(glowPulse ? 0.32 : 0.12))
                    .frame(width: 190, height: 190)
                    .blur(radius: 18)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: glowPulse)

                RoundedRectangle(cornerRadius: 38)
                    .fill(.white.opacity(0.08))
                    .frame(width: 172, height: 172)
                    .overlay {
                        RoundedRectangle(cornerRadius: 38)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        AppTheme.softGold.opacity(0.95),
                                        .white.opacity(0.28),
                                        AppTheme.gold.opacity(0.75)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                    .shadow(color: AppTheme.gold.opacity(0.28), radius: 22, x: 0, y: 12)

                Image("ChaseINGreenIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 118, height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    .shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 8)
            }

            VStack(spacing: 8) {
                Text("ChaseINGreen")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .white,
                                AppTheme.softGold,
                                AppTheme.gold
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.75), radius: 1, x: 1, y: 2)
                    .shadow(color: AppTheme.gold.opacity(0.35), radius: 14, x: 0, y: 6)

                Text("Market context. Trade alerts. Profit protection.")
                    .font(.system(size: 17, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.secondaryText)

                Text("Powered by Otis Execution Systems")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.softGold.opacity(0.9))
                    .padding(.top, 2)
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
                    id: "logout",
                    title: "Logout / Switch Account",
                    subtitle: "Clear OES secure session",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    tint: AppTheme.danger
                ) {
                    logout()
                }
            } else {
                glassButton(
                    id: "login",
                    title: "Login with OES Secure Access",
                    subtitle: "Secure access to your ChaseINGreen dashboard",
                    systemImage: "lock.shield.fill",
                    tint: AppTheme.gold
                ) {
                    login()
                }
            }
        }
        .padding(.top, 8)
    }

    private var footerSection: some View {
        VStack(spacing: 6) {
            Text("Version 1")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.softGold)

            Text("An Otis Execution Systems product.")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)

            Text("Built for traders who want cleaner context before making decisions.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.mutedText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }

    private func statusMessage(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .multilineTextAlignment(.center)
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
                        .frame(width: 48, height: 48)

                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

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
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.35),
                                tint.opacity(0.45),
                                .white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .scaleEffect(pressedButton == id ? 0.97 : 1.0)
            .shadow(color: tint.opacity(0.20), radius: pressedButton == id ? 5 : 16, x: 0, y: pressedButton == id ? 3 : 10)
        }
        .buttonStyle(.plain)
    }

    private func login() {
        authMessage = "Opening OES secure login..."

        Auth0
            .webAuth()
            .audience("https://myapi.ChaseINGreen.com")
            .scope("openid profile email")
            .parameters(["prompt": "login"])
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
                        authMessage = "Logged out. You can switch accounts now."
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
