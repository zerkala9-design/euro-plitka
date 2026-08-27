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

    // v3: a SHARED identity baked into the app, so every phone presents the
    // same client certificate. The TV only trusts one remote certificate, so a
    // shared one lets several phones stay paired at once (it sees them as one
    // remote) instead of each pairing evicting the previous.
    private static let keyTag = "com.europlitka.philipsremote.atv.key.v3".data(using: .utf8)!
    private static let certLabel = "com.europlitka.philipsremote.atv.cert.v3"

    /// Fixed RSA private key shared by every install (PKCS#8 PEM).
    private static let sharedKeyPEM = """
    -----BEGIN PRIVATE KEY-----
    MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC2QZDZoI1sUNNf
    zD5tM0IOSpPzDd5Za02RVQAdCWM9FpeN/fJSelwO2hKIQUzeBprQUa4xrdwhE49M
    yRvWkulHksYxxC36BaEsCv0Vpy+EbWdntbqIk2BlS2g2xnyDsxcTvKxkyjxEMCJp
    FTLgFnSMEnn18TW58gJCkmjVdGpc81c4ueX06dvVM2gcfU1hk81NVCNnk0FTDNYf
    KHS17cUHKRPWqPkl7ZsIA1dEAC7HPhdFn4op4BRctpEqTOSDhvbhmvfVvikBiEYs
    QCvz9UU1QExKpIrsTjHDmimcDtfalOxMxHD2HcT9mjRO1wLfjpCQyK4vZijwRrkh
    EY2Fs16NAgMBAAECggEACzgmtOQ88HcFRrdppwqUaBF6jBLFe5cEaQw6Jo9xDCNQ
    5GJxQVcw8DpyZkWGzYAglZmsRyNJvWuD0xk/h8pMEVDdYdY5clOtuUAFQQj6qYSb
    7KFzldFktLebTGE+7FM2T3Zk3Qt/Vuno+bO0Cba4KUtAi2hJg2R8ySD+0m0JLdGJ
    Eki2hhY4+UB0VkbfHHdIDRmMl0WHBDppOvLWkiGRYWpiklznzp8/cyg1kfoCHo7G
    MLjcaOM2p1TRNhV3cR4u7CZXLqD+F6n8ctBEUCvLu0F+YzNm6KWzn/k0SYeey12g
    AlTGL9TIdoLGz4I3/pgjRqrPh6yGKVqYJku6+DOtTQKBgQDf2LPI/lphYE7EyVM8
    Az/z0q8xTIfjN8cWLXxWMTbDnOhsxja7PAtzM3gELAjTvXtjMe3+caKOX9XGg5od
    1IGAQgkG9qfdUH4tdBRKfg/vHbfBlxK0ujgn7B8A+bLLZCjWDjNh4cP6vWZ9HWH5
    VEg5nxUjkbR2ca06Y/MmKNGr2wKBgQDQb3/f/siQK6jeNRLBTwfx/a8OBCaSWIWk
    MPRBkaE6obTMPnE3PQx5yfKa2Y2MXtb7mha01WPmkxbdCdCb64SgFLEjzo50mYjq
    Xg/N43SE1YaIq0qiAtYp+IKGLyw/CZHXFoTXtUEWVhQzQF4I1jUGSJvGh4YM560M
    t2pXzKYftwKBgQDdG3GjBNODwhysNu0Xp2IhVqeke6LyZuMpXe6mOOCOYkwXPcdM
    NOhed6WCAXkKpezeM7CRF+/o0HMaLl4qPwFYDmJaVYPEkUDBZxqv5kuY9vLOr4pT
    qGnVzV9mmD7qttm7brWEZvwtja5RwZdIL99Tw3ae9sqaAHmK5rWDqOhK5wKBgDlH
    iuKph8Bm3x9BgofxCgPsbSDy7w6kmQVIFre2J5KPQbonJsHBWx5U6wC27Hk4zueR
    rs+/HJcOsOfJfLR8gpPjW9K1Pty4HLIba0hvS2P9sdz5BaeEFAqwql3ptMUWAigT
    nioRO3PB8Actlynig+vYJEbok2QUfq/R7711Fen9AoGBAIG1roaUsz9tag0UhwHg
    QC0kAN2ZO1uyH35wYQLp9/HgJrrSYVJTqaR0ZsaHdK3/QX/s+lmEdyaA4yh6XKba
    vPEJE30doKVkh8hrUVWwQA2aE6NUjEAwWiJMV6yztswX6qD6Ov+5EF4yboZGcOh0
    779K0P1IqfSeMAbXC72TJqGr
    -----END PRIVATE KEY-----
    """

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

        let rsa = try _RSA.Signing.PrivateKey(pemRepresentation: Self.sharedKeyPEM)
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
        // Fixed serial + validity dates so every install produces a byte‑identical
        // certificate (the TV must recognise the same cert from any phone).
        let cert = try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(bytes: [0x2E, 0x75, 0x88, 0x1A, 0x9C, 0x40, 0x3B, 0x12]),
            publicKey: key.publicKey,
            notValidBefore: Date(timeIntervalSince1970: 1_700_000_000),   // 2023-11-14
            notValidAfter: Date(timeIntervalSince1970: 2_650_000_000),    // 2053
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
