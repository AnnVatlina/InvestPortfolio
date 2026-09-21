//
//  SampleDataService.swift
//  InvestPortfolio
//
//  Generates realistic sample deposits and subscriptions for onboarding demo.
//

import Foundation

enum SampleDataService {

    // MARK: - Public

    static func load(into container: DIContainer) async throws {
        let depositsService = container.makeDepositsService()
        let subscriptionsService = container.makeSubscriptionsService()
        for d in sampleDeposits {
            try await depositsService.add(d)
        }
        for s in sampleSubscriptions {
            try await subscriptionsService.add(s)
        }
    }

    // MARK: - Deposits (10 items, mixed currencies, 2024–2026)

    private static var sampleDeposits: [Deposit] {[
        // ── Closed ──────────────────────────────────────────────────────────
        Deposit(
            title: "Вклад «Сохраняй»",
            bankName: "Сбербанк",
            amount: 500_000,
            currency: .RUB,
            createdAt: d(2024, 1, 10),
            openDate:  d(2024, 1, 15),
            closeDate: d(2025, 1, 15),
            annualInterestRate: 12.5
        ),
        Deposit(
            title: "Накопительный",
            bankName: "ВТБ",
            amount: 300_000,
            currency: .RUB,
            createdAt: d(2024, 2, 25),
            openDate:  d(2024, 3, 1),
            closeDate: d(2024, 9, 1),
            annualInterestRate: 13.0
        ),
        Deposit(
            title: "Вклад «Прибыльный»",
            bankName: "Тинькофф",
            amount: 1_000_000,
            currency: .RUB,
            createdAt: d(2024, 5, 28),
            openDate:  d(2024, 6, 1),
            closeDate: d(2025, 6, 1),
            annualInterestRate: 14.0
        ),
        Deposit(
            title: "USD Savings",
            bankName: "Альфа-Банк",
            amount: 5_000,
            currency: .USD,
            createdAt: d(2024, 1, 29),
            openDate:  d(2024, 2, 1),
            closeDate: d(2025, 2, 1),
            annualInterestRate: 4.5
        ),
        Deposit(
            title: "Срочный вклад",
            bankName: "Газпромбанк",
            amount: 700_000,
            currency: .RUB,
            createdAt: d(2024, 8, 28),
            openDate:  d(2024, 9, 1),
            closeDate: d(2025, 3, 1),
            annualInterestRate: 15.0
        ),
        Deposit(
            title: "Новогодний вклад",
            bankName: "Сбербанк",
            amount: 200_000,
            currency: .RUB,
            createdAt: d(2025, 1, 10),
            openDate:  d(2025, 1, 15),
            closeDate: d(2025, 7, 15),
            annualInterestRate: 16.0
        ),

        // ── Active ───────────────────────────────────────────────────────────
        Deposit(
            title: "USD Growth",
            bankName: "ВТБ",
            amount: 10_000,
            currency: .USD,
            createdAt: d(2024, 6, 28),
            openDate:  d(2024, 7, 1),
            closeDate: nil,
            annualInterestRate: 5.0,
            interestType: .capitalized,
            capitalizationPeriod: .monthly
        ),
        Deposit(
            title: "EUR Reserve",
            bankName: "Тинькофф",
            amount: 3_000,
            currency: .EUR,
            createdAt: d(2025, 2, 25),
            openDate:  d(2025, 3, 1),
            closeDate: d(2026, 9, 1),
            annualInterestRate: 3.5
        ),
        Deposit(
            title: "Вклад «Максимальный»",
            bankName: "Альфа-Банк",
            amount: 1_500_000,
            currency: .RUB,
            createdAt: d(2025, 5, 28),
            openDate:  d(2025, 6, 1),
            closeDate: d(2026, 6, 1),
            annualInterestRate: 17.0,
            interestType: .capitalized,
            capitalizationPeriod: .quarterly
        ),
        Deposit(
            title: "GEL Deposit",
            bankName: "Газпромбанк",
            amount: 8_000,
            currency: .GEL,
            createdAt: d(2024, 9, 28),
            openDate:  d(2024, 10, 1),
            closeDate: d(2026, 10, 1),
            annualInterestRate: 9.0
        ),
    ]}

    // MARK: - Subscriptions (20 items, all USD)

