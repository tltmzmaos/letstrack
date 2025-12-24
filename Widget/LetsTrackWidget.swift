import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Widget Entry
struct LetsTrackEntry: TimelineEntry {
    let date: Date
    let totalBalance: Decimal
    let monthlyExpense: Decimal
    let monthlyIncome: Decimal
    let recentTransactions: [SimpleTransaction]
}

struct SimpleTransaction: Identifiable {
    let id: UUID
    let amount: Decimal
    let isIncome: Bool
    let categoryName: String
    let categoryIcon: String
    let categoryColor: String
}

// MARK: - Timeline Provider
struct LetsTrackProvider: TimelineProvider {
    func placeholder(in context: Context) -> LetsTrackEntry {
        LetsTrackEntry(
            date: Date(),
            totalBalance: 1500000,
            monthlyExpense: 850000,
            monthlyIncome: 2000000,
            recentTransactions: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LetsTrackEntry) -> Void) {
        let entry = LetsTrackEntry(
            date: Date(),
            totalBalance: 1500000,
            monthlyExpense: 850000,
            monthlyIncome: 2000000,
            recentTransactions: []
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LetsTrackEntry>) -> Void) {
        Task { @MainActor in
            let entry = await fetchData()
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    @MainActor
    private func fetchData() async -> LetsTrackEntry {
        // Try to access shared data
        // Note: In a real implementation, you'd use App Groups to share data between app and widget
        return LetsTrackEntry(
            date: Date(),
            totalBalance: 0,
            monthlyExpense: 0,
            monthlyIncome: 0,
            recentTransactions: []
        )
    }
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    let entry: LetsTrackEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(.blue)
                Text(String(localized: "widget.title"))
                    .font(.caption.bold())
            }

            Spacer()

            Text(String(localized: "widget.monthly_expense"))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(entry.monthlyExpense.formatted())
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .padding()
        .containerBackground(.fill, for: .widget)
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    let entry: LetsTrackEntry

    var body: some View {
        HStack(spacing: 16) {
            // Balance Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.pie.fill")
                        .foregroundStyle(.blue)
                    Text(String(localized: "widget.title"))
                        .font(.caption.bold())
                }

                Spacer()

                Text(String(localized: "widget.total_balance"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(entry.totalBalance.formatted())
                    .font(.title2.bold())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }

            Divider()

            // Monthly Summary
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(String(localized: "dashboard.income"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(entry.monthlyIncome.formatted())
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }

                    Spacer()
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text(String(localized: "dashboard.expense"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(entry.monthlyExpense.formatted())
                            .font(.subheadline.bold())
                            .foregroundStyle(.red)
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .containerBackground(.fill, for: .widget)
    }
}

// MARK: - Widget Configuration
struct LetsTrackWidget: Widget {
    let kind: String = "LetsTrackWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LetsTrackProvider()) { entry in
            LetsTrackWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget.title"))
        .description(String(localized: "widget.description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LetsTrackWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: LetsTrackEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle
@main
struct LetsTrackWidgetBundle: WidgetBundle {
    var body: some Widget {
        LetsTrackWidget()
    }
}

// MARK: - Previews
#Preview("Small", as: .systemSmall) {
    LetsTrackWidget()
} timeline: {
    LetsTrackEntry(
        date: Date(),
        totalBalance: 1500000,
        monthlyExpense: 850000,
        monthlyIncome: 2000000,
        recentTransactions: []
    )
}

#Preview("Medium", as: .systemMedium) {
    LetsTrackWidget()
} timeline: {
    LetsTrackEntry(
        date: Date(),
        totalBalance: 1500000,
        monthlyExpense: 850000,
        monthlyIncome: 2000000,
        recentTransactions: []
    )
}
