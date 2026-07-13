# Philips JointSpace API (v6)

Philips Android TVs expose the **JointSpace** REST API. This app targets **API
version 6** over **HTTPS on port 1926** (legacy sets use HTTP on 1925). The TV
presents a self‑signed certificate and protects most endpoints with **HTTP
Digest authentication**.

Base URL: `https://<tv-ip>:1926/6/`

## Pairing handshake

Android TVs (2016+) require a one‑time pairing that yields a username/password
used for digest auth on every subsequent request.

### 1. Request

```
POST /6/pair/request          (no auth)
{
  "scope": ["read", "write", "control"],
  "device": {
    "device_name": "iPhone", "device_os": "iOS",
    "app_name": "Philips Remote", "type": "native",
    "app_id": "com.europlitka.philipsremote", "id": "<random 16 chars>"
  }
}
→ { "error_id": "SUCCESS", "auth_key": "...", "timestamp": 1699999999 }
```

The TV displays a 4‑digit PIN.

### 2. Signature

```
secret     = base64_decode(<well-known Philips secret>)
signature  = base64( hex( HMAC_SHA1(secret, "<timestamp><pin>") ) )
```

Implemented in `PairingCrypto.signature(timestamp:pin:)`.

### 3. Grant

```
POST /6/pair/grant            (Digest auth: user = device id, pass = auth_key)
{
  "auth": {
    "auth_AppId": "1", "pin": "1234",
    "auth_timestamp": 1699999999,
    "auth_signature": "signature===<signature>"
  },
  "device": { …same as request… }
}
→ 200 { "error_id": "SUCCESS" }
```

The credential (`device id`, `auth_key`) is stored in the Keychain and used as
the digest username/password for all future calls.

## Endpoints used

| Feature | Method / Path | Body / Notes |
|---------|---------------|--------------|
| Send key | `POST /6/input/key` | `{ "key": "VolumeUp" }` |
| Volume | `GET/POST /6/audio/volume` | `{ "muted", "current", "min", "max" }` |
| System info | `GET /6/system` | model, software, api_version, featuring |
| Applications | `GET /6/applications` | list of installed apps |
| Launch app | `POST /6/activities/launch` | `{ "intent": { "component": { packageName, className } } }` |
| App icon | `GET /6/applications/<id>/icon` | PNG bytes |
| Ambilight power | `GET/POST /6/ambilight/power` | `{ "power": "On" \| "Off" }` |
| Ambilight config | `POST /6/ambilight/currentconfiguration` | `{ "styleName", … }` |
| Ambilight color | `POST /6/ambilight/cached` | per‑pixel / cached color map |
| Sources (legacy) | `GET /6/sources`, `POST /6/sources/current` | input switching |
| Text entry | `POST /6/input/textentry` | best‑effort, model dependent |

### Common `RemoteKey` values

`Standby`, `Home`, `Back`, `Confirm`, `CursorUp/Down/Left/Right`,
`VolumeUp/VolumeDown`, `Mute`, `ChannelStepUp/Down`, `Digit0…9`,
`RedColour/GreenColour/YellowColour/BlueColour`, `Play`, `Pause`, `PlayPause`,
`Stop`, `FastForward`, `Rewind`, `Next`, `Previous`, `ProgramGuide`, `Options`,
`Info`, `Source`, `Adjust`, `WatchTV`.

See `RemoteKey.swift` for the complete set.

## Capability detection

`GET /6/system` returns a `featuring` object listing supported feature groups
(`ambilight`, `applications`, `pointer`, `inputkey`, …). `CapabilityDetector`
combines this with model‑string heuristics (OLED/PUS series numbers) to decide
which features to surface — so an unsupported command is never offered.

## Error handling

| HTTP | Mapped `PhilipsError` |
|------|-----------------------|
| 401 | `authenticationExpired` / `invalidPin` (during pairing) |
| 404 | `unsupportedCommand` |
| timeout / connection lost | `timeout` / `tvOffline` (retryable) |
| other 4xx/5xx | `invalidResponse(status:)` |

Retryable errors are retried with exponential backoff + jitter (`RetryPolicy`).

> The pairing secret and protocol details are publicly documented by the
> JointSpace / Home Assistant community. This app implements the client side
> only and performs no reverse engineering at runtime.
