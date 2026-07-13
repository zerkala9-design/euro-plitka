import Testing
@testable import PhilipsKit

@Suite("HTTP Digest auth")
struct DigestAuthTests {

    @Test("Parses a standard challenge header")
    func parseChallenge() throws {
        let header = #"Digest realm="XTV", nonce="abc123", qop="auth", opaque="xyz""#
        let challenge = try #require(DigestAuth.Challenge(header: header))
        #expect(challenge.realm == "XTV")
        #expect(challenge.nonce == "abc123")
        #expect(challenge.qop == "auth")
        #expect(challenge.opaque == "xyz")
    }

    @Test("Rejects a non-digest header")
    func rejectsBasic() {
        #expect(DigestAuth.Challenge(header: "Basic realm=\"x\"") == nil)
    }

    @Test("Builds an authorization header with qop=auth")
    func buildsAuthorization() throws {
        let header = #"Digest realm="XTV", nonce="n0nce", qop="auth""#
        let challenge = try #require(DigestAuth.Challenge(header: header))
        let auth = DigestAuth(username: "user", password: "pass")
        let value = auth.authorization(for: challenge, method: "POST", uri: "/6/input/key",
                                       cnonce: "cnonce", nc: "00000001")
        #expect(value.hasPrefix("Digest "))
        #expect(value.contains("username=\"user\""))
        #expect(value.contains("qop=auth"))
        #expect(value.contains("response="))
        #expect(value.contains("uri=\"/6/input/key\""))
    }
}
