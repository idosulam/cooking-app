import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var recipes: [Recipe] = []
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false

    private let repository: RecipeRepository

    init(repository: RecipeRepository) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await repository.fetchRecipes()
            recipes = repository.recipes
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(_ recipe: Recipe) async throws {
        let previous = recipes
        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[index] = recipe
        } else {
            recipes.insert(recipe, at: 0)
        }
        Feedback.save()
        do {
            let saved = previous.contains(where: { $0.id == recipe.id })
                ? try await repository.update(recipe)
                : try await repository.create(recipe)
            replace(saved)
            errorMessage = nil
        } catch {
            recipes = previous
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func delete(_ recipe: Recipe) async {
        let previous = recipes
        recipes.removeAll { $0.id == recipe.id }
        do {
            try await repository.delete(id: recipe.id)
            errorMessage = nil
        } catch {
            recipes = previous
            errorMessage = error.localizedDescription
        }
    }

    private func replace(_ recipe: Recipe) {
        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[index] = recipe
        } else {
            recipes.insert(recipe, at: 0)
        }
    }
}
