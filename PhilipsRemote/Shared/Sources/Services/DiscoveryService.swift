import Foundation
import Network

/// Discovers Philips TVs on the local network.
///
/// Two complementary strategies are used:
/// 1. **Bonjour** — browse `_philips-remote._tcp`, `_airplay._tcp` and
///    `_http._tcp` via `NWBrowser` and resolve candidate hosts.
/// 2. **Active probe** — verify each candidate is a Philips TV by requesting
///    the JointSpace `/6/system` endpoint, which also yields the model, API
///    version and capabilities for the discovery card.
public actor DiscoveryService {

    private var browsers: [NWBrowser] = []
    private var seenHosts: Set<String> = []

    public init() {}

    /// Stream of discovered & verified Philips TVs. The stream keeps emitting as
    /// devices appear; cancel the enclosing task to stop browsing.
    public func discover() -> AsyncStream<TVDevice> {
        AsyncStream { continuation in
            let serviceTypes = ["_philips-remote._tcp", "_airplay._tcp", "_http._tcp"]

            let handleEndpoint: @Sendable (String, String?) -> Void = { host, name in
                Task {
                    if await self.markSeen(host) { return }
                    if let device = try? await self.probe(host: host, advertisedName: name) {
                        continuation.yield(device)
                    }
                }
            }

            for type in serviceTypes {
                let params = NWParameters()
                params.includePeerToPeer = true
                let browser = NWBrowser(for: .bonjour(type: type, domain: nil), using: params)
                browser.browseResultsChangedHandler = { results, _ in
                    for result in results {
                        if case let .service(name, _, _, _) = result.endpoint {
                            self.resolve(result.endpoint) { host in
                                if let host { handleEndpoint(host, name) }
                            }
                        }
                    }
                }
                browser.stateUpdateHandler = { state in
                    if case .failed = state { continuation.finish() }
                }
                browser.start(queue: .global(qos: .userInitiated))
                Task { await self.retain(browser) }
            }

            continuation.onTermination = { _ in
                Task { await self.stop() }
            }
        }
    }

    // Bookkeeping helpers isolated to the actor.
    private func retain(_ browser: NWBrowser) { browsers.append(browser) }
    /// Returns true if the host was already seen (and records it otherwise).
    private func markSeen(_ host: String) -> Bool {
        if seenHosts.contains(host) { return true }
        seenHosts.insert(host)
        return false
    }
    public func resetSeen() { seenHosts.removeAll() }

    public func stop() {
        browsers.forEach { $0.cancel() }
        browsers.removeAll()
    }

    /// Resolve a Bonjour endpoint to an IPv4 host string.
    private nonisolated func resolve(_ endpoint: NWEndpoint, completion: @escaping @Sendable (String?) -> Void) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                if let path = connection.currentPath, let remote = path.remoteEndpoint,
                   case let .hostPort(host, _) = remote {
                    completion(Self.hostString(host))
                } else {
                    completion(nil)
                }
                connection.cancel()
            case .failed, .cancelled:
                completion(nil)
            default:
                break
            }
        }
        connection.start(queue: .global())
    }

    private nonisolated static func hostString(_ host: NWEndpoint.Host) -> String? {
        switch host {
        case .ipv4(let addr):
            return addr.rawValue.map { String($0) }.joined(separator: ".")
        case .name(let name, _):
            return name
        default:
            return nil
        }
    }

    /// Probe a candidate host's JointSpace endpoint and build a `TVDevice`.
    public func probe(host: String, advertisedName: String? = nil, port: Int = 1926) async throws -> TVDevice {
        let transport = HTTPTransport(allowedHosts: [host], timeout: 3)
        let url = URL(string: "https://\(host):\(port)/6/system")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let response = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw PhilipsError.invalidResponse(status: response.statusCode)
        }
        let system = try JSONDecoder().decode(SystemResponse.self, from: response.data)
        // Only treat responses that look like a Philips TV as a match.
        let model = system.model ?? "Philips TV"
        var device = TVDevice(
            name: advertisedName ?? system.name ?? model,
            model: model,
            friendlyName: system.name,
            host: host,
            port: port,
            apiVersion: system.api_version?.Major ?? 6
        )
        device.capabilities = CapabilityDetector.detect(from: system)
        device.systemInfo = CapabilityDetector.systemInfo(from: system, host: host)
        await AppLog.shared.info("Discovered \(model) at \(host)", category: "discovery")
        return device
    }
}
