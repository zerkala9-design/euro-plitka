import Foundation

/// A tiny TTL cache for decoded API responses (apps, system info…).
///
/// Reduces redundant network calls and keeps the UI instant when navigating
/// back to a previously loaded screen.
actor ResponseCache {
    private struct Box {
        let value: Any
        let expiry: Date
    }
    private var storage: [String: Box] = [:]

    func value<T>(for key: String) -> T? {
        guard let box = storage[key] else { return nil }
        if box.expiry < Date() {
            storage[key] = nil
            return nil
        }
        return box.value as? T
    }

    func store<T>(_ value: T, for key: String, ttl: TimeInterval) {
        storage[key] = Box(value: value, expiry: Date().addingTimeInterval(ttl))
    }

    func invalidate(_ key: String) { storage[key] = nil }
    func invalidateAll() { storage.removeAll() }
}
