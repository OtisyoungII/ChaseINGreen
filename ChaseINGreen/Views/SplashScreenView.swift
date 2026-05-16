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
                Image("ChaseINGreenIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: AppTheme.gold.opacity(glow ? 0.75 : 0.25), radius: glow ? 28 : 10)
                    .scaleEffect(scale ? 1.04 : 0.98)

                Text("ChaseINGreen")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.softGold, AppTheme.gold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: AppTheme.gold.opacity(0.45), radius: 8, x: 0, y: 4)

                Text("Trade smarter. Protect profits.")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
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
