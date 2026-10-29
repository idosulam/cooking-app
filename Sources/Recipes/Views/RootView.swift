import SwiftUI

struct RootView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var recipeRepository: RecipeRepository
    @ObservedObject var aiService: AIService
    @AppStorage(RecipeAccent.storageKey) private var selectedAccent = RecipeAccent.tomato.rawValue
    let configurationError: String?
    @State private var showSplash = true

    private var accentColor: Color {
        RecipeAccent(rawValue: selectedAccent)?.color ?? RecipeAccent.tomato.color
    }

    var body: some View {
        Group {
            if let configurationError {
                SetupView(message: configurationError)
            } else if showSplash {
                SplashView()
            } else if authService.isLoading {
                ProgressView()
                    .tint(RecipeTheme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RecipeTheme.canvas)
            } else if authService.session == nil {
                AuthView(authService: authService)
            } else {
                HomeView(authService: authService, repository: recipeRepository, aiService: aiService)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.35))
            withAnimation(.easeOut(duration: 0.45)) {
                showSplash = false
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: authService.session?.user.id)
        .tint(accentColor)
    }
}

private struct SplashView: View {
    @State private var markScale = 0.66
    @State private var markOpacity = 0.2
    @State private var titleOffset: CGFloat = 12

    var body: some View {
        VStack(spacing: 17) {
            ZStack {
                Circle()
                    .fill(RecipeTheme.accent.opacity(0.10))
                    .frame(width: 112, height: 112)
                    .scaleEffect(markScale * 1.15)
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 76, weight: .light))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(RecipeTheme.accent, RecipeTheme.butter)
                    .scaleEffect(markScale)
                    .opacity(markOpacity)
            }
            Text("recipes, gathered")
                .font(.system(.title3, design: .serif).weight(.medium))
                .tracking(0.4)
                .offset(y: titleOffset)
                .opacity(markOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RecipeTheme.canvas.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.68)) {
                markScale = 1
                markOpacity = 1
                titleOffset = 0
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recipes")
    }
}

private struct SetupView: View {
    let message: String

    var body: some View {
        ContentUnavailableView(
            "Connect your kitchen",
            systemImage: "key.horizontal",
            description: Text(message)
        )
    }
}
