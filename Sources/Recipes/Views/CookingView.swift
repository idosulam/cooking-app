import SwiftUI
import UIKit

struct CookingView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @State private var checkedIngredients: Set<UUID> = []
    @State private var phase: Phase = .ingredients
    @State private var currentStep = 0
    @State private var isTimerRunning = false
    @State private var secondsRemaining = 0
    @State private var timerEndDate: Date?
    @State private var timerStartedForStep = false
    @State private var direction: CGFloat = 1
    @AppStorage(RecipeAccent.storageKey) private var selectedAccent = RecipeAccent.tomato.rawValue
    @State private var servings: Int

    init(recipe: Recipe) {
        self.recipe = recipe
        _servings = State(initialValue: max(recipe.servings, 1))
    }

    private enum Phase {
        case ingredients
        case steps
        case finished
    }

    private var currentInstruction: String {
        recipe.steps.indices.contains(currentStep) ? recipe.steps[currentStep] : ""
    }

    private var stepProgress: Double {
        guard !recipe.steps.isEmpty else { return 1 }
        return Double(currentStep + 1) / Double(recipe.steps.count)
    }

    var body: some View {
        ZStack {
            RecipeTheme.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Group {
                    switch phase {
                    case .ingredients: checklist
                    case .steps: stepContent
                    case .finished: finishContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .statusBarHidden()
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            loadTimer(for: 0)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            TimerNotifier.cancel()
            CookingActivityManager.shared.end()
        }
        .onChange(of: phase) { _, newPhase in
            switch newPhase {
            case .ingredients: CookingActivityManager.shared.end()
            case .steps: startActivity()
            case .finished: CookingActivityManager.shared.finish()
            }
        }
        .onChange(of: currentStep) { _, newStep in
            guard phase == .steps else { return }
            CookingActivityManager.shared.update(step: newStep)
        }
        .task(id: isTimerRunning) {
            guard isTimerRunning, let end = timerEndDate else { return }
            while !Task.isCancelled {
                secondsRemaining = max(0, Int(end.timeIntervalSinceNow.rounded(.up)))
                if secondsRemaining == 0 { break }
                try? await Task.sleep(for: .milliseconds(250))
            }
            if !Task.isCancelled && secondsRemaining == 0 && isTimerRunning {
                completeTimer()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 45)
                .onEnded { value in
                    guard phase == .steps else { return }
                    if value.translation.width < -60 {
                        advanceStep()
                    } else if value.translation.width > 60 {
                        goBack()
                    }
                }
        )
    }

    private var topBar: some View {
        HStack {
            Button {
                if phase == .steps {
                    stopTimer()
                    phase = .ingredients
                } else {
                    dismiss()
                }
                Feedback.tap()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(RecipeTheme.card, in: Circle())
            }
            .accessibilityLabel(phase == .steps ? "Back to ingredients" : "Close cooking mode")
            Spacer()
            VStack(spacing: 3) {
                Text("COOKING")
                    .font(.caption2.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(RecipeTheme.accent)
                Text(recipe.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 15))
                .foregroundStyle(RecipeTheme.accent)
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 19)
        .padding(.top, 8)
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Before we begin")
                .font(.system(.largeTitle, design: .serif).weight(.regular))
                .tracking(-0.8)
                .padding(.top, 32)
            Text("\(checkedIngredients.count) of \(recipe.ingredients.count) ready")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 7)
                .padding(.bottom, 16)

            servingsPicker
                .padding(.bottom, 18)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(RecipeTheme.card)
                    Capsule()
                        .fill(RecipeTheme.leaf)
                        .frame(width: proxy.size.width * checklistProgress)
                }
            }
            .frame(height: 5)
            .padding(.bottom, 17)

            ScrollView {
                VStack(spacing: 9) {
                    ForEach(recipe.ingredients) { ingredient in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if checkedIngredients.contains(ingredient.id) {
                                    checkedIngredients.remove(ingredient.id)
                                } else {
                                    checkedIngredients.insert(ingredient.id)
                                    Feedback.check()
                                }
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: checkedIngredients.contains(ingredient.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 26, weight: .regular))
                                    .symbolEffect(.bounce, value: checkedIngredients.contains(ingredient.id))
                                    .foregroundStyle(checkedIngredients.contains(ingredient.id) ? RecipeTheme.leaf : Color(uiColor: .tertiaryLabel))
                                Text(ingredient.name)
                                    .font(.body.weight(.medium))
                                    .strikethrough(checkedIngredients.contains(ingredient.id), color: .secondary)
                                    .foregroundStyle(checkedIngredients.contains(ingredient.id) ? .secondary : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(quantityDescription(ingredient))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 16)
                            .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(ingredient.name), \(quantityDescription(ingredient))")
                        .accessibilityAddTraits(checkedIngredients.contains(ingredient.id) ? .isSelected : [])
                    }
                }
            }
            .padding(.bottom, 20)

            Button {
                phase = .steps
                currentStep = 0
                Feedback.tap()
            } label: {
                Text("Start cooking")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(RecipeTheme.accent, in: Capsule())
            }
            .disabled(checkedIngredients.count < recipe.ingredients.count)
            .opacity(checkedIngredients.count < recipe.ingredients.count ? 0.48 : 1)

            Button("Skip anyway") {
                phase = .steps
                currentStep = 0
                Feedback.tap()
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
            .padding(.bottom, 10)
        }
        .padding(.horizontal, 21)
    }

    private var scale: Double {
        Double(servings) / Double(max(recipe.servings, 1))
    }

    private var servingsPicker: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2")
                .foregroundStyle(RecipeTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Servings").font(.subheadline.weight(.semibold))
                if servings != recipe.servings {
                    Text("Original recipe: \(recipe.servings)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            servingsButton("minus", label: "Fewer servings", disabled: servings <= 1) { servings -= 1 }
            Text("\(servings)")
                .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                .frame(minWidth: 30)
                .contentTransition(.numericText())
            servingsButton("plus", label: "More servings", disabled: servings >= 99) { servings += 1 }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .animation(.snappy, value: servings)
    }

    private func servingsButton(_ symbol: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Feedback.tap()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(RecipeTheme.accent, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(label)
    }

    private var checklistProgress: CGFloat {
        guard !recipe.ingredients.isEmpty else { return 0 }
        return CGFloat(checkedIngredients.count) / CGFloat(recipe.ingredients.count)
    }

    private var stepContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("STEP \(currentStep + 1) OF \(recipe.steps.count)")
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(RecipeTheme.accent)
                Spacer()
                Text("\(Int(stepProgress * 100))%")
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 35)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(RecipeTheme.card)
                    Capsule().fill(RecipeTheme.accent).frame(width: proxy.size.width * stepProgress)
                }
            }
            .frame(height: 5)
            .padding(.top, 13)

            Spacer(minLength: 25)
            Text("Take it one\nstep at a time.")
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundStyle(.secondary)
                .padding(.bottom, 15)

            Text(currentInstruction)
                .font(.system(.largeTitle, design: .serif).weight(.regular))
                .tracking(-0.6)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
                .id(currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
                ))
                .accessibilityAddTraits(.isHeader)

            if secondsRemaining > 0 {
                timerControl
                    .padding(.top, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Spacer(minLength: 25)

            HStack(spacing: 12) {
                Button(action: goBack) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(RecipeTheme.card, in: Capsule())
                }
                .disabled(currentStep == 0)
                .opacity(currentStep == 0 ? 0.4 : 1)

                Button(action: advanceStep) {
                    HStack(spacing: 8) {
                        Text(currentStep == recipe.steps.count - 1 ? "Finish" : "Next step")
                        Image(systemName: currentStep == recipe.steps.count - 1 ? "checkmark" : "arrow.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(RecipeTheme.accent, in: Capsule())
                }
            }
            .padding(.bottom, 22)
        }
        .padding(.horizontal, 22)
    }

    private var timerControl: some View {
        HStack(spacing: 15) {
            Image(systemName: "timer")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(RecipeTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Step timer").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Text(timerText)
                    .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
            }
            Spacer()
            Button {
                toggleTimer()
                Feedback.tap()
            } label: {
                Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(RecipeTheme.accent, in: Circle())
            }
            .accessibilityLabel(isTimerRunning ? "Pause timer" : "Start timer")
        }
        .padding(15)
        .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var timerText: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var finishContent: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(RecipeTheme.accent)
                .symbolEffect(.bounce, value: phase == .finished)
            Text("Enjoy your meal!")
                .font(.system(.largeTitle, design: .serif).weight(.regular))
                .tracking(-0.8)
            Text("The best part is right now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Done") { dismiss() }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(RecipeTheme.accent, in: Capsule())
                .padding(.bottom, 25)
        }
        .padding(.horizontal, 24)
        .multilineTextAlignment(.center)
    }

    private func toggleTimer() {
        if isTimerRunning {
            if let end = timerEndDate {
                secondsRemaining = max(0, Int(end.timeIntervalSinceNow.rounded(.up)))
            }
            stopTimer()
        } else {
            guard secondsRemaining > 0 else { return }
            let end = Date().addingTimeInterval(TimeInterval(secondsRemaining))
            timerEndDate = end
            timerStartedForStep = true
            isTimerRunning = true
            TimerNotifier.schedule(
                at: end,
                title: "Timer done",
                body: "\(recipe.name) · step \(currentStep + 1) of \(recipe.steps.count)"
            )
        }
        pushActivity()
    }

    private func stopTimer() {
        timerEndDate = nil
        isTimerRunning = false
        TimerNotifier.cancel()
    }

    private func completeTimer() {
        stopTimer()
        timerStartedForStep = false
        Feedback.timerDone()
        pushActivity()
    }

    private func pushActivity() {
        guard phase == .steps else { return }
        let paused = timerEndDate == nil && timerStartedForStep && secondsRemaining > 0
        CookingActivityManager.shared.update(
            step: currentStep,
            timerEnd: timerEndDate,
            timerPaused: paused ? secondsRemaining : nil
        )
    }

    private func startActivity() {
        let accent = RecipeAccent(rawValue: selectedAccent)?.color ?? RecipeAccent.tomato.color
        CookingActivityManager.shared.start(recipe: recipe, step: currentStep, accent: accent)
    }

    private func advanceStep() {
        guard currentStep < recipe.steps.count else { return }
        stopTimer()
        if currentStep == recipe.steps.count - 1 {
            phase = .finished
        } else {
            direction = 1
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                currentStep += 1
                loadTimer(for: currentStep)
            }
        }
        Feedback.check()
    }

    private func goBack() {
        guard currentStep > 0 else { return }
        direction = -1
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            currentStep -= 1
            loadTimer(for: currentStep)
        }
        Feedback.tap()
    }

    private func loadTimer(for index: Int) {
        stopTimer()
        timerStartedForStep = false
        guard recipe.steps.indices.contains(index) else {
            secondsRemaining = 0
            return
        }
        let text = recipe.steps[index]
        guard let regex = try? NSRegularExpression(pattern: #"(?i)\b(\d+)\s*(minutes?|mins?|min|hours?|hrs?|hr)\b"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let valueRange = Range(match.range(at: 1), in: text),
              let value = Int(text[valueRange]),
              let unitRange = Range(match.range(at: 2), in: text)
        else {
            secondsRemaining = 0
            return
        }
        let unit = text[unitRange].lowercased()
        secondsRemaining = value * (unit.hasPrefix("h") ? 3600 : 60)
    }

    private func quantityDescription(_ ingredient: Ingredient) -> String {
        guard let quantity = ingredient.quantity else { return ingredient.unit }
        let amount = (quantity * scale).formatted(.number.precision(.fractionLength(0...2)))
        return ingredient.unit.isEmpty ? amount : "\(amount) \(ingredient.unit)"
    }
}
