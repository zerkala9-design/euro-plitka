# Architecture

Philips Remote follows **MVVM** with a clear separation between a reusable,
platform‑agnostic **PhilipsKit** framework and the SwiftUI presentation layer.

```
┌──────────────────────────────────────────────────────────────────┐
│                          Targets                                   │
│                                                                    │
│   PhilipsRemote (iOS app)   PhilipsWidgets   PhilipsWatch          │
│        │   │   │                 │                 │               │
│        ▼   ▼   ▼                 ▼                 ▼               │
│   ┌───────────────────────────────────────────────────────┐       │
│   │                    PhilipsKit (framework)              │       │
│   │  Models · Services · Intents (shared everywhere)       │       │
│   └───────────────────────────────────────────────────────┘       │
└──────────────────────────────────────────────────────────────────┘
```

## Layers

### 1. Domain models (`Shared/Sources/Models`)
Pure `Codable`, `Sendable` value types: `TVDevice`, `TVCapabilities`,
`TVSystemInfo`, `RemoteKey`, `TVApp`, `InputSource`, `AmbilightState`,
`DiagnosticSample`, `RemoteActivityAttributes`. No UIKit/SwiftUI dependencies.

### 2. Services (`Shared/Sources/Services`)
Reusable, testable building blocks — each a single responsibility:

| Service | Responsibility |
|---------|----------------|
| `DiscoveryService` | Bonjour browse (`NWBrowser`) + active JointSpace probe → `AsyncStream<TVDevice>` |
| `AuthenticationService` | Two‑step pairing handshake, credential persistence |
| `PairingCrypto` / `DigestAuth` | HMAC‑SHA1 signature + RFC 2617 digest auth (CryptoKit) |
| `PhilipsAPIClient` | Typed JointSpace REST client (actor) with retry + cache |
| `HTTPTransport` | `URLSession` wrapper: scoped self‑signed trust + digest retry |
| `RetryPolicy` | Exponential backoff with jitter |
| `ResponseCache` | TTL cache (actor) |
| `WakeOnLANService` | UDP magic packet |
| `CapabilityDetector` | Derives capabilities from `/system` + model heuristics |
| `SpeechService` | Live speech‑to‑text |
| `VoiceCommandParser` | Natural language → `Command` (pure, unit‑tested) |
| `TVQuickControl` | Headless one‑shot commands for Siri / widgets / watch |
| `KeychainStore` | Secure credential storage |
| `DeviceRepository` | App‑Group persistence of the TV list |
| `AppLog` | `os.Logger` + ring‑buffer for diagnostics export |

### 3. App state (`App/Sources/App`)
`@Observable` (Observation framework) objects injected via the SwiftUI
environment:

- **`AppModel`** — composition root. Owns services, drives launch behaviour
  (auto‑discovery, auto‑connect, wake‑on‑launch).
- **`TVController`** — the live connection to the selected TV. Exposes `async`
  commands, observable state (volume, apps, sources, ambilight, diagnostics),
  auto‑reconnect, optimistic updates, and Live Activity updates.
- **`DeviceStore`** — the user's TV list (rooms, favorites, rename).
- **`AppSettings`** — preferences (accent, toggles), persisted to the App Group.

### 4. ViewModels (`App/Sources/ViewModels`)
Screen‑specific state machines, e.g. `PairingViewModel` (requesting → awaiting
PIN → confirming → success/failed).

### 5. Views (`App/Sources/Views`) + Design System
SwiftUI screens composed from a small glassmorphic design system (`GlassCard`,
`GlassButton`, `RockerControl`, `DPadView`) with spring animations and Core
Haptics. Dark‑mode only, capability‑gated.

## Concurrency model

- **Swift 6 strict concurrency** (`complete`).
- Networking and caches are **actors**; UI state objects are **`@MainActor`**.
- The API client reports every request to a `@Sendable` diagnostics sink, which
  hops to the main actor to update `TVController`.
- Discovery is exposed as an `AsyncStream`, consumed by `AppModel`.

## Cross‑target sharing

- **PhilipsKit** is linked by the app, widget and (logically) the watch flow.
- **App Group** (`group.com.europlitka.philipsremote`) shares the device list &
  settings with widgets and the Live Activity.
- **Keychain access group** shares pairing tokens with the widget/intents so
  Siri and widgets can control the TV without opening the app.
- The **Apple Watch** talks to the phone over **WatchConnectivity**; the phone
  executes commands through `TVQuickControl`.

## Data flow: sending a key

```
View (button tap)
  → Haptics.tap()
  → TVController.send(.volumeUp)          [@MainActor]
      → capability check
      → PhilipsAPIClient.sendKey          [actor]
          → RetryPolicy.run
              → HTTPTransport.send         (digest 401 → retry w/ Authorization)
              → diagnostics sink            → TVController.record  [@MainActor]
```
