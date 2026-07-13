import SwiftUI
import PhilipsKit

/// Drives the pairing UI state machine on top of `AuthenticationService`.
@MainActor
@Observable
final class PairingViewModel {
    enum Phase: Equatable {
        case requesting
        case awaitingPIN
        case confirming
        case success
        case failed(String)
    }

    private(set) var phase: Phase = .requesting
    private let auth = AuthenticationService()
    private var session: AuthenticationService.PairingSession?

    func begin(pairing device: TVDevice) async {
        phase = .requesting
        do {
            session = try await auth.startPairing(with: device)
            phase = .awaitingPIN
        } catch let error as PhilipsError {
            phase = .failed(error.errorDescription ?? "Couldn't start pairing.")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func confirm(pin: String) async {
        guard let session, pin.count == 4 else { return }
        phase = .confirming
        do {
            try await auth.confirmPairing(session, pin: pin)
            phase = .success
        } catch let error as PhilipsError {
            phase = .failed(error.errorDescription ?? "Pairing failed.")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
