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
    private var continuation: AsyncStream<TVDevice>.Continuation?

    public init() {}

    private func store(_ continuation: AsyncStream<TVDevice>.Continuation) {
        self.continuation = continuation
    }

    /// Stream of discovered & verified Philips TVs. The stream keeps emitting as
    /// devices appear; cancel the enclosing task to stop browsing.
    public func discover() -> AsyncStream<TVDevice> {
        AsyncStream { continuation in
            Task { await self.store(continuation) }
            // Android TV Remote v2 advertises this Bonjour service.
            let serviceTypes = ["_androidtvremote2._tcp", "_androidtvremote._tcp"]

            let handleEndpoint: @Sendable (String, String?) -> Void = { host, name in
                Task {
                    if await self.markSeen(host) { return }
                    continuation.yield(DiscoveryService.androidDevice(host: host, name: name))
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

    /// Build an Android TV device record (pairing/remote use ports 6466/6467).
    public nonisolated static func androidDevice(host: String, name: String?) -> TVDevice {
        var device = TVDevice(name: name ?? "Android TV", model: "Android TV", host: host, port: 6466)
        device.capabilities = TVCapabilities(
            platform: .androidTV,
            supportsWakeOnLan: true,
            supportsApps: true,
            supportsInputText: true
        )
        return device
    }

    public func stop() {
        browsers.forEach { $0.cancel() }
        browsers.removeAll()
        continuation?.finish()
        continuation = nil
    }

    // MARK: - Subnet scan (fallback when mDNS is blocked)

    /// Scan the phone's local /24 subnet for a host with the Android TV remote
    /// port open, returning the first match. Works even when the router blocks
    /// mDNS/Bonjour. Scans in small batches to avoid exhausting sockets.
    public func scanForTV(port: UInt16 = 6466, timeout: TimeInterval = 1.2) async -> String? {
        guard let prefix = Self.subnetPrefix() else { return nil }
        for batchStart in stride(from: 1, through: 254, by: 40) {
            let batchEnd = min(batchStart + 39, 254)
            let found = await withTaskGroup(of: String?.self) { group -> String? in
                for i in batchStart...batchEnd {
                    let host = "\(prefix).\(i)"
                    group.addTask { await Self.probePort(host: host, port: port, timeout: timeout) }
                }
                for await result in group where result != nil {
                    group.cancelAll()
                    return result
                }
                return nil
            }
            if let found { return found }
        }
        return nil
    }

    /// The first three octets of the phone's Wi‑Fi IPv4 address (e.g. "192.168.0").
    private static func subnetPrefix() -> String? {
        var result: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            guard ifa.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: ifa.ifa_name)
            guard name == "en0" else { continue }        // Wi‑Fi
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(ifa.ifa_addr, socklen_t(ifa.ifa_addr.pointee.sa_len),
                        &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            let ip = String(cString: host)
            let parts = ip.split(separator: ".")
            if parts.count == 4 { result = parts[0...2].joined(separator: ".") }
        }
        return result
    }

    /// Try to open a TCP connection to `host:port`; returns the host on success.
    private static func probePort(host: String, port: UInt16, timeout: TimeInterval) async -> String? {
        final class Guard { var done = false; let lock = NSLock() }
        let g = Guard()
        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            let conn = NWConnection(host: NWEndpoint.Host(host),
                                    port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
            let queue = DispatchQueue(label: "atv.probe")
            func finish(_ value: String?) {
                g.lock.lock(); let already = g.done; g.done = true; g.lock.unlock()
                if already { return }
                conn.cancel()
                cont.resume(returning: value)
            }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(host)
                case .failed, .cancelled: finish(nil)
                default: break
                }
            }
            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { finish(nil) }
        }
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
