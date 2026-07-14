# Android TV Remote v2 protocol — implementation plan

The Philips 50PUS7906/12 (Android TV 11) does **not** expose the Philips
JointSpace API (ports 1925/1926 are closed on firmware `TPM215E_R.101...`).
It **does** expose the standard **Google Android TV Remote v2** service:

```
6466  succeeded   ← pairing (TLS)
6467  succeeded   ← remote control (TLS)
8008  succeeded   ← Chromecast / DIAL (app launch, casting)
8009  succeeded   ← Cast
```

So the remote must speak the **Android TV Remote v2** protocol. This document is
the durable spec so the work survives across sessions.

## Overview

Both pairing (6466) and remote (6467) run over **TLS**, where the **client
presents a self-signed certificate**. The same cert/key pair is generated once,
stored in the Keychain, and reused. The TV also uses a self-signed cert, which
the client must accept (pinning-free trust for the TV host).

Messages are **Protocol Buffers**, each **length-prefixed** (see framing below).

### Framing
Each message on the wire is: `<varint length><protobuf bytes>`.
Read a varint for the length, then that many bytes = one protobuf message.
(Both 6466 and 6467 use this delimited framing.)

## Phase 1 — Pairing (port 6466)

Protobuf type: `PairingMessage`
```
message PairingMessage {
  int32 protocol_version = 1;
  Status status = 2;              // 200 = OK
  int32 sequence_number = 3;
  PairingRequest       pairing_request = 10;        // { service_name, client_name }
  PairingRequestAck    pairing_request_ack = 11;    // { server_name }
  PairingOption        pairing_option = 20;          // encodings + preferred_role
  PairingConfiguration pairing_configuration = 30;   // { encoding, client_role }
  PairingSecret        pairing_secret = 40;          // { secret: bytes }
}
Encoding { EncodingType type = 1; int32 symbol_length = 2; }  // type HEX = 3
Roles: ROLE_TYPE_INPUT = 1, ROLE_TYPE_OUTPUT = 2
EncodingType: UNKNOWN=0, ALPHANUMERIC=1, NUMERIC=2, HEXADECIMAL=3, QRCODE=4
```

Handshake sequence (client ⇄ TV):
1. C → `PairingRequest { service_name: "androidtvremote", client_name: "iPhone" }`
2. C → `PairingOption { input_encodings: [{ type: HEXADECIMAL, symbol_length: 6 }], preferred_role: INPUT }`
3. C → `PairingConfiguration { encoding: { HEXADECIMAL, 6 }, client_role: INPUT }`
   → the TV now displays a **6-hex-digit code**.
4. User types the code. Client derives the secret:
   ```
   digest = SHA256()
   digest.update(client_cert.modulus)      // unsigned big-endian, no leading 0x00
   digest.update(client_cert.exponent)     // unsigned big-endian
   digest.update(server_cert.modulus)
   digest.update(server_cert.exponent)
   digest.update(bytes(code[2:]))          // the code minus its first byte (nibble check)
   secret = digest.finalize()              // 32 bytes
   ```
   The first byte of the code (`code[0:2]` hex) must equal `secret[0]` — a check.
   Actually: alpha = the code as bytes; client verifies `alpha[0] == hash_of(... code[1:])[0]`.
   Send `C → PairingSecret { secret }`.
5. TV → `PairingSecret` (validates). On success the cert is now trusted → pairing done.

> Extracting RSA modulus/exponent from the certs is the fiddly part. Use the
> DER of the SubjectPublicKeyInfo → parse the RSAPublicKey SEQUENCE { modulus,
> exponent }. `swift-certificates` / `swift-asn1` expose these directly.

## Phase 2 — Remote control (port 6467)

Reconnect over TLS with the **same** client cert. Protobuf type: `RemoteMessage`.
```
message RemoteMessage {
  RemoteConfigure       remote_configure = 1;    // device info exchange
  RemoteSetActive       remote_set_active = 2;   // { active: 622 }
  RemoteError           remote_error = 3;
  RemotePingRequest     remote_ping_request = 8;  // { val1 }
  RemotePingResponse    remote_ping_response = 9; // { val1 }
  RemoteKeyInject       remote_key_inject = 10;   // { key_code, direction }
  RemoteImeKeyInject    remote_ime_key_inject = 20; // text
  RemoteStart           remote_start = 30;        // { started }
  ...
}
RemoteKeyInject { RemoteDirection direction = 1; RemoteKeyCode key_code = 2; }
RemoteDirection: START_LONG=1, END_LONG=2, SHORT=3
```

Sequence after TLS connect:
1. TV → `RemoteConfigure`  → C echoes `RemoteConfigure { device_info }`
2. TV → `RemoteSetActive`  → C → `RemoteSetActive { active: 622 }`
3. TV → `RemoteStart { started: true }` → ready.
4. Keep-alive: TV → `RemotePingRequest { val1 }` → C → `RemotePingResponse { val1 }`. **Must answer** or the TV drops us.
5. Send a key: C → `RemoteKeyInject { direction: SHORT, key_code: <KEYCODE> }`.

### Android key codes (subset)
```
POWER=26  HOME=3  BACK=4  DPAD_UP=19 DPAD_DOWN=20 DPAD_LEFT=21 DPAD_RIGHT=22
DPAD_CENTER=23 (OK)  VOLUME_UP=24 VOLUME_DOWN=25 VOLUME_MUTE=164
MEDIA_PLAY_PAUSE=85 MEDIA_STOP=86 MEDIA_NEXT=87 MEDIA_PREVIOUS=88
MEDIA_REWIND=89 MEDIA_FAST_FORWARD=90  CHANNEL_UP=166 CHANNEL_DOWN=167
0..9 = 7..16   TV=170  GUIDE=172  SETTINGS=176  INFO=165
```

App launch: use the **DIAL/Cast** service on 8008/8009, or send an intent via
`remote_app_link_launch_request` in RemoteMessage (field carries an app link URI,
e.g. `https://www.youtube.com`, `market://launch?id=com.netflix.ninja`).

## iOS building blocks

| Piece | How |
|-------|-----|
| Self-signed cert + RSA key | `swift-certificates` + `swift-crypto` (SPM), or Security framework |
| Store cert/key | Keychain (reuse across launches) |
| TLS client auth | `Network` framework `NWProtocolTLS`, set local identity via `sec_protocol_options_set_local_identity`; accept server trust via `sec_protocol_options_set_verify_block` |
| Protobuf | Hand-rolled wire encoder/decoder (`ProtobufWriter`/`ProtobufReader`) — messages are small |
| Discovery | Bonjour `_androidtvremote2._tcp` + probe port 6466 |

## Implementation order (resumable checklist)

- [x] Spec (this doc)
- [x] `ATVKeyCode.swift` — RemoteKey → Android keycode
- [x] `ProtobufWire.swift` — varint + length-delimited encode/decode
- [ ] `ATVCertificate.swift` — generate/load self-signed cert+key, extract modulus/exponent
- [ ] `ATVConnection.swift` — NWConnection + TLS with client identity + length-delimited message read/write
- [ ] `ATVPairingClient.swift` — pairing handshake + secret derivation
- [ ] `ATVRemoteClient.swift` — configure/setActive/ping loop + key inject
- [ ] Wire into app: discovery (6466 probe), pairing UI (reuse PairingView), TVController command path
- [ ] Test on device: pair, send keys, verify

## Reference implementations to mirror
- Python `androidtvremote2` (tronikos) — the canonical spec.
- Home Assistant `androidtv_remote` integration.
- `pyatv` (companion protocol notes).
