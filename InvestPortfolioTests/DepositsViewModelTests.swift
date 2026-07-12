//
//  DepositsViewModelTests.swift
//  InvestPortfolioTests
//
//  Tests for DepositsViewModel — local SwiftData-backed behaviour.
//

import Testing
import Foundation
@testable import InvestPortfolio

// MARK: - Helpers

@MainActor
private func makeVM(with deposits: [Deposit] = []) async -> DepositsViewModel {
    let repo = InMemoryDepositsRepository()
    for d in deposits { try? await repo.add(d) }
    let vm = DepositsViewModel(service: DefaultDepositsService(repository: repo))
    await vm.load()
    return vm
}

private func dep(
    title: String = "Deposit",
    bankName: String? = nil,
    amount: Double = 100_000,
    currency: DepositCurrency = .RUB,
    openDate: Date = Date(),
    closeDate: Date? = nil,
    rate: Double = 10.0
) -> Deposit {
    Deposit(title: title, bankName: bankName, amount: amount, currency: currency,
            openDate: openDate, closeDate: closeDate, annualInterestRate: rate)
}

// MARK: - Suite

@Suite("DepositsViewModel — local CRUD")
@MainActor
struct DepositsViewModelTests {

    // MARK: load

    @Test("Load from empty service → deposits is empty")
    func loadEmpty() async {
        let vm = await makeVM()
        #expect(vm.deposits.isEmpty)
        #expect(vm.errorMessage == nil)
    }

    @Test("Load with pre-seeded deposits → list populated")
    func loadPopulates() async {
        let vm = await makeVM(with: [dep(title: "Сбербанк"), dep(title: "ВТБ")])
        #expect(vm.deposits.count == 2)
        #expect(vm.errorMessage == nil)
    }

    // MARK: add

    @Test("Add valid deposit → appears in list")
    func addAppearsInList() async {
        let vm = await makeVM()
        await vm.addDeposit(
            title: "Накопительный", bankName: "", amount: 200_000,
            currency: .RUB, openDate: Date(), closeDate: nil, annualInterestRate: 12.5
        )
        #expect(vm.deposits.count == 1)
        #expect(vm.deposits[0].title == "Накопительный")
        #expect(vm.operationError == nil)
    }

    @Test("Add with empty title → errorMessage set, list unchanged")
    func addEmptyTitleSetsError() async {
        let vm = await makeVM()
        await vm.addDeposit(
            title: "   ", bankName: "", amount: 100,
            currency: .RUB, openDate: Date(), closeDate: nil, annualInterestRate: 5
        )
        #expect(vm.deposits.isEmpty)
        #expect(vm.errorMessage != nil)
    }

    // MARK: delete

    @Test("Delete deposit → removed from list")
    func deleteRemoves() async {
        let vm = await makeVM(with: [dep(title: "ToDelete")])
        #expect(vm.deposits.count == 1)
        await vm.deleteDeposit(vm.deposits[0])
        #expect(vm.deposits.isEmpty)
        #expect(vm.operationError == nil)
    }

    @Test("Delete one of two → other remains")
    func deleteOneOfTwo() async {
        let d1 = dep(title: "Keep",   openDate: Date(timeIntervalSinceNow: -200))
        let d2 = dep(title: "Remove", openDate: Date(timeIntervalSinceNow: -100))
        let vm = await makeVM(with: [d1, d2])
        let toDelete = vm.deposits.first(where: { $0.title == "Remove" })!
        await vm.deleteDeposit(toDelete)
        #expect(vm.deposits.count == 1)
        #expect(vm.deposits[0].title == "Keep")
    }

    // MARK: update

    @Test("Update deposit → title changes in list")
    func updateChangesTitle() async {
        let vm = await makeVM(with: [dep(title: "Old")])
        let id = vm.deposits[0].id
        await vm.updateDeposit(
            id: id, title: "New", bankName: "",
            amount: 100_000, currency: .RUB,
            openDate: Date(), closeDate: nil, annualInterestRate: 10
        )
        #expect(vm.deposits[0].title == "New")
    }

    @Test("Update with empty title → errorMessage set, title unchanged")
    func updateEmptyTitleSetsError() async {
        let vm = await makeVM(with: [dep(title: "Original")])
        let id = vm.deposits[0].id
        await vm.updateDeposit(
            id: id, title: "  ", bankName: "",
            amount: 100_000, currency: .RUB,
            openDate: Date(), closeDate: nil, annualInterestRate: 10
        )
        #expect(vm.errorMessage != nil)
        #expect(vm.deposits[0].title == "Original")
    }

    // MARK: income summary

    @Test("incomeSummary for active deposit with positive rate → incomeToDate > 0")
    func incomeSummaryPositive() async {
        let openDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let vm = await makeVM(with: [dep(amount: 100_000, openDate: openDate, rate: 12.0)])
        let summary = vm.incomeSummary(for: vm.deposits[0])
        #expect(summary.incomeToDate > 0)
    }
}
