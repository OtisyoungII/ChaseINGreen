//
//  TradingCalendarViewModel.swift
//  ChaseINGreen
//
//  Created by Otis Young on 6/29/26.
//

import Foundation
import SwiftUI

@MainActor
final class TradingCalendarViewModel: ObservableObject {

    @Published var summary: TradingCalendarSummaryResponse?
    @Published var days: [TradingCalendarDayResponse] = []
    @Published var selectedDay: TradingCalendarDayDetailResponse?

    @Published var isLoading = false
    @Published var errorMessage: String?

    func refresh(
        accessToken: String
    ) async {

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            // Broker history is the authority for closed fills. Calendar
            // refresh remains usable if Aqua is disconnected or temporarily
            // unavailable, but a connected session is reconciled first.
            try? await APIService.shared.syncAquaClosedHistory(
                accessToken: accessToken
            )

            let response = try await APIService.shared.fetchTradingCalendar(
                accessToken: accessToken
            )

            summary = response.summary
            days = response.days

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadDay(
        _ tradeDate: String,
        accessToken: String
    ) async {

        do {
            selectedDay = try await APIService.shared.fetchTradingCalendarDay(
                tradeDate: tradeDate,
                accessToken: accessToken
            )

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearSelection() {
        selectedDay = nil
    }
}
