import Foundation
import CryptoKit

/// Minimal RFC 2617 HTTP Digest authentication implementation.
///
/// JointSpace on Philips Android TVs protects the API with Digest auth
/// (MD5, `qop=auth`). `URLSession`'s built‑in credential handling is
/// unreliable against the TV's self‑signed certificate + non‑standard flow,
/// so we build the `Authorization` header ourselves.
public struct DigestAuth: Sendable {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    /// The challenge parsed from a `WWW-Authenticate` header.
    public struct Challenge: Sendable {
        public var realm: String
        public var nonce: String
        public var qop: String?
        public var opaque: String?
        public var algorithm: String?

        public init?(header: String) {
            guard header.lowercased().hasPrefix("digest") else { return nil }
            let params = Challenge.parse(header.dropFirst("digest".count).description)
            guard let realm = params["realm"], let nonce = params["nonce"] else { return nil }
            self.realm = realm
            self.nonce = nonce
            self.qop = params["qop"]
            self.opaque = params["opaque"]
            self.algorithm = params["algorithm"]
        }

        static func parse(_ s: String) -> [String: String] {
            var result: [String: String] = [:]
            // Split on commas not inside quotes.
            var current = ""
            var inQuotes = false
            var parts: [String] = []
            for ch in s {
                if ch == "\"" { inQuotes.toggle() }
                if ch == "," && !inQuotes { parts.append(current); current = "" }
                else { current.append(ch) }
            }
            parts.append(current)
            for part in parts {
                let kv = part.split(separator: "=", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                guard kv.count == 2 else { continue }
                let value = kv[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                result[kv[0].lowercased()] = value
            }
            return result
        }
    }

    /// Build the `Authorization` header value for a request.
    public func authorization(
        for challenge: Challenge,
        method: String,
        uri: String,
        cnonce: String = DigestAuth.randomCNonce(),
        nc: String = "00000001"
    ) -> String {
        let ha1 = md5("\(username):\(challenge.realm):\(password)")
        let ha2 = md5("\(method):\(uri)")
        let response: String
        var fields: [String] = [
            "username=\"\(username)\"",
            "realm=\"\(challenge.realm)\"",
            "nonce=\"\(challenge.nonce)\"",
            "uri=\"\(uri)\""
        ]
        if let qop = challenge.qop, qop.contains("auth") {
            response = md5("\(ha1):\(challenge.nonce):\(nc):\(cnonce):auth:\(ha2)")
            fields.append("qop=auth")
            fields.append("nc=\(nc)")
            fields.append("cnonce=\"\(cnonce)\"")
        } else {
            response = md5("\(ha1):\(challenge.nonce):\(ha2)")
        }
        fields.append("response=\"\(response)\"")
        if let opaque = challenge.opaque { fields.append("opaque=\"\(opaque)\"") }
        if let algorithm = challenge.algorithm { fields.append("algorithm=\(algorithm)") }
        return "Digest " + fields.joined(separator: ", ")
    }

    private func md5(_ string: String) -> String {
        Insecure.MD5.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    public static func randomCNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 8)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
