import UIKit
import CoreHaptics

/// Centralised haptic feedback. Respects the user's "Haptics" setting and
/// gracefully no‑ops on devices without a haptic engine.
@MainActor
final class Haptics {
    static let shared = Haptics()

    /// Toggled from Settings.
    var isEnabled = true

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private init() {
        impactLight.prepare()
        impactMedium.prepare()
    }

    func tap() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    func press() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    func edge() {
        guard isEnabled else { return }
        impactRigid.impactOccurred(intensity: 0.7)
    }

    func selectionChanged() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    func success() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    func warning() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    func error() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }
}
