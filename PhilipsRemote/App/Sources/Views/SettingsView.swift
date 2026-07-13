import SwiftUI
import PhilipsKit

/// App settings: accent color, behavior toggles, and links to diagnostics,
/// devices and about. Dark mode is always on by design.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DeviceStore.self) private var store

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Accent color", selection: $settings.accent) {
                        ForEach(Theme.Accent.allCases) { accent in
                            HStack {
                                Circle().fill(accent.color).frame(width: 18, height: 18)
                                Text(accent.rawValue)
                            }.tag(accent)
                        }
                    }
                    LabeledContent("Theme", value: "Dark")
                }

                Section("Behavior") {
                    Toggle("Animations", isOn: $settings.animationsEnabled)
                    Toggle("Haptics", isOn: $settings.hapticsEnabled)
                    Toggle("Wake TV on launch", isOn: $settings.wakeOnLaunch)
                    Toggle("Auto reconnect", isOn: $settings.autoReconnect)
                    Toggle("Auto discovery", isOn: $settings.autoDiscovery)
                }

                Section("Tools") {
                    NavigationLink { DiagnosticsView() } label: {
                        Label("Diagnostics", systemImage: "waveform.path.ecg")
                    }
                    if settings.developerMode {
                        NavigationLink { CommandLogView() } label: {
                            Label("Command Log", systemImage: "terminal")
                        }
                    }
                }

                Section("Developer") {
                    Toggle("Developer mode", isOn: $settings.developerMode)
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("TVs paired", value: "\(store.devices.filter(\.isPaired).count)")
                } header: {
                    Text("About")
                } footer: {
                    Text("Philips Remote is an independent app and is not affiliated with or endorsed by Philips / TP Vision.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

/// Live command / reconnect log (developer mode).
struct CommandLogView: View {
    @State private var entries: [AppLog.Entry] = []

    var body: some View {
        List(entries) { entry in
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message).font(.footnote.monospaced())
                Text("\(entry.category) · \(entry.level)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Command Log")
        .toolbar {
            ShareLink(item: entries.map(\.message).joined(separator: "\n"))
        }
        .task { entries = Array(await AppLog.shared.recentEntries().reversed()) }
        .refreshable { entries = Array(await AppLog.shared.recentEntries().reversed()) }
    }
}
