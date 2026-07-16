import Foundation

/// A minimal DER (ASN.1) reader used to pull the RSA modulus/exponent out of a
/// public key and to unwrap a PKCS#8 private key into PKCS#1. Certificate
/// *building* is handled by swift‑certificates, so no encoder is needed here.
enum ASN1 {

    /// A tiny DER TLV cursor.
    struct Cursor {
        let data: Data
        var i: Data.Index
        init(_ data: Data) { self.data = data; self.i = data.startIndex }

        mutating func readTLV() -> (tag: UInt8, value: Data)? {
            guard i < data.endIndex else { return nil }
            let tag = data[i]; i = data.index(after: i)
            guard i < data.endIndex else { return nil }
            var len = Int(data[i]); i = data.index(after: i)
            if len & 0x80 != 0 {
                let count = len & 0x7F
                len = 0
                for _ in 0..<count {
                    guard i < data.endIndex else { return nil }
                    len = (len << 8) | Int(data[i]); i = data.index(after: i)
                }
            }
            guard let end = data.index(i, offsetBy: len, limitedBy: data.endIndex) else { return nil }
            let value = data.subdata(in: i..<end)
            i = end
            return (tag, value)
        }
    }

    private static func strip(_ data: Data) -> Data {
        var v = data
        while v.count > 1 && v.first == 0 { v.removeFirst() }
        return v
    }

    /// Parse `SEQUENCE { INTEGER modulus, INTEGER exponent }` (PKCS#1 public key).
    static func parseRSAPublicKey(_ der: Data) -> (modulus: Data, exponent: Data)? {
        var cursor = Cursor(der)
        guard let seq = cursor.readTLV(), seq.tag == 0x30 else { return nil }
        var inner = Cursor(seq.value)
        guard let mod = inner.readTLV(), mod.tag == 0x02,
              let exp = inner.readTLV(), exp.tag == 0x02 else { return nil }
        return (strip(mod.value), strip(exp.value))
    }

    /// Return the PKCS#1 `RSAPrivateKey` DER from either a raw PKCS#1 blob or a
    /// PKCS#8 `PrivateKeyInfo` wrapper.
    static func pkcs1PrivateKey(from der: Data) -> Data {
        var cursor = Cursor(der)
        guard let seq = cursor.readTLV(), seq.tag == 0x30 else { return der }
        var inner = Cursor(seq.value)
        guard let version = inner.readTLV(), version.tag == 0x02 else { return der }
        // Peek the next element: SEQUENCE => PKCS#8, INTEGER => already PKCS#1.
        guard let next = inner.readTLV() else { return der }
        if next.tag == 0x02 {
            return der                      // already PKCS#1 RSAPrivateKey
        }
        if next.tag == 0x30 {               // AlgorithmIdentifier → next is OCTET STRING
            guard let octet = inner.readTLV(), octet.tag == 0x04 else { return der }
            return octet.value              // the wrapped PKCS#1 key
        }
        return der
    }
}
