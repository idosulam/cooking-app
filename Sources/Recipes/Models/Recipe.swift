import Foundation

enum RecipeCategory: String, Codable, CaseIterable, Identifiable {
    case starter = "Starter"
    case main = "Main"
    case snack = "Snack"
    case dessert = "Dessert"
    case sauce = "Sauce"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .starter: "leaf"
        case .main: "fork.knife"
        case .snack: "takeoutbag.and.cup.and.straw"
        case .dessert: "birthday.cake"
        case .sauce: "drop"
        }
    }

    var iconName: String {
        switch self {
        case .starter: "CategoryStarter"
        case .main: "CategoryMain"
        case .snack: "CategorySnack"
        case .dessert: "CategoryDessert"
        case .sauce: "CategorySauce"
        }
    }
}

struct Recipe: Codable, Identifiable, Equatable {
    var id: UUID
    var userId: UUID?
    var name: String
    var category: RecipeCategory
    var cookTimeMinutes: Int
    var servings: Int
    var calories: Int
    var protein: Double
    var fat: Double
    var carbs: Double
    var nutritionIsEstimated: Bool
    var ingredients: [Ingredient]
    var steps: [String]
    var createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case category
        case cookTimeMinutes = "cook_time_minutes"
        case servings
        case calories
        case protein
        case fat
        case carbs
        case nutritionIsEstimated = "nutrition_is_estimated"
        case ingredients
        case steps
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        name: String,
        category: RecipeCategory,
        cookTimeMinutes: Int,
        servings: Int = 1,
        calories: Int = 0,
        protein: Double = 0,
        fat: Double = 0,
        carbs: Double = 0,
        nutritionIsEstimated: Bool = false,
        ingredients: [Ingredient],
        steps: [String],
        createdAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.category = category
        self.cookTimeMinutes = cookTimeMinutes
        self.servings = servings
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.nutritionIsEstimated = nutritionIsEstimated
        self.ingredients = ingredients
        self.steps = steps
        self.createdAt = createdAt
    }
}
