import Foundation
import Network
import Security

/// A TLS connection to an Android TV service (pairing :6466 or remote :6467),
/// presenting our client identity and accepting the TV's self-signed cert.
///
/// Frames outgoing/incoming messages with the protocol's varint length prefix.
public final class ATVConnection: @unchecked Sendable {

    private let connection: NWConnection
    private let queue = DispatchQueue(label: "atv.connection")
    private var buffer = FramedMessageBuffer()
    private var messageContinuation: AsyncStream<Data>.Continuation?
    public let messages: AsyncStream<Data>

    /// The TV's leaf certificate captured during the TLS handshake.
    public private(set) var serverCertificate: SecCertificate?

    public init(host: String, port: UInt16, identity: sec_identity_t) {
        let tls = NWProtocolTLS.Options()
        sec_protocol_options_set_local_identity(tls.securityProtocolOptions, identity)
        // Force TLS 1.2: the client certificate is validated during the
        // handshake (not post-handshake as in 1.3), which the TV accepts.
        sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
        sec_protocol_options_set_max_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)

        var captured: SecCertificate?
        sec_protocol_options_set_verify_block(
            tls.securityProtocolOptions,
            { _, trust, complete in
                print("ATV: verify block called — accepting TV server cert")
                let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()
                if let chain = SecTrustCopyCertificateChain(secTrust) as? [SecCertificate],
                   let leaf = chain.first {
                    captured = leaf
                    print("ATV: captured TV cert")
                }
                complete(true)   // accept the TV's self-signed certificate
            },
            queue
        )

        let params = NWParameters(tls: tls)
        self.connection = NWConnection(
            host: .init(host),
            port: .init(rawValue: port)!,
            using: params
        )

        var cont: AsyncStream<Data>.Continuation!
        self.messages = AsyncStream { cont = $0 }
        self.messageContinuation = cont
        self._capturedRef = { captured }
    }

    private let _capturedRef: () -> SecCertificate?

    public func start() async throws {
        var didResume = false
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { [weak self] state in
                print("ATV: connection state = \(state)")
                switch state {
                case .ready:
                    self?.serverCertificate = self?._capturedRef()
                    print("ATV: TLS ready, serverCert=\(self?.serverCertificate != nil)")
                    if !didResume { didResume = true; cont.resume() }
                    self?.receiveLoop()
                case .failed(let error):
                    print("ATV: connection FAILED: \(error)")
                    if !didResume {
                        didResume = true
                        cont.resume(throwing: PhilipsError.unknown("TLS failed: \(error.localizedDescription)"))
                    }
                    self?.messageContinuation?.finish()
                case .cancelled:
                    print("ATV: connection cancelled")
                    if !didResume { didResume = true; cont.resume(throwing: PhilipsError.tvOffline) }
                    self?.messageContinuation?.finish()
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    private func receiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                print("ATV: received \(data.count) bytes")
                self.buffer.append(data)
                while let message = self.buffer.next() {
                    print("ATV: framed message \(message.count) bytes")
                    self.messageContinuation?.yield(message)
                }
            }
            if let error { print("ATV: receive error \(error)") }
            if isComplete || error != nil {
                self.messageContinuation?.finish()
                return
            }
            self.receiveLoop()
        }
    }

    /// Send an already length-prefixed message.
    public func send(_ framed: Data) {
        print("ATV: sending \(framed.count) bytes: \(framed.map { String(format: "%02x", $0) }.joined())")
        connection.send(content: framed, completion: .contentProcessed { error in
            if let error { print("ATV: send error \(error)") }
        })
    }

    public func close() {
        connection.cancel()
        messageContinuation?.finish()
    }
}
