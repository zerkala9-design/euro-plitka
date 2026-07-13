import WidgetKit
import SwiftUI
import AppIntents
import PhilipsKit

// MARK: - Timeline provider

struct TVEntry: TimelineEntry {
    let date: Date
    let tvName: String
}

struct TVProvider: TimelineProvider {
    func placeholder(in context: Context) -> TVEntry {
        TVEntry(date: .now, tvName: "Living Room")
    }
    func getSnapshot(in context: Context, completion: @escaping (TVEntry) -> Void) {
        completion(TVEntry(date: .now, tvName: TVQuickControl.shared.selectedDeviceName()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TVEntry>) -> Void) {
        let entry = TVEntry(date: .now, tvName: TVQuickControl.shared.selectedDeviceName())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
    }
}

private let accent = Color(red: 0.043, green: 0.369, blue: 0.843)   // Philips Blue

// MARK: - Favorite TV (quick launcher)

struct FavoriteTVWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FavoriteTVWidget", provider: TVProvider()) { entry in
            FavoriteTVView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Favorite TV")
        .description("Power, mute and Home for your main TV.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FavoriteTVView: View {
    let entry: TVEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "tv.inset.filled").foregroundStyle(accent)
                Text(entry.tvName).font(.headline).lineLimit(1)
            }
            Spacer()
            HStack(spacing: 10) {
                widgetKey(.standby, "power", .red)
                widgetKey(.home, "house.fill", accent)
                widgetKey(.mute, "speaker.slash.fill", .primary)
            }
        }
        .padding(4)
    }

    private func widgetKey(_ key: RemoteKey, _ symbol: String, _ tint: Color) -> some View {
        Button(intent: SendKeyIntent(key)) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Volume

struct QuickVolumeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickVolumeWidget", provider: TVProvider()) { entry in
            QuickVolumeView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Volume")
        .description("Volume up / down and mute.")
        .supportedFamilies([.systemSmall])
    }
}

struct QuickVolumeView: View {
    let entry: TVEntry
    var body: some View {
        VStack(spacing: 8) {
            Text(entry.tvName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Button(intent: VolumeUpIntent()) {
                Image(systemName: "plus").font(.title2).frame(maxWidth: .infinity, minHeight: 34)
                    .background(accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain)
            Button(intent: MuteTVIntent()) {
                Image(systemName: "speaker.slash.fill").frame(maxWidth: .infinity, minHeight: 28)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain)
            Button(intent: VolumeDownIntent()) {
                Image(systemName: "minus").font(.title2).frame(maxWidth: .infinity, minHeight: 34)
                    .background(accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain)
        }
        .foregroundStyle(.primary)
        .padding(4)
    }
}

// MARK: - Open App (Netflix)

struct OpenAppWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OpenAppWidget", provider: TVProvider()) { entry in
            OpenAppView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Open Netflix")
        .description("One tap to launch Netflix.")
        .supportedFamilies([.systemSmall])
    }
}

struct OpenAppView: View {
    var body: some View {
        Button(intent: LaunchNetflixIntent()) {
            VStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill").font(.largeTitle).foregroundStyle(.red)
                Text("Netflix").font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}

// MARK: - Sleep Timer

struct SleepTimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SleepTimerWidget", provider: TVProvider()) { entry in
            SleepTimerView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Sleep Timer")
        .description("Send your TV to standby.")
        .supportedFamilies([.systemSmall])
    }
}

struct SleepTimerView: View {
    let entry: TVEntry
    var body: some View {
        Button(intent: TurnOffTVIntent()) {
            VStack(spacing: 8) {
                Image(systemName: "moon.zzz.fill").font(.largeTitle).foregroundStyle(accent)
                Text("Sleep \(entry.tvName)").font(.caption).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
