import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    let namespace: Namespace.ID
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isCooking = false
    @State private var showsDeleteConfirmation = false

    private var tint: Color {
        switch recipe.category {
        case .starter: Color(red: 0.87, green: 0.75, blue: 0.58)
        case .main: Color(red: 0.68, green: 0.78, blue: 0.68)
        case .snack: Color(red: 0.94, green: 0.79, blue: 0.47)
        case .dessert: Color(red: 0.88, green: 0.68, blue: 0.62)
        case .sauce: Color(red: 0.70, green: 0.79, blue: 0.83)
        }
    }

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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
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
                Image(systemName: recipe.category.symbol)
                    .font(.system(size: 76, weight: .ultraLight))
                    .foregroundStyle(Color.black.opacity(0.68))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(recipe.category.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(.black.opacity(0.66))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.43), in: Capsule())
                    .padding(16)
            }
            .frame(height: 222)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .matchedGeometryEffect(id: recipe.id, in: namespace)

            Text(recipe.name)
                .font(.system(.largeTitle, design: .serif).weight(.regular))
                .tracking(-0.9)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 0) {
                Label("\(recipe.cookTimeMinutes) min", systemImage: "clock")
                separator
                Label("\(recipe.servings) servings", systemImage: "person.2")
                separator
                Label(recipe.category.rawValue, systemImage: recipe.category.symbol)
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
                NutritionTile(value: recipe.fat.formatted(.number.precision(.fractionLength(0...1))), unit: "g", label: "Fat", tint: Color.orange)
                NutritionTile(value: recipe.carbs.formatted(.number.precision(.fractionLength(0...1))), unit: "g", label: "Carbs", tint: Color.blue)
            }
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
                Text(unit).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
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
