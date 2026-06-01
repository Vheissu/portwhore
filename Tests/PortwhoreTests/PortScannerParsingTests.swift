import Testing
@testable import Portwhore

@Suite("Port scanner parsing")
struct PortScannerParsingTests {
  @Test("Parses TCP listener lines from lsof")
  func parsesTCPListenerLine() {
    let line = "node 5296 dwayne 13u IPv6 0x40b30dfb5dcfb6cf 0t0 TCP *:3311 (LISTEN)"

    let listener = PortScannerParsing.parse(line: line, transport: .tcp)

    #expect(listener?.processName == "node")
    #expect(listener?.pid == 5296)
    #expect(listener?.user == "dwayne")
    #expect(listener?.port == 3311)
    #expect(listener?.endpoint == "*:3311")
    #expect(listener?.state == "LISTEN")
  }

  @Test("Extracts numeric ports from IPv4 and IPv6 endpoints")
  func extractsNumericPorts() {
    #expect(PortScannerParsing.extractPort(from: "127.0.0.1:9000") == 9000)
    #expect(PortScannerParsing.extractPort(from: "[::1]:5173 (LISTEN)") == 5173)
    #expect(PortScannerParsing.extractPort(from: "*:http") == nil)
  }
}
