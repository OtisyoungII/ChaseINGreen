//
//  SplashScreenView.swift
//  ChaseINGreen
//

import SwiftUI

struct SplashScreenView: View {
    @State private var glow = false
    @State private var scale = false

    var body: some View {
        AppBackground {
            VStack(spacing: 22) {
                Image("OESystemsLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: AppTheme.gold.opacity(glow ? 0.75 : 0.25), radius: glow ? 28 : 10)
                    .scaleEffect(scale ? 1.04 : 0.98)

                Text("Otis Execution Systems")
                    .font(.system(size: 32, weight: .black))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.softGold, AppTheme.gold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: AppTheme.gold.opacity(0.45), radius: 8, x: 0, y: 4)

                Text("Launching ChaseINGreen")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)

                Text("Trade smarter. Protect profits.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.mutedText)
            }
            .padding(28)
            .appCard()
            .padding(28)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                glow = true
                scale = true
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
