import SwiftUI
import UIKit
import WidgetKit

enum SharedStore {
    static let groupID = "group.com.idosulam.Recipes"
    static var defaults: UserDefaults { UserDefaults(suiteName: groupID) ?? .standard }

    private static let accentKey = "accentRGB"
    private static let fallbackAccent = [0.79, 0.27, 0.16]

    static var accentColor: Color {
        var rgb = (defaults.array(forKey: accentKey) as? [Double]) ?? fallbackAccent
        if rgb.count != 3 { rgb = fallbackAccent }
        return Color(red: rgb[0], green: rgb[1], blue: rgb[2])
    }

    static func saveAccent(_ color: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let value = [Double(r), Double(g), Double(b)]
        guard (defaults.array(forKey: accentKey) as? [Double]) != value else { return }
        defaults.set(value, forKey: accentKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct PlannedMeal: Codable, Hashable {
    var recipeID: UUID
    var name: String
    var category: String
    var cookTimeMinutes: Int
    var calories: Int
    var protein: Double
}

struct RecipeStub: Codable, Hashable {
    var id: String
    var name: String
}

enum MealPlanStore {
    private static let planKey = "mealPlan"
    private static let stubsKey = "recipeStubs"

    static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func plan() -> [String: PlannedMeal] {
        guard let data = SharedStore.defaults.data(forKey: planKey),
              let plan = try? JSONDecoder().decode([String: PlannedMeal].self, from: data)
        else { return [:] }
        return plan
    }

    static func meal(on date: Date) -> PlannedMeal? {
        plan()[dayKey(date)]
    }

    static func set(_ meal: PlannedMeal?, on date: Date) {
        var current = plan()
        let yesterday = dayKey(Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now)
        current = current.filter { $0.key >= yesterday }
        current[dayKey(date)] = meal
        replace(current)
    }

    static func replace(_ plan: [String: PlannedMeal]) {
        if let data = try? JSONEncoder().encode(plan) {
            SharedStore.defaults.set(data, forKey: planKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    static var recipes: [RecipeStub] {
        guard let data = SharedStore.defaults.data(forKey: stubsKey),
              let stubs = try? JSONDecoder().decode([RecipeStub].self, from: data)
        else { return [] }
        return stubs
    }

    static func saveRecipes(_ stubs: [RecipeStub]) {
        if let data = try? JSONEncoder().encode(stubs) {
            SharedStore.defaults.set(data, forKey: stubsKey)
        }
    }

    static func clearAll() {
        SharedStore.defaults.removeObject(forKey: planKey)
        SharedStore.defaults.removeObject(forKey: stubsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
