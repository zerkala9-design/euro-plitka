import Foundation

/// Maintains the Android TV Remote v2 control channel (port 6467) and sends key
/// events. Echoes the configure handshake and answers keep-alive pings so the
/// TV keeps the session open.
public actor ATVRemoteClient {

    private let host: String
    private var connection: ATVConnection?
    private var readerTask: Task<Void, Never>?
    public private(set) var isReady = false

    public init(host: String) { self.host = host }

    private enum Field {
        static let configure = 1
        static let setActive = 2
        static let pingRequest = 8
        static let pingResponse = 9
        static let keyInject = 10
        static let appLink = 90
    }

    public func connect() async throws {
        let id = try ATVCrypto.loadOrCreateIdentity()
        guard let secIdentity = ATVCrypto.secIdentity(id.secIdentity) else {
            throw PhilipsError.unknown("No TLS identity")
        }
        let conn = ATVConnection(host: host, port: 6466, identity: secIdentity)
        try await conn.start()
        connection = conn

        readerTask = Task { [weak self] in
            guard let self, let messages = await self.connection?.messages else { return }
            for await message in messages {
                await self.handle(message)
            }
            await self.markNotReady()
        }
    }

    private func markNotReady() { isReady = false }

    private func handle(_ data: Data) async {
        var reader = ProtobufReader(data)
        while let tag = reader.readTag() {
            switch tag.field {
            case Field.configure where tag.wire == 2:
                _ = reader.readBytes()
                sendConfigureReply()
                sendSetActive()
                isReady = true
            case Field.pingRequest where tag.wire == 2:
                let body = reader.readBytes() ?? Data()
                let val1 = firstVarint(inField: 1, of: body) ?? 1
                sendPingResponse(val1: Int(val1))
            case Field.setActive where tag.wire == 2:
                _ = reader.readBytes()
                isReady = true
            default:
                reader.skip(wire: tag.wire)
            }
        }
    }

    // MARK: - Outgoing

    public func sendKey(_ code: ATVKeyCode) {
        guard let connection else { return }
        var m = ProtobufWriter()
        m.writeMessage(Field.keyInject) { k in
            k.writeInt(1, 3)                 // direction = SHORT
            k.writeInt(2, code.rawValue)     // key_code
        }
        connection.send(m.lengthDelimited())
    }

    public func launchApp(uri: String) {
        guard let connection else { return }
        var m = ProtobufWriter()
        m.writeMessage(Field.appLink) { a in
            a.writeString(1, uri)
        }
        connection.send(m.lengthDelimited())
    }

    private func sendConfigureReply() {
        guard let connection else { return }
        var m = ProtobufWriter()
        m.writeMessage(Field.configure) { c in
            c.writeInt(1, 622)               // code1
            c.writeMessage(2) { d in         // device_info
                d.writeString(1, "iPhone")   // model
                d.writeString(2, "Apple")    // vendor
                d.writeInt(3, 1)             // unknown1
                d.writeString(4, "1")        // unknown2
                d.writeString(5, "com.europlitka.philipsremote")
                d.writeString(6, "1.0")      // app_version
            }
        }
        connection.send(m.lengthDelimited())
    }

    private func sendSetActive() {
        guard let connection else { return }
        var m = ProtobufWriter()
        m.writeMessage(Field.setActive) { s in
            s.writeInt(1, 622)
        }
        connection.send(m.lengthDelimited())
    }

    private func sendPingResponse(val1: Int) {
        guard let connection else { return }
        var m = ProtobufWriter()
        m.writeMessage(Field.pingResponse) { p in
            p.writeInt(1, val1)
        }
        connection.send(m.lengthDelimited())
    }

    private func firstVarint(inField field: Int, of data: Data) -> UInt64? {
        var reader = ProtobufReader(data)
        while let tag = reader.readTag() {
            if tag.field == field, tag.wire == 0 { return reader.readVarint() }
            reader.skip(wire: tag.wire)
        }
        return nil
    }

    public func disconnect() {
        readerTask?.cancel()
        connection?.close()
        isReady = false
    }
}
