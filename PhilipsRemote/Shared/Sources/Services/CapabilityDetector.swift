import Foundation

/// Derives a `TVCapabilities` and `TVSystemInfo` from the raw `/6/system`
/// response, plus heuristics on the model string. This is what powers the
/// "only show supported features" requirement.
public enum CapabilityDetector {

    public static func detect(from system: SystemResponse) -> TVCapabilities {
        let features = system.featuring?.jsonfeatures
        let osType = system.os_type ?? system.featuring?.systemfeatures?.os_type ?? ""
        let tvType = system.featuring?.systemfeatures?.tvtype ?? ""

        let platform: TVCapabilities.Platform = {
            let combined = (osType + tvType).lowercased()
            if combined.contains("google") { return .googleTV }
            if combined.contains("android") { return .androidTV }
            if combined.contains("saphi") { return .saphi }
            return .androidTV   // JointSpace v6 is Android-era by default
        }()

        let model = system.model ?? ""
        let supportsAmbilight = (features?.ambilight?.isEmpty == false)
            || modelSupportsAmbilight(model)

        return TVCapabilities(
            platform: platform,
            supportsAmbilight: supportsAmbilight,
            ambilightStyles: features?.ambilight ?? [],
            supportsWakeOnLan: platform == .androidTV || platform == .googleTV,
            supportsApps: features?.applications?.isEmpty == false || platform != .saphi,
            supportsGoogleAssistant: platform == .googleTV,
            supportsPointer: features?.pointer?.isEmpty == false,
            supportsInputText: features?.inputkey?.isEmpty == false,
            supportsChannels: features?.channels?.isEmpty == false || true,
            supportsHDR: modelSupportsHDR(model),
            supportsDolbyVision: model.uppercased().contains("OLED") || modelSupportsHDR(model),
            supportsDolbyAtmos: model.uppercased().contains("OLED"),
            supportedKeys: [],   // empty = allow all; populated if TV advertises a list
            hdmiPortCount: estimatedHDMIPorts(model)
        )
    }

    public static func systemInfo(from system: SystemResponse, host: String) -> TVSystemInfo {
        let apiVersion = system.api_version.map {
            "\($0.Major ?? 6).\($0.Minor ?? 0).\($0.Patch ?? 0)"
        }
        let model = system.model ?? ""
        return TVSystemInfo(
            name: system.name ?? "",
            model: model,
            serialNumber: system.serialnumber_encrypted,
            softwareVersion: system.softwareversion,
            androidVersion: androidVersion(from: system.softwareversion),
            osType: system.os_type,
            apiVersion: apiVersion,
            screenResolution: model.contains("8") ? "3840×2160 (4K)" : "3840×2160 (4K)",
            ipAddress: host,
            supportsHDR: modelSupportsHDR(model),
            supportsDolbyVision: model.uppercased().contains("OLED"),
            supportsDolbyAtmos: model.uppercased().contains("OLED")
        )
    }

    // MARK: - Model heuristics

    static func modelSupportsAmbilight(_ model: String) -> Bool {
        let m = model.uppercased()
        // Philips Ambilight is present on OLED and most xxPUS7xxx and above.
        if m.contains("OLED") { return true }
        if let series = seriesNumber(m) { return series >= 7000 }
        return false
    }

    static func modelSupportsHDR(_ model: String) -> Bool {
        let m = model.uppercased()
        if m.contains("OLED") { return true }
        if let series = seriesNumber(m) { return series >= 6000 }
        return false
    }

    static func estimatedHDMIPorts(_ model: String) -> Int {
        let m = model.uppercased()
        if m.contains("OLED") { return 4 }
        if let series = seriesNumber(m), series >= 8000 { return 4 }
        return 3
    }

    /// Extract the 4‑digit series number, e.g. "50PUS7906/12" → 7906 → 7000.
    static func seriesNumber(_ model: String) -> Int? {
        // Find first run of 4 digits after the "PUS"/"OLED" marker.
        let digits = model.filter(\.isNumber)
        guard digits.count >= 4 else { return nil }
        // The panel size is a leading 2 digits; series follows the letters.
        if let range = model.range(of: #"[A-Za-z]{2,4}(\d{3,4})"#, options: .regularExpression) {
            let match = model[range].filter(\.isNumber)
            if let value = Int(match) { return value }
        }
        return nil
    }

    static func androidVersion(from software: String?) -> String? {
        // Best effort: Philips Android 11 sets ship "TPM..." software builds.
        guard let software else { return nil }
        if software.contains("TPM19") { return "Android 11" }
        if software.contains("TPM18") { return "Android 10" }
        if software.contains("TPM17") { return "Android 9" }
        return nil
    }
}
