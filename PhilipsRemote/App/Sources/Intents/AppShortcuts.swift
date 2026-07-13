import AppIntents

/// Registers Siri phrases so users can control the TV hands‑free, e.g.
/// "Turn on my TV with Philips Remote".
struct PhilipsRemoteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TurnOnTVIntent(),
            phrases: [
                "Turn on my TV with \(.applicationName)",
                "Turn on the television with \(.applicationName)"
            ],
            shortTitle: "Turn TV On",
            systemImageName: "power"
        )
        AppShortcut(
            intent: TurnOffTVIntent(),
            phrases: ["Turn off my TV with \(.applicationName)"],
            shortTitle: "Turn TV Off",
            systemImageName: "power"
        )
        AppShortcut(
            intent: VolumeUpIntent(),
            phrases: ["Turn up the volume with \(.applicationName)"],
            shortTitle: "Volume Up",
            systemImageName: "speaker.plus.fill"
        )
        AppShortcut(
            intent: VolumeDownIntent(),
            phrases: ["Turn down the volume with \(.applicationName)"],
            shortTitle: "Volume Down",
            systemImageName: "speaker.minus.fill"
        )
        AppShortcut(
            intent: MuteTVIntent(),
            phrases: ["Mute my TV with \(.applicationName)"],
            shortTitle: "Mute",
            systemImageName: "speaker.slash.fill"
        )
        AppShortcut(
            intent: LaunchYouTubeIntent(),
            phrases: ["Open YouTube with \(.applicationName)"],
            shortTitle: "YouTube",
            systemImageName: "play.rectangle.fill"
        )
        AppShortcut(
            intent: LaunchNetflixIntent(),
            phrases: ["Open Netflix with \(.applicationName)"],
            shortTitle: "Netflix",
            systemImageName: "play.rectangle.fill"
        )
    }
}
