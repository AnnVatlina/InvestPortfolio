//
//  PortfolioPosition.swift
//  
//
//  Created by Anna on 26.12.25.
//

import Foundation

// Структура ответа API для портфеля
struct PortfolioResponse: Decodable {
    let key: String?
    let acc: [AccountInfo]?
    let pos: [PositionInfo]?
    let errMsg: String?
    let code: Int?
    
    struct AccountInfo: Decodable {
        let curr: String?
        let currval: Double?
        let forecastIn: Double?
        let forecastOut: Double?
        let s: String? // свободные средства
        
        enum CodingKeys: String, CodingKey {
            case curr, currval, s
            case forecastIn = "forecast_in"
            case forecastOut = "forecast_out"
        }
    }
    
    struct PositionInfo: Decodable {
        let accPosId: Int?
        let accruedintA: String?
        let curr: String?
        let currval: Double?
        let fv: Double?
        let go: String?
        let i: String? // Тикер
        let k: Double?
        let q: Double? // Количество
        let s: Double?
        let t: Int?
        let t2In: String?
        let t2Out: String?
        let vm: String?
        let name: String?
        let name2: String?
        let mktPrice: Double? // Рыночная стоимость
        let marketValue: Double?
        let balPriceA: Double? // Балансовая стоимость открытия
        let openBal: Double?
        let priceA: Double? // Балансовая цена открытия (avgPrice)
        let profitClose: Double?
        let profitPrice: Double? // Текущая прибыль
        let closePrice: Double?
        let trade: [TradeInfo]?
        
        enum CodingKeys: String, CodingKey {
            case i, q, s, t, k, curr, currval, fv, go, vm, name, name2, trade
            case accPosId = "acc_pos_id"
            case accruedintA = "accruedint_a"
            case t2In = "t2_in"
            case t2Out = "t2_out"
            case mktPrice = "mkt_price"
            case marketValue = "market_value"
            case balPriceA = "bal_price_a"
            case openBal = "open_bal"
            case priceA = "price_a"
            case profitClose = "profit_close"
            case profitPrice = "profit_price"
            case closePrice = "close_price"
        }
        
        struct TradeInfo: Decodable {
            let tradeCount: Int?
            
            enum CodingKeys: String, CodingKey {
                case tradeCount = "trade_count"
            }
        }
    }
}

struct PortfolioPosition: Identifiable, Decodable {
    let id = UUID()
    let ticker: String
    let quantity: Double
    let avgPrice: Double
    let currentPrice: Double
    let profit: Double
    let name: String?
    let currency: String?
    
    // Инициализатор из PositionInfo
    init(from positionInfo: PortfolioResponse.PositionInfo) {
        self.ticker = positionInfo.i ?? ""
        self.quantity = positionInfo.q ?? 0.0
        self.avgPrice = positionInfo.priceA ?? 0.0
        self.currentPrice = positionInfo.mktPrice ?? 0.0
        self.profit = positionInfo.profitPrice ?? 0.0
        self.name = positionInfo.name
        self.currency = positionInfo.curr
    }
}
