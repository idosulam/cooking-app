import Foundation

extension PlannedMeal {
    init(recipe: Recipe) {
        self.init(
            recipeID: recipe.id,
            name: recipe.name,
            category: recipe.category.rawValue,
            cookTimeMinutes: recipe.cookTimeMinutes,
            calories: recipe.calories,
            protein: recipe.protein
        )
    }
}

enum MealPlanner {
    static func plan(_ recipe: Recipe, on date: Date) {
        MealPlanStore.set(PlannedMeal(recipe: recipe), on: date)
    }

    static func remove(on date: Date) {
        MealPlanStore.set(nil, on: date)
    }

    /// Keeps the Shortcuts recipe list and the planned meals in step with the collection.
    static func sync(with recipes: [Recipe]) {
        MealPlanStore.saveRecipes(recipes.map { RecipeStub(id: $0.id.uuidString, name: $0.name) })

        var plan = MealPlanStore.plan()
        var changed = false
        for (key, meal) in plan {
            if let recipe = recipes.first(where: { $0.id == meal.recipeID }) {
                let updated = PlannedMeal(recipe: recipe)
                if updated != meal {
                    plan[key] = updated
                    changed = true
                }
            } else {
                plan[key] = nil
                changed = true
            }
        }
        if changed { MealPlanStore.replace(plan) }
    }
}
