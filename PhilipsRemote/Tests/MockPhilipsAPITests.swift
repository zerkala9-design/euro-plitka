import Testing
import Foundation
@testable import PhilipsKit

/// Canned JSON payloads mirroring real Philips JointSpace v6 responses, used to
/// verify the decoding layer without hitting a physical TV.
enum MockPhilipsAPI {
    static let system = """
    {
      "name": "Living Room",
      "model": "50PUS7906/12",
      "serialnumber_encrypted": "ABC123==",
      "softwareversion": "TPM196E_R.101.001.184.001",
      "os_type": "MSAF_2019_UHD",
      "api_version": { "Major": 6, "Minor": 4, "Patch": 0 },
      "featuring": {
        "jsonfeatures": {
          "ambilight": ["Ambilight"],
          "applications": ["applications", "activities"],
          "pointer": ["pointer"],
          "inputkey": ["key"]
        },
        "systemfeatures": {
          "tvtype": "consumer",
          "pairing_type": "digest_auth_pairing",
          "os_type": "Android"
        }
      }
    }
    """

    static let applications = """
    {
      "version": 0,
      "applications": [
        {
          "id": "com.netflix.ninja-com.netflix.ninja.MainActivity",
          "label": "Netflix",
          "type": "app",
          "intent": {
            "component": {
              "packageName": "com.netflix.ninja",
              "className": "com.netflix.ninja.MainActivity"
            },
            "action": "android.intent.action.MAIN"
          }
        },
        {
          "id": "com.google.android.youtube.tv",
          "label": "YouTube",
          "type": "app",
          "intent": {
            "component": {
              "packageName": "com.google.android.youtube.tv",
              "className": "com.google.android.apps.youtube.tv.activity.ShellActivity"
            }
          }
        }
      ]
    }
    """

    static let volume = """
    { "muted": false, "current": 12, "min": 0, "max": 60 }
    """
}

@Suite("Mock Philips API decoding")
struct MockPhilipsAPITests {

    @Test("Decodes system + derives capabilities")
    func system() throws {
        let data = Data(MockPhilipsAPI.system.utf8)
        let system = try JSONDecoder().decode(SystemResponse.self, from: data)
        #expect(system.model == "50PUS7906/12")
        #expect(system.api_version?.Major == 6)

        let caps = CapabilityDetector.detect(from: system)
        #expect(caps.supportsAmbilight)
        #expect(caps.platform == .androidTV)

        let info = CapabilityDetector.systemInfo(from: system, host: "192.168.0.5")
        #expect(info.androidVersion == "Android 11")
        #expect(info.apiVersion == "6.4.0")
    }

    @Test("Decodes applications into TVApp models")
    func applications() throws {
        let data = Data(MockPhilipsAPI.applications.utf8)
        let response = try JSONDecoder().decode(ApplicationsResponse.self, from: data)
        #expect(response.applications.count == 2)
        let netflix = response.applications[0]
        #expect(netflix.label == "Netflix")
        #expect(netflix.intent.component.packageName == "com.netflix.ninja")

        // Category heuristic
        let app = TVApp(id: "x", label: "Netflix", packageName: "com.netflix.ninja", className: "y")
        #expect(app.category == .streaming)
    }

    @Test("Decodes volume")
    func volume() throws {
        let data = Data(MockPhilipsAPI.volume.utf8)
        let volume = try JSONDecoder().decode(PhilipsAPIClient.Volume.self, from: data)
        #expect(volume.current == 12)
        #expect(volume.max == 60)
        #expect(!volume.muted)
    }
}
