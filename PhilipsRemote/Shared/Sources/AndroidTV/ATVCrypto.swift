import Foundation
import Security
import CryptoKit
import Network

/// Certificate + key material for the Android TV Remote TLS connections.
///
/// Generates a persistent self-signed RSA identity (stored in the Keychain and
/// reused across launches), exposes it as a `sec_identity_t` for the `Network`
/// framework, and implements the pairing-secret hash.
public enum ATVCrypto {

    private static let keyTag = "com.europlitka.philipsremote.atv.key".data(using: .utf8)!
    private static let certLabel = "com.europlitka.philipsremote.atv.cert"

    public struct Identity {
        public let secIdentity: SecIdentity
        public let modulus: Data
        public let exponent: Data
    }

    // MARK: - Load or create the client identity

    public static func loadOrCreateIdentity() throws -> Identity {
        let privateKey = try loadOrCreatePrivateKey()
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw PhilipsError.unknown("No public key")
        }
        guard let pubData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?,
              let numbers = DER.parseRSAPublicKey(pubData) else {
            throw PhilipsError.unknown("Can't read public key")
        }

        let identity = try loadIdentityFromKeychain() ?? {
            let certDER = try buildSelfSignedCertificate(privateKey: privateKey, publicKeyPKCS1: pubData)
            try storeCertificate(certDER)
            guard let id = try loadIdentityFromKeychain() else {
                throw PhilipsError.unknown("Identity not found after store")
            }
            return id
        }()

        return Identity(secIdentity: identity, modulus: numbers.modulus, exponent: numbers.exponent)
    }

    /// Bridge a `SecIdentity` into a `Network` framework `sec_identity_t`.
    public static func secIdentity(_ identity: SecIdentity) -> sec_identity_t? {
        sec_identity_create(identity)
    }

    // MARK: - Private key

    private static func loadOrCreatePrivateKey() throws -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let key = item {
            return (key as! SecKey)
        }
        // Create a new permanent key.
        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag
            ]
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attrs as CFDictionary, &error) else {
            throw PhilipsError.unknown("Key generation failed")
        }
        return key
    }

    // MARK: - Certificate persistence / identity lookup

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
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let item else { return nil }
        return (item as! SecIdentity)
    }

    // MARK: - Self-signed certificate builder

    private static func buildSelfSignedCertificate(privateKey: SecKey, publicKeyPKCS1: Data) throws -> Data {
        // OIDs
        let sha256WithRSA = DER.sequence([DER.oid([0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B]), DER.null()])
        let rsaEncryption = DER.sequence([DER.oid([0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01]), DER.null()])
        // CN = "atvremote"  (OID 2.5.4.3)
        let name = DER.sequence([DER.set([DER.sequence([DER.oid([0x55, 0x04, 0x03]), DER.utf8String("atvremote")])])])
        let now = Date().addingTimeInterval(-86_400)
        let far = Date().addingTimeInterval(60 * 60 * 24 * 3650)
        let validity = DER.sequence([DER.utcTime(now), DER.utcTime(far)])
        let spki = DER.sequence([rsaEncryption, DER.bitString(publicKeyPKCS1)])

        let tbs = DER.sequence([
            DER.explicit(0, DER.integer(2)),          // version v3
            DER.integer(Int.random(in: 1...Int.max)), // serial
            sha256WithRSA,
            name,
            validity,
            name,
            spki
        ])

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey, .rsaSignatureMessagePKCS1v15SHA256, tbs as CFData, &error
        ) as Data? else {
            throw PhilipsError.unknown("TBS signing failed")
        }

        return DER.sequence([tbs, sha256WithRSA, DER.bitString(signature)])
    }

    // MARK: - Pairing secret

    /// Extract (modulus, exponent) from a server certificate seen during TLS.
    public static func publicKeyNumbers(from certificate: SecCertificate) -> (modulus: Data, exponent: Data)? {
        guard let key = SecCertificateCopyKey(certificate),
              let data = SecKeyCopyExternalRepresentation(key, nil) as Data? else { return nil }
        return DER.parseRSAPublicKey(data)
    }

    /// Compute the pairing secret and whether the code's checksum byte matches.
    /// `code` is the 6-hex-character code shown on the TV.
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
