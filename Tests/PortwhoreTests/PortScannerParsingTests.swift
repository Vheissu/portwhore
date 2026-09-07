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
    #expect(PortScannerParsing.extractPort(from: "*:0") == nil)
    #expect(PortScannerParsing.extractPort(from: "*:65536") == nil)
  }

  @Test("Connected UDP sockets are grouped by their local port")
  func parsesConnectedUDP() {
    let line = "client 5296 dwayne 13u IPv4 0x40b30dfb5dcfb6cf 0t0 UDP 127.0.0.1:54321->127.0.0.1:443"
    let listener = PortScannerParsing.parse(line: line, transport: .udp)
    #expect(listener?.port == 54321)
    #expect(listener?.endpoint == "127.0.0.1:54321->127.0.0.1:443")
    #expect(PortScannerParsing.extractPort(from: "[::1]:54321->[::1]:443") == 54321)
    #expect(PortScannerParsing.extractPort(from: "*:54321->*:*") == 54321)
    #expect(PortScannerParsing.extractPort(from: "*:*->127.0.0.1:443") == nil)
  }
}
