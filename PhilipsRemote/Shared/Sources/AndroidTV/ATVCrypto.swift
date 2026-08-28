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
    private static let keyTag = "com.europlitka.philipsremote.atv.key.v4".data(using: .utf8)!
    private static let certLabel = "com.europlitka.philipsremote.atv.cert.v4"

    /// Fixed RSA private key shared by every install (PKCS#1 PEM).
    private static let sharedKeyPEM = """
    -----BEGIN RSA PRIVATE KEY-----
    MIIEowIBAAKCAQEAsA88987tWDtPQEuUPNVN9AvwekfAywZ9328BguLMpADT9dv4
    I+ziC2JWzfddl/HrL7Xm29mSKHeArvFaJ9uwbEsV1o0Blpn5jtS7dm6yAcbURVMQ
    PHemVkft7JUIxit/PqQxiDRw17aWM+9cZ2uF4Udx8FXZJXw5stb75/HQL31B9lCU
    rF9SvDBrPjMZRKH/bBTgfNWWbByVMjhlvb+P9Zf3fZVkpe5/2MXkkPEhyAxFj/Hb
    0Klfcnx1hXkowI7+hqvBxe8nBHvlm+HTtHuARqIQF4EqyqDZZAO9XOwDYpKQMa5L
    ac+mB7Y3uiTsm0CZoD77N6rEnFF9r9uA3jseAQIDAQABAoIBAA52EKDd3pQaJQo9
    MFh8gHoXVqHt+F7vcicy4pR6EBXi2oYt6AMoFIYbsPvF1yp2ohs0Yq7JaiOy8yng
    zwdfQxhrZMhkzc4Cvjig7nf4eNxuqjtlKqbTgMvCqJSU8O2kH4AenlHs1XL71KPA
    mV4GUIQeqUl00mYC6ZNawhdnvvJTgZFo1rpdTUqKzw5PYGXTbao1caSZ4q8WihFT
    u33Kk0/tX2HF4CzzoReUFFtJ109ASlUJNO6kXAUHZ6VhBHYkLUfTdy2MWGeKVLOF
    wpIcu5ZOAk+b85HdcEIzwyxBFn4rDuRfjuyOR0oEf0FjT3GOLPxZ636T8W4kvllr
    s3a6CxUCgYEA3CEBuxlJT/cT3RFeZltTlfaALrtOsx1PL1pHh5Uqle54hbO1aXr5
    8jsphdbNZtSlYJ3WWbpQJpOSdIU7Njpa/u+64jY+qSbHOssTZHGti93dihYLkVvn
    ftK2/wjAaWAW7Qz2s0uA9xnLY5lXk+T0qeCkR3bPuzniqyVfnsQIRcUCgYEAzL/Q
    IBpXxRrLpDU4R62MTplp0kdHJBClvH9jdaf8fXg3C6V5X2vAkWkJeK/x9z1vPpLx
    /S2oN67lyW8ETgHa462Gw03g0bKRnlvf/5Cjz26wFaXqrLamElvAEtsDEV42fMfT
    d8pcVuFnfyFpzJj48df3MNm8CpjXTdzaaDLtdw0CgYBBvUm7Co4uZ2dzOeCrSNLp
    kjgtvJqAO1yOk7OQ9idFp3Yu18Bxw9wpTynTYpbtAsxw0jJVkaKmIqQ2UCOiykKq
    qAVz0SdddMtC76rW8GwXvSaQOo0x1/SGl383IvHzhlLScHCskvvsz7NCB2V0MYgv
    w3rMLNtU2rCq0/p+e6TM0QKBgQC/kkzibKNoqYyWJLF251ubAxGvDL/0b5sSxkJC
    CJ5Gqx8dx4LLlB8GLrgM8tq7kQCwFH9Ues6k4wDfOv9VGYk7c9XekNRkf+adu6rX
    DPcoE5Gvf6EWXoL+NFh/i+nP602h7LngoDdLlvTmT1YVd5+dcIs5as/1PlJc6OJ1
    kgj7VQKBgBeDXitU+zB2oK9Xhd17/7JMAKo+JK/fMNTHZFyxrqRAjI9MOr1/zxG/
    FZxdM5ODZyfPLaJGNDxIn9LD+SHVfwPCnYPk8J77QM7+u4HOBoEtfLjWPPA8O1M0
    UmFjSh5QsOdaB3LhU8PEGSGcqbkrYCWosnHskh4/fH2ipa0OZZmG
    -----END RSA PRIVATE KEY-----
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
        try importPrivateKey(pkcs1DER: Self.sharedKeyPKCS1DER())
        try storeCertificate(certDER)

        guard let identity = try loadIdentityFromKeychain() else {
            throw PhilipsError.unknown("Identity failed: no identity in keychain")
        }
        guard let cert = copyCertificate(from: identity) else {
            throw PhilipsError.unknown("Identity failed: no cert in identity")
        }
        guard let numbers = publicKeyNumbers(from: cert) else {
            throw PhilipsError.unknown("Identity failed: no public key numbers")
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

    /// The shared key's raw PKCS#1 DER (exactly what SecKeyCreateWithData wants
    /// for an RSA private key), decoded straight from the embedded PEM.
    private static func sharedKeyPKCS1DER() -> Data {
        let base64 = sharedKeyPEM
            .replacingOccurrences(of: "-----BEGIN RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END RSA PRIVATE KEY-----", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        return Data(base64Encoded: base64) ?? Data()
    }

    private static func importPrivateKey(pkcs1DER: Data) throws {
        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 2048
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(pkcs1DER as CFData, attrs as CFDictionary, &error) else {
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
