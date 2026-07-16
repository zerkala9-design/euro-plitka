import Foundation

/// Tiny DER (ASN.1) encoder + a minimal reader, just enough to hand-build a
/// self-signed X.509 certificate and to parse an RSA public key
/// (`SEQUENCE { modulus INTEGER, exponent INTEGER }`).
enum DER {

    // MARK: - Encoding

    static func length(_ n: Int) -> Data {
        if n < 0x80 { return Data([UInt8(n)]) }
        var bytes: [UInt8] = []
        var v = n
        while v > 0 { bytes.insert(UInt8(v & 0xFF), at: 0); v >>= 8 }
        return Data([0x80 | UInt8(bytes.count)] + bytes)
    }

    static func tlv(_ tag: UInt8, _ value: Data) -> Data {
        Data([tag]) + length(value.count) + value
    }

    static func sequence(_ items: [Data]) -> Data {
        tlv(0x30, items.reduce(Data(), +))
    }

    static func set(_ items: [Data]) -> Data {
        tlv(0x31, items.reduce(Data(), +))
    }

    /// INTEGER from an unsigned big-endian magnitude (adds a leading 0x00 if the
    /// high bit is set so it stays positive).
    static func integer(_ magnitude: Data) -> Data {
        var m = Array(magnitude)
        while m.count > 1 && m.first == 0 { m.removeFirst() }
        if let first = m.first, first & 0x80 != 0 { m.insert(0, at: 0) }
        return tlv(0x02, Data(m))
    }

    static func integer(_ value: Int) -> Data {
        var v = value
        var bytes: [UInt8] = []
        repeat { bytes.insert(UInt8(v & 0xFF), at: 0); v >>= 8 } while v != 0
        if let first = bytes.first, first & 0x80 != 0 { bytes.insert(0, at: 0) }
        return tlv(0x02, Data(bytes))
    }

    static func bitString(_ value: Data) -> Data {
        tlv(0x03, Data([0x00]) + value)   // 0 unused bits
    }

    static func octetString(_ value: Data) -> Data { tlv(0x04, value) }
    static func oid(_ bytes: [UInt8]) -> Data { tlv(0x06, Data(bytes)) }
    static func null() -> Data { Data([0x05, 0x00]) }
    static func utf8String(_ s: String) -> Data { tlv(0x0C, Data(s.utf8)) }
    static func utcTime(_ date: Date) -> Data {
        let f = DateFormatter()
        f.dateFormat = "yyMMddHHmmss'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return tlv(0x17, Data(f.string(from: date).utf8))
    }
    static func explicit(_ tag: UInt8, _ value: Data) -> Data {
        tlv(0xA0 | tag, value)
    }

    // MARK: - Minimal reader (for RSAPublicKey)

    /// Parse `SEQUENCE { INTEGER modulus, INTEGER exponent }` from PKCS#1 DER,
    /// returning the raw unsigned magnitudes (leading 0x00 stripped).
    static func parseRSAPublicKey(_ der: Data) -> (modulus: Data, exponent: Data)? {
        var cursor = Cursor(der)
        guard let seq = cursor.readTLV(), seq.tag == 0x30 else { return nil }
        var inner = Cursor(seq.value)
        guard let mod = inner.readTLV(), mod.tag == 0x02,
              let exp = inner.readTLV(), exp.tag == 0x02 else { return nil }
        return (strip(mod.value), strip(exp.value))
    }

    private static func strip(_ data: Data) -> Data {
        var v = data
        while v.count > 1 && v.first == 0 { v.removeFirst() }
        return v
    }

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
}
