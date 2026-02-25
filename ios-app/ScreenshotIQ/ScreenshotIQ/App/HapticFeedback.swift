import UIKit

enum HapticFeedback {
    static func copySuccess() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.9)
    }
}
