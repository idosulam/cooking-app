import SwiftUI
import Supabase

@main
struct RecipesApp: App {
    @StateObject private var authService: AuthService
    @StateObject private var recipeRepository: RecipeRepository
    @StateObject private var aiService: AIService
    private let configurationError: String?

    init() {
        do {
            let client = try SupabaseClientProvider.makeClient()
            _authService = StateObject(wrappedValue: AuthService(client: client))
            _recipeRepository = StateObject(wrappedValue: RecipeRepository(client: client))
            _aiService = StateObject(wrappedValue: AIService(client: client))
            configurationError = nil
        } catch {
            _authService = StateObject(wrappedValue: AuthService(client: nil))
            _recipeRepository = StateObject(wrappedValue: RecipeRepository(client: nil))
            _aiService = StateObject(wrappedValue: AIService(client: nil))
            configurationError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                authService: authService,
                recipeRepository: recipeRepository,
                aiService: aiService,
                configurationError: configurationError
            )
            .preferredColorScheme(nil)
        }
    }
}
