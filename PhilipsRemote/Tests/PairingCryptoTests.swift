import Testing
import Foundation
@testable import PhilipsKit

@Suite("Pairing crypto")
struct PairingCryptoTests {

    @Test("Signature is deterministic and base64 encoded")
    func signatureDeterministic() {
        let a = PairingCrypto.signature(timestamp: 12345, pin: "1234")
        let b = PairingCrypto.signature(timestamp: 12345, pin: "1234")
        #expect(a == b)
        #expect(Data(base64Encoded: a) != nil)
        #expect(!a.isEmpty)
    }

    @Test("Different inputs produce different signatures")
    func signatureVaries() {
        let a = PairingCrypto.signature(timestamp: 1, pin: "0000")
        let b = PairingCrypto.signature(timestamp: 2, pin: "0000")
        let c = PairingCrypto.signature(timestamp: 1, pin: "9999")
        #expect(a != b)
        #expect(a != c)
    }

    @Test("Device IDs are 16 chars and unique")
    func deviceID() {
        let ids = (0..<50).map { _ in PairingCrypto.generateDeviceID() }
        #expect(ids.allSatisfy { $0.count == 16 })
        #expect(Set(ids).count == ids.count)
    }
}
