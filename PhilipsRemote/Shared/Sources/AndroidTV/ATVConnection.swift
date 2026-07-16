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
        sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)

        var captured: SecCertificate?
        sec_protocol_options_set_verify_block(
            tls.securityProtocolOptions,
            { _, trust, complete in
                let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()
                if let chain = SecTrustCopyCertificateChain(secTrust) as? [SecCertificate],
                   let leaf = chain.first {
                    captured = leaf
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
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.serverCertificate = self?._capturedRef()
                    cont.resume()
                    self?.receiveLoop()
                case .failed(let error):
                    cont.resume(throwing: PhilipsError.unknown("TLS failed: \(error.localizedDescription)"))
                case .cancelled:
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
                self.buffer.append(data)
                while let message = self.buffer.next() {
                    self.messageContinuation?.yield(message)
                }
            }
            if isComplete || error != nil {
                self.messageContinuation?.finish()
                return
            }
            self.receiveLoop()
        }
    }

    /// Send an already length-prefixed message.
    public func send(_ framed: Data) {
        connection.send(content: framed, completion: .contentProcessed { _ in })
    }

    public func close() {
        connection.cancel()
        messageContinuation?.finish()
    }
}
