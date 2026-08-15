import SwiftUI
import PhilipsKit

/// The main remote screen: the button remote plus the device switcher and TV
/// info in the navigation bar.
struct RemoteHomeView: View {
    @Environment(DeviceStore.self) private var store

    @State private var activeSheet: Sheet?

    enum Sheet: String, Identifiable {
        case info, devices
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            RemoteView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(Theme.background.ignoresSafeArea())
                .navigationTitle(store.selectedDevice?.displayName ?? "Remote")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { activeSheet = .devices } label: {
                            Image(systemName: "rectangle.stack.badge.play")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { activeSheet = .info } label: {
                            Image(systemName: "info.circle")
                        }
                    }
                }
                .sheet(item: $activeSheet) { sheet in
                    switch sheet {
                    case .info: TVInfoView()
                    case .devices: DevicesView()
                    }
                }
        }
    }
}
