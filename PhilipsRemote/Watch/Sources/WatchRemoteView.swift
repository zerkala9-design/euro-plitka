import SwiftUI

/// Compact watch remote: navigation, volume, power and quick apps, plus the
/// Digital Crown for volume.
struct WatchRemoteView: View {
    @Environment(WatchConnector.self) private var connector
    @State private var crownVolume: Double = 0
    @State private var lastCrown: Double = 0

    var body: some View {
        TabView {
            navPage.tag(0)
            volumePage.tag(1)
            appsPage.tag(2)
        }
        .tabViewStyle(.verticalPage)
        .navigationTitle(connector.tvName)
    }

    // Navigation + OK
    private var navPage: some View {
        VStack(spacing: 6) {
            key("chevron.up", "CursorUp")
            HStack(spacing: 6) {
                key("chevron.left", "CursorLeft")
                key("circle.fill", "Confirm", tint: .blue)
                key("chevron.right", "CursorRight")
            }
            key("chevron.down", "CursorDown")
            HStack(spacing: 6) {
                key("chevron.backward", "Back")
                key("house.fill", "Home")
            }
        }
        .padding(.horizontal, 4)
    }

    // Volume + power, crown-driven
    private var volumePage: some View {
        VStack(spacing: 10) {
            Button { connector.volume(up: true) } label: {
                Image(systemName: "plus").font(.title2).frame(maxWidth: .infinity)
            }
            .tint(.blue)
            Button { connector.mute() } label: {
                Image(systemName: "speaker.slash.fill").frame(maxWidth: .infinity)
            }
            Button { connector.volume(up: false) } label: {
                Image(systemName: "minus").font(.title2).frame(maxWidth: .infinity)
            }
            .tint(.blue)
            Button(role: .destructive) { connector.power() } label: {
                Label("Power", systemImage: "power").frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .focusable()
        .digitalCrownRotation($crownVolume, from: -100, through: 100, by: 1, sensitivity: .low)
        .onChange(of: crownVolume) { _, new in
            if new - lastCrown >= 1 { connector.volume(up: true); lastCrown = new }
            else if lastCrown - new >= 1 { connector.volume(up: false); lastCrown = new }
        }
    }

    // Quick apps
    private var appsPage: some View {
        ScrollView {
            VStack(spacing: 8) {
                appButton("Netflix", .red)
                appButton("YouTube", .red)
                appButton("Disney+", .blue)
                appButton("Prime Video", .cyan)
                appButton("Spotify", .green)
            }
        }
    }

    private func key(_ symbol: String, _ code: String, tint: Color = .gray) -> some View {
        Button { connector.send(key: code) } label: {
            Image(systemName: symbol).font(.title3).frame(width: 46, height: 40)
        }
        .buttonStyle(.bordered)
        .tint(tint)
    }

    private func appButton(_ name: String, _ tint: Color) -> some View {
        Button { connector.launch(app: name) } label: {
            Text(name).frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(tint)
    }
}
