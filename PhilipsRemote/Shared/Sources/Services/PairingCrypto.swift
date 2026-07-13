import Foundation
import CryptoKit

/// Cryptography for the Philips Android TV (JointSpace v6) pairing handshake.
///
/// The handshake works as follows:
/// 1. `POST /6/pair/request` (unauthenticated) → the TV returns an `auth_key`
///    and a `timestamp`, and displays a 4‑digit PIN on screen.
/// 2. The client computes an HMAC‑SHA1 signature over `timestamp + pin` using a
///    well‑known shared secret, then base64‑encodes the *hex* digest.
/// 3. `POST /6/pair/grant` (HTTP Digest auth) with the signature confirms the
///    pairing; every subsequent request uses HTTP Digest auth.
public enum PairingCrypto {

    /// Well‑known secret used by Philips 2016+ Android TVs for the pairing
    /// signature. Publicly documented in the community JointSpace tooling.
    private static let secretKeyBase64 =
        "ZmVay1EQVFOaZhwQ4Kv81ypLAZNczV9sG4KkseXWn1NEk6cXmPKO/MCa9sryslvLCFMnNe4Z4CPXztoowvhHvA="

    /// Compute the base64 signature required for `pair/grant`.
    ///
    /// - Note: The signature is `base64( hexdigest( HMAC_SHA1(secret, timestamp+pin) ) )`,
    ///   matching the reference implementation used by Home Assistant & pylips.
    public static func signature(timestamp: Int, pin: String) -> String {
        let secret = Data(base64Encoded: secretKeyBase64) ?? Data()
        let message = Data("\(timestamp)\(pin)".utf8)
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: message, using: SymmetricKey(data: secret))
        let hex = mac.map { String(format: "%02x", $0) }.joined()
        return Data(hex.utf8).base64EncodedString()
    }

    /// Generate a stable, random device identifier (16 lowercase hex-ish chars)
    /// used as the digest username for a paired TV.
    public static func generateDeviceID() -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<16).map { _ in chars.randomElement()! })
    }
}
