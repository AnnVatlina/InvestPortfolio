//
//  CashOperation.swift
//  
//
//  Created by Anna on 26.12.25.
//

import Foundation

struct CashOperation: Identifiable, Decodable {
    let id = UUID()
    let date: String
    let type: String
    let amount: Double
    let currency: String
    let comment: String?
}
