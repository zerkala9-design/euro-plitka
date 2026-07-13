import SwiftUI
import PhilipsKit

/// Observable owner of the user's TV list. Wraps `DeviceRepository` and keeps
/// the shared App Group persistence in sync for widgets & the watch app.
@MainActor
@Observable
final class DeviceStore {
    private(set) var devices: [TVDevice] = []
    var selectedDeviceID: UUID? {
        didSet { repository.setSelectedDeviceID(selectedDeviceID) }
    }

    private let repository: DeviceRepository

    init(repository: DeviceRepository = .shared) {
        self.repository = repository
        devices = repository.loadDevices()
        selectedDeviceID = repository.selectedDeviceID() ?? devices.first?.id
    }

    var selectedDevice: TVDevice? {
        devices.first { $0.id == selectedDeviceID }
    }

    var devicesByRoom: [Room: [TVDevice]] {
        Dictionary(grouping: devices, by: \.room)
    }

    func upsert(_ device: TVDevice) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
        } else if let index = devices.firstIndex(where: { $0.host == device.host }) {
            // Same host rediscovered — refresh in place, keep the stable id.
            var updated = device
            updated.id = devices[index].id
            devices[index] = updated
        } else {
            devices.append(device)
        }
        if selectedDeviceID == nil { selectedDeviceID = device.id }
        persist()
    }

    func remove(_ device: TVDevice) {
        devices.removeAll { $0.id == device.id }
        AuthenticationService().removeCredential(for: device)
        if selectedDeviceID == device.id { selectedDeviceID = devices.first?.id }
        persist()
    }

    func select(_ device: TVDevice) {
        selectedDeviceID = device.id
    }

    func setName(_ name: String, for device: TVDevice) {
        update(device) { $0.name = name }
    }

    func setRoom(_ room: Room, for device: TVDevice) {
        update(device) { $0.room = room }
    }

    func toggleFavorite(_ device: TVDevice) {
        update(device) { $0.isFavorite.toggle() }
    }

    func markPaired(_ device: TVDevice, paired: Bool = true) {
        update(device) {
            $0.isPaired = paired
            $0.lastConnected = Date()
        }
    }

    private func update(_ device: TVDevice, _ transform: (inout TVDevice) -> Void) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        transform(&devices[index])
        persist()
    }

    private func persist() {
        repository.save(devices)
    }
}
