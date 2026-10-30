import AudioToolbox
import SwiftUI
import UIKit

enum Feedback {
    static let soundsKey = "soundsEnabled"

    private static var soundsEnabled: Bool {
        UserDefaults.standard.object(forKey: soundsKey) as? Bool ?? true
    }

    private static func playSound(_ id: SystemSoundID) {
        guard soundsEnabled else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            AudioServicesPlaySystemSound(id)
        }
    }

    /// Light selection tick: filter chips, accent picker.
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Soft tap: buttons and navigation.
    static func tap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    /// Checking off an ingredient or moving to the next step.
    static func check() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.8)
    }

    static func save() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func timerDone() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        playSound(1005)
    }

    static func finish() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        playSound(1057)
    }
}
