//
//  SubscriptionsWidget.swift
//  InvestPortfolioWidgets
//
//  Shows the nearest upcoming active subscription payment.
//

import WidgetKit
import SwiftUI
import SwiftData

struct SubscriptionsWidgetEntry: TimelineEntry {
    struct Item {
        let title: String
        let amount: Double
        let currency: String
        let dueDate: Date
    }

    let date: Date
    let item: Item?
}

struct SubscriptionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> SubscriptionsWidgetEntry {
        SubscriptionsWidgetEntry(
            date: Date(),
            item: .init(title: "Netflix", amount: 15.49, currency: "USD", dueDate: Date())
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SubscriptionsWidgetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SubscriptionsWidgetEntry>) -> Void) {
        let entry = currentEntry()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let reloadDate = entry.item?.dueDate ?? tomorrow
        completion(Timeline(entries: [entry], policy: .after(reloadDate)))
    }

    private func currentEntry() -> SubscriptionsWidgetEntry {
        guard let container = SharedModelContainer.make() else {
            return SubscriptionsWidgetEntry(date: Date(), item: nil)
        }
        let context = ModelContext(container)
        let subscriptions = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        guard let next = subscriptions.nearestUpcoming(limit: 1).first else {
            return SubscriptionsWidgetEntry(date: Date(), item: nil)
        }
        return SubscriptionsWidgetEntry(
            date: Date(),
            item: .init(title: next.title, amount: next.amount, currency: next.currency.rawValue, dueDate: next.dueDate)
        )
    }
}

struct SubscriptionsWidgetView: View {
    var entry: SubscriptionsWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text("widget.subscriptions.title")
                    .font(.caption2.weight(.semibold))
            } icon: {
                Image(systemName: "repeat.circle.fill")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            if let item = entry.item {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(item.dueDate, format: .dateTime.day().month(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("\(item.amount, specifier: "%.2f") \(item.currency)")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("widget.subscriptions.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct SubscriptionsWidget: Widget {
    let kind = "SubscriptionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SubscriptionsProvider()) { entry in
            SubscriptionsWidgetView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringKey("widget.subscriptions.displayName"))
        .description(LocalizedStringKey("widget.subscriptions.description"))
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    SubscriptionsWidget()
} timeline: {
    SubscriptionsWidgetEntry(date: .now, item: .init(title: "Netflix", amount: 15.49, currency: "USD", dueDate: .now))
    SubscriptionsWidgetEntry(date: .now, item: nil)
}
