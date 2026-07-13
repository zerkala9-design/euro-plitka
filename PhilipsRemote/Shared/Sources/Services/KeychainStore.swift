import Foundation
import Security

/// Thin, type‑safe wrapper around the iOS Keychain used to persist the
/// per‑TV pairing credentials. Items are stored with
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` so they survive
/// reboots but never leave the device or sync to iCloud.
public struct KeychainStore: Sendable {
    public static let shared = KeychainStore()

    private let service = "com.europlitka.philipsremote.credentials"

    public init() {}

    // MARK: - Codable convenience

    public func save<T: Encodable>(_ value: T, for key: String) throws {
        let data = try JSONEncoder().encode(value)
        try saveData(data, for: key)
    }

    public func load<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        guard let data = loadData(for: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Raw data

    public func saveData(_ data: Data, for key: String) throws {
        var query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)   // replace any existing item
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PhilipsError.unknown("Keychain write failed (\(status)).")
        }
    }

    public func loadData(for key: String) -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    public func delete(for key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}

/// The credential material returned by the Philips pairing handshake.
public struct PairingCredential: Codable, Sendable, Hashable {
    /// Device identifier we generated and registered with the TV.
    public var deviceID: String
    /// The `auth_key` (username) returned by the TV.
    public var username: String
    /// The shared secret (password) used for HTTP digest auth on every request.
    public var password: String
    public var createdAt: Date

    public init(deviceID: String, username: String, password: String, createdAt: Date = Date()) {
        self.deviceID = deviceID
        self.username = username
        self.password = password
        self.createdAt = createdAt
    }
}
