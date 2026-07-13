import Foundation

/// The complete set of JointSpace input keys understood by Philips Android TVs.
///
/// Raw values map 1:1 to the strings accepted by `POST /6/input/key`.
public enum RemoteKey: String, Codable, CaseIterable, Sendable {
    // Power & system
    case standby = "Standby"
    case home = "Home"
    case back = "Back"
    case exit = "WatchTV"           // returns to live TV
    case options = "Options"
    case info = "Info"
    case source = "Source"
    case settings = "Adjust"        // quick settings menu

    // D-pad
    case up = "CursorUp"
    case down = "CursorDown"
    case left = "CursorLeft"
    case right = "CursorRight"
    case confirm = "Confirm"        // OK / select

    // Volume
    case volumeUp = "VolumeUp"
    case volumeDown = "VolumeDown"
    case mute = "Mute"

    // Channels
    case channelUp = "ChannelStepUp"
    case channelDown = "ChannelStepDown"

    // Numeric
    case digit0 = "Digit0"
    case digit1 = "Digit1"
    case digit2 = "Digit2"
    case digit3 = "Digit3"
    case digit4 = "Digit4"
    case digit5 = "Digit5"
    case digit6 = "Digit6"
    case digit7 = "Digit7"
    case digit8 = "Digit8"
    case digit9 = "Digit9"

    // Colored keys
    case red = "RedColour"
    case green = "GreenColour"
    case yellow = "YellowColour"
    case blue = "BlueColour"

    // Playback / transport
    case play = "Play"
    case pause = "Pause"
    case playPause = "PlayPause"
    case stop = "Stop"
    case record = "Record"
    case fastForward = "FastForward"
    case rewind = "Rewind"
    case next = "Next"
    case previous = "Previous"

    // Guide & teletext
    case guide = "ProgramGuide"
    case teletext = "Teletext"
    case subtitle = "Subtitle"

    /// SF Symbol name used for the on-screen button.
    public var systemImage: String {
        switch self {
        case .standby: return "power"
        case .home: return "house.fill"
        case .back: return "chevron.backward"
        case .exit: return "rectangle.on.rectangle"
        case .options: return "ellipsis"
        case .info: return "info.circle"
        case .source: return "rectangle.connected.to.line.below"
        case .settings: return "gearshape.fill"
        case .up: return "chevron.up"
        case .down: return "chevron.down"
        case .left: return "chevron.left"
        case .right: return "chevron.right"
        case .confirm: return "circle.fill"
        case .volumeUp: return "plus"
        case .volumeDown: return "minus"
        case .mute: return "speaker.slash.fill"
        case .channelUp: return "chevron.up.2"
        case .channelDown: return "chevron.down.2"
        case .digit0, .digit1, .digit2, .digit3, .digit4,
             .digit5, .digit6, .digit7, .digit8, .digit9: return "number"
        case .red, .green, .yellow, .blue: return "circle.fill"
        case .play: return "play.fill"
        case .pause: return "pause.fill"
        case .playPause: return "playpause.fill"
        case .stop: return "stop.fill"
        case .record: return "record.circle"
        case .fastForward: return "forward.fill"
        case .rewind: return "backward.fill"
        case .next: return "forward.end.fill"
        case .previous: return "backward.end.fill"
        case .guide: return "tv.and.mediabox"
        case .teletext: return "text.alignleft"
        case .subtitle: return "captions.bubble"
        }
    }

    /// Convenience for numeric keypad construction.
    public static func digit(_ value: Int) -> RemoteKey? {
        RemoteKey(rawValue: "Digit\(value)")
    }
}
