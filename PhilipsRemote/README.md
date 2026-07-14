# Philips Remote — Premium Universal Philips TV Remote for iPhone

A production‑quality, App Store‑grade universal remote for **every Philips
Android TV / Google TV** (PUS7xxx, PUS8xxx, OLED7xx/8xx/9xx and more, including
the **Philips 50PUS7906/12** on Android TV 11).

Built entirely in **SwiftUI + Swift 6 concurrency** with a glassmorphic,
visionOS‑inspired design, it automatically discovers your TV on Wi‑Fi, pairs
securely, detects each model's capabilities and exposes only supported features.

> Independent app — not affiliated with or endorsed by Philips / TP Vision.

---

## ✨ Features

| Area | Highlights |
|------|-----------|
| **Discovery** | Bonjour + active JointSpace probing, signal quality, one‑tap connect, manual IP add |
| **Secure Pairing** | Digest‑auth handshake, HMAC‑SHA1 signature, animated PIN flow, Keychain‑stored tokens, auto‑reconnect |
| **Main Remote** | Power, Home, Back, Settings, D‑pad + OK, volume/channel rockers, numeric keypad, colored keys, full transport controls |
| **Gesture Remote** | Full‑screen trackpad — swipe, tap, double‑tap, long‑press, momentum |
| **Keyboard** | Native iPhone keyboard streamed to the TV (emoji, dictation, paste, autofill) |
| **Voice Control** | Hold‑to‑talk speech recognition → parsed commands ("Open Netflix", "Volume up", "Search for Interstellar") |
| **Apps** | Live app grid with icons, search, favorites, recents, categories |
| **Input Sources** | HDMI / ARC / USB / AV / TV detection, rename & favorite |
| **Ambilight** | Power, modes, brightness/saturation, color wheel & presets (capability‑gated) |
| **TV Info** | Model, serial, software, Android, API, resolution, HDR/Dolby, MAC/IP, capabilities |
| **Wake‑on‑LAN** | Magic‑packet wake, wake‑on‑launch |
| **Multiple TVs** | Unlimited TVs grouped by room, per‑device settings |
| **Apple Watch** | Companion app: navigation, volume (Digital Crown), power, quick apps |
| **Widgets** | Favorite TV, Quick Volume, Open Netflix, Sleep Timer (interactive) |
| **Live Activity** | "Now Watching" on Lock Screen + Dynamic Island with controls |
| **Siri** | App Intents & Shortcuts: power, volume, mute, launch apps |
| **Diagnostics** | Latency, packet loss, signal quality, live chart, command log export |

## 🧱 Tech stack

SwiftUI · MVVM · Swift Concurrency (async/await, actors) · Combine · Network
framework · Bonjour · URLSession · CryptoKit · Keychain · Speech · Core Haptics
· WidgetKit · ActivityKit (Live Activities) · App Intents · WatchConnectivity ·
Swift Testing.

- **Minimum iOS 18**, watchOS 11. No storyboards. Dark‑mode only.

## 📂 Project layout

```
PhilipsRemote/
├── project.yml                 # XcodeGen project definition
├── Shared/Sources/             # PhilipsKit framework (shared by all targets)
│   ├── Models/                 # TVDevice, RemoteKey, TVApp, Ambilight, …
│   ├── Services/               # Discovery, Auth, API client, WoL, crypto, cache…
│   └── Intents/                # App Intents (shared with widgets)
├── App/Sources/                # iOS app
│   ├── App/                    # AppModel, TVController, stores, settings
│   ├── DesignSystem/           # Glass components, theme, haptics
│   ├── ViewModels/             # MVVM view models
│   ├── Views/                  # All SwiftUI screens
│   └── Utilities/              # Icon cache, layout helpers
├── Widget/                     # WidgetKit + Live Activity extension
├── Watch/Sources/              # Apple Watch app
├── Config/                     # Entitlements
├── Tests/                      # Swift Testing unit + decoding tests
└── Docs/                       # Architecture, API, Setup, Troubleshooting
```

## 🚀 Getting started

The project is defined with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
so the `.xcodeproj` is generated deterministically.

**Easiest — double‑click `bootstrap.command`** (installs XcodeGen if needed,
generates the project and opens it in Xcode).

Or manually:

```bash
brew install xcodegen
cd PhilipsRemote
xcodegen generate
open PhilipsRemote.xcodeproj
```

> The project builds in **Swift 5 language mode** (`SWIFT_VERSION = 5.0`) so
> concurrency edge‑cases surface as warnings rather than hard errors. All modern
> concurrency features (async/await, actors, `@Observable`) are still used.

Then set your **Development Team** in *Signing & Capabilities* for each target
and run on a device (the Local Network + Bonjour features require a real iPhone,
not the simulator). See [`Docs/SETUP.md`](Docs/SETUP.md) for full details.

## 🧪 Tests

```bash
xcodegen generate
xcodebuild test -scheme PhilipsRemote -destination 'platform=iOS Simulator,name=iPhone 16'
```

Unit tests cover the pairing crypto, digest auth, Wake‑on‑LAN packets, voice
parsing, capability detection and the JointSpace decoding layer (mock API).

## 📖 Documentation

- [Architecture](Docs/ARCHITECTURE.md)
- [Philips JointSpace API](Docs/API.md)
- [Setup guide](Docs/SETUP.md)
- [Troubleshooting](Docs/TROUBLESHOOTING.md)

## 🔒 Security & privacy

- Pairing tokens are stored in the **Keychain** (`ThisDeviceOnly`, never synced).
- The shared device list lives in an **App Group**; **secrets never do**.
- All TV traffic stays on the **local network**; self‑signed TLS trust is scoped
  to the TV host only. No analytics, no sensitive logging.
