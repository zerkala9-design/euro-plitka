import AppIntents

// App Intents live in the shared framework so both the main app (App Shortcuts,
// Siri) and the widget / Live Activity extension can invoke them.

// MARK: - Power

public struct TurnOnTVIntent: AppIntent {
    public static var title: LocalizedStringResource = "Turn TV On"
    public static var description = IntentDescription("Wake your Philips TV.")
    public static var openAppWhenRun = false
    public init() {}
    public func perform() async throws -> some IntentResult {
        _ = await TVQuickControl.shared.power(on: true)
        return .result()
    }
}

public struct TurnOffTVIntent: AppIntent {
    public static var title: LocalizedStringResource = "Turn TV Off"
    public static var description = IntentDescription("Put your Philips TV into standby.")
    public init() {}
    public func perform() async throws -> some IntentResult {
        _ = await TVQuickControl.shared.power(on: false)
        return .result()
    }
}

// MARK: - Volume

public struct VolumeUpIntent: AppIntent {
    public static var title: LocalizedStringResource = "Increase Volume"
    public init() {}
    public func perform() async throws -> some IntentResult {
        _ = await TVQuickControl.shared.adjustVolume(up: true)
        return .result()
    }
}

public struct VolumeDownIntent: AppIntent {
    public static var title: LocalizedStringResource = "Decrease Volume"
    public init() {}
    public func perform() async throws -> some IntentResult {
        _ = await TVQuickControl.shared.adjustVolume(up: false)
        return .result()
    }
}

public struct MuteTVIntent: AppIntent {
    public static var title: LocalizedStringResource = "Mute TV"
    public init() {}
    public func perform() async throws -> some IntentResult {
        _ = await TVQuickControl.shared.mute()
        return .result()
    }
}

// MARK: - Launch apps

public struct LaunchAppIntent: AppIntent {
    public static var title: LocalizedStringResource = "Open App on TV"
    public static var description = IntentDescription("Open a streaming app on your Philips TV.")

    @Parameter(title: "App name")
    public var appName: String

    public init() {}

    public static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$appName) on TV")
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let ok = await TVQuickControl.shared.launchApp(named: appName)
        return .result(dialog: ok ? "Opening \(appName)." : "I couldn't find \(appName) on your TV.")
    }
}

public struct LaunchYouTubeIntent: AppIntent {
    public static var title: LocalizedStringResource = "Launch YouTube"
    public init() {}
    public func perform() async throws -> some IntentResult {
        _ = await TVQuickControl.shared.launchApp(named: "YouTube")
        return .result()
    }
}

public struct LaunchNetflixIntent: AppIntent {
    public static var title: LocalizedStringResource = "Launch Netflix"
    public init() {}
    public func perform() async throws -> some IntentResult {
        _ = await TVQuickControl.shared.launchApp(named: "Netflix")
        return .result()
    }
}

// MARK: - Widget / Live Activity key intent

/// A lightweight intent used by interactive widgets & the Live Activity to send
/// a single remote key.
public struct SendKeyIntent: AppIntent {
    public static var title: LocalizedStringResource = "Send Remote Key"
    public static var openAppWhenRun = false

    @Parameter(title: "Key")
    public var rawKey: String

    public init() {}
    public init(_ key: RemoteKey) { self.rawKey = key.rawValue }

    public func perform() async throws -> some IntentResult {
        if let key = RemoteKey(rawValue: rawKey) {
            _ = await TVQuickControl.shared.send(key)
        }
        return .result()
    }
}
