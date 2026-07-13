import Foundation
import PhilipsKit

/// Lightweight per‑app preferences (favorites, recents, input renames) stored in
/// the App Group defaults. Keyed by package/source id so they persist across
/// re‑discovery.
enum AppPreferences {
    private static var defaults: UserDefaults { AppGroup.defaults }

    // MARK: Favorite apps
    private static let favKey = "apps.favorites"

    static func favoriteApps() -> [String] {
        defaults.stringArray(forKey: favKey) ?? []
    }

    static func toggleFavoriteApp(_ package: String) {
        var set = Set(favoriteApps())
        if set.contains(package) { set.remove(package) } else { set.insert(package) }
        defaults.set(Array(set), forKey: favKey)
    }

    // MARK: Recent apps
    private static let recentKey = "apps.recents"

    static func recentApps() -> [String: Date] {
        (defaults.dictionary(forKey: recentKey) as? [String: Date]) ?? [:]
    }

    static func recordRecentApp(_ package: String) {
        var map = recentApps()
        map[package] = Date()
        // Keep the 12 most recent.
        if map.count > 12 {
            let trimmed = map.sorted { $0.value > $1.value }.prefix(12)
            map = Dictionary(uniqueKeysWithValues: trimmed.map { ($0.key, $0.value) })
        }
        defaults.set(map, forKey: recentKey)
    }

    // MARK: Input renames / favorites
    static func inputName(for id: String) -> String? {
        defaults.string(forKey: "input.name.\(id)")
    }
    static func setInputName(_ name: String?, for id: String) {
        defaults.set(name, forKey: "input.name.\(id)")
    }
    static func isInputFavorite(_ id: String) -> Bool {
        defaults.bool(forKey: "input.fav.\(id)")
    }
    static func toggleInputFavorite(_ id: String) {
        defaults.set(!isInputFavorite(id), forKey: "input.fav.\(id)")
    }
}
