import Foundation

/// Detected feature set of a TV. Populated by `CapabilityDetector` after
/// pairing by probing the JointSpace `/system` endpoint and known feature URLs.
///
/// The UI reads this to enable/disable features, so an unsupported command is
/// never offered to the user.
public struct TVCapabilities: Codable, Hashable, Sendable {
    public var platform: Platform
    public var supportsAmbilight: Bool
    public var ambilightStyles: [String]
    public var supportsWakeOnLan: Bool
    public var supportsApps: Bool
    public var supportsGoogleAssistant: Bool
    public var supportsPointer: Bool          // gesture/trackpad pointer
    public var supportsInputText: Bool        // remote keyboard
    public var supportsChannels: Bool
    public var supportsHDR: Bool
    public var supportsDolbyVision: Bool
    public var supportsDolbyAtmos: Bool
    /// Raw list of supported key names reported by `/system` featuring.
    public var supportedKeys: Set<String>
    public var hdmiPortCount: Int

    public enum Platform: String, Codable, Sendable {
        case androidTV = "Android TV"
        case googleTV = "Google TV"
        case saphi = "Saphi"
        case unknown = "Unknown"
    }

    public init(
        platform: Platform = .unknown,
        supportsAmbilight: Bool = false,
        ambilightStyles: [String] = [],
        supportsWakeOnLan: Bool = false,
        supportsApps: Bool = false,
        supportsGoogleAssistant: Bool = false,
        supportsPointer: Bool = false,
        supportsInputText: Bool = false,
        supportsChannels: Bool = true,
        supportsHDR: Bool = false,
        supportsDolbyVision: Bool = false,
        supportsDolbyAtmos: Bool = false,
        supportedKeys: Set<String> = [],
        hdmiPortCount: Int = 0
    ) {
        self.platform = platform
        self.supportsAmbilight = supportsAmbilight
        self.ambilightStyles = ambilightStyles
        self.supportsWakeOnLan = supportsWakeOnLan
        self.supportsApps = supportsApps
        self.supportsGoogleAssistant = supportsGoogleAssistant
        self.supportsPointer = supportsPointer
        self.supportsInputText = supportsInputText
        self.supportsChannels = supportsChannels
        self.supportsHDR = supportsHDR
        self.supportsDolbyVision = supportsDolbyVision
        self.supportsDolbyAtmos = supportsDolbyAtmos
        self.supportedKeys = supportedKeys
        self.hdmiPortCount = hdmiPortCount
    }

    public func supports(_ key: RemoteKey) -> Bool {
        supportedKeys.isEmpty || supportedKeys.contains(key.rawValue)
    }
}

/// Detailed system information shown on the "TV Info" screen.
public struct TVSystemInfo: Codable, Hashable, Sendable {
    public var name: String
    public var model: String
    public var serialNumber: String?
    public var softwareVersion: String?
    public var androidVersion: String?
    public var osType: String?
    public var apiVersion: String?
    public var countryCode: String?
    public var menuLanguage: String?
    public var screenResolution: String?
    public var macAddress: String?
    public var ipAddress: String?
    public var supportsHDR: Bool
    public var supportsDolbyVision: Bool
    public var supportsDolbyAtmos: Bool

    public init(
        name: String = "",
        model: String = "",
        serialNumber: String? = nil,
        softwareVersion: String? = nil,
        androidVersion: String? = nil,
        osType: String? = nil,
        apiVersion: String? = nil,
        countryCode: String? = nil,
        menuLanguage: String? = nil,
        screenResolution: String? = nil,
        macAddress: String? = nil,
        ipAddress: String? = nil,
        supportsHDR: Bool = false,
        supportsDolbyVision: Bool = false,
        supportsDolbyAtmos: Bool = false
    ) {
        self.name = name
        self.model = model
        self.serialNumber = serialNumber
        self.softwareVersion = softwareVersion
        self.androidVersion = androidVersion
        self.osType = osType
        self.apiVersion = apiVersion
        self.countryCode = countryCode
        self.menuLanguage = menuLanguage
        self.screenResolution = screenResolution
        self.macAddress = macAddress
        self.ipAddress = ipAddress
        self.supportsHDR = supportsHDR
        self.supportsDolbyVision = supportsDolbyVision
        self.supportsDolbyAtmos = supportsDolbyAtmos
    }
}
