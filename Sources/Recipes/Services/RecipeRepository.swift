import Foundation
import Supabase

@MainActor
final class RecipeRepository: ObservableObject {
    @Published private(set) var recipes: [Recipe] = []
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false

    private let client: SupabaseClient?

    init(client: SupabaseClient?) {
        self.client = client
    }

    func fetchRecipes() async throws {
        guard let client else { throw AppError.unavailable }
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched: [Recipe] = try await client
                .from("recipes")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            let legacySamples = fetched.filter { recipe in
                Self.legacySampleRecipes.contains { Self.matches(recipe, sample: $0) }
            }
            for sample in legacySamples {
                try await client
                    .from("recipes")
                    .delete()
                    .eq("id", value: sample.id.uuidString)
                    .execute()
            }
            let legacySampleIDs = Set(legacySamples.map(\.id))
            recipes = fetched.filter { !legacySampleIDs.contains($0.id) }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func create(_ recipe: Recipe) async throws -> Recipe {
        guard let client else { throw AppError.unavailable }
        let saved: Recipe = try await client
            .from("recipes")
            .insert(recipe)
            .select()
            .single()
            .execute()
            .value
        return saved
    }

    func update(_ recipe: Recipe) async throws -> Recipe {
        guard let client else { throw AppError.unavailable }
        let saved: Recipe = try await client
            .from("recipes")
            .update(recipe)
            .eq("id", value: recipe.id.uuidString)
            .select()
            .single()
            .execute()
            .value
        return saved
    }

    func delete(id: UUID) async throws {
        guard let client else { throw AppError.unavailable }
        try await client
            .from("recipes")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    private static func matches(_ recipe: Recipe, sample: Recipe) -> Bool {
        recipe.name == sample.name
            && recipe.category == sample.category
            && recipe.cookTimeMinutes == sample.cookTimeMinutes
            && recipe.servings == sample.servings
            && recipe.calories == sample.calories
            && recipe.protein == sample.protein
            && recipe.fat == sample.fat
            && recipe.carbs == sample.carbs
            && recipe.nutritionIsEstimated == sample.nutritionIsEstimated
            && recipe.steps == sample.steps
            && recipe.ingredients.count == sample.ingredients.count
            && zip(recipe.ingredients, sample.ingredients).allSatisfy { recipeIngredient, sampleIngredient in
                recipeIngredient.name == sampleIngredient.name
                    && recipeIngredient.quantity == sampleIngredient.quantity
                    && recipeIngredient.unit == sampleIngredient.unit
            }
    }

    private static let legacySampleRecipes: [Recipe] = [
        Recipe(name: "Roasted tomato soup", category: .starter, cookTimeMinutes: 35, servings: 4, calories: 182, protein: 4.8, fat: 9.2, carbs: 21.4, ingredients: [
            Ingredient(name: "Cherry tomatoes", quantity: 600, unit: "g"),
            Ingredient(name: "Red onion", quantity: 1, unit: "piece"),
            Ingredient(name: "Olive oil", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Vegetable stock", quantity: 500, unit: "ml")
        ], steps: ["Roast the tomatoes and onion with olive oil at 200°C until blistered.", "Warm the stock, add the roasted vegetables, and blend until smooth."]),
        Recipe(name: "Lemon herb orzo", category: .main, cookTimeMinutes: 25, servings: 3, calories: 428, protein: 16.2, fat: 12.1, carbs: 62.4, ingredients: [
            Ingredient(name: "Orzo", quantity: 240, unit: "g"),
            Ingredient(name: "Vegetable stock", quantity: 600, unit: "ml"),
            Ingredient(name: "Lemon", quantity: 1, unit: "piece"),
            Ingredient(name: "Baby spinach", quantity: 80, unit: "g")
        ], steps: ["Simmer the orzo in the stock, stirring often, until tender.", "Fold in spinach, lemon zest, and juice before serving."]),
        Recipe(name: "Crispy chickpeas", category: .snack, cookTimeMinutes: 32, servings: 4, calories: 156, protein: 7.3, fat: 4.6, carbs: 22.1, ingredients: [
            Ingredient(name: "Chickpeas", quantity: 400, unit: "g"),
            Ingredient(name: "Olive oil", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Smoked paprika", quantity: 1, unit: "tsp")
        ], steps: ["Dry the chickpeas well and toss with oil and paprika.", "Bake at 200°C, shaking the tray once, until crisp."]),
        Recipe(name: "Tahini date bites", category: .dessert, cookTimeMinutes: 15, servings: 8, calories: 124, protein: 3.2, fat: 6.1, carbs: 16.8, ingredients: [
            Ingredient(name: "Medjool dates", quantity: 8, unit: "piece"),
            Ingredient(name: "Tahini", quantity: 3, unit: "tbsp"),
            Ingredient(name: "Rolled oats", quantity: 80, unit: "g"),
            Ingredient(name: "Cocoa powder", quantity: 1, unit: "tbsp")
        ], steps: ["Blend dates, tahini, oats, and cocoa until the mixture holds together.", "Roll into small bites and chill until firm."])
    ]
}
