//
//  InvestPortfolioWidgetsBundle.swift
//  InvestPortfolioWidgets
//
//  Created by Anna on 20.09.2026.
//

import WidgetKit
import SwiftUI

@main
struct InvestPortfolioWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SubscriptionsWidget()
        DepositsWidget()
    }
}
