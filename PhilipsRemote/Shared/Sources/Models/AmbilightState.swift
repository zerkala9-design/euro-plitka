import Foundation

/// Represents the current Ambilight configuration on the TV.
///
/// Maps to the JointSpace `/6/ambilight/*` endpoints.
public struct AmbilightState: Codable, Hashable, Sendable {
    public var power: Bool
    public var mode: Mode
    /// 0...255
    public var brightness: Int
    /// 0...255
    public var saturation: Int
    /// Static color (used when `mode == .manual`).
    public var color: RGBColor

    public init(
        power: Bool = false,
        mode: Mode = .followVideo,
        brightness: Int = 200,
        saturation: Int = 180,
        color: RGBColor = .init(r: 0, g: 122, b: 255)
    ) {
        self.power = power
        self.mode = mode
        self.brightness = brightness
        self.saturation = saturation
        self.color = color
    }

    public enum Mode: String, Codable, CaseIterable, Identifiable, Sendable {
        case followVideo = "FOLLOW_VIDEO"
        case followAudio = "FOLLOW_AUDIO"
        case manual = "MANUAL"           // static color
        case expert = "EXPERT"
        case lounge = "LOUNGE"           // used for rainbow / lounge light scenes

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .followVideo: return "Follow Video"
            case .followAudio: return "Follow Audio / Music"
            case .manual: return "Static Color"
            case .expert: return "Expert"
            case .lounge: return "Lounge / Rainbow"
            }
        }

        public var systemImage: String {
            switch self {
            case .followVideo: return "film.fill"
            case .followAudio: return "waveform"
            case .manual: return "paintpalette.fill"
            case .expert: return "slider.horizontal.3"
            case .lounge: return "sparkles"
            }
        }
    }
}

/// Simple RGB container (0...255 per channel), `Codable` for the API.
public struct RGBColor: Codable, Hashable, Sendable {
    public var r: Int
    public var g: Int
    public var b: Int

    public init(r: Int, g: Int, b: Int) {
        self.r = max(0, min(255, r))
        self.g = max(0, min(255, g))
        self.b = max(0, min(255, b))
    }
}
