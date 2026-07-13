import Foundation

/// Drives the two‑step Philips pairing handshake and persists the resulting
/// credential to the Keychain.
public actor AuthenticationService {

    private let keychain: KeychainStore

    public init(keychain: KeychainStore = .shared) {
        self.keychain = keychain
    }

    /// State carried between the two pairing steps while the TV shows a PIN.
    public struct PairingSession: Sendable {
        public let device: TVDevice
        public let deviceID: String
        public let authKey: String
        public let timestamp: Int
    }

    private struct RequestResponse: Codable {
        var error_id: String?
        var error_text: String?
        var auth_key: String?
        var timestamp: Int?
    }
    private struct GrantResponse: Codable {
        var error_id: String?
        var error_text: String?
    }

    private func deviceInfo(id: String) -> [String: Any] {
        [
            "device_name": "iPhone",
            "device_os": "iOS",
            "app_name": "Philips Remote",
            "type": "native",
            "app_id": "com.europlitka.philipsremote",
            "id": id
        ]
    }

    /// Step 1 — request a pairing session. The TV will display a PIN.
    public func startPairing(with device: TVDevice) async throws -> PairingSession {
        let transport = HTTPTransport(allowedHosts: [device.host])
        let deviceID = PairingCrypto.generateDeviceID()
        let body: [String: Any] = [
            "scope": ["read", "write", "control"],
            "device": deviceInfo(id: deviceID)
        ]
        var request = URLRequest(url: device.baseURL.appendingPathComponent("pair/request"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let response = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw PhilipsError.invalidResponse(status: response.statusCode)
        }
        let decoded = try JSONDecoder().decode(RequestResponse.self, from: response.data)
        guard decoded.error_id == "SUCCESS",
              let authKey = decoded.auth_key,
              let timestamp = decoded.timestamp else {
            throw PhilipsError.pairingRejected
        }
        await AppLog.shared.info("Pairing started with \(device.displayName)", category: "pairing")
        return PairingSession(device: device, deviceID: deviceID, authKey: authKey, timestamp: timestamp)
    }

    /// Step 2 — confirm pairing with the PIN shown on the TV.
    @discardableResult
    public func confirmPairing(_ session: PairingSession, pin: String) async throws -> PairingCredential {
        let transport = HTTPTransport(allowedHosts: [session.device.host])
        let signature = PairingCrypto.signature(timestamp: session.timestamp, pin: pin)
        let body: [String: Any] = [
            "auth": [
                "auth_AppId": "1",
                "pin": pin,
                "auth_timestamp": session.timestamp,
                "auth_signature": "signature===" + signature
            ],
            "device": deviceInfo(id: session.deviceID)
        ]
        var request = URLRequest(url: session.device.baseURL.appendingPathComponent("pair/grant"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // pair/grant is protected by Digest auth using (deviceID, authKey).
        let digest = DigestAuth(username: session.deviceID, password: session.authKey)
        let response = try await transport.send(request, digest: digest)

        switch response.statusCode {
        case 200..<300:
            break
        case 401:
            throw PhilipsError.invalidPin
        default:
            let decoded = try? JSONDecoder().decode(GrantResponse.self, from: response.data)
            if decoded?.error_id == "INVALID_PIN" { throw PhilipsError.invalidPin }
            if decoded?.error_id == "TIMEOUT" { throw PhilipsError.pairingExpired }
            throw PhilipsError.invalidResponse(status: response.statusCode)
        }

        let credential = PairingCredential(
            deviceID: session.deviceID,
            username: session.deviceID,
            password: session.authKey
        )
        try keychain.save(credential, for: session.device.id.uuidString)
        await AppLog.shared.info("Pairing succeeded with \(session.device.displayName)", category: "pairing")
        return credential
    }

    // MARK: - Credential lifecycle

    public nonisolated func credential(for device: TVDevice) -> PairingCredential? {
        keychain.load(PairingCredential.self, for: device.id.uuidString)
    }

    public nonisolated func removeCredential(for device: TVDevice) {
        keychain.delete(for: device.id.uuidString)
    }
}
