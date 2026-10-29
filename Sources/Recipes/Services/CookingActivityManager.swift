import ActivityKit
import SwiftUI
import UIKit

@MainActor
final class CookingActivityManager {
    static let shared = CookingActivityManager()

    private var activity: Activity<CookingActivityAttributes>?
    private var steps: [String] = []

    func start(recipe: Recipe, step: Int, accent: Color) {
        end()
        guard ActivityAuthorizationInfo().areActivitiesEnabled, !recipe.steps.isEmpty else { return }
        steps = recipe.steps

        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(accent).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let attributes = CookingActivityAttributes(
            recipeName: recipe.name,
            accentRed: Double(red),
            accentGreen: Double(green),
            accentBlue: Double(blue)
        )
        let content = ActivityContent(state: state(for: step), staleDate: nil)
        activity = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    func update(step: Int) {
        guard let activity else { return }
        let content = ActivityContent(state: state(for: step), staleDate: nil)
        Task { await activity.update(content) }
    }

    func finish() {
        guard let activity, !steps.isEmpty else { return }
        self.activity = nil
        var final = state(for: steps.count - 1)
        final.finished = true
        let content = ActivityContent(state: final, staleDate: nil)
        Task { await activity.end(content, dismissalPolicy: .after(.now + 60)) }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    private func state(for step: Int) -> CookingActivityAttributes.ContentState {
        let index = min(max(step, 0), max(steps.count - 1, 0))
        var text = steps.indices.contains(index) ? steps[index] : ""
        if text.count > 140 { text = String(text.prefix(137)) + "…" }
        return .init(step: index, totalSteps: steps.count, instruction: text, finished: false)
    }
}
