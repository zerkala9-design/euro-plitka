import Foundation

/// Android `KEYCODE_*` values used by the Android TV Remote v2 protocol
/// (`RemoteKeyInject.key_code`). Values match the Android `KeyEvent` constants.
public enum ATVKeyCode: Int, Sendable {
    case power = 26
    case home = 3
    case back = 4
    case dpadUp = 19
    case dpadDown = 20
    case dpadLeft = 21
    case dpadRight = 22
    case dpadCenter = 23        // OK / select
    case volumeUp = 24
    case volumeDown = 25
    case volumeMute = 164
    case mediaPlayPause = 85
    case mediaPlay = 126
    case mediaPause = 127
    case mediaStop = 86
    case mediaNext = 87
    case mediaPrevious = 88
    case mediaRewind = 89
    case mediaFastForward = 90
    case channelUp = 166
    case channelDown = 167
    case tv = 170
    case guide = 172
    case settings = 176
    case info = 165
    case menu = 82
    case digit0 = 7
    case digit1 = 8
    case digit2 = 9
    case digit3 = 10
    case digit4 = 11
    case digit5 = 12
    case digit6 = 13
    case digit7 = 14
    case digit8 = 15
    case digit9 = 16
    // Colored keys (Android TV program keys)
    case progRed = 183
    case progGreen = 184
    case progYellow = 185
    case progBlue = 186

    /// Map the app's platform-agnostic `RemoteKey` to an Android key code.
    public init?(_ key: RemoteKey) {
        switch key {
        case .standby: self = .power
        case .home: self = .home
        case .back: self = .back
        case .up: self = .dpadUp
        case .down: self = .dpadDown
        case .left: self = .dpadLeft
        case .right: self = .dpadRight
        case .confirm: self = .dpadCenter
        case .volumeUp: self = .volumeUp
        case .volumeDown: self = .volumeDown
        case .mute: self = .volumeMute
        case .channelUp: self = .channelUp
        case .channelDown: self = .channelDown
        case .play: self = .mediaPlay
        case .pause: self = .mediaPause
        case .playPause: self = .mediaPlayPause
        case .stop: self = .mediaStop
        case .next: self = .mediaNext
        case .previous: self = .mediaPrevious
        case .fastForward: self = .mediaFastForward
        case .rewind: self = .mediaRewind
        case .guide: self = .guide
        case .settings: self = .settings
        case .info: self = .info
        case .options: self = .menu
        case .exit, .source: self = .home
        case .red: self = .progRed
        case .green: self = .progGreen
        case .yellow: self = .progYellow
        case .blue: self = .progBlue
        case .digit0: self = .digit0
        case .digit1: self = .digit1
        case .digit2: self = .digit2
        case .digit3: self = .digit3
        case .digit4: self = .digit4
        case .digit5: self = .digit5
        case .digit6: self = .digit6
        case .digit7: self = .digit7
        case .digit8: self = .digit8
        case .digit9: self = .digit9
        case .record, .teletext, .subtitle: return nil
        }
    }
}

/// Well-known app-link URIs for launching apps via `RemoteAppLinkLaunchRequest`.
public enum ATVAppLink {
    /// Launch an installed app by its Android package name. The Play Store
    /// registers `market://launch?id=…` and opens the app if it's installed —
    /// more reliable than guessing an app's own web deep link.
    private static func launch(_ packageName: String) -> String {
        "market://launch?id=\(packageName)"
    }

    public static func uri(forAppNamed name: String) -> String? {
        switch name.lowercased() {
        case let n where n.contains("youtube"): return "https://www.youtube.com"
        case let n where n.contains("netflix"): return "https://www.netflix.com/title"
        case let n where n.contains("prime"), let n where n.contains("amazon"):
            return "https://app.primevideo.com"
        case let n where n.contains("disney"): return "https://www.disneyplus.com"
        case let n where n.contains("spotify"): return "spotify://"
        case let n where n.contains("megogo"): return launch("com.megogo.application.tv")
        case let n where n.contains("kyivstar") || n.contains("київстар"): return launch("com.kyivstar.tv.androidtv")
        case let n where n.contains("sweet"): return launch("tv.sweet.player")
        case let n where n.contains("megafon"): return "https://megafon.tv"
        default: return nil
        }
    }
}
