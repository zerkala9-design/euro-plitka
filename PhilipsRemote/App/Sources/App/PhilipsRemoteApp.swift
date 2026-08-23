import SwiftUI
import PhilipsKit

@main
struct PhilipsRemoteApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.settings)
                .environment(model.deviceStore)
                .environment(model.controller)
                .tint(model.settings.accentColor)
                .preferredColorScheme(.dark)
                .task { await model.bootstrap() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Returning to the app: restore the connection, and if the TV's
                // IP changed while away, find it automatically.
                Task { await model.reconnectOrLocate() }
            case .background:
                // Stop retrying while suspended; we reconnect on next foreground.
                model.controller.enterBackground()
            default:
                break
            }
        }
    }
}
