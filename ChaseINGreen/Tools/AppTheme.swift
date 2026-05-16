//
//  AppTheme.swift
//  ChaseINGreen
//
//  Created by Otis Young.
//

import SwiftUI

enum AppTheme {
    static let gold = Color(red: 0.86, green: 0.65, blue: 0.25)
    static let softGold = Color(red: 0.96, green: 0.83, blue: 0.45)
    static let deepBlack = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let cardBlack = Color(red: 0.09, green: 0.09, blue: 0.11)
    static let cardStroke = Color(red: 0.86, green: 0.65, blue: 0.25).opacity(0.35)

    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.72)
    static let mutedText = Color.white.opacity(0.55)

    static let success = Color.green
    static let danger = Color.red
    static let warning = Color.orange

    static let bodyFont = Font.system(size: 17, weight: .regular)
    static let captionFont = Font.system(size: 15, weight: .regular)
    static let headlineFont = Font.system(size: 20, weight: .semibold)
    static let titleFont = Font.system(size: 28, weight: .bold)
}

struct AppBackground<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.deepBlack,
                    Color(red: 0.08, green: 0.08, blue: 0.10),
                    Color(red: 0.10, green: 0.08, blue: 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content
        }
    }
}

struct AppCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(AppTheme.cardBlack.opacity(0.92))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCardBackground())
    }
}
