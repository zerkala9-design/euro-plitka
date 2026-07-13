import Foundation

/// A physical / virtual input on the TV (HDMI, USB, AV…).
public struct InputSource: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    /// User assigned name override (persisted locally).
    public var customName: String?
    public var kind: Kind
    public var isFavorite: Bool

    public init(
        id: String,
        name: String,
        customName: String? = nil,
        kind: Kind,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.customName = customName
        self.kind = kind
        self.isFavorite = isFavorite
    }

    public var displayName: String { customName ?? name }

    public enum Kind: String, Codable, CaseIterable, Sendable {
        case hdmi = "HDMI"
        case hdmiARC = "HDMI ARC"
        case usb = "USB"
        case tv = "TV"
        case av = "AV"
        case bluetooth = "Bluetooth"
        case other = "Other"

        public var systemImage: String {
            switch self {
            case .hdmi: return "cable.connector"
            case .hdmiARC: return "hifispeaker.and.homepod.fill"
            case .usb: return "cable.connector.horizontal"
            case .tv: return "antenna.radiowaves.left.and.right"
            case .av: return "av.remote.fill"
            case .bluetooth: return "wave.3.right"
            case .other: return "rectangle.connected.to.line.below"
            }
        }

        /// Classify a raw source label reported by the TV.
        public static func classify(_ label: String) -> Kind {
            let l = label.lowercased()
            if l.contains("arc") || l.contains("earc") { return .hdmiARC }
            if l.contains("hdmi") { return .hdmi }
            if l.contains("usb") { return .usb }
            if l.contains("bluetooth") { return .bluetooth }
            if l.contains("av") || l.contains("composite") || l.contains("scart") { return .av }
            if l.contains("tv") || l.contains("antenna") || l.contains("dvb") { return .tv }
            return .other
        }
    }
}
