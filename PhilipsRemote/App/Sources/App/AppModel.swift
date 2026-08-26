import SwiftUI
import PhilipsKit

/// Composition root — creates and wires the shared services and observable
/// stores, and drives launch‑time behaviour (auto‑discovery, auto‑connect,
/// wake‑on‑launch).
@MainActor
@Observable
final class AppModel {
    let settings: AppSettings
    let deviceStore: DeviceStore
    let controller: TVController
    let discovery = DiscoveryService()

    /// Devices found live during discovery that aren't yet saved.
    private(set) var discovered: [TVDevice] = []
    private(set) var isScanning = false
    private var discoveryTask: Task<Void, Never>?

    init() {
        let settings = AppSettings()
        self.settings = settings
        self.deviceStore = DeviceStore()
        self.controller = TVController(settings: settings)
    }

    /// Called on first appearance.
    func bootstrap() async {
        PhoneConnectivity.shared.activate()
        if let device = deviceStore.selectedDevice, device.isPaired {
            if settings.wakeOnLaunch { await controller.wake() }
            await controller.connect(to: device)
            // If the TV's IP changed (couldn't connect), find it and heal.
            if !controller.state.isConnected {
                await autoLocateTV()
            }
        }
    }

    /// Browse the network for the saved TV and, if it's found at a new IP,
    /// update its address and reconnect. Independent of the stored IP/MAC —
    /// this is how the app follows the TV when its address changes.
    func autoLocateTV() async {
        guard !isScanning,
              let target = deviceStore.selectedDevice ?? deviceStore.devices.first else { return }
        isScanning = true
        defer { isScanning = false }

        // 1. Try Bonjour/mDNS (fast when the router allows it).
        var newHost = await firstDiscoveredHost(within: 5)
        // 2. Fallback: scan the local subnet for the TV's remote port.
        if newHost == nil {
            newHost = await discovery.scanForTV()
        }

        guard let newHost, newHost != target.host else { return }
        deviceStore.setHost(newHost, for: target)
        if target.isPaired, deviceStore.selectedDeviceID == target.id,
           let updated = deviceStore.selectedDevice {
            await controller.connect(to: updated)
        }
    }

    /// First Android TV host seen via Bonjour within `seconds`, or nil.
    private func firstDiscoveredHost(within seconds: Double) async -> String? {
        await discovery.resetSeen()
        let stream = await discovery.discover()
        let locate = Task { () -> String? in
            for await found in stream { return found.host }
            return nil
        }
        let timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            locate.cancel()
            await self?.discovery.stop()
        }
        let host = await locate.value
        timeout.cancel()
        await discovery.stop()
        return host
    }

    // MARK: - Discovery

    func startDiscovery() {
        guard discoveryTask == nil else { return }
        isScanning = true
        discovered = []
        discoveryTask = Task { [weak self] in
            guard let self else { return }
            await self.discovery.resetSeen()
            for await device in await self.discovery.discover() {
                await MainActor.run {
                    self.mergeDiscovered(device)
                }
            }
            await MainActor.run { self.isScanning = false }
        }
    }

    func stopDiscovery() {
        discoveryTask?.cancel()
        discoveryTask = nil
        isScanning = false
        Task { await discovery.stop() }
    }

    private func mergeDiscovered(_ device: TVDevice) {
        // If already saved, refresh capabilities silently; else show as new.
        if let existing = deviceStore.devices.first(where: { $0.host == device.host }) {
            var merged = device
            merged.id = existing.id
            merged.name = existing.name
            merged.room = existing.room
            merged.isPaired = existing.isPaired
            merged.isFavorite = existing.isFavorite
            deviceStore.upsert(merged)
        } else if !discovered.contains(where: { $0.host == device.host }) {
            discovered.append(device)
            Haptics.shared.selectionChanged()
        }
    }

    /// Returning to the app: reconnect, and if that fails (IP changed while we
    /// were away) locate the TV and heal the address.
    func reconnectOrLocate() async {
        await controller.reconnectIfNeeded()
        if !controller.state.isConnected, deviceStore.selectedDevice?.isPaired == true {
            await autoLocateTV()
        }
    }

    // MARK: - Connect flow

    func connect(to device: TVDevice) async {
        deviceStore.select(device)
        PhoneConnectivity.shared.syncSelectedTV()
        await controller.connect(to: device)
    }
}
