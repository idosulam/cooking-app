import SwiftUI
import PhotosUI
import UIKit

struct RecipeEditorView: View {
    let aiService: AIService
    let onSave: (Recipe) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Recipe
    @State private var stepsText: String
    @State private var isSaving = false
    @State private var aiAction: AIAction?
    @State private var failedAIAction: AIAction?
    @State private var retrySaveAfterError = false
    @State private var aiError: String?
    @State private var improvedSteps: [String] = []
    @State private var showInstructionsPreview = false
    @State private var nutritionPreview: NutritionPreview?
    @State private var recipeDescription = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var recipePhotoData: Data?
    @State private var hasGeneratedRecipe = false
    private let editingExisting: Bool

    private enum AIAction: Equatable {
        case instructions
        case nutrition
        case generateRecipe
    }

    private struct NutritionPreview: Identifiable {
        let id = UUID()
        let estimate: NutritionEstimate
    }

    init(recipe: Recipe?, aiService: AIService, onSave: @escaping (Recipe) async throws -> Void) {
        self.aiService = aiService
        self.onSave = onSave
        editingExisting = recipe != nil
        let value = recipe ?? Recipe(
            name: "",
            category: .main,
            cookTimeMinutes: 30,
            ingredients: [Ingredient(name: "", quantity: nil, unit: "g")],
            steps: [""]
        )
        _draft = State(initialValue: value)
        _stepsText = State(initialValue: value.steps.joined(separator: "\n"))
    }

