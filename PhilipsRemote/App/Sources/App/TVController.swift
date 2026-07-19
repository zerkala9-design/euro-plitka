import SwiftUI
import Combine
import PhilipsKit

/// The heart of the app: owns the live connection to the selected TV and
/// exposes high‑level, `async` commands plus observable state for the UI.
///
/// Handles auto‑reconnect, capability‑gated commands, optimistic volume
/// updates and diagnostics collection.
@MainActor
@Observable
final class TVController {

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)

        var isConnected: Bool { self == .connected }
    }

    // Observable state
    private(set) var device: TVDevice?
    private(set) var state: ConnectionState = .disconnected
    private(set) var volume: Int = 0
    private(set) var volumeRange: ClosedRange<Int> = 0...60
    private(set) var isMuted = false
    private(set) var apps: [TVApp] = []
    private(set) var sources: [InputSource] = []
    var ambilight = AmbilightState()
    private(set) var diagnostics: [DiagnosticSample] = []
    private(set) var currentAppName: String?

    // Dependencies
    private let auth = AuthenticationService()
    private let wol = WakeOnLANService()
    private var client: PhilipsAPIClient?
    private var reconnectTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Connection lifecycle

    private var atv: ATVRemoteClient?
    /// Bumped on every connect so a stale connection's drop callback is ignored.
    private var connectionGeneration = 0
    /// True while the app is foregrounded and should hold a live connection.
    private var wantsConnection = false

    func connect(to device: TVDevice) async {
        disconnect(userInitiated: false)
        self.device = device
        wantsConnection = true
        state = .connecting
        connectionGeneration += 1
        let generation = connectionGeneration

        // Android TV Remote v2 (ports 6466/6467). The trusted client cert stored
        // in the Keychain during pairing is the credential — no token needed.
        let client = ATVRemoteClient(host: device.host)
        self.atv = client
        // Reconnect automatically if the TV or iOS drops the socket.
        await client.setOnClose { [weak self] in
            Task { @MainActor in self?.handleDropped(generation: generation) }
        }
        do {
            try await client.connect()
            state = .connected
            startLiveActivity()
        } catch let error as PhilipsError {
            state = .failed(error.localizedDescription)
            if wantsConnection, settings.autoReconnect { scheduleReconnect(to: device) }
        } catch {
            state = .failed(error.localizedDescription)
            if wantsConnection, settings.autoReconnect { scheduleReconnect(to: device) }
        }
    }

    func disconnect(userInitiated: Bool = true) {
        if userInitiated { wantsConnection = false }
        reconnectTask?.cancel(); reconnectTask = nil
        pollTask?.cancel(); pollTask = nil
        Task { [atv] in await atv?.disconnect() }
        atv = nil
        client = nil
        state = .disconnected
        LiveActivityController.shared.end()
    }

    /// The live control channel dropped on its own — try to restore it silently.
    private func handleDropped(generation: Int) {
        guard generation == connectionGeneration, wantsConnection else { return }
        state = .connecting
        if let device, settings.autoReconnect { scheduleReconnect(to: device, delay: 1.5) }
    }

    // MARK: - Foreground / background

    /// Call when the app returns to the foreground: restore the connection if it
    /// was lost while suspended, so the remote is ready without a manual retry.
    func reconnectIfNeeded() async {
        guard let device, device.isPaired else { return }
        wantsConnection = true
        if !state.isConnected { await connect(to: device) }
    }

    /// Call when the app is backgrounded: stop retry attempts to save battery.
    /// iOS suspends the socket anyway; we reconnect on the next foreground.
    func enterBackground() {
        reconnectTask?.cancel(); reconnectTask = nil
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        LiveActivityController.shared.start(
            tvName: device?.displayName ?? "TV",
            state: liveActivityState
        )
    }

    private func updateLiveActivity() {
        LiveActivityController.shared.update(liveActivityState)
    }

    private var liveActivityState: RemoteActivityAttributes.ContentState {
        .init(appName: currentAppName ?? "Home", volume: volume, isMuted: isMuted, isPlaying: true)
    }

    private func scheduleReconnect(to device: TVDevice, delay: TimeInterval = 3) {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, self?.wantsConnection == true else { return }
            await AppLog.shared.info("Auto‑reconnecting to \(device.displayName)", category: "reconnect")
            await self?.connect(to: device)
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                await self?.refreshVolume()
            }
        }
    }

    // MARK: - Refresh

    func refreshAll() async {
        await refreshVolume()
        async let a: Void = refreshApps()
        async let s: Void = refreshSources()
        async let am: Void = refreshAmbilight()
        _ = await (a, s, am)
    }

    func refreshVolume() async {
        guard let client else { return }
        if let v = try? await client.getVolume() {
            volume = v.current
            volumeRange = v.min...max(v.max, v.min + 1)
            isMuted = v.muted
            if state.isConnected { updateLiveActivity() }
        }
    }

    func refreshApps() async {
        guard let client, device?.capabilities.supportsApps == true else { return }
        if let list = try? await client.getApplications() {
            apps = mergePreferences(into: list)
        }
    }

    func refreshSources() async {
        guard let client else { return }
        if let list = try? await client.getSources() { sources = list }
    }

    func refreshAmbilight() async {
        guard let client, device?.capabilities.supportsAmbilight == true else { return }
        if let power = try? await client.getAmbilightPower() {
            ambilight.power = power
        }
    }

    // MARK: - Commands

    func send(_ key: RemoteKey) async {
        guard let atv, let code = ATVKeyCode(key) else {
            Haptics.shared.warning()
            return
        }
        await atv.sendKey(code)
        await AppLog.shared.info("Sent \(key.rawValue)", category: "command")
    }

    // MARK: - Press & hold (auto‑repeat while a key is held)

    private var holdTask: Task<Void, Never>?

    /// Begin repeating a key while a button is held (volume, channels, D‑pad).
    func beginHold(_ key: RemoteKey) {
        endHold()
        holdTask = Task { [weak self] in
            await self?.send(key)                        // immediate first press
            try? await Task.sleep(for: .seconds(0.35))   // delay before repeating
            while !Task.isCancelled {
                await self?.send(key)
                try? await Task.sleep(for: .seconds(0.11))
            }
        }
    }

    func endHold() {
        holdTask?.cancel()
        holdTask = nil
    }

    // MARK: - True key hold (physical‑remote style, used by the D‑pad)

    private var heldKey: RemoteKey?
    private var releaseTask: Task<Void, Never>?

    /// Hold a navigation key down the way a physical remote does: send one
    /// key‑down now and the matching key‑up on release, letting the TV do its
    /// own native auto‑repeat. Avoids the rapid tap‑flood that some apps (e.g.
    /// cursor‑based web apps) mishandle.
    func beginPress(_ key: RemoteKey) {
        endPress()   // release anything still held
        guard let atv, let code = ATVKeyCode(key) else {
            Haptics.shared.warning()
            return
        }
        heldKey = key
        Task { await atv.pressKey(code) }
        // Safety net: never leave a key stuck down if the release is missed.
        releaseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            self?.endPress()
        }
    }

    func endPress() {
        releaseTask?.cancel(); releaseTask = nil
        guard let key = heldKey else { return }
        heldKey = nil
        if let atv, let code = ATVKeyCode(key) {
            Task { await atv.releaseKey(code) }
        }
    }

    func setVolume(_ value: Int) async {
        // The Android TV protocol has no absolute volume; step towards target.
        let delta = value - volume
        volume = value
        let step: RemoteKey = delta >= 0 ? .volumeUp : .volumeDown
        for _ in 0..<min(abs(delta), 10) { await send(step) }
    }

    func volumeStep(up: Bool) async {
        await send(up ? .volumeUp : .volumeDown)
        volume = min(volumeRange.upperBound, max(volumeRange.lowerBound, volume + (up ? 1 : -1)))
    }

    func toggleMute() async {
        isMuted.toggle()                     // optimistic
        await send(.mute)
    }

    func appIconData(_ app: TVApp) async -> Data? {
        try? await client?.appIcon(app)
    }

    func launch(_ app: TVApp) async {
        guard let atv else { return }
        if let uri = ATVAppLink.uri(forAppNamed: app.label) {
            await atv.launchApp(uri: uri)
            currentAppName = app.label
            recordRecentApp(app)
            updateLiveActivity()
        } else {
            Haptics.shared.warning()
        }
    }

    /// Launch an app on the TV by name (used by voice/quick actions).
    func launchApp(named name: String) async {
        guard let atv, let uri = ATVAppLink.uri(forAppNamed: name) else { return }
        await atv.launchApp(uri: uri)
        currentAppName = name
    }

    /// Launch a raw app‑link / URL on the TV (used by user‑added links).
    func launchURL(_ uri: String) async {
        guard let atv, !uri.isEmpty else { return }
        await atv.launchApp(uri: uri)
    }

    func selectSource(_ source: InputSource) async {
        guard let client else { return }
        try? await client.selectSource(source)
    }

    /// Remote text entry — writes into the TV's focused text field (via the
    /// Android TV IME channel). Only works while a field is focused on the TV.
    func sendText(_ text: String) async {
        guard let atv else { return }
        await atv.sendText(text)
    }

    /// Whether the TV currently has a focused text field we can type into.
    func canSendText() async -> Bool {
        guard let atv else { return false }
        return await atv.canSendText
    }

    func setAmbilightPower(_ on: Bool) async {
        guard let client else { return }
        ambilight.power = on
        try? await client.setAmbilightPower(on)
    }

    func setAmbilightMode(_ mode: AmbilightState.Mode) async {
        guard let client else { return }
        ambilight.mode = mode
        try? await client.setAmbilightMode(mode)
    }

    func setAmbilightColor(_ color: RGBColor) async {
        guard let client else { return }
        ambilight.color = color
        ambilight.mode = .manual
        try? await client.setAmbilightColor(color)
    }

    // MARK: - Power / Wake on LAN

    func wake() async {
        guard let device, let mac = device.macAddress else { return }
        try? await wol.wake(macAddress: mac)
    }

    func powerToggle() async {
        if state.isConnected {
            await send(.standby)     // KEYCODE_POWER toggles standby
        } else {
            await wake()             // Wake‑on‑LAN for a fully sleeping TV
            if let device { scheduleReconnect(to: device, delay: 2) }
        }
    }

    // MARK: - Diagnostics

    private func record(_ sample: DiagnosticSample) {
        diagnostics.append(sample)
        if diagnostics.count > 200 { diagnostics.removeFirst(diagnostics.count - 200) }
    }

    var diagnosticsReport: DiagnosticsReport { DiagnosticsReport(samples: diagnostics) }

    // MARK: - Helpers

    private func handle(_ error: Error) async {
        Haptics.shared.error()
        if let philips = error as? PhilipsError {
            await AppLog.shared.error(philips.localizedDescription, category: "command")
            if philips == .authenticationExpired || philips == .notPaired {
                state = .failed(philips.localizedDescription)
            } else if philips.isRetryable, let device, settings.autoReconnect {
                scheduleReconnect(to: device)
            }
        }
    }

    // Persisted per‑app favorites / recents.
    private func mergePreferences(into apps: [TVApp]) -> [TVApp] {
        let favs = Set(AppPreferences.favoriteApps())
        let recents = AppPreferences.recentApps()
        return apps.map { app in
            var a = app
            a.isFavorite = favs.contains(app.packageName)
            a.lastUsed = recents[app.packageName]
            return a
        }
    }

    func toggleFavoriteApp(_ app: TVApp) {
        AppPreferences.toggleFavoriteApp(app.packageName)
        if let i = apps.firstIndex(where: { $0.id == app.id }) { apps[i].isFavorite.toggle() }
    }

    private func recordRecentApp(_ app: TVApp) {
        AppPreferences.recordRecentApp(app.packageName)
    }
}
