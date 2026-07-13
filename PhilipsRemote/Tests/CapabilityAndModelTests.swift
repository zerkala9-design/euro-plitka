import Testing
import Foundation
@testable import PhilipsKit

@Suite("Capability detection")
struct CapabilityDetectorTests {

    @Test("OLED models support Ambilight, HDR and Dolby")
    func oled() {
        #expect(CapabilityDetector.modelSupportsAmbilight("OLED805/12"))
        #expect(CapabilityDetector.modelSupportsHDR("OLED805/12"))
    }

    @Test("7000-series PUS supports Ambilight")
    func pus7xxx() {
        #expect(CapabilityDetector.modelSupportsAmbilight("50PUS7906/12"))
    }

    @Test("Series number extraction", arguments: [
        ("50PUS7906/12", 7906),
        ("65OLED806/12", 806),
        ("43PUS8007/12", 8007)
    ])
    func series(model: String, expected: Int) {
        #expect(CapabilityDetector.seriesNumber(model) == expected)
    }

    @Test("Detects platform and Ambilight from system response")
    func detectFromSystem() {
        var system = SystemResponse()
        system.model = "50PUS7906/12"
        system.os_type = "Android"
        system.featuring = .init(
            jsonfeatures: .init(ambilight: ["Ambilight"], applications: ["activities"],
                                pointer: nil, inputkey: ["key"], activities: nil, channels: ["tv"]),
            systemfeatures: .init(tvtype: "consumer", content: nil, pairing_type: "digest_auth_pairing", os_type: "Android")
        )
        let caps = CapabilityDetector.detect(from: system)
        #expect(caps.platform == .androidTV)
        #expect(caps.supportsAmbilight)
        #expect(caps.supportsWakeOnLan)
    }
}

@Suite("Input source classification")
struct InputSourceTests {
    @Test("Classifies labels", arguments: [
        ("HDMI 1", InputSource.Kind.hdmi),
        ("HDMI 2 ARC", .hdmiARC),
        ("USB 1", .usb),
        ("TV Antenna", .tv),
        ("AV Composite", .av),
        ("Bluetooth", .bluetooth)
    ])
    func classify(label: String, expected: InputSource.Kind) {
        #expect(InputSource.Kind.classify(label) == expected)
    }
}

@Suite("Wake on LAN")
struct WakeOnLANTests {
    @Test("Magic packet is 102 bytes with correct header")
    func packet() throws {
        let data = try #require(WakeOnLANService.magicPacket(for: "AA:BB:CC:DD:EE:FF"))
        #expect(data.count == 102)
        #expect(Array(data.prefix(6)) == [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
        #expect(Array(data[6..<12]) == [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])
    }

    @Test("Accepts dash separated MACs")
    func dashes() {
        #expect(WakeOnLANService.magicPacket(for: "AA-BB-CC-DD-EE-FF") != nil)
    }

    @Test("Rejects malformed MACs")
    func malformed() {
        #expect(WakeOnLANService.magicPacket(for: "not-a-mac") == nil)
        #expect(WakeOnLANService.magicPacket(for: "AA:BB:CC") == nil)
    }
}

@Suite("Diagnostics + models")
struct DiagnosticsTests {
    @Test("Report computes averages and loss")
    func report() {
        let samples = [
            DiagnosticSample(latencyMs: 20, success: true, endpoint: "system"),
            DiagnosticSample(latencyMs: 40, success: true, endpoint: "system"),
            DiagnosticSample(latencyMs: 0, success: false, endpoint: "system")
        ]
        let report = DiagnosticsReport(samples: samples)
        #expect(report.averageLatencyMs == 30)
        #expect(abs(report.packetLossPercent - 33.33) < 0.1)
        #expect(report.sampleCount == 3)
    }

    @Test("Signal quality thresholds")
    func quality() {
        #expect(SignalQuality(latencyMs: 20, packetLoss: 0) == .excellent)
        #expect(SignalQuality(latencyMs: 200, packetLoss: 20) == .poor)
        #expect(SignalQuality(latencyMs: 10, packetLoss: 80) == .offline)
    }

    @Test("RGBColor clamps to 0...255")
    func rgbClamp() {
        let c = RGBColor(r: 300, g: -5, b: 128)
        #expect(c.r == 255)
        #expect(c.g == 0)
        #expect(c.b == 128)
    }

    @Test("TVDevice base URL uses https on 1926")
    func baseURL() {
        let d = TVDevice(name: "TV", model: "50PUS7906/12", host: "192.168.0.5")
        #expect(d.baseURL.absoluteString == "https://192.168.0.5:1926/6/")
    }
}
