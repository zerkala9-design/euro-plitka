import Foundation

/// Maintains the Android TV Remote v2 control channel (port 6467) and sends key
/// events. Echoes the configure handshake and answers keep-alive pings so the
/// TV keeps the session open.
public actor ATVRemoteClient {

    private let host: String
    private var connection: ATVConnection?
    private var readerTask: Task<Void, Never>?
    public private(set) var isReady = false

    /// Set to `true` when we tear the connection down on purpose, so the
    /// unexpected‑drop callback doesn't fire and trigger a reconnect.
    private var intentionalClose = false
    /// Fired when the control channel ends unexpectedly (TV/iOS dropped it).
    private var onClose: (@Sendable () -> Void)?
    /// Fired when the TV reports a focused text field (so the phone can offer
    /// its keyboard).
    private var onTextFocus: (@Sendable () -> Void)?

    public init(host: String) { self.host = host }

    /// Register a handler invoked once if the connection drops on its own.
    public func setOnClose(_ handler: @escaping @Sendable () -> Void) {
        onClose = handler
    }

    /// Register a handler invoked when the TV focuses a text field.
    public func setOnTextFocus(_ handler: @escaping @Sendable () -> Void) {
        onTextFocus = handler
    }

    private enum Field {
        static let configure = 1
        static let setActive = 2
        static let pingRequest = 8
        static let pingResponse = 9
        static let keyInject = 10
        static let imeKeyInject = 20
        static let imeBatchEdit = 21
        static let appLink = 90
    }

    // Latest text‑field identifiers reported by the TV. Needed to address a
    // focused text field when injecting text via a batch edit.
    private var imeCounter: Int?
    private var fieldCounter: Int?

    public func connect() async throws {
        intentionalClose = false
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
            await self.connectionDidEnd()
        }
    }

    /// The message stream finished — the socket is gone. Notify the owner so it
    /// can reconnect (unless we closed it ourselves).
    private func connectionDidEnd() {
        isReady = false
        if !intentionalClose { onClose?() }
    }

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
            case Field.imeKeyInject where tag.wire == 2:
                // TV focused a text field — remember how to address it.
                parseImeKeyInject(reader.readBytes() ?? Data())
            case Field.imeBatchEdit where tag.wire == 2:
                parseImeCounters(fromBatchEdit: reader.readBytes() ?? Data())
            default:
                reader.skip(wire: tag.wire)
            }
        }
    }

    /// RemoteImeKeyInject { app_info(1){ counter(1) }, text_field_status(2){ counter_field(1) } }
    private func parseImeKeyInject(_ data: Data) {
        var reader = ProtobufReader(data)
        while let tag = reader.readTag() {
            switch tag.field {
            case 1 where tag.wire == 2:   // app_info
                let appInfo = reader.readBytes() ?? Data()
                if let c = firstVarint(inField: 1, of: appInfo) { imeCounter = Int(c) }
            case 2 where tag.wire == 2:   // text_field_status
                let status = reader.readBytes() ?? Data()
                if let f = firstVarint(inField: 1, of: status) { fieldCounter = Int(f) }
            default:
                reader.skip(wire: tag.wire)
            }
        }
        // A text field is focused and addressable — let the phone offer typing.
        if imeCounter != nil, fieldCounter != nil { onTextFocus?() }
    }

    /// RemoteImeBatchEdit { ime_counter(1), field_counter(2), ... }
    private func parseImeCounters(fromBatchEdit data: Data) {
        var reader = ProtobufReader(data)
        while let tag = reader.readTag() {
            switch tag.field {
            case 1 where tag.wire == 0: imeCounter = Int(reader.readVarint() ?? 0)
            case 2 where tag.wire == 0: fieldCounter = Int(reader.readVarint() ?? 0)
            default: reader.skip(wire: tag.wire)
            }
        }
    }

    // MARK: - Outgoing

    public func sendKey(_ code: ATVKeyCode) {
        // A tap = key down (direction 1) then key up (direction 2).
        sendKeyEvent(code.rawValue, direction: 1)
        sendKeyEvent(code.rawValue, direction: 2)
    }

    /// Press and hold a key (key down only) — like holding a button on a
    /// physical remote. The TV generates its own native auto‑repeat until
    /// `releaseKey` sends the matching key up.
    public func pressKey(_ code: ATVKeyCode) {
        sendKeyEvent(code.rawValue, direction: 1)
    }

    /// Release a key previously held with `pressKey`.
    public func releaseKey(_ code: ATVKeyCode) {
        sendKeyEvent(code.rawValue, direction: 2)
    }

    private func sendKeyEvent(_ code: Int, direction: Int) {
        guard let connection else { return }
        var m = ProtobufWriter()
        m.writeMessage(Field.keyInject) { k in
            k.writeInt(1, code)          // key_code (field 1)
            k.writeInt(2, direction)     // direction (field 2): 1=down, 2=up
        }
        connection.send(m.lengthDelimited())
    }

    /// True once the TV has told us about a focused text field, so `sendText`
    /// has somewhere to write.
    public var canSendText: Bool { imeCounter != nil && fieldCounter != nil }

    /// Set the contents of the TV's currently focused text field. Requires the
    /// TV to have reported a focused field (see `canSendText`).
    public func sendText(_ text: String) {
        guard let connection, let ic = imeCounter, let fc = fieldCounter else { return }
        let cursor = max(0, text.utf16.count - 1)
        var m = ProtobufWriter()
        m.writeMessage(Field.imeBatchEdit) { b in        // RemoteImeBatchEdit
            b.writeInt(1, ic)                            // ime_counter
            b.writeInt(2, fc)                            // field_counter
            b.writeMessage(3) { e in                     // edit_info[0] (RemoteEditInfo)
                e.writeInt(1, 1)                         // insert
                e.writeMessage(2) { o in                 // text_field_status (RemoteImeObject)
                    o.writeInt(1, cursor)                // start
                    o.writeInt(2, cursor)                // end
                    o.writeString(3, text)               // value
                }
            }
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
        intentionalClose = true
        readerTask?.cancel()
        connection?.close()
        isReady = false
    }
}
