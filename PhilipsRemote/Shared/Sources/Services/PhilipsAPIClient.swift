import Foundation

/// Typed client for the Philips JointSpace v6 REST API.
///
/// Owns the HTTP transport, digest credentials, a small response cache and the
/// retry policy. All methods are `async` and throw `PhilipsError`.
public actor PhilipsAPIClient {

    public let device: TVDevice
    private let credential: PairingCredential?
    private let transport: HTTPTransport
    private let retry: RetryPolicy
    private let cache = ResponseCache()
    /// Called after every request with a diagnostic sample (latency, success…).
    private let diagnosticsSink: (@Sendable (DiagnosticSample) -> Void)?

    public init(
        device: TVDevice,
        credential: PairingCredential?,
        retry: RetryPolicy = .default,
        diagnosticsSink: (@Sendable (DiagnosticSample) -> Void)? = nil
    ) {
        self.device = device
        self.credential = credential
        self.transport = HTTPTransport(allowedHosts: [device.host])
        self.retry = retry
        self.diagnosticsSink = diagnosticsSink
    }

    private var digest: DigestAuth? {
        guard let c = credential else { return nil }
        return DigestAuth(username: c.username, password: c.password)
    }

    // MARK: - Remote keys

    public func sendKey(_ key: RemoteKey) async throws {
        try await post("input/key", body: ["key": key.rawValue])
        await AppLog.shared.info("Sent key \(key.rawValue) to \(device.displayName)", category: "command")
    }

    // MARK: - Volume

    public struct Volume: Codable, Sendable {
        public var muted: Bool
        public var current: Int
        public var min: Int
        public var max: Int
    }

    public func getVolume() async throws -> Volume {
        try await get("audio/volume", as: Volume.self)
    }

    public func setVolume(_ value: Int, muted: Bool = false) async throws {
        try await post("audio/volume", body: ["muted": muted, "current": value])
    }

    // MARK: - System / capabilities

    public func getSystem() async throws -> SystemResponse {
        try await get("system", as: SystemResponse.self, cacheKey: "system", ttl: 60)
    }

    // MARK: - Applications

    public func getApplications() async throws -> [TVApp] {
        let response = try await get("applications", as: ApplicationsResponse.self, cacheKey: "apps", ttl: 30)
        return response.applications.map { app in
            TVApp(
                id: app.intent.component.packageName,
                label: app.label,
                packageName: app.intent.component.packageName,
                className: app.intent.component.className,
                type: app.type,
                iconPath: app.id
            )
        }
    }

    public func launch(_ app: TVApp) async throws {
        let body: [String: Any] = [
            "intent": [
                "component": [
                    "packageName": app.packageName,
                    "className": app.className
                ],
                "action": "empty"
            ]
        ]
        try await postRaw("activities/launch", body: body)
        await AppLog.shared.info("Launched \(app.label)", category: "command")
    }

    /// Fetch the raw PNG icon data for an application.
    public func appIcon(_ app: TVApp) async throws -> Data {
        guard let iconPath = app.iconPath else { throw PhilipsError.unsupportedCommand("app icon") }
        return try await getData("applications/\(iconPath)/icon")
    }

    // MARK: - Ambilight

    public func getAmbilightPower() async throws -> Bool {
        struct P: Codable { let power: String }
        let p = try await get("ambilight/power", as: P.self)
        return p.power.lowercased() == "on"
    }

    public func setAmbilightPower(_ on: Bool) async throws {
        try await post("ambilight/power", body: ["power": on ? "On" : "Off"])
    }

    public func setAmbilightMode(_ mode: AmbilightState.Mode, style: String? = nil) async throws {
        var body: [String: Any] = ["styleName": style ?? mode.rawValue]
        if mode == .manual { body = ["styleName": "FOLLOW_COLOR", "isExpert": false, "menuSetting": "HOT_LAVA"] }
        try await postRaw("ambilight/currentconfiguration", body: body)
    }

    /// Set a single static color across all Ambilight LEDs via the cached layer.
    public func setAmbilightColor(_ color: RGBColor) async throws {
        let body: [String: Any] = [
            "r": color.r, "g": color.g, "b": color.b
        ]
        try await postRaw("ambilight/cached", body: ["colorSettings": ["color": body]])
    }

    // MARK: - Sources / inputs

    public func getSources() async throws -> [InputSource] {
        // Modern Android sets expose inputs as activities; legacy sets expose /sources.
        if let response = try? await get("sources", as: [String: SourceEntry].self) {
            return response.map { key, value in
                InputSource(id: key, name: value.name, kind: .init(from: value.name))
            }.sorted { $0.name < $1.name }
        }
        return []
    }

    public func selectSource(_ source: InputSource) async throws {
        try await post("sources/current", body: ["id": source.id])
    }

    // MARK: - Text entry (best effort — model dependent)

    public func sendText(_ text: String) async throws {
        try await post("input/textentry", body: ["textentry": text])
    }

    // MARK: - Ping / diagnostics probe

    @discardableResult
    public func ping() async throws -> Bool {
        _ = try await get("system", as: SystemResponse.self, cacheKey: nil)
        return true
    }

    // MARK: - Core request helpers

    private func url(_ path: String) -> URL {
        device.baseURL.appendingPathComponent(path)
    }

    private func get<T: Decodable>(
        _ path: String,
        as type: T.Type,
        cacheKey: String? = nil,
        ttl: TimeInterval = 0
    ) async throws -> T {
        if let key = cacheKey, let cached: T = await cache.value(for: key) {
            return cached
        }
        let data = try await getData(path)
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            if let key = cacheKey, ttl > 0 { await cache.store(decoded, for: key, ttl: ttl) }
            return decoded
        } catch {
            throw PhilipsError.decoding(String(describing: error))
        }
    }

    private func getData(_ path: String) async throws -> Data {
        try await execute(method: "GET", path: path, body: nil)
    }

    private func post(_ path: String, body: [String: Any]) async throws {
        _ = try await execute(method: "POST", path: path, body: body)
    }

    private func postRaw(_ path: String, body: [String: Any]) async throws {
        _ = try await execute(method: "POST", path: path, body: body)
    }

    private func execute(method: String, path: String, body: [String: Any]?) async throws -> Data {
        let url = url(path)
        // Serialize the body here so the retry closure only captures Sendable values.
        let bodyData: Data? = try body.map { try JSONSerialization.data(withJSONObject: $0) }
        return try await retry.run { [transport, digest, diagnosticsSink] in
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
            let start = Date()
            let response = try await transport.send(request, digest: digest)
            let latency = Date().timeIntervalSince(start) * 1000
            let ok = (200..<300).contains(response.statusCode)
            diagnosticsSink?(DiagnosticSample(
                latencyMs: latency,
                success: ok,
                endpoint: path,
                statusCode: response.statusCode
            ))
            switch response.statusCode {
            case 200..<300: return response.data
            case 401: throw PhilipsError.authenticationExpired
            case 404: throw PhilipsError.unsupportedCommand(path)
            default: throw PhilipsError.invalidResponse(status: response.statusCode)
            }
        }
    }
}

