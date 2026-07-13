import Foundation

/// A single recorded diagnostic sample used by the Diagnostics screen and export.
public struct DiagnosticSample: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var timestamp: Date
    /// Round trip latency of the probe in milliseconds.
    public var latencyMs: Double
    public var success: Bool
    public var endpoint: String
    public var statusCode: Int?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        latencyMs: Double,
        success: Bool,
        endpoint: String,
        statusCode: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.latencyMs = latencyMs
        self.success = success
        self.endpoint = endpoint
        self.statusCode = statusCode
    }
}

/// Aggregated connection quality metrics.
public struct DiagnosticsReport: Codable, Sendable {
    public var averageLatencyMs: Double
    public var minLatencyMs: Double
    public var maxLatencyMs: Double
    public var packetLossPercent: Double
    public var sampleCount: Int
    public var signalQuality: SignalQuality
    public var generatedAt: Date

    public init(samples: [DiagnosticSample]) {
        let latencies = samples.filter(\.success).map(\.latencyMs)
        averageLatencyMs = latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count)
        minLatencyMs = latencies.min() ?? 0
        maxLatencyMs = latencies.max() ?? 0
        let failures = samples.filter { !$0.success }.count
        packetLossPercent = samples.isEmpty ? 0 : (Double(failures) / Double(samples.count)) * 100
        sampleCount = samples.count
        signalQuality = SignalQuality(latencyMs: averageLatencyMs, packetLoss: packetLossPercent)
        generatedAt = Date()
    }
}

public enum SignalQuality: String, Codable, Sendable {
    case excellent, good, fair, poor, offline

    public init(latencyMs: Double, packetLoss: Double) {
        if packetLoss >= 50 { self = .offline; return }
        switch (latencyMs, packetLoss) {
        case let (l, p) where l < 40 && p < 1: self = .excellent
        case let (l, p) where l < 90 && p < 5: self = .good
        case let (l, p) where l < 180 && p < 15: self = .fair
        default: self = .poor
        }
    }

    public var bars: Int {
        switch self {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .poor: return 1
        case .offline: return 0
        }
    }

    public var label: String { rawValue.capitalized }
}
