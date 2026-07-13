import SwiftUI
import PhilipsKit

/// Multi‑TV manager grouped by room, with rename, room assignment, favorite and
/// remove actions plus one‑tap connect.
struct DevicesView: View {
    @Environment(DeviceStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(TVController.self) private var controller
    @Environment(\.dismiss) private var dismiss
    @State private var editing: TVDevice?

    var body: some View {
        NavigationStack {
            List {
                ForEach(Room.allCases) { room in
                    let devices = store.devices.filter { $0.room == room }
                    if !devices.isEmpty {
                        Section {
                            ForEach(devices) { device in
                                deviceRow(device)
                            }
                        } header: {
                            Label(room.rawValue, systemImage: room.systemImage)
                        }
                    }
                }

                Section {
                    Button {
                        dismiss()
                        model.startDiscovery()
                    } label: {
                        Label("Add another TV", systemImage: "plus.circle.fill")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("My TVs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $editing) { device in EditDeviceView(device: device) }
        }
    }

    private func deviceRow(_ device: TVDevice) -> some View {
        Button {
            Task { await model.connect(to: device); dismiss() }
        } label: {
            HStack {
                Image(systemName: "tv").foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text(device.displayName).font(.headline).foregroundStyle(.primary)
                    Text("\(device.model) · \(device.host)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if store.selectedDeviceID == device.id && controller.state.isConnected {
                    Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(.green)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { store.remove(device) } label: {
                Label("Remove", systemImage: "trash")
            }
            Button { editing = device } label: {
                Label("Edit", systemImage: "pencil")
            }.tint(.blue)
        }
        .swipeActions(edge: .leading) {
            Button { store.toggleFavorite(device) } label: {
                Label("Favorite", systemImage: device.isFavorite ? "star.slash" : "star")
            }.tint(.yellow)
        }
    }
}

/// Rename / room assignment editor.
struct EditDeviceView: View {
    let device: TVDevice
    @Environment(DeviceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var room: Room = .livingRoom

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("TV name", text: $name)
                }
                Section("Room") {
                    Picker("Room", selection: $room) {
                        ForEach(Room.allCases) { Label($0.rawValue, systemImage: $0.systemImage).tag($0) }
                    }
                    .pickerStyle(.inline)
                }
                Section("Details") {
                    LabeledContent("Model", value: device.model)
                    LabeledContent("IP", value: device.host)
                    if let mac = device.macAddress { LabeledContent("MAC", value: mac) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Edit TV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.setName(name, for: device)
                        store.setRoom(room, for: device)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear { name = device.name; room = device.room }
        }
    }
}
