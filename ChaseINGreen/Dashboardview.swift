//
//  Dashboardview.swift
//  ChaseINGreen
//
//  Created by Otis Young on 8/6/25.
//

import SwiftUI

struct DashboardView: View {
    let accessToken: String
    @State private var responseMessage: String = "Loading..."
    
    var body: some View {
        VStack(spacing: 20) {
            Text("📊 Dashboard")
                .font(.largeTitle)
            
            Text("🔐 API Response:")
                .bold()
            
            
            Text(responseMessage)
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
        .onAppear {
            fetchProtectedData()
        }
    }
    
    func fetchProtectedData() {
        // Replace the IP with your machine's local IP address for simulator access
        guard let url = URL(string: "https://fcbd1044a461.ngrok-free.app/protected-endpoint") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Request error: \(error)")
                return
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.responseMessage = responseString
                }
            }
        }.resume()
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView(accessToken: "dummy-access-token")
    }
}
