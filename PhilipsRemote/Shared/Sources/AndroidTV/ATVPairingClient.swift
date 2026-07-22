import Foundation
import Security

/// Performs the Android TV Remote v2 pairing handshake on port 6466.
///
/// Usage:
///   let client = ATVPairingClient(host: ip)
///   try await client.begin()          // TV shows a 6-hex code
///   try await client.confirm(code:)   // completes pairing
public actor ATVPairingClient {

    private let host: String
    private let deviceName: String
    private var connection: ATVConnection?
    private var iterator: AsyncStream<Data>.Iterator?
    private var identity: ATVCrypto.Identity?
    private var serverModulus = Data()
    private var serverExponent = Data()

    public init(host: String, deviceName: String = "iPhone") {
        self.host = host
        self.deviceName = deviceName
    }

    // Fields
    private enum Field {
        static let protocolVersion = 1
        static let status = 2
        static let pairingRequest = 10
        static let pairingOption = 20
        static let pairingConfiguration = 30
        static let pairingSecret = 40
    }
    private static let statusOK = 200
    private static let encodingHex = 3
    private static let symbolLength = 6
    private static let roleInput = 1

    public func begin() async throws {
        let id = try ATVCrypto.loadOrCreateIdentity()
        identity = id
        guard let secIdentity = ATVCrypto.secIdentity(id.secIdentity) else {
            throw PhilipsError.unknown("No TLS identity")
        }
        let conn = ATVConnection(host: host, port: 6467, identity: secIdentity)
        try await conn.start()
        connection = conn
        iterator = conn.messages.makeAsyncIterator()

        // Capture the TV's public key from its certificate.
        if let cert = conn.serverCertificate,
           let numbers = ATVCrypto.publicKeyNumbers(from: cert) {
            serverModulus = numbers.modulus
            serverExponent = numbers.exponent
        } else {
            throw PhilipsError.unknown("No server certificate")
        }
        try send { m in
            base(&m)
            m.writeMessage(Field.pairingRequest) { r in
                r.writeString(1, "androidtvremote")
                r.writeString(2, deviceName)     // client name shown/stored by the TV
            }
        }
        try await expectOK()

        try send { m in
            base(&m)
            m.writeMessage(Field.pairingOption) { o in
                o.writeMessage(1) { e in           // input_encodings[0]
                    e.writeInt(1, Self.encodingHex)
                    e.writeInt(2, Self.symbolLength)
                }
                o.writeInt(3, Self.roleInput)      // preferred_role
            }
        }
        try await expectOK()

        try send { m in
            base(&m)
            m.writeMessage(Field.pairingConfiguration) { c in
                c.writeMessage(1) { e in           // encoding
                    e.writeInt(1, Self.encodingHex)
                    e.writeInt(2, Self.symbolLength)
                }
                c.writeInt(2, Self.roleInput)      // client_role
            }
        }
        try await expectOK()   // TV now displays the code
    }

    public func confirm(code: String) async throws {
        guard let id = identity else { throw PhilipsError.notPaired }
        guard let result = ATVCrypto.pairingSecret(
            clientModulus: id.modulus, clientExponent: id.exponent,
            serverModulus: serverModulus, serverExponent: serverExponent,
            code: code
        ) else { throw PhilipsError.invalidPin }
        guard result.matches else { throw PhilipsError.invalidPin }

        try send { m in
            base(&m)
            m.writeMessage(Field.pairingSecret) { s in
                s.writeBytes(1, result.secret)
            }
        }
        try await expectOK()
        connection?.close()
    }

    public func cancel() {
        connection?.close()
    }

    // MARK: - Helpers

    private func base(_ m: inout ProtobufWriter) {
        m.writeInt(Field.protocolVersion, 2)
        m.writeInt(Field.status, Self.statusOK)
    }

    private func send(_ build: (inout ProtobufWriter) -> Void) throws {
        guard let connection else { throw PhilipsError.tvOffline }
        var writer = ProtobufWriter()
        build(&writer)
        connection.send(writer.lengthDelimited())
    }

    private func nextMessage() async throws -> Data {
        guard iterator != nil else { throw PhilipsError.tvOffline }
        var it = iterator!
        let msg = await it.next()
        iterator = it
        guard let message = msg else { throw PhilipsError.tvOffline }
        return message
    }

    /// Read the next message and verify its status is OK.
    private func expectOK() async throws {
        let data = try await nextMessage()
        var reader = ProtobufReader(data)
        var status = Self.statusOK
        while let tag = reader.readTag() {
            if tag.field == Field.status, tag.wire == 0 {
                status = Int(reader.readVarint() ?? 0)
            } else {
                reader.skip(wire: tag.wire)
            }
        }
        if status != Self.statusOK && status != 0 {
            throw PhilipsError.pairingRejected
        }
    }
}
