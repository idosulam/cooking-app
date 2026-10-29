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
                        ProgressView(value: state.progress)
                            .tint(accent)
                    }
                }
            } compactLeading: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(accent)
            } compactTrailing: {
                Text(state.finished ? "Done" : "\(state.step + 1)/\(state.totalSteps)")
                    .font(.caption.weight(.semibold).monospacedDigit())
            } minimal: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(accent)
            }
            .keylineTint(accent)
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

            ProgressView(value: state.progress)
                .tint(accent)

            Text("\(Int(state.progress * 100))% complete")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}
