import ActivityKit
import SwiftUI
import WidgetKit

struct CookingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CookingActivityAttributes.self) { context in
            LockScreenCookingView(context: context)
                .activitySystemActionForegroundColor(context.attributes.accentColor)
        } dynamicIsland: { context in
            let accent = context.attributes.accentColor
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(state.finished ? "Done" : "\(state.step + 1)/\(state.totalSteps)")
                        .font(.headline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.recipeName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(state.finished ? "Enjoy your meal!" : state.instruction)
                            .font(.subheadline)
                            .lineLimit(2)
                        StepTimerRow(state: state, isStale: context.isStale, accent: accent)
                        ProgressView(value: state.progress)
                            .tint(accent)
                    }
                }
            } compactLeading: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(accent)
            } compactTrailing: {
                if let end = state.timerEnd, !context.isStale, end > Date.now {
                    Text(timerInterval: Date.now...max(end, Date.now), countsDown: true, showsHours: false)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .frame(width: 44)
                } else {
                    Text(state.finished ? "Done" : "\(state.step + 1)/\(state.totalSteps)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
            } minimal: {
                Image(systemName: state.timerEnd != nil ? "timer" : "flame.fill")
                    .foregroundStyle(accent)
            }
            .keylineTint(accent)
        }
    }
}

private struct StepTimerRow: View {
    let state: CookingActivityAttributes.ContentState
    let isStale: Bool
    let accent: Color

    private var isRunning: Bool {
        guard let end = state.timerEnd else { return false }
        return !isStale && end > Date.now
    }

    var body: some View {
        if let end = state.timerEnd {
            HStack(spacing: 8) {
                Image(systemName: isRunning ? "timer" : "bell.fill")
                    .foregroundStyle(accent)
                if isRunning {
                    Text(timerInterval: Date.now...max(end, Date.now), countsDown: true, showsHours: false)
                        .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Time’s up")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else if let paused = state.timerPaused {
            HStack(spacing: 8) {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.secondary)
                Text(String(format: "%d:%02d", paused / 60, paused % 60))
                    .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("Paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

private struct LockScreenCookingView: View {
    let context: ActivityViewContext<CookingActivityAttributes>

    var body: some View {
        let accent = context.attributes.accentColor
        let state = context.state

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(accent)
                Text(context.attributes.recipeName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(state.finished ? "Done" : "Step \(state.step + 1) of \(state.totalSteps)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(state.finished ? "Enjoy your meal!" : state.instruction)
                .font(.subheadline)
                .lineLimit(2)

            StepTimerRow(state: state, isStale: context.isStale, accent: accent)

            ProgressView(value: state.progress)
                .tint(accent)

            Text("\(Int(state.progress * 100))% complete")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}
