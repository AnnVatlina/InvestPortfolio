//
//  DepositsWidget.swift
//  InvestPortfolioWidgets
//
//  Shows the open deposit that closes soonest.
//

import WidgetKit
import SwiftUI
import SwiftData

struct DepositsWidgetEntry: TimelineEntry {
    struct Item {
        let title: String
        let amount: Double
        let currency: String
        let closeDate: Date?
    }

    let date: Date
    let item: Item?
}

struct DepositsProvider: TimelineProvider {
    func placeholder(in context: Context) -> DepositsWidgetEntry {
        DepositsWidgetEntry(
            date: Date(),
            item: .init(title: "USD Growth", amount: 10_000, currency: "USD", closeDate: Date())
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DepositsWidgetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DepositsWidgetEntry>) -> Void) {
        let entry = currentEntry()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let reloadDate = entry.item?.closeDate ?? tomorrow
        completion(Timeline(entries: [entry], policy: .after(reloadDate)))
    }

    private func currentEntry() -> DepositsWidgetEntry {
        guard let container = SharedModelContainer.make() else {
            return DepositsWidgetEntry(date: Date(), item: nil)
        }
        let context = ModelContext(container)
        let deposits = (try? context.fetch(FetchDescriptor<Deposit>())) ?? []
        guard let next = deposits.openSortedByCloseDate.first else {
            return DepositsWidgetEntry(date: Date(), item: nil)
        }
        return DepositsWidgetEntry(
            date: Date(),
            item: .init(title: next.title, amount: next.amount, currency: next.currency.rawValue, closeDate: next.closeDate)
        )
    }
}

struct DepositsWidgetView: View {
    var entry: DepositsWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text("widget.deposits.title")
                    .font(.caption2.weight(.semibold))
            } icon: {
                Image(systemName: "banknote.fill")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            if let item = entry.item {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                if let closeDate = item.closeDate {
                    Text(closeDate, format: .dateTime.day().month(.abbreviated))
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("widget.deposits.noEndDate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(item.amount, specifier: "%.0f") \(item.currency)")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("widget.deposits.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct DepositsWidget: Widget {
    let kind = "DepositsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DepositsProvider()) { entry in
            DepositsWidgetView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringKey("widget.deposits.displayName"))
        .description(LocalizedStringKey("widget.deposits.description"))
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    DepositsWidget()
} timeline: {
    DepositsWidgetEntry(date: .now, item: .init(title: "USD Growth", amount: 10_000, currency: "USD", closeDate: .now))
    DepositsWidgetEntry(date: .now, item: nil)
}
