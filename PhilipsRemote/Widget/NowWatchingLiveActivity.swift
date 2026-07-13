import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents
import PhilipsKit

/// Lock Screen + Dynamic Island presentation of the "Now Watching" activity,
/// with interactive volume / mute / play‑pause controls.
struct NowWatchingLiveActivity: Widget {
    private let accent = Color(red: 0.043, green: 0.369, blue: 0.843)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RemoteActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color.black.opacity(0.5))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.tvName, systemImage: "tv.fill")
                        .font(.caption).foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label("\(context.state.volume)", systemImage: context.state.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.appName).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        islandButton(VolumeDownIntent(), "speaker.minus.fill")
                        islandButton(SendKeyIntent(.playPause), context.state.isPlaying ? "pause.fill" : "play.fill")
                        islandButton(MuteTVIntent(), "speaker.slash.fill")
                        islandButton(VolumeUpIntent(), "speaker.plus.fill")
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "tv.fill").foregroundStyle(accent)
            } compactTrailing: {
                Image(systemName: context.state.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            } minimal: {
                Image(systemName: "tv.fill").foregroundStyle(accent)
            }
        }
    }

    private func lockScreen(_ context: ActivityViewContext<RemoteActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "tv.inset.filled").font(.title).foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.tvName).font(.headline)
                Text(context.state.appName).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 12) {
                islandButton(VolumeDownIntent(), "speaker.minus.fill")
                islandButton(SendKeyIntent(.playPause), context.state.isPlaying ? "pause.fill" : "play.fill")
                islandButton(VolumeUpIntent(), "speaker.plus.fill")
            }
        }
        .padding()
    }

    private func islandButton(_ intent: some AppIntent, _ symbol: String) -> some View {
        Button(intent: intent) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}
