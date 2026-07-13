import UIKit

/// A simple two‑tier (memory + disk) cache for TV app icons, keeping the grid
/// instant and avoiding repeat network fetches.
final class IconCache: @unchecked Sendable {
    static let shared = IconCache()

    private let memory = NSCache<NSString, UIImage>()
    private let directory: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent("AppIcons", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func image(for key: String) -> UIImage? {
        if let cached = memory.object(forKey: key as NSString) { return cached }
        let url = directory.appendingPathComponent(key.safeFilename)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        memory.setObject(image, forKey: key as NSString)
        return image
    }

    func store(_ image: UIImage, for key: String) {
        memory.setObject(image, forKey: key as NSString)
        let url = directory.appendingPathComponent(key.safeFilename)
        if let data = image.pngData() { try? data.write(to: url) }
    }
}

private extension String {
    var safeFilename: String {
        addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "icon"
    }
}
