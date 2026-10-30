import SwiftUI
import WidgetKit

struct MealEntry: TimelineEntry {
    let date: Date
    let meal: PlannedMeal?
}

struct MealProvider: TimelineProvider {
    private static let sample = PlannedMeal(
        recipeID: UUID(), name: "Teriyaki chicken bowl", category: "Main",
        cookTimeMinutes: 25, calories: 540, protein: 46
    )

    func placeholder(in context: Context) -> MealEntry {
        MealEntry(date: .now, meal: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (MealEntry) -> Void) {
        let meal = MealPlanStore.meal(on: .now) ?? (context.isPreview ? Self.sample : nil)
        completion(MealEntry(date: .now, meal: meal))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MealEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(3600)
        let entries = [
            MealEntry(date: now, meal: MealPlanStore.meal(on: now)),
            MealEntry(date: midnight, meal: MealPlanStore.meal(on: midnight))
        ]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct TodaysMealWidget: Widget {
    let kind = "TodaysMealWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MealProvider()) { entry in
            MealWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(uiColor: .secondarySystemGroupedBackground)
                }
        }
        .configurationDisplayName("Today’s meal")
        .description("See what you planned to cook today and jump straight into cooking.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct MealWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MealEntry

    private var accent: Color { SharedStore.accentColor }

    private var url: URL {
        if let meal = entry.meal, let url = URL(string: "recipes://cook/\(meal.recipeID.uuidString)") {
            return url
        }
        return URL(string: "recipes://home")!
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: accessory
            case .systemMedium: medium
            default: small
            }
        }
        .widgetURL(url)
    }

    private func icon(_ meal: PlannedMeal, size: CGFloat) -> some View {
        Image("Category\(meal.category)")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(accent)
    }

    private func details(_ meal: PlannedMeal) -> String {
        "\(meal.cookTimeMinutes) min · \(meal.calories) kcal"
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("TODAY")
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(accent)
                Spacer()
                if let meal = entry.meal {
                    icon(meal, size: 26)
                }
            }
            Spacer(minLength: 6)
            if let meal = entry.meal {
                Text(meal.name)
                    .font(.system(.headline, design: .serif))
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                Text(details(meal))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                Text("Nothing planned")
                    .font(.system(.headline, design: .serif))
                Text("Plan a meal in the app")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(accent.opacity(0.14))
                if let meal = entry.meal {
                    icon(meal, size: 52)
                } else {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(accent)
                }
            }
            .frame(width: 110)

            VStack(alignment: .leading, spacing: 5) {
                Text("TODAY’S MEAL")
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(accent)
                if let meal = entry.meal {
                    Text(meal.name)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .lineLimit(2)
                    Text("\(details(meal)) · \(Int(meal.protein.rounded()))g protein")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Label("Tap to start cooking", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                } else {
                    Text("Nothing planned yet")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                    Text("Open a recipe and choose Plan meal.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var accessory: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let meal = entry.meal {
                Label("Today", systemImage: "flame.fill")
                    .font(.caption2.weight(.semibold))
                    .widgetAccentable()
                Text(meal.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(details(meal)) · \(Int(meal.protein.rounded()))g P")
                    .font(.caption)
                    .lineLimit(1)
            } else {
                Label("Today", systemImage: "flame")
                    .font(.caption2.weight(.semibold))
                Text("Nothing planned")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
