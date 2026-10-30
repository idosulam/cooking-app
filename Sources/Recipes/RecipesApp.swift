import SwiftUI
import Supabase

@main
struct RecipesApp: App {
    @StateObject private var authService: AuthService
    @StateObject private var recipeRepository: RecipeRepository
    @StateObject private var aiService: AIService
    private let configurationError: String?

    init() {
        Self.configureAppearance()
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

    private static func configureAppearance() {
        let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
        if let serif = base.withDesign(.serif) {
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: UIFont(descriptor: serif, size: 0)]
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
            .onOpenURL { AppRouter.shared.handle($0) }
        }
    }
}
