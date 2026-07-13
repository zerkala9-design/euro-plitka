# Troubleshooting

## The TV isn't found during discovery

- Confirm the iPhone and TV are on the **same Wi‑Fi network / VLAN** (guest
  networks and AP isolation block discovery).
- Grant **Local Network** permission: *iOS Settings → Philips Remote → Local
  Network*.
- Some routers block mDNS/Bonjour — use **Add TV by IP** (the *+* button) and
  enter the TV's IP (find it on the TV: *Settings → Network → View network
  settings*).
- Make sure the TV is **on** (or was recently on). A fully powered‑off TV won't
  answer the API — use Wake‑on‑LAN.

## Pairing fails / "That PIN didn't match"

- Enter the PIN promptly — the TV **expires** the pairing session after ~60s.
  Tap *Try Again* to get a fresh code.
- Ensure the TV is a **JointSpace v6** Android model. Very old models use a
  different (non‑paired) API.
- If it keeps failing, on the TV go to *Settings → General → Restart* and retry.

## "Authentication expired" after it worked before

- The stored token was rejected (e.g. after a TV factory reset). Open the TV in
  *My TVs*, remove it, and pair again. Removing a TV also deletes its Keychain
  credential.

## Commands are slow or drop out

- Open **Settings → Diagnostics** to see live latency and packet loss.
- High latency usually means weak Wi‑Fi near the TV — a 5 GHz connection or a
  wired TV connection helps.
- The app retries transient failures automatically and reconnects in the
  background.

## A feature is missing / greyed out

The app only shows features the TV reports as supported. For example, Ambilight
appears only on Ambilight‑capable models (OLED and most 7000‑series and above).
Check **TV Information → Capabilities** to see what your model exposes.

## Voice control does nothing

- Grant **Microphone** and **Speech Recognition** permissions when prompted
  (or enable them in iOS Settings).
- Speak a supported phrase: "Open Netflix", "Volume up", "Pause", "Search for …".

## Wake‑on‑LAN doesn't power the TV on

- Enable *Wake on Wi‑Fi/LAN* on the TV.
- Ensure the TV's **MAC address** is set (*Edit TV*).
- Deep‑sleep/Eco modes on some models disable network wake — set the TV to a
  networked standby mode.

## Widgets / Live Activity not updating

- Confirm the app has run at least once and paired a TV (widgets read the shared
  App Group written by the app).
- Live Activities must be enabled: *iOS Settings → Philips Remote → Live
  Activities*.

## Export diagnostics for a bug report

*Settings → Diagnostics → Share* exports latency, packet loss and the recent
command/reconnect log (no secrets are included).
