import SwiftUI
import PhilipsKit

/// User preferences, persisted to the shared App Group so widgets pick up the
/// accent color too. Dark mode is always on per the product spec.
@MainActor
@Observable
final class AppSettings {
    var accent: Theme.Accent {
        didSet { defaults.set(accent.rawValue, forKey: "accent"); syncHaptics() }
    }
    var animationsEnabled: Bool { didSet { defaults.set(animationsEnabled, forKey: "animations") } }
    var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: "haptics"); syncHaptics() } }
    var wakeOnLaunch: Bool { didSet { defaults.set(wakeOnLaunch, forKey: "wakeOnLaunch") } }
    var autoReconnect: Bool { didSet { defaults.set(autoReconnect, forKey: "autoReconnect") } }
    var autoDiscovery: Bool { didSet { defaults.set(autoDiscovery, forKey: "autoDiscovery") } }
    var developerMode: Bool { didSet { defaults.set(developerMode, forKey: "developerMode") } }

    private let defaults = AppGroup.defaults

    init() {
        accent = Theme.Accent(rawValue: defaults.string(forKey: "accent") ?? "") ?? .philipsBlue
        animationsEnabled = defaults.object(forKey: "animations") as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: "haptics") as? Bool ?? true
        wakeOnLaunch = defaults.object(forKey: "wakeOnLaunch") as? Bool ?? false
        autoReconnect = defaults.object(forKey: "autoReconnect") as? Bool ?? true
        autoDiscovery = defaults.object(forKey: "autoDiscovery") as? Bool ?? true
        developerMode = defaults.object(forKey: "developerMode") as? Bool ?? false
        syncHaptics()
    }

    private func syncHaptics() {
        Haptics.shared.isEnabled = hapticsEnabled
    }

    var accentColor: Color { accent.color }
}
