import Foundation

/// A discovered / paired Philips television.
///
/// `TVDevice` is the central domain model. It is `Codable` so it can be
/// persisted (device list) and shared across the app, widgets and the watch
/// via an App Group.
public struct TVDevice: Identifiable, Codable, Hashable, Sendable {

    public var id: UUID
    /// User facing name, e.g. "Living Room". Defaults to the model name.
    public var name: String
    /// The model string reported by the TV, e.g. "50PUS7906/12".
    public var model: String
    /// Marketing/friendly name reported over Bonjour if available.
    public var friendlyName: String?
    public var host: String
    /// JointSpace API port. 1926 for HTTPS (Android TV), 1925 for legacy HTTP.
    public var port: Int
    /// MAC address, used for Wake-on-LAN. Formatted "AA:BB:CC:DD:EE:FF".
    public var macAddress: String?
    /// Detected JointSpace API version, e.g. 6.
    public var apiVersion: Int
    /// Which logical room this TV belongs to.
    public var room: Room
    public var capabilities: TVCapabilities
    public var systemInfo: TVSystemInfo?
    /// True once the device has completed pairing and holds a stored token.
    public var isPaired: Bool
    public var lastConnected: Date?
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        model: String,
        friendlyName: String? = nil,
        host: String,
        port: Int = 1926,
        macAddress: String? = nil,
        apiVersion: Int = 6,
        room: Room = .livingRoom,
        capabilities: TVCapabilities = .init(),
        systemInfo: TVSystemInfo? = nil,
        isPaired: Bool = false,
        lastConnected: Date? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.model = model
        self.friendlyName = friendlyName
        self.host = host
        self.port = port
        self.macAddress = macAddress
        self.apiVersion = apiVersion
        self.room = room
        self.capabilities = capabilities
        self.systemInfo = systemInfo
        self.isPaired = isPaired
        self.lastConnected = lastConnected
        self.isFavorite = isFavorite
    }

    /// Base URL for the JointSpace REST API, e.g. `https://192.168.0.10:1926/6/`.
    public var baseURL: URL {
        let scheme = port == 1926 ? "https" : "http"
        return URL(string: "\(scheme)://\(host):\(port)/\(apiVersion)/")!
    }

    /// Best available display name for the TV.
    public var displayName: String {
        if !name.isEmpty { return name }
        if let f = friendlyName, !f.isEmpty { return f }
        return model
    }
}

/// Logical grouping of TVs for multi-room support.
public enum Room: String, Codable, CaseIterable, Identifiable, Sendable {
    case livingRoom = "Living Room"
    case bedroom = "Bedroom"
    case office = "Office"
    case kitchen = "Kitchen"
    case other = "Other"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .livingRoom: return "sofa.fill"
        case .bedroom: return "bed.double.fill"
        case .office: return "briefcase.fill"
        case .kitchen: return "fork.knife"
        case .other: return "house.fill"
        }
    }
}
