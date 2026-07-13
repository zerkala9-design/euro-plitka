import Foundation

/// Unified error type surfaced to the UI. Each case maps to a friendly,
/// user facing message and, where useful, a recovery suggestion.
public enum PhilipsError: LocalizedError, Sendable, Equatable {
    case tvOffline
    case notPaired
    case pairingRejected
    case pairingExpired
    case invalidPin
    case authenticationExpired
    case unsupportedCommand(String)
    case timeout
    case networkChanged
    case invalidResponse(status: Int)
    case decoding(String)
    case wakeOnLanUnavailable
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .tvOffline:
            return "Your TV appears to be offline."
        case .notPaired:
            return "This TV isn’t paired yet."
        case .pairingRejected:
            return "Pairing was rejected by the TV."
        case .pairingExpired:
            return "The pairing session expired. Please try again."
        case .invalidPin:
            return "That PIN didn’t match. Check the code on your TV."
        case .authenticationExpired:
            return "The saved credentials expired. Re‑pairing is required."
        case .unsupportedCommand(let c):
            return "“\(c)” isn’t supported by this TV model."
        case .timeout:
            return "The TV took too long to respond."
        case .networkChanged:
            return "Your network changed. Reconnecting…"
        case .invalidResponse(let status):
            return "The TV returned an unexpected response (\(status))."
        case .decoding(let detail):
            return "Couldn’t read the TV’s response. \(detail)"
        case .wakeOnLanUnavailable:
            return "Wake‑on‑LAN isn’t available for this TV."
        case .unknown(let d):
            return d
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .tvOffline:
            return "Make sure the TV is powered on and connected to the same Wi‑Fi network."
        case .notPaired, .authenticationExpired, .pairingExpired:
            return "Open the TV in the app and tap Pair to reconnect."
        case .timeout, .networkChanged:
            return "The app will keep retrying in the background."
        default:
            return nil
        }
    }

    /// Whether the error is transient and worth an automatic retry.
    public var isRetryable: Bool {
        switch self {
        case .timeout, .networkChanged, .tvOffline, .invalidResponse:
            return true
        default:
            return false
        }
    }
}
