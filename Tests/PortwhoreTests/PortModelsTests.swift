import Testing
@testable import Portwhore

@Suite("Port models")
struct PortModelsTests {
  @Test("Classifies ownership and deduplicates PIDs")
  func classifiesOwnedRecords() {
    let record = PortRecord(
      port: 3000,
      listeners: [
        listener(pid: 42, user: "dwayne", owned: true),
        listener(pid: 42, user: "dwayne", owned: true, transport: .udp),
        listener(pid: 12, user: "dwayne", owned: true),
      ]
    )

    #expect(record.ownershipTone == .mine)
    #expect(record.uniquePIDs == [12, 42])
    #expect(record.uniqueUsers == ["dwayne"])
    #expect(record.transportLabel == "TCP/UDP")
  }

  @Test("Root listeners are protected")
  func classifiesRootRecordsAsProtected() {
    let record = PortRecord(
      port: 80,
      listeners: [
        listener(pid: 1, user: "root", owned: false),
      ]
    )

    #expect(record.ownershipTone == .protected)
  }

  @Test("Your macOS services are classed as system, not yours")
  func classifiesSystemRecords() {
    var service = listener(pid: 723, user: "dwayne", owned: true)
    service.isSystemService = true
    #expect(PortRecord(port: 5000, listeners: [service]).ownershipTone == .system)
    #expect(PortRecord(port: 5000, listeners: [listener(pid: 9, user: "dwayne", owned: true)]).ownershipTone == .mine)
  }

  private func listener(
    pid: Int,
    user: String,
    owned: Bool,
    transport: NetworkTransport = .tcp
  ) -> PortListener {
    PortListener(
      port: 3000,
      pid: pid,
      processName: "node",
      command: "/usr/local/bin/node server.js",
      user: user,
      transport: transport,
      endpoint: "*:3000",
      state: "LISTEN",
      isOwnedByCurrentUser: owned
    )
  }
}
