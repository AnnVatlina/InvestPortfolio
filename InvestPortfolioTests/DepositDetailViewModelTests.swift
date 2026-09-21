//
//  DepositDetailViewModelTests.swift
//  InvestPortfolioTests
//

import Testing
import Foundation
@testable import InvestPortfolio

@MainActor
private func makeViewModel(deposit: Deposit) async -> DepositDetailViewModel {
    let vm = DepositDetailViewModel(deposit: deposit, service: DefaultDepositsService(repository: InMemoryDepositsRepository()))
    await vm.load()
    return vm
}

private func makeDeposit(
    openDate: Date,
    closeDate: Date? = nil,
    rate: Double = 12.0,
    isRevocable: Bool = true,
    earlyWithdrawalRate: Double? = nil
) -> Deposit {
    Deposit(title: "T", amount: 100_000, currency: .RUB, openDate: openDate, closeDate: closeDate,
            annualInterestRate: rate, isRevocable: isRevocable, earlyWithdrawalRate: earlyWithdrawalRate)
}

@Suite("DepositDetailViewModel — early closure loss preview")
@MainActor
struct DepositDetailViewModelEarlyClosureTests {

    @Test("Irrevocable deposit with an early-withdrawal rate, not yet at term, shows a positive loss")
    func irrevocableBeforeTermShowsLoss() async {
        let openDate = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let closeDate = Calendar.current.date(byAdding: .day, value: 100, to: Date())!
        let deposit = makeDeposit(openDate: openDate, closeDate: closeDate, rate: 12.0, isRevocable: false, earlyWithdrawalRate: 1.0)
        let vm = await makeViewModel(deposit: deposit)

        #expect(vm.projectedEarlyClosureLoss() > 0)
    }

    @Test("Revocable deposit shows no loss even with a close date in the future")
    func revocableShowsNoLoss() async {
        let openDate = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let closeDate = Calendar.current.date(byAdding: .day, value: 100, to: Date())!
        let deposit = makeDeposit(openDate: openDate, closeDate: closeDate, rate: 12.0, isRevocable: true)
        let vm = await makeViewModel(deposit: deposit)

        #expect(vm.projectedEarlyClosureLoss() == 0)
    }

    @Test("Irrevocable deposit without an early-withdrawal rate shows no loss")
    func irrevocableWithoutRateShowsNoLoss() async {
        let openDate = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let closeDate = Calendar.current.date(byAdding: .day, value: 100, to: Date())!
        let deposit = makeDeposit(openDate: openDate, closeDate: closeDate, rate: 12.0, isRevocable: false, earlyWithdrawalRate: nil)
        let vm = await makeViewModel(deposit: deposit)

        #expect(vm.projectedEarlyClosureLoss() == 0)
    }

    @Test("Irrevocable deposit already past its close date shows no loss — closing now isn't early")
    func irrevocablePastCloseDateShowsNoLoss() async {
        let openDate = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let closeDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let deposit = makeDeposit(openDate: openDate, closeDate: closeDate, rate: 12.0, isRevocable: false, earlyWithdrawalRate: 1.0)
        let vm = await makeViewModel(deposit: deposit)

        #expect(vm.projectedEarlyClosureLoss() == 0)
    }

    @Test("Irrevocable deposit with no close date at all shows no loss — there's no term to break")
    func irrevocableWithoutCloseDateShowsNoLoss() async {
        let openDate = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let deposit = makeDeposit(openDate: openDate, closeDate: nil, rate: 12.0, isRevocable: false, earlyWithdrawalRate: 1.0)
        let vm = await makeViewModel(deposit: deposit)

        #expect(vm.projectedEarlyClosureLoss() == 0)
    }
}
