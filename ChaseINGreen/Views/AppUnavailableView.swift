//
//  AppUnavailableView.swift
//  ChaseINGreen
//
//  Created by Otis Young on 5/16/26.
//


import SwiftUI

struct AppUnavailableView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(AppTheme.gold)

            Text(title)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(
            LinearGradient(
                colors: [
                    .white.opacity(0.13),
                    .white.opacity(0.05),
                    AppTheme.gold.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(AppTheme.gold.opacity(0.35), lineWidth: 1.2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}