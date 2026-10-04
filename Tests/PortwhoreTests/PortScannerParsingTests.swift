import Testing
@testable import Portwhore

@Suite("Port scanner parsing")
struct PortScannerParsingTests {
  @Test("Parses TCP listeners from lsof field output")
  func parsesTCPFieldOutput() {
    let output = """
    p5296
    cnode
    u501
    Ldwayne
    f13
    n*:3311
    TST=LISTEN
    TQR=0
    TQS=0
    f14
    n[::1]:5173
    TST=LISTEN
    """

    let listeners = PortScannerParsing.parseFieldOutput(output, transport: .tcp)

    #expect(listeners.count == 2)
    #expect(listeners[0].processName == "node")
    #expect(listeners[0].pid == 5296)
    #expect(listeners[0].uid == 501)
    #expect(listeners[0].user == "dwayne")
    #expect(listeners[0].port == 3311)
    #expect(listeners[0].endpoint == "*:3311")
    #expect(listeners[0].state == "LISTEN")
    #expect(listeners[1].port == 5173)
  }

  @Test("Keeps full process names, including spaces")
  func keepsFullNames() {
    let output = """
    p723
    cControlCenter
    u501
    Ldwayne
    f10
    n*:5000
    p2580
    cGoogle Chrome Helper
    u501
    Ldwayne
    f68
    n*:5353
    """

    let names = PortScannerParsing.parseFieldOutput(output, transport: .udp).map(\.processName)
    #expect(names == ["ControlCenter", "Google Chrome Helper"])
  }

  @Test("Falls back to the UID when lsof has no login name")
  func fallsBackToUID() {
    let output = "p42\ncdaemon\nu270\nf3\nn*:9000\n"
    let listener = PortScannerParsing.parseFieldOutput(output, transport: .tcp).first
    #expect(listener?.user == "270")
  }

  @Test("Extracts numeric ports from IPv4 and IPv6 endpoints")
  func extractsNumericPorts() {
    #expect(PortScannerParsing.extractPort(from: "127.0.0.1:9000") == 9000)
    #expect(PortScannerParsing.extractPort(from: "[::1]:5173 (LISTEN)") == 5173)
    #expect(PortScannerParsing.extractPort(from: "*:http") == nil)
    #expect(PortScannerParsing.extractPort(from: "*:0") == nil)
    #expect(PortScannerParsing.extractPort(from: "*:65536") == nil)
  }

  @Test("Skips connected UDP sockets and unbound sockets")
  func skipsNonListeningUDP() {
    let output = """
    p2580
    cGoogle Chrome Helper
    u501
    Ldwayne
    f26
    n192.168.50.241:53348->142.250.207.3:443
    f30
    n[::1]:54321->[::1]:443
    f31
    n*:*
    f68
    n*:5353
    """

    let ports = PortScannerParsing.parseFieldOutput(output, transport: .udp).map(\.port)
    #expect(ports == [5353])
  }

  @Test("Recognises macOS system executables")
  func classifiesSystemExecutables() {
    #expect(PortScannerParsing.isSystemExecutable("/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter"))
    #expect(PortScannerParsing.isSystemExecutable("/usr/libexec/rapportd"))
    #expect(PortScannerParsing.isSystemExecutable("/usr/sbin/sshd"))
    #expect(!PortScannerParsing.isSystemExecutable("/opt/homebrew/bin/redis-server"))
    #expect(!PortScannerParsing.isSystemExecutable("/usr/bin/python3"))
    #expect(!PortScannerParsing.isSystemExecutable("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"))
    #expect(!PortScannerParsing.isSystemExecutable(nil))
  }
}
