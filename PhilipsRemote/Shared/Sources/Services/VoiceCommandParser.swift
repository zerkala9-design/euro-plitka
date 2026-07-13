import Foundation

/// Translates a natural‑language phrase into a concrete TV action.
///
/// Kept free of UI and platform dependencies so it can be unit‑tested and
/// reused by Siri App Intents and the in‑app voice control.
public enum VoiceCommandParser {

    public enum Command: Equatable, Sendable {
        case key(RemoteKey)
        case setVolume(Int)
        case launchApp(name: String)
        case search(query: String)
        case unknown
    }

    private static let appAliases: [String: String] = [
        "youtube": "YouTube",
        "netflix": "Netflix",
        "disney": "Disney+",
        "prime": "Prime Video",
        "amazon": "Prime Video",
        "spotify": "Spotify",
        "apple tv": "Apple TV",
        "hbo": "HBO Max",
        "plex": "Plex"
    ]

    public static func parse(_ phrase: String) -> Command {
        let text = phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .unknown }

        // Search intent.
        if let range = text.range(of: #"(search for|find|look for)\s+"#, options: .regularExpression) {
            let query = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !query.isEmpty { return .search(query: query) }
        }

        // App launch.
        if text.contains("open") || text.contains("launch") || text.contains("start") || text.contains("play") {
            for (alias, canonical) in appAliases where text.contains(alias) {
                return .launchApp(name: canonical)
            }
        }

        // Volume.
        if text.contains("volume up") || text.contains("louder") { return .key(.volumeUp) }
        if text.contains("volume down") || text.contains("quieter") { return .key(.volumeDown) }
        if text.contains("mute") || text.contains("unmute") { return .key(.mute) }
        if let match = text.range(of: #"volume (to )?\d+"#, options: .regularExpression) {
            let number = text[match].filter(\.isNumber)
            if let value = Int(number) { return .setVolume(min(100, max(0, value))) }
        }

        // Transport / navigation keywords → keys.
        let keywordKeys: [(String, RemoteKey)] = [
            ("pause", .pause), ("play", .play), ("stop", .stop),
            ("forward", .fastForward), ("rewind", .rewind),
            ("next", .next), ("previous", .previous),
            ("home", .home), ("back", .back), ("power", .standby),
            ("turn off", .standby), ("turn on", .standby),
            ("channel up", .channelUp), ("channel down", .channelDown),
            ("guide", .guide), ("settings", .settings), ("info", .info),
            ("up", .up), ("down", .down), ("left", .left), ("right", .right),
            ("select", .confirm), ("ok", .confirm), ("enter", .confirm)
        ]
        for (keyword, key) in keywordKeys where text.contains(keyword) {
            return .key(key)
        }

        return .unknown
    }
}
