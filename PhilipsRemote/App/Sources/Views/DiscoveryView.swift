import SwiftUI
import PhilipsKit

/// Onboarding & discovery. Scans the network, lists found and saved TVs, and
/// starts pairing on tap.
struct DiscoveryView: View {
    @Environment(AppModel.self) private var model
    @Environment(DeviceStore.self) private var store
    @State private var pairingTarget: TVDevice?
    @State private var showManualAdd = false
    @State private var manualHost = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header

                    if !store.devices.isEmpty {
                        section(title: "Your TVs") {
                            ForEach(store.devices) { device in
                                DeviceRow(device: device) { select(device) }
                            }
                        }
                    }

                    section(title: model.isScanning ? "Searching…" : "Found on your network") {
                        if model.discovered.isEmpty {
                            ScanningPlaceholder(isScanning: model.isScanning)
                        } else {
                            ForEach(model.discovered) { device in
                                DeviceRow(device: device) { select(device) }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Philips Remote")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.isScanning ? model.stopDiscovery() : model.startDiscovery()
                    } label: {
                        Image(systemName: model.isScanning ? "stop.circle" : "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showManualAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $pairingTarget) { device in
                PairingView(device: device)
            }
            .alert("Add TV by IP", isPresented: $showManualAdd) {
                TextField("192.168.0.10", text: $manualHost)
                    .keyboardType(.numbersAndPunctuation)
                Button("Add") { addManual() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter your TV's local IP address if it wasn't found automatically.")
            }
            .task { if model.discovered.isEmpty { model.startDiscovery() } }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "tv.inset.filled")
                .font(.system(size: 54))
                .foregroundStyle(.tint)
                .padding(.top, 12)
            Text("Control every Philips TV")
                .font(.title2.bold())
            Text("We'll find your Android TV or Google TV on Wi‑Fi. Tap to connect.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func select(_ device: TVDevice) {
        if device.isPaired {
            store.select(device)
            Task { await model.controller.connect(to: device) }
        } else {
            pairingTarget = device
        }
    }

    private func addManual() {
        let host = manualHost.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty else { return }
        let device = DiscoveryService.androidDevice(host: host, name: "Philips TV")
        store.upsert(device)
        pairingTarget = device
        manualHost = ""
    }
}

/// A rich device card showing model art, IP, signal and online state.
struct DeviceRow: View {
    let device: TVDevice
    let action: () -> Void
    @Environment(TVController.self) private var controller

    var body: some View {
        Button(action: action) {
            GlassCard(cornerRadius: Theme.cornerRadiusMedium, padding: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .frame(width: 64, height: 44)
                        Image(systemName: "tv")
                            .font(.title2)
                            .foregroundStyle(.tint)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(device.displayName).font(.headline)
                        Text(device.model).font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Label(device.host, systemImage: "wifi").font(.caption2)
                            if device.capabilities.supportsAmbilight {
                                Image(systemName: "light.panel.fill").font(.caption2).foregroundStyle(.tint)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        if device.isPaired {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        } else {
                            Text("Pair").font(.caption.bold())
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.tint, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        SignalBars(quality: .good)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct SignalBars: View {
    let quality: SignalQuality
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < quality.bars ? Color.tint : Color.secondary.opacity(0.3))
                    .frame(width: 3, height: CGFloat(6 + i * 3))
            }
        }
    }
}

struct ScanningPlaceholder: View {
    let isScanning: Bool
    var body: some View {
        GlassCard(cornerRadius: Theme.cornerRadiusMedium) {
            HStack(spacing: 12) {
                if isScanning {
                    ProgressView().tint(.tint)
                } else {
                    Image(systemName: "wifi.exclamationmark").foregroundStyle(.secondary)
                }
                Text(isScanning ? "Scanning your network…" : "No TVs found yet. Pull to rescan.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

private extension Color {
    static var tint: Color { .accentColor }
}
