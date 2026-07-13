import SwiftUI
import UIKit
import PhilipsKit

/// Installed‑apps launcher: searchable grid with favorites, recents & category
/// filtering. Icons are fetched from the TV and cached.
struct AppsView: View {
    @Environment(TVController.self) private var controller
    @State private var search = ""
    @State private var category: TVApp.Category?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 18)]

    private var filtered: [TVApp] {
        var apps = controller.apps
        if let category { apps = apps.filter { $0.category == category } }
        if !search.isEmpty { apps = apps.filter { $0.label.localizedCaseInsensitiveContains(search) } }
        return apps.sorted { $0.label < $1.label }
    }
    private var favorites: [TVApp] { controller.apps.filter(\.isFavorite) }
    private var recents: [TVApp] {
        controller.apps.filter { $0.lastUsed != nil }
            .sorted { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
            .prefix(6).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    categoryChips

                    if search.isEmpty {
                        if !favorites.isEmpty { appSection("Favorites", favorites) }
                        if !recents.isEmpty { appSection("Recently Used", recents) }
                    }

                    appSection(search.isEmpty ? "All Apps" : "Results", filtered)
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Apps")
            .searchable(text: $search, prompt: "Search apps")
            .overlay {
                if controller.apps.isEmpty {
                    ContentUnavailableView("No apps yet", systemImage: "square.grid.2x2",
                                           description: Text("Connect to your TV to load installed apps."))
                }
            }
            .task { await controller.refreshApps() }
            .refreshable { await controller.refreshApps() }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(nil, "All", "square.grid.2x2.fill")
                ForEach(TVApp.Category.allCases, id: \.self) { cat in
                    chip(cat, cat.rawValue, cat.systemImage)
                }
            }
        }
    }

    private func chip(_ cat: TVApp.Category?, _ title: String, _ symbol: String) -> some View {
        let selected = category == cat
        return Button {
            Haptics.shared.selectionChanged()
            withAnimation(.smooth) { category = selected ? nil : cat }
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.ultraThinMaterial), in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func appSection(_ title: String, _ apps: [TVApp]) -> some View {
        if !apps.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(apps) { app in AppTile(app: app) }
                }
            }
        }
    }
}

/// A single app tile with async icon loading and a long‑press favorite toggle.
struct AppTile: View {
    let app: TVApp
    @Environment(TVController.self) private var controller

    var body: some View {
        Button {
            Haptics.shared.press()
            Task { await controller.launch(app) }
        } label: {
            VStack(spacing: 8) {
                AppIconView(app: app)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.12)))
                    .overlay(alignment: .topTrailing) {
                        if app.isFavorite {
                            Image(systemName: "star.fill").font(.caption2)
                                .foregroundStyle(.yellow).padding(4)
                        }
                    }
                Text(app.label).font(.caption2).lineLimit(1).foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                controller.toggleFavoriteApp(app)
            } label: {
                Label(app.isFavorite ? "Unfavorite" : "Favorite",
                      systemImage: app.isFavorite ? "star.slash" : "star")
            }
        }
    }
}

/// Loads an app icon from the TV, falling back to a category glyph.
struct AppIconView: View {
    let app: TVApp
    @Environment(TVController.self) private var controller
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Rectangle().fill(.ultraThinMaterial)
                Image(systemName: app.category.systemImage)
                    .font(.title).foregroundStyle(.tint)
            }
        }
        .task { await loadIcon() }
    }

    private func loadIcon() async {
        if let cached = IconCache.shared.image(for: app.id) { image = cached; return }
        if let data = await controller.appIconData(app), let ui = UIImage(data: data) {
            IconCache.shared.store(ui, for: app.id)
            image = ui
        }
    }
}
