import Foundation

public enum AppGroup {
    /// Shared container used by the app, widgets, Live Activity and watch app.
    public static let identifier = "group.com.europlitka.philipsremote"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// Persists the user's list of TVs and per‑TV preferences to the shared App
/// Group container so every target (app, widget, watch) sees the same data.
///
/// Pairing secrets are **never** stored here — those live in the Keychain.
public struct DeviceRepository: Sendable {
    public static let shared = DeviceRepository()

    private let devicesKey = "tv.devices"
    private let selectedKey = "tv.selected"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    public func loadDevices() -> [TVDevice] {
        guard let data = defaults.data(forKey: devicesKey),
              let devices = try? JSONDecoder().decode([TVDevice].self, from: data) else {
            return []
        }
        return devices
    }

    public func save(_ devices: [TVDevice]) {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        defaults.set(data, forKey: devicesKey)
    }

    public func selectedDeviceID() -> UUID? {
        guard let raw = defaults.string(forKey: selectedKey) else { return nil }
        return UUID(uuidString: raw)
    }

    public func setSelectedDeviceID(_ id: UUID?) {
        defaults.set(id?.uuidString, forKey: selectedKey)
    }
}
