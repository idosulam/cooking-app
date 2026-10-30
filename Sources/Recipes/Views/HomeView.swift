import SwiftUI

struct HomeView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var repository: RecipeRepository
    @ObservedObject var aiService: AIService
    @StateObject private var viewModel: HomeViewModel
    @State private var query = ""
    @State private var selectedCategory: RecipeCategory?
    @State private var navigationPath: [UUID] = []
    @State private var isEditorPresented = false
    @State private var editingRecipe: Recipe?
    @State private var isSettingsPresented = false
    @State private var deleteCandidate: Recipe?
    @Namespace private var recipeTransition
    @ObservedObject private var router = AppRouter.shared
    @State private var cookingRecipe: Recipe?
    @State private var todaysMeal: PlannedMeal?
    @State private var hasLoaded = false

    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 13)]

    init(authService: AuthService, repository: RecipeRepository, aiService: AIService) {
        self.authService = authService
        self.repository = repository
        self.aiService = aiService
        _viewModel = StateObject(wrappedValue: HomeViewModel(repository: repository))
    }

    private var filteredRecipes: [Recipe] {
        viewModel.recipes.filter { recipe in
            (selectedCategory == nil || recipe.category == selectedCategory)
                && (query.isEmpty || recipe.name.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    dateLine
                    todaysMealCard
                    categoryFilters
                    recipeContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .background(RecipeTheme.canvas.ignoresSafeArea())
            .refreshable { await viewModel.load() }
            .onAppear { refreshTodaysMeal() }
            .onChange(of: navigationPath) { _, _ in refreshTodaysMeal() }
            .onChange(of: router.pending) { _, _ in handleRouterRequest() }
            .onChange(of: viewModel.recipes) { _, _ in handleRouterRequest() }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Find a favorite")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isSettingsPresented = true
                        Feedback.tap()
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: presentEditor) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add recipe")
                }
            }
            .navigationDestination(for: UUID.self) { recipeID in
                if let recipe = viewModel.recipes.first(where: { $0.id == recipeID }) {
                    RecipeDetailView(
                        recipe: recipe,
                        namespace: recipeTransition,
                        onEdit: {
                            editingRecipe = recipe
                            isEditorPresented = true
                        },
                        onDelete: { Task { await viewModel.delete(recipe) } }
                    )
                } else {
                    ContentUnavailableView("Recipe not found", systemImage: "fork.knife")
                }
            }
            .sheet(isPresented: $isEditorPresented) {
                RecipeEditorView(recipe: editingRecipe, aiService: aiService) { recipe in
                    try await viewModel.save(recipe)
                }
            }
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView(authService: authService)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: $cookingRecipe) { recipe in
                CookingView(recipe: recipe)
            }
            .alert("Delete recipe?", isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            )) {
                Button("Cancel", role: .cancel) { deleteCandidate = nil }
                Button("Delete", role: .destructive) {
                    if let deleteCandidate {
                        Task { await viewModel.delete(deleteCandidate) }
                    }
                    deleteCandidate = nil
                }
            } message: {
                Text("This recipe will be removed from your collection.")
            }
            .task {
                await viewModel.load()
                hasLoaded = true
                refreshTodaysMeal()
                handleRouterRequest()
            }
            .alert("Couldn't update recipes", isPresented: Binding(
                get: {
                    viewModel.errorMessage != nil
                        && !isEditorPresented
                        && !viewModel.recipes.isEmpty
                },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
                Button("Retry") { Task { await viewModel.load() } }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var todaysMealCard: some View {
        if let meal = todaysMeal {
            Button {
                navigationPath = [meal.recipeID]
                Feedback.tap()
            } label: {
                HStack(spacing: 14) {
                    Image("Category\(meal.category)")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .foregroundStyle(RecipeTheme.accent)
                        .frame(width: 54, height: 54)
                        .background(RecipeTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TODAY’S MEAL")
                            .font(.caption2.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(RecipeTheme.accent)
                        Text(meal.name)
                            .font(.system(.headline, design: .serif))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("\(meal.cookTimeMinutes) min · \(meal.calories) kcal · \(Int(meal.protein.rounded()))g protein")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            }
            .buttonStyle(.pressable)
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
    }

    private func refreshTodaysMeal() {
        withAnimation(Motion.standard) {
            todaysMeal = MealPlanStore.meal(on: .now)
        }
    }

    private func handleRouterRequest() {
        guard let request = router.pending else { return }
        func recipe(_ id: UUID) -> Recipe? {
            viewModel.recipes.first { $0.id == id }
        }
        switch request {
        case .open(let id):
            guard recipe(id) != nil else {
                if hasLoaded { router.pending = nil }
                return
            }
            navigationPath = [id]
        case .cook(let id):
            guard let found = recipe(id) else {
                if hasLoaded { router.pending = nil }
                return
            }
            cookingRecipe = found
        case .cookToday:
            guard let meal = MealPlanStore.meal(on: .now) else {
                router.pending = nil
                return
            }
            guard let found = recipe(meal.recipeID) else {
                if hasLoaded { router.pending = nil }
                return
            }
            cookingRecipe = found
        }
        router.pending = nil
    }

    private var dateLine: some View {
        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased())
            .font(.caption2.weight(.bold))
            .tracking(1.6)
            .foregroundStyle(RecipeTheme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(RecipeCategory.allCases) { category in
                    filterChip(category.rawValue, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
        }
        .contentMargins(.trailing, 2)
    }

    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Motion.quick) {
                action()
            }
            Feedback.selection()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(isSelected ? RecipeTheme.accent : RecipeTheme.card, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var recipeContent: some View {
        if viewModel.isLoading && viewModel.recipes.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 70)
        } else if viewModel.recipes.isEmpty && viewModel.errorMessage != nil {
            ContentUnavailableView {
                Label("Your collection didn’t load", systemImage: "wifi.exclamationmark")
            } description: {
                Text(viewModel.errorMessage ?? "Check your connection and try again.")
            } actions: {
                Button("Try again") { Task { await viewModel.load() } }
                    .buttonStyle(.borderedProminent)
                    .tint(RecipeTheme.accent)
            }
            .padding(.top, 35)
        } else if filteredRecipes.isEmpty {
            if viewModel.recipes.isEmpty {
                ContentUnavailableView {
                    Label("Add your first recipe", systemImage: "book.closed")
                } description: {
                    Text("Keep the good ones close.")
                } actions: {
                    Button("Create a recipe") { presentEditor() }
                        .buttonStyle(.borderedProminent)
                        .tint(RecipeTheme.accent)
                }
                .padding(.top, 35)
            } else {
                ContentUnavailableView.search(text: query)
                    .padding(.top, 35)
            }
        } else {
            LazyVGrid(columns: columns, spacing: 13) {
                ForEach(Array(filteredRecipes.enumerated()), id: \.element.id) { index, recipe in
                    RecipeCard(recipe: recipe, index: index, namespace: recipeTransition) {
                        navigationPath.append(recipe.id)
                        Feedback.tap()
                    }
                    .contextMenu {
                        Button {
                            editingRecipe = recipe
                            isEditorPresented = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deleteCandidate = recipe
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func presentEditor() {
        editingRecipe = nil
        isEditorPresented = true
        Feedback.tap()
    }
}

private struct RecipeCard: View {
    let recipe: Recipe
    let index: Int
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var isVisible = false

    private var tint: Color { recipe.category.tint }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.56), tint.opacity(0.24)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Circle()
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                        .frame(width: 92, height: 92)
                        .offset(x: 22, y: 22)
                    CategoryIcon(category: recipe.category, size: 48)
                        .foregroundStyle(recipe.category.iconInk)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(recipe.category.iconInk.opacity(0.8))
                        .padding(9)
                }
                .frame(height: 112)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .zoomSource(id: recipe.id, in: namespace)
                .padding(.bottom, 12)

                Text(recipe.name)
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)

                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .medium))
                    Text("\(recipe.cookTimeMinutes) min")
                    Text("·")
                    Text("\(recipe.calories) kcal")
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 6) {
                    MacroBar(protein: recipe.protein, fat: recipe.fat, carbs: recipe.carbs)
                    HStack(spacing: 8) {
                        MacroMini(label: "P", amount: recipe.protein, color: RecipeTheme.protein)
                        MacroMini(label: "F", amount: recipe.fat, color: RecipeTheme.fat)
                        MacroMini(label: "C", amount: recipe.carbs, color: RecipeTheme.carbs)
                    }
                }
                .padding(.top, 10)
            }
            .padding(11)
            .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 11)
        }
        .buttonStyle(.pressable)
        .scrollTransition(.animated) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.5)
                .scaleEffect(phase.isIdentity ? 1 : 0.96)
        }
        .accessibilityLabel("\(recipe.name), \(recipe.cookTimeMinutes) minutes, \(recipe.calories) calories")
        .onAppear {
            withAnimation(Motion.standard.delay(Double(min(index, 6)) * 0.045)) {
                isVisible = true
            }
        }
    }
}

