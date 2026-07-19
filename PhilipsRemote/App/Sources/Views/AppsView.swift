import SwiftUI
import PhilipsKit

/// Quick‑launch grid for the TV's popular apps plus user‑added links.
///
/// The Android TV Remote protocol doesn't expose the installed‑app list, so we
/// present a curated set of apps launched by their app‑link URI, and let the
/// user add their own links (opened on the TV as an app‑link).
struct AppsView: View {
    @Environment(TVController.self) private var controller
    @State private var search = ""
    @State private var customApps: [CustomLink] = CustomLinkStore.load()
    @State private var showAdd = false

    struct QuickApp: Identifiable {
        let id = UUID()
        let name: String
        let color: Color
        let symbol: String
    }

    private let apps: [QuickApp] = [
        .init(name: "YouTube", color: .red, symbol: "play.rectangle.fill"),
        .init(name: "Kyivstar TV", color: .blue, symbol: "tv.fill"),
    ]

    private var filteredApps: [QuickApp] {
        guard !search.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var filteredCustom: [CustomLink] {
        guard !search.isEmpty else { return customApps }
        return customApps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 18)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(filteredApps) { app in
                        tile(color: app.color, symbol: app.symbol, name: app.name) {
                            Task { await controller.launchApp(named: app.name) }
                        }
                    }
                    ForEach(filteredCustom) { link in
                        tile(color: .indigo, symbol: "link", name: link.name) {
                            Task { await controller.launchURL(link.url) }
                        }
                        .contextMenu {
                            Button(role: .destructive) { remove(link) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    if search.isEmpty { addTile }
                }
                .padding()

                Text("Tap an app to open it on your TV. Use + to add your own link. Not every app or link supports remote launch — if one doesn't open, use the TV's Home screen.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Apps")
            .searchable(text: $search, prompt: "Search apps")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddLinkView { newLink in
                    customApps.append(newLink)
                    CustomLinkStore.save(customApps)
                }
            }
        }
    }

    // MARK: - Tiles

    private func tile(color: Color, symbol: String, name: String,
                      action: @escaping () -> Void) -> some View {
        Button {
            Haptics.shared.press()
            action()
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(color.gradient)
                    .frame(width: 78, height: 78)
                    .overlay(
                        Image(systemName: symbol)
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.15)))
                    .shadow(color: color.opacity(0.4), radius: 8, y: 4)
                Text(name).font(.caption2).lineLimit(1).foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    private var addTile: some View {
        Button {
            Haptics.shared.tap()
            showAdd = true
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundStyle(.secondary)
                    .frame(width: 78, height: 78)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.secondary)
                    )
                Text("Add").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func remove(_ link: CustomLink) {
        customApps.removeAll { $0.id == link.id }
        CustomLinkStore.save(customApps)
    }
}

/// A user‑added launchable link.
struct CustomLink: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var url: String
}

/// Persists user‑added links in `UserDefaults`.
enum CustomLinkStore {
    private static let key = "customAppLinks"

    static func load() -> [CustomLink] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let links = try? JSONDecoder().decode([CustomLink].self, from: data)
        else { return [] }
        return links
    }

    static func save(_ links: [CustomLink]) {
        if let data = try? JSONEncoder().encode(links) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// Sheet for entering a new custom link (name + URL).
private struct AddLinkView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (CustomLink) -> Void

    @State private var name = ""
    @State private var address = ""

    private var normalizedURL: String {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.contains("://") { return trimmed }
        return "https://\(trimmed)"
    }

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !normalizedURL.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. UAFIX", text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section("Link") {
                    TextField("https://…", text: $address)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
                Section {
                    Text("The link opens on your TV as an app‑link. Web pages open only if the TV has a browser that handles them.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(CustomLink(name: name.trimmingCharacters(in: .whitespaces),
                                         url: normalizedURL))
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }
}
