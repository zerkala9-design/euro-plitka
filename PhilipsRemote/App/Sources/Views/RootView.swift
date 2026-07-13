import SwiftUI
import PhilipsKit

/// Top‑level scene. Shows the onboarding/discovery flow until a paired TV is
/// selected, then the tabbed remote experience.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(DeviceStore.self) private var store
    @Environment(TVController.self) private var controller
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if store.selectedDevice?.isPaired == true {
                MainTabView()
                    .transition(.opacity)
            } else {
                DiscoveryView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: store.selectedDeviceID)
        .animation(.smooth, value: store.selectedDevice?.isPaired)
    }
}

struct MainTabView: View {
    @Environment(TVController.self) private var controller
    @Environment(DeviceStore.self) private var store
    @State private var selection: TabItem = .remote

    enum TabItem: Hashable { case remote, apps, ambilight, settings }

    private var showAmbilight: Bool {
        store.selectedDevice?.capabilities.supportsAmbilight ?? false
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Remote", systemImage: "av.remote.fill", value: TabItem.remote) {
                RemoteHomeView()
            }
            Tab("Apps", systemImage: "square.grid.2x2.fill", value: TabItem.apps) {
                AppsView()
            }
            if showAmbilight {
                Tab("Ambilight", systemImage: "light.panel.fill", value: TabItem.ambilight) {
                    AmbilightView()
                }
            }
            Tab("Settings", systemImage: "gearshape.fill", value: TabItem.settings) {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .safeAreaInset(edge: .top) { ConnectionBanner() }
    }
}

/// A thin banner that surfaces the current connection state with a live pulse.
struct ConnectionBanner: View {
    @Environment(TVController.self) private var controller
    @Environment(DeviceStore.self) private var store

    var body: some View {
        Group {
            switch controller.state {
            case .connected:
                EmptyView()
            case .connecting:
                banner(text: "Connecting to \(store.selectedDevice?.displayName ?? "TV")…",
                       color: .yellow, showsProgress: true)
            case .disconnected:
                EmptyView()
            case .failed(let message):
                banner(text: message, color: .red, showsProgress: false)
            }
        }
        .animation(.smooth, value: controller.state)
    }

    @ViewBuilder
    private func banner(text: String, color: Color, showsProgress: Bool) -> some View {
        HStack(spacing: 8) {
            if showsProgress {
                ProgressView().controlSize(.small).tint(color)
            } else {
                Circle().fill(color).frame(width: 8, height: 8)
            }
            Text(text).font(.footnote.weight(.medium)).lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1))
        .padding(.horizontal)
    }
}
