import Foundation
import Network

/// Sends a Wake‑on‑LAN "magic packet" to power on a sleeping TV.
///
/// The magic packet is 6× `0xFF` followed by the target MAC repeated 16 times,
/// broadcast to UDP port 9 on the local subnet.
public actor WakeOnLANService {

    public init() {}

    public func wake(macAddress: String, broadcastPort: UInt16 = 9) async throws {
        guard let packet = Self.magicPacket(for: macAddress) else {
            throw PhilipsError.wakeOnLanUnavailable
        }
        try await send(packet, port: broadcastPort)
        await AppLog.shared.info("Sent Wake‑on‑LAN packet to \(macAddress)", category: "wol")
    }

    private func send(_ data: Data, port: UInt16) async throws {
        let endpoint = NWEndpoint.hostPort(
            host: .init("255.255.255.255"),
            port: .init(rawValue: port)!
        )
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        if let ip = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }
        let connection = NWConnection(to: endpoint, using: params)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: data, completion: .contentProcessed { error in
                        if let error {
                            cont.resume(throwing: PhilipsError.unknown(error.localizedDescription))
                        } else {
                            cont.resume()
                        }
                        connection.cancel()
                    })
                case .failed(let error):
                    cont.resume(throwing: PhilipsError.unknown(error.localizedDescription))
                    connection.cancel()
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }
    }

    /// Build the 102‑byte magic packet, or nil for a malformed MAC.
    static func magicPacket(for macAddress: String) -> Data? {
        let cleaned = macAddress.replacingOccurrences(of: "-", with: ":")
        let bytes = cleaned.split(separator: ":").compactMap { UInt8($0, radix: 16) }
        guard bytes.count == 6 else { return nil }
        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet.append(contentsOf: bytes) }
        return packet
    }
}
