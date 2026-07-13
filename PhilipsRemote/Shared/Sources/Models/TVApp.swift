import Foundation

/// An application installed on the TV, returned by `/6/applications`.
public struct TVApp: Identifiable, Codable, Hashable, Sendable {
    public var id: String            // package name, unique
    public var label: String
    public var packageName: String
    public var className: String
    public var type: String?         // e.g. "app" / "game"
    /// Relative icon path on the TV, resolved lazily by `AppService`.
    public var iconPath: String?
    public var isFavorite: Bool
    public var lastUsed: Date?

    public init(
        id: String,
        label: String,
        packageName: String,
        className: String,
        type: String? = nil,
        iconPath: String? = nil,
        isFavorite: Bool = false,
        lastUsed: Date? = nil
    ) {
        self.id = id
        self.label = label
        self.packageName = packageName
        self.className = className
        self.type = type
        self.iconPath = iconPath
        self.isFavorite = isFavorite
        self.lastUsed = lastUsed
    }

    /// Heuristic category derived from the package name for grouping.
    public var category: Category {
        let p = packageName.lowercased()
        if p.contains("netflix") || p.contains("youtube") || p.contains("disney")
            || p.contains("primevideo") || p.contains("hbo") || p.contains("hulu")
            || p.contains("appletv") || p.contains("plex") { return .streaming }
        if p.contains("music") || p.contains("spotify") || p.contains("tidal")
            || p.contains("deezer") { return .music }
        if p.contains("game") || p.contains("stadia") || p.contains("geforce") { return .games }
        if p.contains("chrome") || p.contains("browser") { return .web }
        return .other
    }

    public enum Category: String, CaseIterable, Sendable {
        case streaming = "Streaming"
        case music = "Music"
        case games = "Games"
        case web = "Web"
        case other = "Other"

        public var systemImage: String {
            switch self {
            case .streaming: return "play.tv.fill"
            case .music: return "music.note"
            case .games: return "gamecontroller.fill"
            case .web: return "globe"
            case .other: return "square.grid.2x2.fill"
            }
        }
    }
}
