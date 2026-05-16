//
//  AppTheme.swift
//  ChaseINGreen
//
//  Created by Otis Young.
//

import SwiftUI

enum AppTheme {
    static let gold = Color(red: 0.86, green: 0.65, blue: 0.25)
    static let softGold = Color(red: 0.98, green: 0.84, blue: 0.48)
    static let richGold = Color(red: 1.00, green: 0.72, blue: 0.20)

    static let deepBlack = Color(red: 0.025, green: 0.025, blue: 0.035)
    static let midnight = Color(red: 0.055, green: 0.055, blue: 0.075)
    static let cardBlack = Color(red: 0.10, green: 0.10, blue: 0.13)

    static let cardStroke = gold.opacity(0.42)

    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.86)
    static let mutedText = Color.white.opacity(0.72)
    static let faintText = Color.white.opacity(0.58)

    static let fieldText = Color.black
    static let fieldBackground = Color.white
    static let fieldPlaceholder = Color.black.opacity(0.45)

    static let success = Color(red: 0.32, green: 0.86, blue: 0.40)
    static let danger = Color(red: 1.00, green: 0.32, blue: 0.32)
    static let warning = Color(red: 1.00, green: 0.62, blue: 0.22)

    static let bodyFont = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let captionFont = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let headlineFont = Font.system(size: 21, weight: .bold, design: .rounded)
    static let titleFont = Font.system(size: 30, weight: .black, design: .rounded)
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
                    AppTheme.midnight,
                    Color(red: 0.10, green: 0.075, blue: 0.025)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    AppTheme.gold.opacity(0.20),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            content
                .foregroundStyle(AppTheme.primaryText)
        }
        .preferredColorScheme(.dark)
    }
}

struct AppCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                LinearGradient(
                    colors: [
                        .white.opacity(0.13),
                        .white.opacity(0.055),
                        AppTheme.gold.opacity(0.08)
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
                                .white.opacity(0.24),
                                AppTheme.cardStroke,
                                .white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: AppTheme.gold.opacity(0.12), radius: 14, x: 0, y: 8)
    }
}

struct AppSectionTitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.headlineFont)
            .foregroundStyle(AppTheme.softGold)
            .shadow(color: .black.opacity(0.75), radius: 1, x: 1, y: 2)
    }
}

struct AppReadableText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.bodyFont)
            .foregroundStyle(AppTheme.secondaryText)
    }
}

struct AppTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(AppTheme.fieldText)
            .tint(AppTheme.gold)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppTheme.fieldBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.gold.opacity(0.35), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCardBackground())
    }

    func appSectionTitle() -> some View {
        modifier(AppSectionTitle())
    }

    func appReadableText() -> some View {
        modifier(AppReadableText())
    }

    func appTextField() -> some View {
        modifier(AppTextFieldStyle())
    }
}
