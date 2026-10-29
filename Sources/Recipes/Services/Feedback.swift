import AudioToolbox
import SwiftUI
import UIKit

enum Feedback {
    static func tap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        AudioServicesPlaySystemSound(1104)
    }

    static func check() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1057)
    }

    static func save() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1057)
    }

    static func timerDone() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1005)
    }
}
