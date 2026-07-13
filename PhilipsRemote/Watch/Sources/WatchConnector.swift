import Foundation
import Observation
import WatchConnectivity
import WatchKit

/// Sends remote commands from the watch to the paired iPhone, which performs the
/// actual JointSpace call against the TV. Uses `sendMessage` when the phone is
/// reachable and falls back to `transferUserInfo` otherwise.
@Observable
final class WatchConnector: NSObject, WCSessionDelegate, @unchecked Sendable {
    var isReachable = false
    var tvName = "TV"

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Command keys mirror `RemoteKey.rawValue` on the phone side.
    func send(key: String) {
        deliver(["type": "key", "key": key])
    }
    func volume(up: Bool) { deliver(["type": "key", "key": up ? "VolumeUp" : "VolumeDown"]) }
    func mute() { deliver(["type": "key", "key": "Mute"]) }
    func power() { deliver(["type": "power"]) }
    func launch(app: String) { deliver(["type": "launch", "app": app]) }

    private func deliver(_ message: [String: Any]) {
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }
        WKInterfaceDevice.current().play(.click)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if let name = session.receivedApplicationContext["tvName"] as? String { self.tvName = name }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.isReachable = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            if let name = applicationContext["tvName"] as? String { self.tvName = name }
        }
    }
}