    private static var sampleSubscriptions: [Subscription] {[

        // ── One-time purchases (5) ───────────────────────────────────────────
        Subscription(
            title: "Sketch",
            amount: 99.00,
            currency: .USD,
            billingCycle: .oneTime,
            startDate: d(2024, 3, 15),
            category: "Design",
            iconName: "cpu.fill",
            isActive: true
        ),
        Subscription(
            title: "Affinity Photo 2",
            amount: 69.99,
            currency: .USD,
            billingCycle: .oneTime,
            startDate: d(2024, 5, 20),
            category: "Design",
            iconName: "waveform",
            isActive: true
        ),
        Subscription(
            title: "Setapp Lifetime",
            amount: 149.00,
            currency: .USD,
            billingCycle: .oneTime,
            startDate: d(2024, 8, 10),
            category: "Productivity",
            iconName: "cloud.fill",
            isActive: true
        ),
        Subscription(
            title: "Final Cut Pro",
            amount: 299.99,
            currency: .USD,
            billingCycle: .oneTime,
            startDate: d(2025, 1, 10),
            category: "Video",
            iconName: "waveform",
            isActive: true
        ),
        Subscription(
            title: "Logic Pro",
            amount: 199.99,
            currency: .USD,
            billingCycle: .oneTime,
            startDate: d(2025, 4, 20),
            category: "Music",
            iconName: "music.note",
            isActive: true
        ),

        // ── Cancelled (5) ────────────────────────────────────────────────────
        Subscription(
            title: "Hulu",
            amount: 7.99,
            currency: .USD,
            billingCycle: .monthly,
            startDate: d(2024, 2, 1),
            category: "Streaming",
            iconName: "tv.fill",
            isActive: false,
            endDate: d(2024, 6, 15)
        ),
        Subscription(
            title: "Adobe Creative Cloud",
            amount: 54.99,
            currency: .USD,
            billingCycle: .monthly,
            startDate: d(2024, 1, 10),
            category: "Design",
            iconName: "waveform",
            isActive: false,
            endDate: d(2024, 9, 30)
        ),
        Subscription(
            title: "Xbox Game Pass",
            amount: 14.99,
            currency: .USD,
            billingCycle: .monthly,
            startDate: d(2024, 4, 1),
            category: "Gaming",
            iconName: "gamecontroller.fill",
            isActive: false,
            endDate: d(2024, 12, 31)
        ),
        Subscription(
            title: "LinkedIn Premium",
            amount: 39.99,
            currency: .USD,
            billingCycle: .monthly,
            startDate: d(2024, 3, 15),
            category: "Career",
            iconName: "envelope.fill",
            isActive: false,
            endDate: d(2025, 1, 15)
        ),
        Subscription(
            title: "Duolingo Super",
            amount: 6.99,
            currency: .USD,
            billingCycle: .monthly,
            startDate: d(2025, 1, 1),
            category: "Education",
            iconName: "book.fill",
            isActive: false,
            endDate: d(2025, 6, 1)
        ),

        // ── Active monthly (5) ───────────────────────────────────────────────
        Subscription(
            title: "Netflix",
            amount: 15.49,
            currency: .USD,
            billingCycle: .monthly,
            startDate: d(2024, 2, 15),
            category: "Streaming",
            iconName: "tv.fill",
            isActive: true
        ),
        Subscription(
            title: "Spotify",
            amount: 9.99,
            currency: .USD,
            billingCycle: .monthly,
            startDate: d(2024, 1, 20),
            category: "Music",
            iconName: "music.note",
            isActive: true
        ),
        Subscription(
            title: "iCloud+ 200 GB",
            amount: 2.99,
            currency: .USD,
            billingCycle: .monthly,
            startDate: d(2024, 3, 1),
            category: "Cloud",
            iconName: "cloud.fill",
            isActive: true
        ),
        Subscription(
            title: "YouTube Premium",
            amount: 13.99,
            currency: .USD,
            billingCycle: .monthly,
            startDate: d(2024, 7, 10),
            category: "Streaming",
            iconName: "tv.fill",
            isActive: true
        ),
        Subscription(
            title: "ChatGPT Plus",
            amount: 20.00,
            currency: .USD,
            billingCycle: .monthly,
            startDate: d(2024, 11, 1),
            category: "AI",
            iconName: "cpu.fill",
            isActive: true
        ),

        // ── Active yearly (5) ────────────────────────────────────────────────
        Subscription(
            title: "Apple Developer",
            amount: 99.00,
            currency: .USD,
            billingCycle: .yearly,
            startDate: d(2024, 6, 1),
            category: "Development",
            iconName: "cpu.fill",
            isActive: true
        ),
        Subscription(
            title: "Setapp",
            amount: 107.88,
            currency: .USD,
            billingCycle: .yearly,
            startDate: d(2024, 4, 15),
            category: "Productivity",
            iconName: "cloud.fill",
            isActive: true
        ),
        Subscription(
            title: "1Password",
            amount: 35.88,
            currency: .USD,
            billingCycle: .yearly,
            startDate: d(2024, 9, 1),
            category: "Security",
            iconName: "envelope.fill",
            isActive: true
        ),
        Subscription(
            title: "Notion Pro",
            amount: 96.00,
            currency: .USD,
            billingCycle: .yearly,
            startDate: d(2025, 1, 15),
            category: "Productivity",
            iconName: "book.fill",
            isActive: true
        ),
        Subscription(
            title: "GitHub Pro",
            amount: 48.00,
            currency: .USD,
            billingCycle: .yearly,
            startDate: d(2025, 3, 1),
            category: "Development",
            iconName: "cpu.fill",
            isActive: true
        ),
    ]}

    // MARK: - Date helper

    private static func d(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }
}
