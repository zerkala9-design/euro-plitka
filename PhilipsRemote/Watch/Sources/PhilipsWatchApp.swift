import SwiftUI

@main
struct PhilipsWatchApp: App {
    @State private var connector = WatchConnector()

    var body: some Scene {
        WindowGroup {
            WatchRemoteView()
                .environment(connector)
        }
    }
}
