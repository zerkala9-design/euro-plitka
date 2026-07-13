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
        if settings.autoDiscovery { startDiscovery() }
        if let device = deviceStore.selectedDevice, device.isPaired {
            if settings.wakeOnLaunch { await controller.wake() }
            await controller.connect(to: device)
        }
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

    // MARK: - Connect flow

    func connect(to device: TVDevice) async {
        deviceStore.select(device)
        PhoneConnectivity.shared.syncSelectedTV()
        await controller.connect(to: device)
    }
}
