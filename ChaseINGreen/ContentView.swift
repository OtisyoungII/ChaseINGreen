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

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 20) {
                Text("ChaseINGreen")
                    .font(.largeTitle.bold())

                if let authMessage {
                    Text(authMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if isLoggedIn {
                    Button("Go to Dashboard") {
                        path.append("dashboard")
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Logout / Switch Account") {
                        logout()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button("Login with Auth0") {
                        login()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationDestination(for: String.self) { route in
                if route == "dashboard", let token = accessToken {
                    DashboardView(accessToken: token)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Logout") {
                                    logout()
                                }
                                .tint(.red)
                            }
                        }
                }
            }
        }
    }

    private func login() {
        authMessage = "Opening login..."

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
                        authMessage = "Logged in."
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
                        authMessage = "Local logout complete. Auth0 session clear failed: \(error.localizedDescription)"
                    }
                    print("❌ Auth0 logout failed: \(error)")
                }
            }
    }
}

#Preview {
    ContentView()
}
