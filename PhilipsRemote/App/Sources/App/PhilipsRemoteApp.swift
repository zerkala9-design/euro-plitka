import SwiftUI
import PhilipsKit

@main
struct PhilipsRemoteApp: App {
    @State private var model = AppModel()

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
    }
}
