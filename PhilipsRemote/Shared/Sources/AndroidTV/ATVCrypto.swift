import Foundation
import Security
import Network
import Crypto

/// Certificate + key material for the Android TV Remote TLS connections.
///
/// A single fixed client identity (RSA key + self‑signed cert) is baked into
/// the app as a PKCS#12 blob and loaded with `SecPKCS12Import`. Because every
/// install presents the *same* certificate, the TV — which only trusts one
/// remote certificate — keeps several phones paired at once (it sees them as
/// one remote) instead of each pairing evicting the previous.
public enum ATVCrypto {

    /// Password protecting the embedded PKCS#12 identity.
    private static let p12Password = "europlitka"

    /// Fixed shared identity (RSA 2048 key + self‑signed cert), PKCS#12/DER,
    /// legacy‑encrypted for `SecPKCS12Import` compatibility, base64‑encoded.
    private static let identityP12Base64 = """
    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
    """

    public struct Identity {
        public let secIdentity: SecIdentity
        public let modulus: Data
        public let exponent: Data
    }

    // MARK: - Identity

    public static func loadOrCreateIdentity() throws -> Identity {
        let base64 = identityP12Base64.components(separatedBy: .whitespacesAndNewlines).joined()
        guard let p12Data = Data(base64Encoded: base64) else {
            throw PhilipsError.unknown("Identity failed: bad p12 data")
        }
        let options: [String: Any] = [kSecImportExportPassphrase as String: p12Password]
        var items: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)
        guard status == errSecSuccess,
              let array = items as? [[String: Any]],
              let first = array.first,
              let identityRef = first[kSecImportItemIdentity as String] else {
            throw PhilipsError.unknown("Identity failed: p12 import (\(status))")
        }
        let identity = identityRef as! SecIdentity
        guard let cert = copyCertificate(from: identity),
              let numbers = publicKeyNumbers(from: cert) else {
            throw PhilipsError.unknown("Identity failed: no public key")
        }
        return Identity(secIdentity: identity, modulus: numbers.modulus, exponent: numbers.exponent)
    }

    public static func secIdentity(_ identity: SecIdentity) -> sec_identity_t? {
        sec_identity_create(identity)
    }

    private static func copyCertificate(from identity: SecIdentity) -> SecCertificate? {
        var cert: SecCertificate?
        SecIdentityCopyCertificate(identity, &cert)
        return cert
    }

    // MARK: - Public key numbers + pairing secret

    public static func publicKeyNumbers(from certificate: SecCertificate) -> (modulus: Data, exponent: Data)? {
        guard let key = SecCertificateCopyKey(certificate),
              let data = SecKeyCopyExternalRepresentation(key, nil) as Data? else { return nil }
        return ASN1.parseRSAPublicKey(data)
    }

    public static func pairingSecret(
        clientModulus: Data, clientExponent: Data,
        serverModulus: Data, serverExponent: Data,
        code: String
    ) -> (secret: Data, matches: Bool)? {
        guard let codeBytes = hexToData(code), codeBytes.count >= 2 else { return nil }
        var hasher = SHA256()
        hasher.update(data: clientModulus)
        hasher.update(data: clientExponent)
        hasher.update(data: serverModulus)
        hasher.update(data: serverExponent)
        hasher.update(data: codeBytes.subdata(in: codeBytes.index(after: codeBytes.startIndex)..<codeBytes.endIndex))
        let digest = Data(hasher.finalize())
        let matches = digest.first == codeBytes.first
        return (digest, matches)
    }

    private static func hexToData(_ hex: String) -> Data? {
        let clean = hex.trimmingCharacters(in: .whitespaces)
        guard clean.count % 2 == 0 else { return nil }
        var data = Data()
        var idx = clean.startIndex
        while idx < clean.endIndex {
            let next = clean.index(idx, offsetBy: 2)
            guard let byte = UInt8(clean[idx..<next], radix: 16) else { return nil }
            data.append(byte)
            idx = next
        }
        return data
    }
}
