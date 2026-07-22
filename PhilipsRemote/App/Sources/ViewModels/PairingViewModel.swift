import SwiftUI
import PhilipsKit

/// Drives the pairing UI state machine on top of the Android TV Remote v2
/// pairing client (`ATVPairingClient`). The TV shows a 6‑hex‑digit code which
/// the user types to complete pairing; the trusted client certificate is then
/// stored in the Keychain for all future connections.
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
    private var client: ATVPairingClient?

    func begin(pairing device: TVDevice) async {
        phase = .requesting
        let client = ATVPairingClient(host: device.host, deviceName: TVController.thisDeviceName)
        self.client = client
        do {
            try await client.begin()      // TV now displays the code
            phase = .awaitingPIN
        } catch let error as PhilipsError {
            phase = .failed(error.errorDescription ?? "Couldn't start pairing.")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func confirm(pin: String) async {
        guard let client, pin.count == 6 else { return }
        phase = .confirming
        do {
            try await client.confirm(code: pin)
            phase = .success
        } catch let error as PhilipsError {
            phase = .failed(error.errorDescription ?? "Pairing failed.")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
