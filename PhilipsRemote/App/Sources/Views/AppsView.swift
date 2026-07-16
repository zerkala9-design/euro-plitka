import SwiftUI
import PhilipsKit

/// Quick‑launch grid for the TV's popular apps.
///
/// The Android TV Remote protocol doesn't expose the installed‑app list, so we
/// present a curated set of apps that can be launched by their app‑link URI.
struct AppsView: View {
    @Environment(TVController.self) private var controller
    @State private var search = ""

    struct QuickApp: Identifiable {
        let id = UUID()
        let name: String
        let color: Color
        let symbol: String
    }

    private let apps: [QuickApp] = [
        .init(name: "YouTube", color: .red, symbol: "play.rectangle.fill"),
        .init(name: "Netflix", color: .red, symbol: "play.tv.fill"),
        .init(name: "Megogo", color: .orange, symbol: "film.fill"),
        .init(name: "Kyivstar TV", color: .blue, symbol: "tv.fill"),
        .init(name: "Sweet.TV", color: .pink, symbol: "sparkles.tv.fill"),
        .init(name: "Disney+", color: Color(red: 0.05, green: 0.2, blue: 0.6), symbol: "star.fill"),
        .init(name: "Prime Video", color: .cyan, symbol: "play.tv.fill"),
        .init(name: "Spotify", color: .green, symbol: "music.note"),
    ]

    private var filtered: [QuickApp] {
        guard !search.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 18)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(filtered) { app in
                        Button {
                            Haptics.shared.press()
                            Task { await controller.launchApp(named: app.name) }
                        } label: {
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(app.color.gradient)
                                    .frame(width: 78, height: 78)
                                    .overlay(
                                        Image(systemName: app.symbol)
                                            .font(.system(size: 32))
                                            .foregroundStyle(.white)
                                    )
                                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(.white.opacity(0.15)))
                                    .shadow(color: app.color.opacity(0.4), radius: 8, y: 4)
                                Text(app.name).font(.caption2).lineLimit(1).foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()

                Text("Tap an app to open it on your TV. Not every app supports remote launch — if one doesn't open, use the TV's Home screen.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Apps")
            .searchable(text: $search, prompt: "Search apps")
        }
    }
}
