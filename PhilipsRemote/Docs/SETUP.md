# Setup guide

## Requirements

- macOS with **Xcode 16** or later
- **iOS 18** device (a physical iPhone — Local Network + Bonjour discovery does
  not work in the Simulator)
- A Philips **Android TV / Google TV** on the same Wi‑Fi network
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## 1. Generate the Xcode project

```bash
brew install xcodegen
cd PhilipsRemote
xcodegen generate
open PhilipsRemote.xcodeproj
```

`project.yml` defines five targets: `PhilipsKit` (framework), `PhilipsRemote`
(app), `PhilipsWidgets`, `PhilipsWatch`, and `PhilipsRemoteTests`.

## 2. Signing & capabilities

For **each** target, in *Signing & Capabilities*:

1. Select your **Team**.
2. Adjust the bundle identifiers if `com.europlitka.philipsremote*` is taken.
3. Ensure these capabilities are present (already declared in the entitlements):
   - **App Groups** → `group.com.europlitka.philipsremote`
   - **Keychain Sharing** → `com.europlitka.philipsremote`
4. The app's Info settings already include:
   - `NSLocalNetworkUsageDescription` + `NSBonjourServices`
   - `NSMicrophoneUsageDescription` + `NSSpeechRecognitionUsageDescription`
   - `NSSupportsLiveActivities = YES`

> If you change the App Group / Keychain group identifiers, update
> `AppGroup.identifier`, `KeychainStore.service` and the entitlements files.

## 3. Run

1. Build & run the **PhilipsRemote** scheme on your iPhone.
2. Grant **Local Network** access when prompted.
3. Your TV appears under *Found on your network* — tap it.
4. Enter the 4‑digit PIN shown on the TV.
5. You're connected. The token is stored securely and reconnects automatically.

## 4. Wake‑on‑LAN (optional)

To power the TV on from standby:

- Enable it on the TV: *Settings → Wireless & networks → Wake on Wi‑Fi/LAN*.
- Add the TV's **MAC address** (it is captured during discovery where available,
  or set it in *Edit TV*).

## 5. Widgets, Live Activity, Siri & Watch

- **Widgets**: long‑press the Home Screen → *+* → search "Philips".
- **Live Activity**: starts automatically while connected (Lock Screen / Dynamic
  Island).
- **Siri**: "Turn on my TV with Philips Remote", "Open Netflix with Philips
  Remote", etc.
- **Apple Watch**: install the companion app from the Watch app; it controls the
  currently selected TV through your iPhone.

## 6. Tests

```bash
xcodebuild test -scheme PhilipsRemote \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