    private var isEditing: Bool { editingExisting }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    intro
                    if !isEditing {
                        aiRecipeSection
                    }
                    detailsSection
                    ingredientsSection
                    instructionsSection
                    nutritionSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 35)
            }
            .background(RecipeTheme.canvas.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit recipe" : "New recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveRecipe() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .sheet(isPresented: $showInstructionsPreview) {
                instructionsPreviewSheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $nutritionPreview) { preview in
                nutritionPreviewSheet(preview.estimate)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task { await loadPhoto(item) }
            }
            .alert("Couldn't complete that", isPresented: Binding(
                get: { aiError != nil },
                set: { if !$0 { aiError = nil } }
            )) {
                Button("Not now", role: .cancel) { aiError = nil }
                if let failedAIAction {
                    Button("Retry") {
                        Task { await runAI(failedAIAction) }
                    }
                } else if retrySaveAfterError {
                    Button("Retry save") {
                        Task { await saveRecipe() }
                    }
                }
            } message: {
                Text(aiError ?? "")
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(isEditing ? "Make it yours." : "Save something good.")
                .font(.system(.title, design: .serif).weight(.regular))
                .tracking(-0.7)
            Text("A few details now, and it’s yours to keep.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var aiRecipeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Start with AI", eyebrow: "AI")
            Text("Add a recipe screenshot or describe what you want to make. AI will draft the details for you to review.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Your photo and description are sent to the AI service to create the draft.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if let recipePhotoData, let image = UIImage(data: recipePhotoData) {
                HStack(spacing: 12) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 68, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text("Photo ready")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Button {
                        self.recipePhotoData = nil
                        selectedPhoto = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Remove recipe photo")
                }
                .padding(10)
                .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 15))
            }

            TextField("Describe a dish or add notes…", text: $recipeDescription, axis: .vertical)
                .lineLimit(3...6)
                .padding(13)
                .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 15))

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Add photo", systemImage: "photo")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RecipeTheme.card, in: Capsule())
                }
                .disabled(aiAction != nil)

                Button {
                    Task { await runAI(.generateRecipe) }
                } label: {
                    HStack(spacing: 8) {
                        if aiAction == .generateRecipe {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(aiAction == .generateRecipe ? "Creating…" : "Fill recipe")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(RecipeTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(
                    aiAction != nil
                        || (recipePhotoData == nil && recipeDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                )
                Spacer(minLength: 0)
            }

            if hasGeneratedRecipe {
                Label("Draft filled in — check it before saving. Nutrition is estimated.", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(RecipeTheme.leaf)
            }
        }
        .padding(15)
        .background(RecipeTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("The recipe", eyebrow: "01")
            TextField("Recipe name", text: $draft.name)
                .font(.title3.weight(.medium))
                .padding(15)
                .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 15))

            Picker("Category", selection: $draft.category) {
                ForEach(RecipeCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .tint(RecipeTheme.accent)

            HStack(spacing: 12) {
                numberCard("Cook time", symbol: "clock", value: $draft.cookTimeMinutes, suffix: "min", range: 1...999)
                VStack(alignment: .leading, spacing: 9) {
                    Label("Serves", systemImage: "person.2")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("\(draft.servings)")
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        Stepper("Adjust servings", value: $draft.servings, in: 1...99)
                            .labelsHidden()
                            .fixedSize()
                            .accessibilityValue("\(draft.servings)")
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 15))
            }
            .onChange(of: draft.servings) { _, value in
                draft.nutritionIsEstimated = false
            }
        }
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Ingredients", eyebrow: "02")
                Spacer()
                Text("\(draft.ingredients.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 9) {
                ForEach(Array(draft.ingredients.enumerated()), id: \.element.id) { index, ingredient in
                    ingredientRow(at: index, ingredient: ingredient)
                }
            }

            Button {
                withAnimation(Motion.standard) {
                    draft.ingredients.append(Ingredient(name: "", quantity: nil, unit: "g"))
                }
                Feedback.tap()
            } label: {
                Label("Add ingredient", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RecipeTheme.accent)
            }
            .padding(.top, 2)
        }
        .onChange(of: draft.ingredients) { _, _ in
            draft.nutritionIsEstimated = false
        }
    }

    private func ingredientRow(at index: Int, ingredient: Ingredient) -> some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                TextField("Ingredient", text: ingredientBinding(index, \.name))
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    moveIngredient(at: index, by: -1)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .disabled(index == 0)
                .accessibilityLabel("Move ingredient up")
                Button {
                    moveIngredient(at: index, by: 1)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .disabled(index == draft.ingredients.count - 1)
                .accessibilityLabel("Move ingredient down")
                Button(role: .destructive) {
                    withAnimation { _ = draft.ingredients.remove(at: index) }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .accessibilityLabel("Remove ingredient")
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                TextField("Qty", text: quantityBinding(index))
                    .keyboardType(.decimalPad)
                    .frame(width: 76)
                    .accessibilityLabel("Ingredient quantity")
                TextField("Unit", text: ingredientBinding(index, \.unit))
                    .frame(width: 82)
                    .accessibilityLabel("Ingredient unit")
                Text("g · ml · cup · tbsp · tsp · piece")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 1)
        }
        .padding(13)
        .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("How it comes together", eyebrow: "03")
            Text("Write it however you remember it. Rough notes are welcome.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $stepsText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 140)
                .padding(10)
                .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 15))
                .overlay(alignment: .topLeading) {
                    if stepsText.isEmpty {
                        Text("Chop this, add that, let it simmer...")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 19)
                            .allowsHitTesting(false)
                    }
                }
            aiButton(
                title: "Improve instructions",
                subtitle: "Keep your meaning, make it clearer",
                action: .instructions
            )
        }
    }

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("Nutrition", eyebrow: "04")
                Spacer()
                Text("per serving")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                nutritionField("Calories", value: $draft.calories, unit: "kcal")
                macroField("Protein", value: $draft.protein, unit: "g")
                macroField("Fat", value: $draft.fat, unit: "g")
                macroField("Carbs", value: $draft.carbs, unit: "g")
            }
            .onChange(of: draft.calories) { _, _ in draft.nutritionIsEstimated = false }
            .onChange(of: draft.protein) { _, _ in draft.nutritionIsEstimated = false }
            .onChange(of: draft.fat) { _, _ in draft.nutritionIsEstimated = false }
            .onChange(of: draft.carbs) { _, _ in draft.nutritionIsEstimated = false }

            if draft.nutritionIsEstimated {
                Label("Estimated · editable anytime", systemImage: "sparkles")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(RecipeTheme.accent)
            }
            aiButton(
                title: "Calculate nutrition",
                subtitle: "An estimate from your ingredients",
                action: .nutrition
            )
        }
    }

    private var instructionsPreviewSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Your notes")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                    Text(stepsText.isEmpty ? "No notes yet." : stepsText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(15)
                        .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 16))

                    Text("A clearer version")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(improvedSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 11) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(RecipeTheme.accent)
                                    .frame(width: 22, height: 22)
                                    .background(RecipeTheme.accent.opacity(0.1), in: Circle())
                                Text(step)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(15)
                    .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(20)
            }
            .navigationTitle("Review instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep mine") { showInstructionsPreview = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use this") {
                        stepsText = improvedSteps.joined(separator: "\n")
                        showInstructionsPreview = false
                        Feedback.save()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func nutritionPreviewSheet(_ estimate: NutritionEstimate) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(Int(estimate.perServing.calories.rounded()))")
                            .font(.system(.largeTitle, design: .serif).weight(.regular))
                        Text("kcal per serving")
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 9) {
                        previewMacro("Protein", estimate.perServing.protein)
                        previewMacro("Fat", estimate.perServing.fat)
                        previewMacro("Carbs", estimate.perServing.carbs)
                    }

                    if !estimate.warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Check these ingredients first", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)
                            ForEach(estimate.warnings, id: \.self) { warning in
                                Text("• \(warning)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Add quantities or clarify names, then recalculate. No estimate has been applied.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 15))
                    }

                    DisclosureGroup("Per-ingredient breakdown") {
                        VStack(spacing: 10) {
                            ForEach(estimate.breakdown) { line in
                                HStack(alignment: .top) {
                                    Text(line.ingredient)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(line.calories.formatted(.number.precision(.fractionLength(0)))) kcal")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.footnote)
                                HStack(spacing: 12) {
                                    Text("P \(line.protein.formatted(.number.precision(.fractionLength(1))))g")
                                    Text("F \(line.fat.formatted(.number.precision(.fractionLength(1))))g")
                                    Text("C \(line.carbs.formatted(.number.precision(.fractionLength(1))))g")
                                }
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                if line.id != estimate.breakdown.last?.id { Divider() }
                            }
                        }
                        .padding(.top, 12)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(15)
                    .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 15))
                }
                .padding(20)
            }
            .navigationTitle("Nutrition estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { nutritionPreview = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(estimate.warnings.isEmpty ? "Use estimate" : "Fix ingredients") {
                        guard estimate.warnings.isEmpty else {
                            nutritionPreview = nil
                            return
                        }
                        draft.calories = Int(estimate.perServing.calories.rounded())
                        draft.protein = estimate.perServing.protein
                        draft.fat = estimate.perServing.fat
                        draft.carbs = estimate.perServing.carbs
                        draft.nutritionIsEstimated = true
                        nutritionPreview = nil
                        Feedback.save()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func aiButton(title: String, subtitle: String, action: AIAction) -> some View {
        Button {
            Task { await runAI(action) }
        } label: {
            HStack(spacing: 12) {
                if aiAction == action {
                    ProgressView().tint(RecipeTheme.accent)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(RecipeTheme.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(aiAction != nil)
    }

    private func runAI(_ action: AIAction) async {
        aiAction = action
        failedAIAction = nil
        retrySaveAfterError = false
        aiError = nil
        defer { aiAction = nil }
        do {
            switch action {
            case .generateRecipe:
                let description = recipeDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                guard recipePhotoData != nil || !description.isEmpty else {
                    throw AppError.invalidRecipe("Add a photo or describe the recipe first.")
                }
                let generated = try await aiService.generateRecipe(
                    description: description,
                    imageData: recipePhotoData
                )
                draft.name = generated.name
                draft.category = generated.category
                draft.cookTimeMinutes = generated.cookTimeMinutes
                draft.servings = generated.servings
                draft.calories = generated.calories
                draft.protein = generated.protein
                draft.fat = generated.fat
                draft.carbs = generated.carbs
                draft.ingredients = generated.ingredients
                stepsText = generated.steps.joined(separator: "\n")
                draft.nutritionIsEstimated = true
                hasGeneratedRecipe = true
            case .instructions:
                guard !stepsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AppError.invalidRecipe("Add your cooking notes first.")
                }
                improvedSteps = try await aiService.improveInstructions(
                    notes: stepsText,
                    ingredients: usableIngredients
                )
                showInstructionsPreview = true
            case .nutrition:
                guard !usableIngredients.isEmpty else {
                    throw AppError.invalidRecipe("Add at least one named ingredient first.")
                }
                nutritionPreview = NutritionPreview(
                    estimate: try await aiService.calculateNutrition(
                        ingredients: usableIngredients,
                        servings: draft.servings
                    )
                )
            }
        } catch {
            aiError = error.localizedDescription
            if let appError = error as? AppError, case .invalidRecipe = appError {
                failedAIAction = nil
            } else {
                failedAIAction = action
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                throw AppError.invalidResponse
            }

            let maximumDimension: CGFloat = 1400
            let scale = min(1, maximumDimension / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            var renderer = UIGraphicsImageRenderer(size: size)
            var compressed = renderer.jpegData(withCompressionQuality: 0.72) { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            if compressed.count > 1 * 1_024 * 1_024 {
                let smallerSize = CGSize(width: size.width * 0.8, height: size.height * 0.8)
                renderer = UIGraphicsImageRenderer(size: smallerSize)
                compressed = renderer.jpegData(withCompressionQuality: 0.55) { _ in
                    image.draw(in: CGRect(origin: .zero, size: smallerSize))
                }
            }
            guard compressed.count <= 1 * 1_024 * 1_024 else {
                throw AppError.invalidRecipe("That photo is too large to send. Choose a smaller image.")
            }
            recipePhotoData = compressed
            aiError = nil
            failedAIAction = nil
        } catch {
            selectedPhoto = nil
            aiError = error.localizedDescription
            failedAIAction = nil
        }
    }

    private var usableIngredients: [Ingredient] {
        draft.ingredients.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func saveRecipe() async {
        aiError = nil
        failedAIAction = nil
        retrySaveAfterError = false
        let ingredients = usableIngredients
        let steps = stepsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            aiError = "Give your recipe a name before saving."
            return
        }
        guard !ingredients.isEmpty else {
            aiError = "Add at least one ingredient before saving."
            return
        }
        guard !steps.isEmpty else {
            aiError = "Add at least one cooking step before saving."
            return
        }
        guard draft.cookTimeMinutes > 0, draft.servings > 0 else {
            aiError = "Cook time and servings must be greater than zero."
            return
        }
        guard draft.calories >= 0, draft.protein >= 0, draft.fat >= 0, draft.carbs >= 0 else {
            aiError = "Nutrition values can’t be negative."
            return
        }
        guard ingredients.allSatisfy({ ($0.quantity ?? 0) >= 0 }) else {
            aiError = "Ingredient quantities can’t be negative."
            return
        }
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.ingredients = ingredients
        draft.steps = steps
        draft.cookTimeMinutes = max(1, draft.cookTimeMinutes)
        draft.servings = max(1, draft.servings)
        isSaving = true
        retrySaveAfterError = false
        defer { isSaving = false }
        do {
            try await onSave(draft)
            dismiss()
        } catch {
            aiError = error.localizedDescription
            retrySaveAfterError = true
        }
    }

    private func sectionTitle(_ title: String, eyebrow: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(eyebrow)
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(RecipeTheme.accent)
            Text(title)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .tracking(-0.2)
        }
    }

    private func numberCard(_ title: String, symbol: String, value: Binding<Int>, suffix: String, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 5) {
                TextField("0", text: Binding(
                    get: { String(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0) ?? 0 }
                ))
                .keyboardType(.numberPad)
                .font(.title3.weight(.semibold).monospacedDigit())
                .frame(maxWidth: .infinity)
                Text(suffix).font(.caption).foregroundStyle(.secondary)
            }
            Stepper("", value: value, in: range)
                .labelsHidden()
                .frame(height: 17)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 15))
    }

    private func nutritionField(_ title: String, value: Binding<Int>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            TextField("0", text: Binding(
                get: { String(value.wrappedValue) },
                set: { value.wrappedValue = Int($0) ?? 0 }
            ))
            .keyboardType(.numberPad)
            .font(.headline.monospacedDigit())
            Text(unit).font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 13))
    }

    private func macroField(_ title: String, value: Binding<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            TextField("0", text: Binding(
                get: { value.wrappedValue == 0 ? "" : value.wrappedValue.formatted(.number.precision(.fractionLength(0...1))) },
                set: { value.wrappedValue = Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0 }
            ))
            .keyboardType(.decimalPad)
            .font(.headline.monospacedDigit())
            Text(unit).font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 13))
    }

    private func previewMacro(_ name: String, _ amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).font(.caption).foregroundStyle(.secondary)
            Text("\(amount.formatted(.number.precision(.fractionLength(1))))g")
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 13))
    }

    private func ingredientBinding(_ index: Int, _ keyPath: WritableKeyPath<Ingredient, String>) -> Binding<String> {
        Binding(
            get: { draft.ingredients.indices.contains(index) ? draft.ingredients[index][keyPath: keyPath] : "" },
            set: { if draft.ingredients.indices.contains(index) { draft.ingredients[index][keyPath: keyPath] = $0 } }
        )
    }

    private func quantityBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard draft.ingredients.indices.contains(index), let quantity = draft.ingredients[index].quantity else { return "" }
                return quantity.formatted(.number.precision(.fractionLength(0...2)))
            },
            set: {
                guard draft.ingredients.indices.contains(index) else { return }
                draft.ingredients[index].quantity = Double($0.replacingOccurrences(of: ",", with: "."))
            }
        )
    }

    private func moveIngredient(at index: Int, by offset: Int) {
        let destination = index + offset
        guard draft.ingredients.indices.contains(destination), draft.ingredients.indices.contains(index) else { return }
        withAnimation(Motion.standard) {
            draft.ingredients.swapAt(index, destination)
        }
        Feedback.tap()
    }
}
