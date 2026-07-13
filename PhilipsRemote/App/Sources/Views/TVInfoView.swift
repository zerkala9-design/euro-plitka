import SwiftUI
import PhilipsKit

/// Rich TV information screen: model, software, capabilities, network.
struct TVInfoView: View {
    @Environment(DeviceStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var device: TVDevice? { store.selectedDevice }
    private var info: TVSystemInfo? { device?.systemInfo }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    if let info { detailCard(info) }
                    capabilitiesCard
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("TV Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .presentationDetents([.large])
        }
    }

    private var hero: some View {
        GlassCard {
            VStack(spacing: 10) {
                Image(systemName: "tv.inset.filled").font(.system(size: 46)).foregroundStyle(.tint)
                Text(device?.displayName ?? "TV").font(.title2.bold())
                Text(device?.model ?? "").font(.subheadline).foregroundStyle(.secondary)
                if let platform = device?.capabilities.platform {
                    Text(platform.rawValue)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.tint.opacity(0.2), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func detailCard(_ info: TVSystemInfo) -> some View {
        GlassCard {
            VStack(spacing: 0) {
                row("Model", info.model)
                row("Serial", info.serialNumber ?? "—")
                row("Software", info.softwareVersion ?? "—")
                row("Android", info.androidVersion ?? "—")
                row("API Version", info.apiVersion ?? "—")
                row("Resolution", info.screenResolution ?? "—")
                row("IP Address", info.ipAddress ?? device?.host ?? "—")
                row("MAC Address", info.macAddress ?? device?.macAddress ?? "—")
            }
        }
    }

    private var capabilitiesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Capabilities").font(.headline)
                let caps = device?.capabilities
                FlowChips(chips: [
                    caps?.supportsAmbilight == true ? "Ambilight" : nil,
                    caps?.supportsHDR == true ? "HDR" : nil,
                    caps?.supportsDolbyVision == true ? "Dolby Vision" : nil,
                    caps?.supportsDolbyAtmos == true ? "Dolby Atmos" : nil,
                    caps?.supportsWakeOnLan == true ? "Wake‑on‑LAN" : nil,
                    caps?.supportsApps == true ? "Apps" : nil,
                    caps?.supportsGoogleAssistant == true ? "Assistant" : nil,
                    caps.map { "\($0.hdmiPortCount)× HDMI" }
                ].compactMap { $0 })
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
            }
            .font(.subheadline)
            .padding(.vertical, 10)
            Divider().background(.white.opacity(0.06))
        }
    }
}

/// A wrapping chip layout for capability tags.
struct FlowChips: View {
    let chips: [String]
    var body: some View {
        FlexibleWrap(chips, spacing: 8) { chip in
            Text(chip)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        }
    }
}
