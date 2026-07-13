import SwiftUI
import Combine
import PhilipsKit

/// Network diagnostics: live latency, packet loss, signal quality, plus an
/// export of the full log for troubleshooting.
struct DiagnosticsView: View {
    @Environment(TVController.self) private var controller
    @State private var report: DiagnosticsReport?
    @State private var exportText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                signalCard
                metricsGrid
                latencyChart
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ShareLink(item: exportText.isEmpty ? "No diagnostics yet" : exportText) {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .task { await refresh() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            Task { await refresh() }
        }
    }

    private var quality: SignalQuality { report?.signalQuality ?? .offline }

    private var signalCard: some View {
        GlassCard {
            VStack(spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(0..<4) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < quality.bars ? Color.accentColor : Color.secondary.opacity(0.25))
                            .frame(width: 12, height: CGFloat(16 + i * 8))
                    }
                }
                Text(quality.label).font(.title2.bold())
                Text("Connection quality").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var metricsGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 14) {
            metric("Avg latency", value: format(report?.averageLatencyMs), unit: "ms", symbol: "timer")
            metric("Peak latency", value: format(report?.maxLatencyMs), unit: "ms", symbol: "gauge.high")
            metric("Packet loss", value: format(report?.packetLossPercent), unit: "%", symbol: "chart.line.downtrend.xyaxis")
            metric("Samples", value: "\(report?.sampleCount ?? 0)", unit: "", symbol: "number")
        }
    }

    private var latencyChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recent latency").font(.headline)
                let samples = controller.diagnostics.suffix(40)
                GeometryReader { geo in
                    let maxL = max(samples.map(\.latencyMs).max() ?? 1, 1)
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(sample.success ? Color.accentColor : Color.red)
                                .frame(height: max(2, geo.size.height * sample.latencyMs / maxL))
                        }
                    }
                }
                .frame(height: 90)
                if samples.isEmpty {
                    Text("Send a few commands to gather samples.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func metric(_ title: String, value: String, unit: String, symbol: String) -> some View {
        GlassCard(cornerRadius: Theme.cornerRadiusMedium, padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol).foregroundStyle(.tint)
                Text(value + (unit.isEmpty ? "" : " \(unit)")).font(.title3.bold())
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f", value)
    }

    private func refresh() async {
        report = controller.diagnosticsReport
        exportText = await AppLog.shared.exportText()
    }
}
