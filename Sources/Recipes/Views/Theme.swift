import SwiftUI

enum RecipeAccent: String, CaseIterable, Identifiable {
    case tomato
    case sage
    case saffron
    case ocean
    case plum

    static let storageKey = "recipeAccent"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .tomato: "Tomato"
        case .sage: "Sage"
        case .saffron: "Saffron"
        case .ocean: "Ocean"
        case .plum: "Plum"
        }
    }

    var color: Color {
        switch self {
        case .tomato: Color(red: 0.79, green: 0.27, blue: 0.16)
        case .sage: Color(red: 0.25, green: 0.48, blue: 0.35)
        case .saffron: Color(red: 0.73, green: 0.49, blue: 0.08)
        case .ocean: Color(red: 0.18, green: 0.42, blue: 0.60)
        case .plum: Color(red: 0.53, green: 0.32, blue: 0.49)
        }
    }
}

enum RecipeTheme {
    static let accent = Color.accentColor
    static let leaf = Color(red: 0.25, green: 0.48, blue: 0.35)
    static let butter = Color(red: 0.96, green: 0.77, blue: 0.36)
    static let ink = Color.primary
    static let secondaryInk = Color.secondary
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let canvas = Color(uiColor: .systemGroupedBackground)
}

extension View {
    func recipeCardStyle() -> some View {
        padding(16)
            .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct CategoryIcon: View {
    let category: RecipeCategory
    var size: CGFloat = 32

    var body: some View {
        Image(category.iconName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