private struct MacroMini: View {
    let label: String
    let amount: Double
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .foregroundStyle(color)
                .fontWeight(.bold)
            Text("\(amount.formatted(.number.precision(.fractionLength(0...1))))g")
                .foregroundStyle(.secondary)
        }
        .font(.caption2.weight(.medium))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

private struct SettingsView: View {
    @ObservedObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @AppStorage(RecipeAccent.storageKey) private var selectedAccent = RecipeAccent.tomato.rawValue
    @AppStorage(Feedback.soundsKey) private var soundsEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Accent colour") {
                    HStack(spacing: 0) {
                        ForEach(RecipeAccent.allCases) { accent in
                            Button {
                                selectedAccent = accent.rawValue
                                Feedback.tap()
                            } label: {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(accent.color)
                                            .frame(width: 38, height: 38)
                                        if selectedAccent == accent.rawValue {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    Text(accent.name)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(accent.name) accent")
                            .accessibilityAddTraits(selectedAccent == accent.rawValue ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Feedback") {
                    Toggle("Timer and finish sounds", isOn: $soundsEnabled)
                }
                Section {
                    LabeledContent("Signed in as", value: authService.session?.user.email ?? "")
                }
                if let errorMessage = authService.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Button("Sign out", role: .destructive) {
                        Task {
                            if await authService.signOut() {
                                MealPlanStore.clearAll()
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
