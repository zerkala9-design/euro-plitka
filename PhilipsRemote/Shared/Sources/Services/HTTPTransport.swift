import Foundation

/// A `URLSession` wrapper that accepts the Philips TV's self‑signed
/// certificate (the JointSpace HTTPS endpoint on :1926 always uses one) and
/// performs HTTP Digest authentication for a given credential.
///
/// Trust is intentionally scoped: we only bypass validation for connections to
/// the private‑range host we are actively controlling, never for arbitrary
/// hosts, and all traffic stays on the local network.
public final class HTTPTransport: NSObject, URLSessionDelegate, @unchecked Sendable {

    private var session: URLSession!
    private let allowedHosts: Set<String>

    public init(allowedHosts: Set<String>, timeout: TimeInterval = 6) {
        self.allowedHosts = allowedHosts
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        super.init()
        // `self` is needed as the delegate, so build the session after super.init.
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    public struct Response: Sendable {
        public let data: Data
        public let statusCode: Int
        public let headers: [String: String]
    }

    /// Send a request, transparently handling a Digest `401` challenge/response.
    public func send(
        _ request: URLRequest,
        digest: DigestAuth? = nil
    ) async throws -> Response {
        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else {
            throw PhilipsError.invalidResponse(status: -1)
        }

        // Retry once with the Digest authorization header if challenged.
        if http.statusCode == 401,
           let digest,
           let wwwAuth = http.value(forHTTPHeaderField: "WWW-Authenticate"),
           let challenge = DigestAuth.Challenge(header: wwwAuth) {
            var authed = request
            let uri = request.url?.pathWithQuery ?? "/"
            let header = digest.authorization(
                for: challenge,
                method: request.httpMethod ?? "GET",
                uri: uri
            )
            authed.setValue(header, forHTTPHeaderField: "Authorization")
            let (data2, response2) = try await perform(authed)
            guard let http2 = response2 as? HTTPURLResponse else {
                throw PhilipsError.invalidResponse(status: -1)
            }
            return Response(
                data: data2,
                statusCode: http2.statusCode,
                headers: http2.allHeaderFields as? [String: String] ?? [:]
            )
        }

        return Response(
            data: data,
            statusCode: http.statusCode,
            headers: http.allHeaderFields as? [String: String] ?? [:]
        )
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut: throw PhilipsError.timeout
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
                throw PhilipsError.tvOffline
            case .notConnectedToInternet: throw PhilipsError.networkChanged
            default: throw PhilipsError.unknown(error.localizedDescription)
            }
        }
    }

    // MARK: - Self‑signed trust (scoped to the TV host)

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              allowedHosts.contains(challenge.protectionSpace.host),
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

extension URL {
    /// Path + query used as the digest `uri` value.
    var pathWithQuery: String {
        var result = path.isEmpty ? "/" : path
        if let q = query { result += "?\(q)" }
        return result
    }
}
