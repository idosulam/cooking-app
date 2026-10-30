import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    let namespace: Namespace.ID
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isCooking = false
    @State private var showsDeleteConfirmation = false
    @State private var isPlanSheetPresented = false
    @State private var planToast: String?

    private var tint: Color { recipe.category.tint }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                nutrition
                ingredients
                method
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 115)
        }
        .background(RecipeTheme.canvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                isCooking = true
                Feedback.tap()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "flame.fill")
                    Text("Cook")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(RecipeTheme.accent, in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
        }
        .zoomDestination(id: recipe.id, in: namespace)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Menu {
                        Button("Today") { planMeal(on: .now) }
                        Button("Tomorrow") {
                            planMeal(on: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
                        }
                        Button("Choose date…") { isPlanSheetPresented = true }
                        if MealPlanStore.meal(on: .now)?.recipeID == recipe.id {
                            Button("Remove from today", role: .destructive) {
                                MealPlanner.remove(on: .now)
                                Feedback.tap()
                            }
                        }
                    } label: {
                        Label("Plan meal", systemImage: "calendar.badge.plus")
                    }
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit recipe", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showsDeleteConfirmation = true
                    } label: {
                        Label("Delete recipe", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .accessibilityLabel("Recipe options")
            }
        }
        .confirmationDialog("Delete this recipe?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete recipe", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("This can’t be undone.")
        }
        .fullScreenCover(isPresented: $isCooking) {
            CookingView(recipe: recipe)
        }
        .sheet(isPresented: $isPlanSheetPresented) {
            PlanDateSheet { date in planMeal(on: date) }
        }
        .overlay(alignment: .top) {
            if let planToast {
                Label(planToast, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func planMeal(on date: Date) {
        MealPlanner.plan(recipe, on: date)
        Feedback.check()
        let label: String
        if Calendar.current.isDateInToday(date) {
            label = "Planned for today"
        } else if Calendar.current.isDateInTomorrow(date) {
            label = "Planned for tomorrow"
        } else {
            label = "Planned for \(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))"
        }
        withAnimation(Motion.standard) { planToast = label }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.3)) { planToast = nil }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 17) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.75), tint.opacity(0.32)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle()
                    .strokeBorder(.white.opacity(0.42), lineWidth: 1)
                    .frame(width: 190, height: 190)
                    .offset(x: 220, y: 48)
                CategoryIcon(category: recipe.category, size: 104)
                    .foregroundStyle(recipe.category.iconInk)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(recipe.category.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(recipe.category.iconInk)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(RecipeTheme.chipFill, in: Capsule())
                    .padding(16)
            }
            .frame(height: 222)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            Text(recipe.name)
                .font(.system(.largeTitle, design: .serif).weight(.regular))
                .tracking(-0.9)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 0) {
                Label("\(recipe.cookTimeMinutes) min", systemImage: "clock")
                separator
                Label("\(recipe.servings) servings", systemImage: "person.2")
                separator
                Label {
                    Text(recipe.category.rawValue)
                } icon: {
                    CategoryIcon(category: recipe.category, size: 15)
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
    }

    private var separator: some View {
        Circle().fill(.tertiary).frame(width: 3, height: 3).padding(.horizontal, 10)
    }

    private var nutrition: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Per serving")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                Spacer()
                if recipe.nutritionIsEstimated {
                    Label("Estimated", systemImage: "sparkles")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(RecipeTheme.accent)
                }
            }
            HStack(spacing: 9) {
                NutritionTile(value: "\(recipe.calories)", unit: "kcal", label: "Energy", tint: RecipeTheme.accent)
                NutritionTile(value: recipe.protein.formatted(.number.precision(.fractionLength(0...1))), unit: "g", label: "Protein", tint: RecipeTheme.leaf)
                NutritionTile(value: recipe.fat.formatted(.number.precision(.fractionLength(0...1))), unit: "g", label: "Fat", tint: RecipeTheme.fat)
                NutritionTile(value: recipe.carbs.formatted(.number.precision(.fractionLength(0...1))), unit: "g", label: "Carbs", tint: RecipeTheme.carbs)
            }
            MacroBar(protein: recipe.protein, fat: recipe.fat, carbs: recipe.carbs)
        }
    }

    private var ingredients: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeading("Ingredients", count: "\(recipe.ingredients.count)")
            VStack(spacing: 0) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.element.id) { index, ingredient in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Circle()
                            .fill(RecipeTheme.leaf.opacity(0.75))
                            .frame(width: 6, height: 6)
                        Text(ingredient.name)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(quantityDescription(ingredient))
                            .font(.subheadline.weight(.medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    if index < recipe.ingredients.count - 1 { Divider().padding(.leading, 17) }
                }
            }
            .padding(.horizontal, 15)
            .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var method: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeading("The method", count: "\(recipe.steps.count) steps")
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 13) {
                        Text(String(format: "%02d", index + 1))
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(RecipeTheme.accent)
                            .frame(width: 30, height: 30)
                            .background(RecipeTheme.accent.opacity(0.1), in: Circle())
                        Text(step)
                            .font(.subheadline)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(16)
            .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func sectionHeading(_ title: String, count: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(.title3, design: .serif).weight(.semibold))
            Spacer()
            Text(count).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func quantityDescription(_ ingredient: Ingredient) -> String {
        guard let quantity = ingredient.quantity else { return ingredient.unit }
        let value = quantity.formatted(.number.precision(.fractionLength(0...2)))
        return ingredient.unit.isEmpty ? value : "\(value) \(ingredient.unit)"
    }
}

private struct NutritionTile: View {
    let value: String
    let unit: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(.headline, design: .rounded).weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            }
            Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            Capsule().fill(tint).frame(width: 20, height: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct PlanDateSheet: View {
    let onPlan: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            DatePicker("Day", selection: $date, in: Date.now..., displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(.horizontal)
                .navigationTitle("Plan meal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add") {
                            onPlan(date)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            Spacer()
        }
        .presentationDetents([.medium])
    }
}
