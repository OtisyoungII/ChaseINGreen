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

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 20) {
                if isLoggedIn {
                    Button("Go to Dashboard") {
                        path.append("dashboard")
                    }
                } else {
                    Button("Login with Auth0") {
                        login()
                    }
                }
            }
            .navigationDestination(for: String.self) { route in
                if route == "dashboard", let token = accessToken {
                    DashboardView(accessToken: token)
                }
            }
            .padding()
        }
    }

    func login() {
        Auth0
            .webAuth()
            .audience("https://myapi.ChaseINGreen.com")
            .scope("openid profile email")
            .start { result in
                switch result {
                case .success(let credentials):
                    DispatchQueue.main.async {
                        accessToken = credentials.accessToken
                        isLoggedIn = true
                    }
                    print("✅ Login succeeded")
                case .failure(let error):
                    print("❌ Login failed: \(error)")
                }
            }
    }
}

#Preview {
    ContentView()
}
