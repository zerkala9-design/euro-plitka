import Foundation

/// A headless helper that performs a single TV command without any UI state.
///
/// Shared by Siri App Intents, interactive Widgets, Live Activity buttons and
/// the Watch app — anywhere we need to act on the currently selected TV using
/// the persisted device list + Keychain credential.
public struct TVQuickControl: Sendable {
    public static let shared = TVQuickControl()

    private let repository: DeviceRepository
    private let keychain: KeychainStore
    private let wol = WakeOnLANService()

    public init(repository: DeviceRepository = .shared, keychain: KeychainStore = .shared) {
        self.repository = repository
        self.keychain = keychain
    }

    public enum Target: Sendable {
        case selected
        case named(String)
    }

    private func resolve(_ target: Target) -> TVDevice? {
        let devices = repository.loadDevices()
        switch target {
        case .selected:
            if let id = repository.selectedDeviceID(), let d = devices.first(where: { $0.id == id }) { return d }
            return devices.first(where: \.isPaired) ?? devices.first
        case .named(let name):
            return devices.first { $0.displayName.localizedCaseInsensitiveContains(name) }
        }
    }

    private func client(for device: TVDevice) -> PhilipsAPIClient {
        let credential = keychain.load(PairingCredential.self, for: device.id.uuidString)
        return PhilipsAPIClient(device: device, credential: credential, retry: .none)
    }

    // MARK: - Public commands

    @discardableResult
    public func send(_ key: RemoteKey, to target: Target = .selected) async -> Bool {
        guard let device = resolve(target) else { return false }
        do { try await client(for: device).sendKey(key); return true }
        catch { return false }
    }

    @discardableResult
    public func adjustVolume(up: Bool, to target: Target = .selected) async -> Bool {
        await send(up ? .volumeUp : .volumeDown, to: target)
    }

    @discardableResult
    public func mute(to target: Target = .selected) async -> Bool {
        await send(.mute, to: target)
    }

    @discardableResult
    public func power(on: Bool, to target: Target = .selected) async -> Bool {
        guard let device = resolve(target) else { return false }
        if on, let mac = device.macAddress {
            try? await wol.wake(macAddress: mac)
        }
        return await send(.standby, to: target)
    }

    /// Launch an app by fuzzy name (e.g. "Netflix").
    @discardableResult
    public func launchApp(named name: String, to target: Target = .selected) async -> Bool {
        guard let device = resolve(target) else { return false }
        let client = client(for: device)
        guard let apps = try? await client.getApplications(),
              let app = apps.first(where: { $0.label.localizedCaseInsensitiveContains(name) }) else {
            return false
        }
        do { try await client.launch(app); return true }
        catch { return false }
    }

    /// Current volume snapshot for widgets / live activity.
    public func currentVolume(to target: Target = .selected) async -> PhilipsAPIClient.Volume? {
        guard let device = resolve(target) else { return nil }
        return try? await client(for: device).getVolume()
    }

    public func selectedDeviceName() -> String {
        resolve(.selected)?.displayName ?? "TV"
    }
}
