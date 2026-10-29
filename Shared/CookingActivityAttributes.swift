import ActivityKit
import SwiftUI

struct CookingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var step: Int            // 0-based index of the current step
        var totalSteps: Int
        var instruction: String
        var finished: Bool

        var progress: Double {
            finished ? 1 : Double(step + 1) / Double(max(totalSteps, 1))
        }
    }

    var recipeName: String
    var accentRed: Double
    var accentGreen: Double
    var accentBlue: Double

    var accentColor: Color {
        Color(red: accentRed, green: accentGreen, blue: accentBlue)
    }
}
