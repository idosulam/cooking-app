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
            try? await Task.sleep(for: .seconds(2.1))
            withAnimation(.easeOut(duration: 0.45)) {
                showSplash = false
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: authService.session?.user.id)
        .tint(accentColor)
    }
}

private struct SplashView: View {
    @State private var tileScale: CGFloat = 0.7
    @State private var tileOpacity = 0.0
    @State private var potProgress: CGFloat = 0
    @State private var lidDrop: CGFloat = -16
    @State private var lidOpacity = 0.0
    @State private var steamProgress: CGFloat = 0
    @State private var titleOpacity = 0.0
    @State private var titleOffset: CGFloat = 12

    private let stroke = StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)

    var body: some View {
        VStack(spacing: 26) {
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [RecipeTheme.accent, RecipeTheme.accent.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: RecipeTheme.accent.opacity(0.35), radius: 22, y: 12)
                ZStack {
                    PotBodyShape().fill(.white.opacity(0.14))
                    PotBodyShape()
                        .trim(from: 0, to: potProgress)
                        .stroke(.white, style: stroke)
                    LidShape()
                        .stroke(.white, style: stroke)
                        .offset(y: lidDrop)
                        .opacity(lidOpacity)
                    SteamShape()
                        .trim(from: 0, to: steamProgress)
                        .stroke(RecipeTheme.butter, style: stroke)
                }
                .frame(width: 80, height: 80)
                .offset(y: 4)
            }
            .frame(width: 128, height: 128)
            .scaleEffect(tileScale)
            .opacity(tileOpacity)

            VStack(spacing: 6) {
                Text("Recipes")
                    .font(.system(size: 34, design: .serif).weight(.semibold))
                    .tracking(-0.6)
                Text("COOK SOMETHING GOOD")
                    .font(.caption2.weight(.bold))
                    .tracking(2.2)
                    .foregroundStyle(.secondary)
            }
            .offset(y: titleOffset)
            .opacity(titleOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RecipeTheme.canvas.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                tileScale = 1
                tileOpacity = 1
            }
            withAnimation(.easeInOut(duration: 0.5).delay(0.25)) {
                potProgress = 1
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.7)) {
                lidDrop = 0
                lidOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.95)) {
                steamProgress = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
                titleOpacity = 1
                titleOffset = 0
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recipes")
    }
}

private struct PotBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x / 100 * rect.width, y: rect.minY + y / 100 * rect.height)
        }
        var path = Path()
        path.move(to: p(18, 52))
        path.addLine(to: p(18, 68))
        path.addQuadCurve(to: p(30, 82), control: p(18, 82))
        path.addLine(to: p(70, 82))
        path.addQuadCurve(to: p(82, 68), control: p(82, 82))
        path.addLine(to: p(82, 52))
        path.move(to: p(18, 60))
        path.addLine(to: p(8, 60))
        path.move(to: p(82, 60))
        path.addLine(to: p(92, 60))
        return path
    }
}

private struct LidShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x / 100 * rect.width, y: rect.minY + y / 100 * rect.height)
        }
        var path = Path()
        path.move(to: p(14, 52))
        path.addLine(to: p(86, 52))
        path.move(to: p(24, 52))
        path.addCurve(to: p(76, 52), control1: p(28, 34), control2: p(72, 34))
        path.addEllipse(in: CGRect(
            x: rect.minX + 46.5 / 100 * rect.width,
            y: rect.minY + 31 / 100 * rect.height,
            width: 7 / 100 * rect.width,
            height: 7 / 100 * rect.height
        ))
        return path
    }
}

private struct SteamShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x / 100 * rect.width, y: rect.minY + y / 100 * rect.height)
        }
        var path = Path()
        let wisps: [(CGFloat, CGFloat)] = [(35, 15), (50, 20), (65, 15)]
        for (x, h) in wisps {
            path.move(to: p(x, 27))
            path.addCurve(
                to: p(x, 27 - h),
                control1: p(x - 6, 27 - h * 0.35),
                control2: p(x + 6, 27 - h * 0.7)
            )
        }
        return path
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
