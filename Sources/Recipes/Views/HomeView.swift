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
                    header
                    searchBar
                    categoryFilters
                    recipeContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 110)
            }
            .background(RecipeTheme.canvas.ignoresSafeArea())
            .refreshable { await viewModel.load() }
            .navigationBarHidden(true)
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
            .overlay(alignment: .bottomTrailing) {
                addButton
                    .padding(.trailing, 22)
                    .padding(.bottom, 24)
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
            .task { await viewModel.load() }
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

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(RecipeTheme.accent)
                Text("Recipes")
                    .font(.system(.largeTitle, design: .serif).weight(.regular))
                    .tracking(-1.3)
                Text("A good thing, made again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            Button {
                isSettingsPresented = true
                Feedback.tap()
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 45, height: 45)
                    .background(RecipeTheme.card, in: Circle())
            }
            .accessibilityLabel("Settings")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Find a favorite", text: $query)
                .font(.body)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 50)
        .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                action()
            }
            Feedback.tap()
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

    private var addButton: some View {
        Button(action: presentEditor) {
            Image(systemName: "plus")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(RecipeTheme.accent, in: Circle())
                .shadow(color: RecipeTheme.accent.opacity(0.27), radius: 12, x: 0, y: 7)
        }
        .accessibilityLabel("Add recipe")
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

    private var tint: Color {
        switch recipe.category {
        case .starter: Color(red: 0.76, green: 0.85, blue: 0.79)
        case .main: Color(red: 0.67, green: 0.76, blue: 0.68)
        case .snack: Color(red: 0.95, green: 0.83, blue: 0.55)
        case .dessert: Color(red: 0.88, green: 0.72, blue: 0.70)
        case .sauce: Color(red: 0.71, green: 0.80, blue: 0.90)
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.72), tint.opacity(0.28)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Circle()
                        .fill(.white.opacity(0.12))
                        .frame(width: 96, height: 96)
                        .offset(x: 18, y: 18)
                    Image(systemName: recipe.category.symbol)
                        .font(.system(size: 31, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.68))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black.opacity(0.6))
                        .padding(9)
                }
                .frame(height: 112)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .matchedGeometryEffect(id: recipe.id, in: namespace)
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

                HStack(spacing: 8) {
                    MacroMini(label: "P", amount: recipe.protein, color: RecipeTheme.leaf)
                    MacroMini(label: "F", amount: recipe.fat, color: RecipeTheme.accent)
                    MacroMini(label: "C", amount: recipe.carbs, color: Color.blue.opacity(0.75))
                }
                .padding(.top, 10)
            }
            .padding(11)
            .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 11)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(recipe.name), \(recipe.cookTimeMinutes) minutes, \(recipe.calories) calories")
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8).delay(Double(min(index, 6)) * 0.045)) {
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
        .font(.system(size: 10, weight: .medium))
        .lineLimit(1)
    }
}

private struct SettingsView: View {
    @ObservedObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @AppStorage(RecipeAccent.storageKey) private var selectedAccent = RecipeAccent.tomato.rawValue

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
