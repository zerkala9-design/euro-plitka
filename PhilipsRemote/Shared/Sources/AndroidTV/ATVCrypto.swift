import Foundation
import Security
import Network
import Crypto
import _CryptoExtras
import X509
import SwiftASN1

/// Certificate + key material for the Android TV Remote TLS connections.
///
/// A persistent self‑signed RSA identity is generated with swift‑certificates
/// (a valid X.509 cert — the hand‑rolled one was rejected by the TV), stored in
/// the Keychain, and reused. Exposed as a `sec_identity_t` for `Network`.
public enum ATVCrypto {

    // v2: force a fresh swift-certificates identity, ignoring any earlier
    // hand-built (invalid) cert left in the Keychain from older builds.
    private static let keyTag = "com.europlitka.philipsremote.atv.key.v2".data(using: .utf8)!
    private static let certLabel = "com.europlitka.philipsremote.atv.cert.v2"

    public struct Identity {
        public let secIdentity: SecIdentity
        public let modulus: Data
        public let exponent: Data
    }

    // MARK: - Identity

    public static func loadOrCreateIdentity() throws -> Identity {
        if let identity = try loadIdentityFromKeychain(),
           let cert = copyCertificate(from: identity),
           let numbers = publicKeyNumbers(from: cert) {
            return Identity(secIdentity: identity, modulus: numbers.modulus, exponent: numbers.exponent)
        }

        let rsa = try _RSA.Signing.PrivateKey(keySize: .bits2048)
        let certDER = try makeCertificate(rsa: rsa)
        try importPrivateKey(rsa)
        try storeCertificate(certDER)

        guard let identity = try loadIdentityFromKeychain(),
              let cert = copyCertificate(from: identity),
              let numbers = publicKeyNumbers(from: cert) else {
            throw PhilipsError.unknown("Identity setup failed")
        }
        return Identity(secIdentity: identity, modulus: numbers.modulus, exponent: numbers.exponent)
    }

    public static func secIdentity(_ identity: SecIdentity) -> sec_identity_t? {
        sec_identity_create(identity)
    }

    // MARK: - Certificate (swift-certificates)

    private static func makeCertificate(rsa: _RSA.Signing.PrivateKey) throws -> Data {
        let key = Certificate.PrivateKey(rsa)
        let name = try DistinguishedName { CommonName("atvremote") }
        let cert = try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: key.publicKey,
            notValidBefore: Date().addingTimeInterval(-86_400),
            notValidAfter: Date().addingTimeInterval(60 * 60 * 24 * 3650),
            issuer: name,
            subject: name,
            signatureAlgorithm: .sha256WithRSAEncryption,
            extensions: Certificate.Extensions {},
            issuerPrivateKey: key
        )
        var serializer = DER.Serializer()
        try serializer.serialize(cert)
        return Data(serializer.serializedBytes)
    }

    // MARK: - Keychain: key + certificate → identity

    private static func importPrivateKey(_ rsa: _RSA.Signing.PrivateKey) throws {
        let pkcs1 = ASN1.pkcs1PrivateKey(from: rsa.derRepresentation)
        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 2048
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(pkcs1 as CFData, attrs as CFDictionary, &error) else {
            throw PhilipsError.unknown("Key import failed")
        }
        let add: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecValueRef as String: key
        ]
        SecItemDelete(add as CFDictionary)
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw PhilipsError.unknown("Key store failed (\(status))")
        }
    }

    private static func storeCertificate(_ der: Data) throws {
        guard let cert = SecCertificateCreateWithData(nil, der as CFData) else {
            throw PhilipsError.unknown("Bad certificate DER")
        }
        let add: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: cert,
            kSecAttrLabel as String: certLabel
        ]
        SecItemDelete(add as CFDictionary)
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw PhilipsError.unknown("Certificate store failed (\(status))")
        }
    }

    private static func loadIdentityFromKeychain() throws -> SecIdentity? {
        // Match only OUR identity (by the certificate label), so a stale
        // identity from an earlier build is never picked up.
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: certLabel,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let item else { return nil }
        return (item as! SecIdentity)
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
