import Foundation
import Testing
@testable import Portwhore

@Suite("Port validation")
struct PortValidationTests {
  @Test("Normalizes valid port text")
  func normalizesPortText() {
    #expect(PortValidation.normalizedPort(from: " 3000 ") == 3000)
    #expect(PortValidation.normalizedPort(from: "0") == nil)
    #expect(PortValidation.normalizedPort(from: "65536") == nil)
    #expect(PortValidation.normalizedPort(from: "vite") == nil)
  }

  @Test("Sanitizes stored port lists")
  func sanitizesStoredPorts() {
    #expect(PortValidation.sanitizedPorts([3000, 0, 8080, 3000, 65536, 1]) == [1, 3000, 8080])
  }

  @Test("Trims labels and drops empty labels")
  func sanitizesLabels() {
    #expect(PortValidation.sanitizedLabel("  API  ") == "API")
    #expect(PortValidation.sanitizedLabel("   ") == nil)
    #expect(PortValidation.sanitizedLabel(nil) == nil)
  }

  @Test("Falls back for unsupported refresh intervals")
  func normalizesRefreshIntervals() {
    #expect(PortValidation.normalizedRefreshInterval(2) == 2)
    #expect(PortValidation.normalizedRefreshInterval(0) == PortValidation.defaultRefreshInterval)
    #expect(PortValidation.normalizedRefreshInterval(7) == PortValidation.defaultRefreshInterval)
  }
}
