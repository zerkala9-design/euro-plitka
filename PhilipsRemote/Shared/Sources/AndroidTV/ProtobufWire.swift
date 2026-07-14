import Foundation

/// A minimal Protocol Buffers wire-format encoder/decoder.
///
/// The Android TV Remote v2 messages are small and use only a handful of field
/// types (varint, length-delimited), so a hand-rolled codec avoids pulling in
/// the full SwiftProtobuf toolchain / `protoc` build step.
///
/// Wire types used: 0 = varint, 2 = length-delimited.
public struct ProtobufWriter {
    public private(set) var data = Data()
    public init() {}

    private mutating func tag(_ field: Int, _ wire: Int) {
        writeVarint(UInt64(field << 3 | wire))
    }

    public mutating func writeVarint(_ value: UInt64) {
        var v = value
        repeat {
            var byte = UInt8(v & 0x7F)
            v >>= 7
            if v != 0 { byte |= 0x80 }
            data.append(byte)
        } while v != 0
    }

    /// field with a varint (int32/int64/bool/enum).
    public mutating func writeInt(_ field: Int, _ value: Int) {
        guard value != 0 else { return }   // proto3 default omitted
        tag(field, 0)
        writeVarint(UInt64(bitPattern: Int64(value)))
    }

    public mutating func writeBool(_ field: Int, _ value: Bool) {
        guard value else { return }
        tag(field, 0)
        writeVarint(1)
    }

    /// field with length-delimited bytes (string/bytes/embedded message).
    public mutating func writeBytes(_ field: Int, _ value: Data) {
        guard !value.isEmpty else { return }
        tag(field, 2)
        writeVarint(UInt64(value.count))
        data.append(value)
    }

    public mutating func writeString(_ field: Int, _ value: String) {
        writeBytes(field, Data(value.utf8))
    }

    /// Embed a nested message built by `body`.
    public mutating func writeMessage(_ field: Int, _ body: (inout ProtobufWriter) -> Void) {
        var nested = ProtobufWriter()
        body(&nested)
        // Nested empty messages still need to be present for some fields; callers
        // that require an explicit empty message should append the tag manually.
        tag(field, 2)
        writeVarint(UInt64(nested.data.count))
        data.append(nested.data)
    }

    /// Prefix the buffer with its varint length (the on-wire framing).
    public func lengthDelimited() -> Data {
        var prefix = ProtobufWriter()
        prefix.writeVarint(UInt64(data.count))
        return prefix.data + data
    }
}

/// A cursor-based reader for the same wire format.
public struct ProtobufReader {
    private let data: Data
    private var index: Int

    public init(_ data: Data) {
        self.data = data
        self.index = data.startIndex
    }

    public var isAtEnd: Bool { index >= data.endIndex }

    public mutating func readVarint() -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while index < data.endIndex {
            let byte = data[index]; index += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
            if shift > 63 { return nil }
        }
        return nil
    }

    /// Returns (fieldNumber, wireType) for the next field, or nil at end.
    public mutating func readTag() -> (field: Int, wire: Int)? {
        guard let key = readVarint() else { return nil }
        return (Int(key >> 3), Int(key & 0x7))
    }

    public mutating func readBytes() -> Data? {
        guard let len = readVarint() else { return nil }
        let end = index + Int(len)
        guard end <= data.endIndex else { return nil }
        let slice = data.subdata(in: index..<end)
        index = end
        return slice
    }

    /// Skip a field of the given wire type (for unknown fields).
    public mutating func skip(wire: Int) {
        switch wire {
        case 0: _ = readVarint()
        case 2: _ = readBytes()
        case 5: index += 4
        case 1: index += 8
        default: break
        }
    }
}

/// Read length-delimited messages from a growing byte stream (TLS gives us
/// arbitrary chunks). Feed bytes in, pull complete framed messages out.
public struct FramedMessageBuffer {
    private var buffer = Data()
    public init() {}

    public mutating func append(_ chunk: Data) { buffer.append(chunk) }

    /// Pull the next complete message (payload without the length prefix), or nil.
    public mutating func next() -> Data? {
        var reader = ProtobufReader(buffer)
        guard let len = reader.readVarint() else { return nil }
        // Compute how many bytes the varint prefix consumed.
        let prefixLen = varintLength(len)
        let total = prefixLen + Int(len)
        guard buffer.count >= total else { return nil }
        let message = buffer.subdata(in: (buffer.startIndex + prefixLen)..<(buffer.startIndex + total))
        buffer.removeSubrange(buffer.startIndex..<(buffer.startIndex + total))
        return message
    }

    private func varintLength(_ value: UInt64) -> Int {
        var v = value, n = 1
        while v >= 0x80 { v >>= 7; n += 1 }
        return n
    }
}