// MARK: - Wire models

public struct SystemResponse: Codable, Sendable {
    public var name: String? = nil
    public var serialnumber_encrypted: String? = nil
    public var softwareversion: String? = nil
    public var model: String? = nil
    public var deviceid: String? = nil
    public var nettvversion: String? = nil
    public var epgsource: String? = nil
    public var api_version: APIVersion? = nil
    public var featuring: Featuring? = nil
    public var os_type: String? = nil

    public init() {}

    public struct APIVersion: Codable, Sendable {
        public var Major: Int? = nil
        public var Minor: Int? = nil
        public var Patch: Int? = nil
    }
    public struct Featuring: Codable, Sendable {
        public var jsonfeatures: JSONFeatures? = nil
        public var systemfeatures: SystemFeatures? = nil
        public init(jsonfeatures: JSONFeatures? = nil, systemfeatures: SystemFeatures? = nil) {
            self.jsonfeatures = jsonfeatures
            self.systemfeatures = systemfeatures
        }
    }
    public struct JSONFeatures: Codable, Sendable {
        public var ambilight: [String]? = nil
        public var applications: [String]? = nil
        public var pointer: [String]? = nil
        public var inputkey: [String]? = nil
        public var activities: [String]? = nil
        public var channels: [String]? = nil
        public init(ambilight: [String]? = nil, applications: [String]? = nil,
                    pointer: [String]? = nil, inputkey: [String]? = nil,
                    activities: [String]? = nil, channels: [String]? = nil) {
            self.ambilight = ambilight; self.applications = applications
            self.pointer = pointer; self.inputkey = inputkey
            self.activities = activities; self.channels = channels
        }
    }
    public struct SystemFeatures: Codable, Sendable {
        public var tvtype: String? = nil
        public var content: [String]? = nil
        public var pairing_type: String? = nil
        public var os_type: String? = nil
        public init(tvtype: String? = nil, content: [String]? = nil,
                    pairing_type: String? = nil, os_type: String? = nil) {
            self.tvtype = tvtype; self.content = content
            self.pairing_type = pairing_type; self.os_type = os_type
        }
    }
}

struct ApplicationsResponse: Codable, Sendable {
    struct App: Codable, Sendable {
        struct Intent: Codable, Sendable {
            struct Component: Codable, Sendable {
                var packageName: String
                var className: String
            }
            var component: Component
            var action: String?
        }
        var id: String
        var label: String
        var type: String?
        var intent: Intent
    }
    var applications: [App]
    var version: Int?
}

struct SourceEntry: Codable, Sendable {
    var name: String
}

extension InputSource.Kind {
    init(from label: String) { self = InputSource.Kind.classify(label) }
}
