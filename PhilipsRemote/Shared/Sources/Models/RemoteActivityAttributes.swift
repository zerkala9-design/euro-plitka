import Foundation
import ActivityKit

/// Live Activity state for the "Now Watching" activity shown on the Lock Screen
/// and Dynamic Island. Shared between the app (which starts/updates it) and the
/// widget extension (which renders it).
public struct RemoteActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var appName: String
        public var volume: Int
        public var isMuted: Bool
        public var isPlaying: Bool

        public init(appName: String, volume: Int, isMuted: Bool, isPlaying: Bool) {
            self.appName = appName
            self.volume = volume
            self.isMuted = isMuted
            self.isPlaying = isPlaying
        }
    }

    public var tvName: String

    public init(tvName: String) {
        self.tvName = tvName
    }
}
