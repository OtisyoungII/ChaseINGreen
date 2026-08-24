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
    enum Scope: String, CaseIterable, Identifiable {
        case month = "Month"
        case all = "All"

        var id: String { rawValue }
    }

    private struct CachedCalendar {
        let response: TradingCalendarResponse
        let savedAt: Date
    }

    private static var calendarCache: [
        String: CachedCalendar
    ] = [:]
    private static var dayCache: [
        String: TradingCalendarDayDetailResponse
    ] = [:]
    private static var reconciledOwners: Set<String> = []
    private static let cacheLimit = 24

    @Published var summary: TradingCalendarSummaryResponse?
    @Published var days: [TradingCalendarDayResponse] = []
    @Published var selectedDay: TradingCalendarDayDetailResponse?

    @Published var isLoading = false
    @Published var errorMessage: String?

    func refresh(
        accessToken: String,
        scope: Scope = .month,
        month: Date = Date(),
        force: Bool = false
    ) async {
        errorMessage = nil
        let bounds = Self.bounds(
            for: scope,
            month: month
        )
        let ownerScope = APIRefreshKey.ownerScope(
            accessToken: accessToken
        )
        let cacheKey = "\(ownerScope):\(bounds.cacheKey)"

        if !force,
           let cached = Self.calendarCache[cacheKey],
           Date().timeIntervalSince(cached.savedAt)
                < bounds.cacheLifetime {
            apply(cached.response)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Calendar delivery is intentionally independent from broker
            // reconciliation. Aqua/Match-Trader history may be slow,
            // disconnected, or unavailable and must never delay the calendar.
            //
            // Closed-history reconciliation has its own lifecycle elsewhere.
            let response = try await APIService.shared.fetchTradingCalendar(
                startDate: bounds.startDate,
                endDate: bounds.endDate,
                accessToken: accessToken
            )

            Self.calendarCache[cacheKey] = CachedCalendar(
                response: response,
                savedAt: Date()
            )
            Self.trimCalendarCache()
            apply(response)

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadDay(
        _ tradeDate: String,
        accessToken: String
    ) async {
        let ownerScope = APIRefreshKey.ownerScope(
            accessToken: accessToken
        )
        let cacheKey = "\(ownerScope):\(tradeDate)"

        if let cached = Self.dayCache[cacheKey] {
            selectedDay = cached
            return
        }

        do {
            let detail = try await APIService.shared.fetchTradingCalendarDay(
                tradeDate: tradeDate,
                accessToken: accessToken
            )
            Self.dayCache[cacheKey] = detail
            if Self.dayCache.count > Self.cacheLimit {
                Self.dayCache.removeValue(
                    forKey: Self.dayCache.keys.sorted().first ?? ""
                )
            }
            selectedDay = detail

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearSelection() {
        selectedDay = nil
    }

    private func apply(
        _ response: TradingCalendarResponse
    ) {
        summary = response.summary
        days = response.days.sorted {
            $0.tradeDate > $1.tradeDate
        }
    }

    private static func bounds(
        for scope: Scope,
        month: Date
    ) -> (
        startDate: String?,
        endDate: String?,
        cacheKey: String,
        cacheLifetime: TimeInterval
    ) {
        guard scope == .month else {
            return (
                nil,
                nil,
                "all",
                600
            )
        }

        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(
            from: calendar.dateComponents(
                [.year, .month],
                from: month
            )
        ) ?? month
        let end = calendar.date(
            byAdding: DateComponents(
                month: 1,
                day: -1
            ),
            to: start
        ) ?? start
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let monthKey = formatter.string(from: start)
            .prefix(7)

        return (
            formatter.string(from: start),
            formatter.string(from: end),
            "month:\(monthKey)",
            calendar.isDate(
                start,
                equalTo: Date(),
                toGranularity: .month
            ) ? 120 : 3600
        )
    }

    private static func trimCalendarCache() {
        let overflow = calendarCache.count - cacheLimit
        guard overflow > 0 else { return }

        let oldestKeys = calendarCache
            .sorted { $0.value.savedAt < $1.value.savedAt }
            .prefix(overflow)
            .map(\.key)

        for key in oldestKeys {
            calendarCache.removeValue(forKey: key)
        }
    }
}
