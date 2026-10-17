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
    private struct CachedDay { let response: TradingCalendarDayDetailResponse; let savedAt: Date }
    private var summaryGeneration = LedgerRequestGeneration()
    private var selectedAccountKey: String?
    private var selectedTimezone: String?

    private static var dayCache: [
        String: CachedDay
    ] = [:]
    private static var dayTaskIDs: [String: UUID] = [:]
    private static var dayTasks: [
        String: Task<TradingCalendarDayDetailResponse, Error>
    ] = [:]
    private static var dayRetryAfter: [String: Date] = [:]
    private static let cacheLimit = 24
    @Published private var daySelection = CalendarDaySelection<TradingCalendarDayDetailResponse>()

    @Published var summary: TradingCalendarSummaryResponse?
    @Published var days: [TradingCalendarDayResponse] = []
    var selectedDay: TradingCalendarDayDetailResponse? { daySelection.detail }
    var selectedDate: String? { daySelection.date }
    @Published var dayErrorMessage: String?

    @Published var isLoading = false
    @Published var isLoadingDay = false
    @Published var errorMessage: String?

    static func invalidateLedgerTruth() {
        calendarCache.removeAll()
        dayCache.removeAll()
        dayTasks.values.forEach { $0.cancel() }
        dayTasks.removeAll()
        dayTaskIDs.removeAll()
        dayRetryAfter.removeAll()
    }

    func refresh(
        accessToken: String,
        scope: Scope = .month,
        month: Date = Date(),
        force: Bool = false,
        accountKey: String? = nil
    ) async {
        let timezone = TimeZone.autoupdatingCurrent.identifier
        let generation = summaryGeneration.begin()
        if selectedTimezone != timezone { clearSelection() }
        selectedTimezone = timezone
        let revision = LedgerTruthRevision.current
        if selectedAccountKey != accountKey { clearSelection() }
        selectedAccountKey = accountKey
        errorMessage = nil
        let bounds = Self.bounds(
            for: scope,
            month: month, timezone: timezone
        )
        let ownerScope = APIRefreshKey.ownerScope(
            accessToken: accessToken
        )
        let cacheKey = LaunchAccountingPolicy.calendarCacheKey(owner: ownerScope, account: accountKey, scope: bounds.cacheKey, timezone: timezone)

        if !force,
           let cached = Self.calendarCache[cacheKey],
           Date().timeIntervalSince(cached.savedAt)
                < bounds.cacheLifetime {
            apply(cached.response)
            isLoading = false
            return
        }

        isLoading = summary == nil && days.isEmpty
        defer { if summaryGeneration.accepts(generation) { isLoading = false } }

        do {
            // Calendar delivery is intentionally independent from broker
            // reconciliation. Aqua/Match-Trader history may be slow,
            // disconnected, or unavailable and must never delay the calendar.
            //
            // Closed-history reconciliation has its own lifecycle elsewhere.
            let response = try await APIService.shared.fetchTradingCalendar(
                startDate: bounds.startDate,
                endDate: bounds.endDate,
                accountKey: accountKey,
                timezone: timezone,
                accessToken: accessToken
            )

            guard timezone == TimeZone.autoupdatingCurrent.identifier, summaryGeneration.accepts(generation), revision == LedgerTruthRevision.current else { return }
            Self.calendarCache[cacheKey] = CachedCalendar(
                response: response,
                savedAt: Date()
            )
            Self.trimCalendarCache()
            apply(response)
            if force, let date = selectedDate {
                await loadDay(date, accessToken: accessToken, force: true)
            }

        } catch {
            guard timezone == TimeZone.autoupdatingCurrent.identifier, summaryGeneration.accepts(generation), revision == LedgerTruthRevision.current else { return }
            if CalendarDaySelection<TradingCalendarDayDetailResponse>.isCancellation(error) { return }
            errorMessage = error.localizedDescription
            #if DEBUG
            print("[Calendar] action=failed stage=request-or-decode scope=summary error=\(error)")
            #endif
        }
    }

    func loadDay(
        _ tradeDate: String,
        accessToken: String,
        force: Bool = false
    ) async {
        let revision = LedgerTruthRevision.current
        let timezone = TimeZone.autoupdatingCurrent.identifier
        let accountKey = selectedAccountKey
        let requestID = daySelection.begin(tradeDate)
        isLoadingDay = true
        dayErrorMessage = nil
        let ownerScope = APIRefreshKey.ownerScope(
            accessToken: accessToken
        )
        let cacheKey = LaunchAccountingPolicy.calendarCacheKey(owner: ownerScope, account: accountKey, scope: tradeDate, timezone: timezone)
        print("[Calendar] date=\(tradeDate) generation=\(requestID) action=start")
        defer {
            if daySelection.requestID == requestID {
                isLoadingDay = false
                print("[Calendar] date=\(tradeDate) generation=\(requestID) spinner=false")
            }
        }

        if force {
            Self.dayTasks.removeValue(forKey: cacheKey)?.cancel()
            Self.dayTaskIDs.removeValue(forKey: cacheKey)
            Self.dayCache.removeValue(forKey: cacheKey)
            Self.dayRetryAfter.removeValue(forKey: cacheKey)
        }
        if let cached = Self.dayCache[cacheKey], LedgerTruthPolicy.fresh(savedAt: cached.savedAt) {
            if daySelection.requestID == requestID {
                daySelection.complete(cached.response, request: requestID)
                print("[Calendar] date=\(tradeDate) generation=\(requestID) action=complete-cache")
            }
            return
        }

        if let retryAfter = Self.dayRetryAfter[cacheKey], retryAfter > Date() {
            isLoadingDay = false
            dayErrorMessage = "Day details are temporarily unavailable. Please try again shortly."
            print("[Calendar] date=\(tradeDate) generation=\(requestID) action=cooldown")
            return
        }

        let task: Task<TradingCalendarDayDetailResponse, Error>
        if let existing = Self.dayTasks[cacheKey] {
            task = existing
            print("[Calendar] date=\(tradeDate) generation=\(requestID) action=coalesced")
        } else {
            task = Task {
                try await APIService.shared.fetchTradingCalendarDay(
                    tradeDate: tradeDate,
                    accountKey: accountKey,
                    timezone: timezone,
                    accessToken: accessToken
                )
            }
            Self.dayTasks[cacheKey] = task
            Self.dayTaskIDs[cacheKey] = UUID()
        }

        let taskID = Self.dayTaskIDs[cacheKey]
        do {
            let detail = try await task.value
            guard timezone == TimeZone.autoupdatingCurrent.identifier, revision == LedgerTruthRevision.current, Self.dayTaskIDs[cacheKey] == taskID else { return }
            Self.dayTasks.removeValue(forKey: cacheKey)
            Self.dayCache[cacheKey] = CachedDay(response: detail, savedAt: Date())
            Self.dayRetryAfter.removeValue(forKey: cacheKey)
            if Self.dayCache.count > Self.cacheLimit {
                let oldestKey = Self.dayCache.min { $0.value.savedAt < $1.value.savedAt }?.key ?? ""
                Self.dayCache.removeValue(forKey: oldestKey)
                Self.dayTaskIDs.removeValue(forKey: oldestKey)
            }
            guard daySelection.requestID == requestID else { return }
            daySelection.complete(detail, request: requestID)
            print("[Calendar] date=\(tradeDate) generation=\(requestID) action=complete")

        } catch {
            guard timezone == TimeZone.autoupdatingCurrent.identifier, revision == LedgerTruthRevision.current, Self.dayTaskIDs[cacheKey] == taskID else { return }
            Self.dayTasks.removeValue(forKey: cacheKey)
            guard daySelection.requestID == requestID else { return }
            if CalendarDaySelection<TradingCalendarDayDetailResponse>.isCancellation(error) {
                daySelection.cancel(request: requestID)
                print("[Calendar] date=\(tradeDate) generation=\(requestID) action=cancelled")
                return
            }
            dayErrorMessage = error.localizedDescription
            Self.dayRetryAfter[cacheKey] = Date().addingTimeInterval(60)
            if Self.dayRetryAfter.count > Self.cacheLimit {
                let key = Self.dayRetryAfter.keys.sorted().first ?? ""
                Self.dayRetryAfter.removeValue(forKey: key)
                Self.dayTaskIDs.removeValue(forKey: key)
            }
            #if DEBUG
            print("[Calendar] date=\(tradeDate) generation=\(requestID) action=failed stage=request-or-decode error=\(error)")
            #else
            print("[Calendar] date=\(tradeDate) generation=\(requestID) action=failed")
            #endif
        }
    }

    func clearSelection() {
        daySelection.clear()
        isLoadingDay = false
        dayErrorMessage = nil
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
        month: Date, timezone: String
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

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezone) ?? .gmt
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
        formatter.timeZone = calendar.timeZone
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
