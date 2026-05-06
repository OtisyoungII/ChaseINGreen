//
//  TradeActionPrompt.swift
//  ChaseINGreen
//
//  Created by Otis Young on 4/27/26.
//

import Foundation

enum TradeActionPrompt: Identifiable {
    case editTrade(LoggedTradeResponse)
    case brokerPrice(LoggedTradeResponse)
    case stopLoss(LoggedTradeResponse)
    case clearStopLoss(LoggedTradeResponse)
    case takeProfit(LoggedTradeResponse)
    case clearTakeProfit(LoggedTradeResponse)
    case quantity(LoggedTradeResponse)
    case reduce(LoggedTradeResponse)
    case add(LoggedTradeResponse)
    case close(LoggedTradeResponse)
    case stopLossHit(LoggedTradeResponse)
    case takeProfitHit(LoggedTradeResponse)

    var id: String {
        "\(title)-\(trade.id.uuidString)"
    }

    var title: String {
        switch self {
        case .editTrade: return "Edit Trade"
        case .brokerPrice: return "Update Broker Price"
        case .stopLoss: return "Set Stop Loss"
        case .clearStopLoss: return "Remove Stop Loss"
        case .takeProfit: return "Set Take Profit"
        case .clearTakeProfit: return "Remove Take Profit"
        case .quantity: return "Update Quantity"
        case .reduce: return "Reduce Position"
        case .add: return "Add to Position"
        case .close: return "Close Trade"
        case .stopLossHit: return "Stop Loss Hit"
        case .takeProfitHit: return "Take Profit Hit"
        }
    }

    var trade: LoggedTradeResponse {
        switch self {
        case .editTrade(let trade),
             .brokerPrice(let trade),
             .stopLoss(let trade),
             .clearStopLoss(let trade),
             .takeProfit(let trade),
             .clearTakeProfit(let trade),
             .quantity(let trade),
             .reduce(let trade),
             .add(let trade),
             .close(let trade),
             .stopLossHit(let trade),
             .takeProfitHit(let trade):
            return trade
        }
    }

    var needsValue: Bool {
        switch self {
        case .editTrade, .clearStopLoss, .clearTakeProfit:
            return false
        default:
            return true
        }
    }

    func defaultValue(currentQuotePrice: Double?) -> Double? {
        switch self {
        case .editTrade:
            return nil
        case .brokerPrice(let trade):
            return trade.currentPrice ?? currentQuotePrice
        case .stopLoss(let trade):
            return trade.stopLoss
        case .takeProfit(let trade):
            return trade.takeProfit
        case .quantity(let trade), .reduce(let trade):
            return trade.quantity
        case .add:
            return nil
        case .close(let trade):
            return trade.currentPrice ?? currentQuotePrice
        case .stopLossHit(let trade):
            return trade.stopLoss ?? trade.currentPrice ?? currentQuotePrice
        case .takeProfitHit(let trade):
            return trade.takeProfit ?? trade.currentPrice ?? currentQuotePrice
        case .clearStopLoss, .clearTakeProfit:
            return nil
        }
    }
}
