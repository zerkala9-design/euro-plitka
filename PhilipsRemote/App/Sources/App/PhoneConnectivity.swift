import Foundation
import WatchConnectivity
import PhilipsKit

/// Phone side of WatchConnectivity. Receives commands from the watch and
/// executes them via `TVQuickControl`, and pushes the current TV name to the
/// watch as application context.
final class PhoneConnectivity: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneConnectivity()

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Push the currently selected TV name to the watch.
    func syncSelectedTV() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        try? session.updateApplicationContext(["tvName": TVQuickControl.shared.selectedDeviceName()])
    }

    private func handle(_ message: [String: Any]) {
        Task {
            switch message["type"] as? String {
            case "key":
                if let raw = message["key"] as? String, let key = RemoteKey(rawValue: raw) {
                    _ = await TVQuickControl.shared.send(key)
                }
            case "power":
                _ = await TVQuickControl.shared.power(on: false)
            case "launch":
                if let app = message["app"] as? String {
                    _ = await TVQuickControl.shared.launchApp(named: app)
                }
            default:
                break
            }
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        syncSelectedTV()
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handle(message)
        replyHandler(["ok": true])
    }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handle(userInfo)
    }
}
