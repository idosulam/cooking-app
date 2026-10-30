import AppIntents

struct RecipeEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Recipe")
    static var defaultQuery = RecipeEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct RecipeEntityQuery: EntityStringQuery {
    private func all() -> [RecipeEntity] {
        MealPlanStore.recipes.map { RecipeEntity(id: $0.id, name: $0.name) }
    }

    func entities(for identifiers: [String]) async throws -> [RecipeEntity] {
        all().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [RecipeEntity] {
        all().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [RecipeEntity] {
        all()
    }
}

struct StartCookingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start cooking"
    static var description = IntentDescription("Open a recipe in cooking mode.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Recipe")
    var recipe: RecipeEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Start cooking \(\.$recipe)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: recipe.id) {
            AppRouter.shared.pending = .cook(id)
        }
        return .result()
    }
}

struct CookTodaysMealIntent: AppIntent {
    static var title: LocalizedStringResource = "Cook today’s meal"
    static var description = IntentDescription("Start cooking the meal you planned for today.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard MealPlanStore.meal(on: .now) != nil else {
            return .result(dialog: IntentDialog("Nothing is planned for today yet."))
        }
        AppRouter.shared.pending = .cookToday
        return .result(dialog: IntentDialog("Let’s cook."))
    }
}

struct RecipesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartCookingIntent(),
            phrases: [
                "Start cooking \(\.$recipe) in \(.applicationName)",
                "Cook \(\.$recipe) with \(.applicationName)"
            ],
            shortTitle: "Start cooking",
            systemImageName: "flame.fill"
        )
        AppShortcut(
            intent: CookTodaysMealIntent(),
            phrases: [
                "Cook today's meal in \(.applicationName)",
                "What's for dinner in \(.applicationName)"
            ],
            shortTitle: "Today’s meal",
            systemImageName: "calendar"
        )
    }
}
