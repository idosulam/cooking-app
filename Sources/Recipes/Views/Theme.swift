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
        case .tomato: Color.adaptive(red: 0.79, green: 0.27, blue: 0.16)
        case .sage: Color.adaptive(red: 0.25, green: 0.48, blue: 0.35)
        case .saffron: Color.adaptive(red: 0.73, green: 0.49, blue: 0.08)
        case .ocean: Color.adaptive(red: 0.18, green: 0.42, blue: 0.60)
        case .plum: Color.adaptive(red: 0.53, green: 0.32, blue: 0.49)
        }
    }
}

enum RecipeTheme {
    static let accent = Color.accentColor
    static let leaf = Color.adaptive(red: 0.25, green: 0.48, blue: 0.35)
    static let butter = Color(red: 0.96, green: 0.77, blue: 0.36)
    static let protein = Color.adaptive(red: 0.25, green: 0.48, blue: 0.35)
    static let fat = Color.adaptive(red: 0.93, green: 0.55, blue: 0.15)
    static let carbs = Color.adaptive(red: 0.20, green: 0.45, blue: 0.85)
    static let chipFill = Color(light: .white.opacity(0.43), dark: .white.opacity(0.14))
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

// MARK: - Adaptive colour

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    /// Same hue in light mode, slightly brighter in dark mode so it stays readable.
    static func adaptive(red: Double, green: Double, blue: Double) -> Color {
        Color(
            light: Color(red: red, green: green, blue: blue),
            dark: Color(red: min(red + 0.12, 1), green: min(green + 0.12, 1), blue: min(blue + 0.12, 1))
        )
    }
}

extension RecipeCategory {
    var tint: Color {
        switch self {
        case .starter: Color(light: Color(red: 0.87, green: 0.75, blue: 0.58), dark: Color(red: 0.55, green: 0.42, blue: 0.24))
        case .main: Color(light: Color(red: 0.68, green: 0.78, blue: 0.68), dark: Color(red: 0.28, green: 0.42, blue: 0.30))
        case .snack: Color(light: Color(red: 0.94, green: 0.79, blue: 0.47), dark: Color(red: 0.62, green: 0.46, blue: 0.14))
        case .dessert: Color(light: Color(red: 0.88, green: 0.68, blue: 0.62), dark: Color(red: 0.58, green: 0.32, blue: 0.28))
        case .sauce: Color(light: Color(red: 0.70, green: 0.79, blue: 0.83), dark: Color(red: 0.26, green: 0.40, blue: 0.48))
        }
    }

    /// Icon and label colour that sits on top of `tint`.
    var iconInk: Color {
        Color(light: .black.opacity(0.68), dark: .white.opacity(0.88))
    }
}

// MARK: - Motion

enum Motion {
    static let quick = Animation.spring(response: 0.3, dampingFraction: 0.75)
    static let standard = Animation.spring(response: 0.4, dampingFraction: 0.85)
    static let playful = Animation.spring(response: 0.45, dampingFraction: 0.65)
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

// MARK: - Zoom transition (iOS 18+, falls back to a normal push on iOS 17)

extension View {
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func zoomDestination(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}

// MARK: - Macros

struct MacroBar: View {
    let protein: Double
    let fat: Double
    let carbs: Double

    var body: some View {
        let total = max(protein + fat + carbs, 0.001)
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Rectangle().fill(RecipeTheme.protein)
                    .frame(width: proxy.size.width * protein / total)
                Rectangle().fill(RecipeTheme.fat)
                    .frame(width: proxy.size.width * fat / total)
                Rectangle().fill(RecipeTheme.carbs)
                    .frame(width: proxy.size.width * carbs / total)
            }
            .clipShape(Capsule())
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}
