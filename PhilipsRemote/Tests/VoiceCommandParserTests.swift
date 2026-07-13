import Testing
@testable import PhilipsKit

@Suite("Voice command parsing")
struct VoiceCommandParserTests {

    @Test("Recognises app launches", arguments: [
        ("open netflix", "Netflix"),
        ("launch youtube please", "YouTube"),
        ("play disney", "Disney+")
    ])
    func launchApps(phrase: String, expected: String) {
        #expect(VoiceCommandParser.parse(phrase) == .launchApp(name: expected))
    }

    @Test("Recognises volume commands")
    func volume() {
        #expect(VoiceCommandParser.parse("volume up") == .key(.volumeUp))
        #expect(VoiceCommandParser.parse("make it quieter") == .key(.volumeDown))
        #expect(VoiceCommandParser.parse("mute the tv") == .key(.mute))
        #expect(VoiceCommandParser.parse("set volume to 40") == .setVolume(40))
    }

    @Test("Recognises search")
    func search() {
        #expect(VoiceCommandParser.parse("search for Interstellar") == .search(query: "interstellar"))
        #expect(VoiceCommandParser.parse("find The Matrix") == .search(query: "the matrix"))
    }

    @Test("Recognises transport keys")
    func transport() {
        #expect(VoiceCommandParser.parse("pause") == .key(.pause))
        #expect(VoiceCommandParser.parse("go home") == .key(.home))
    }

    @Test("Unknown phrases map to .unknown")
    func unknown() {
        #expect(VoiceCommandParser.parse("banana milkshake") == .unknown)
        #expect(VoiceCommandParser.parse("") == .unknown)
    }
}
