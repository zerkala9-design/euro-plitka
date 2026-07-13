import Foundation
import ActivityKit
import PhilipsKit

/// Manages the "Now Watching" Live Activity lifecycle.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()
    private var activity: Activity<RemoteActivityAttributes>?

    private init() {}

    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(tvName: String, state: RemoteActivityAttributes.ContentState) {
        guard isSupported, activity == nil else { return }
        let attributes = RemoteActivityAttributes(tvName: tvName)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            activity = nil
        }
    }

    func update(_ state: RemoteActivityAttributes.ContentState) {
        Task {
            await activity?.update(.init(state: state, staleDate: nil))
        }
    }

    func end() {
        Task {
            await activity?.end(nil, dismissalPolicy: .immediate)
            activity = nil
        }
    }
}
