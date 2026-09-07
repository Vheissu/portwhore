import Foundation
import Synchronization
import Testing
@testable import Portwhore

@Suite("Dashboard state")
@MainActor
struct PortDashboardStoreTests {
  @Test("Availability requires a successful scan")
  func availability() async {
    let store = PortDashboardStore(startRefreshing: false, scan: { [] })
    #expect(!store.hasCurrentScan)
    await store.refreshNow()
    #expect(store.hasCurrentScan)
  }

  @Test("A failed scan preserves previous records without claiming they are current")
  func scanFailure() async {
    let store = PortDashboardStore(startRefreshing: false, scan: {
      throw CommandRunnerError.failed(status: 1, message: "scan failed")
    })
    store.records = [record(port: 3000)]
    store.lastUpdated = Date()
    await store.refreshNow()
    #expect(store.records.count == 1)
    #expect(!store.hasCurrentScan)
    #expect(store.lastScanError?.contains("scan failed") == true)
  }

  @Test("Action failures survive successful scans and can be dismissed")
  func actionFailure() async throws {
    let store = PortDashboardStore(startRefreshing: false, scan: { [] }, terminate: { _, _ in
      ProcessActionResult(killedPIDs: [], failures: ["PID 42: permission denied"])
    })
    store.freePort(record(port: 3000))
    try await finishAction(store)
    #expect(store.lastActionError == "PID 42: permission denied")
    #expect(store.hasCurrentScan)
    await store.refreshNow()
    #expect(store.lastError == "PID 42: permission denied")
    #expect(store.statusSnapshot.tone == .warning)
    store.dismissActionError()
    #expect(store.lastError == nil)
  }

  @Test("Bulk stop deduplicates PIDs and ignores repeated clicks")
  func deduplicatesActions() async throws {
    let calls = Mutex([[Int]]())
    let store = PortDashboardStore(startRefreshing: false, scan: { [] }, terminate: { pids, _ in
      calls.withLock { $0.append(pids) }
      return ProcessActionResult(killedPIDs: pids, failures: [])
    })
    store.records = [record(port: 3000), record(port: 8080)]
    #expect(store.killableCount == 2)
    #expect(store.killableProcessCount == 1)
    store.killAllMyPorts()
    store.killAllMyPorts()
    store.freePort(record(port: 3000))
    try await finishAction(store)
    #expect(calls.withLock { $0 } == [[42]])
    #expect(store.lastActionMessage == "Sent stop request to 1 process.")
  }

  @Test("Search trims whitespace and finds transports and endpoints")
  func search() {
    let store = PortDashboardStore(startRefreshing: false)
    store.watchedPorts = [3000]
    store.records = [record(port: 3000), record(port: 8080)]
    for query in ["  TCP \n", "127.0.0.1", " server.js ", " 42 "] {
      store.searchQuery = query
      #expect(store.filteredWatchedSlots.count == 1)
      #expect(store.filteredOtherRecords.count == 1)
    }
    store.searchQuery = " \n "
    #expect(store.filteredOtherRecords.count == 1)
    store.searchQuery = "missing"
    #expect(store.filteredOtherRecords.isEmpty)
    #expect(store.filteredWatchedSlots.isEmpty)
  }

  @Test("Tied process and PID sorts keep ports in numeric order")
  func stableSort() {
    let store = PortDashboardStore(startRefreshing: false)
    store.watchedPorts = []
    store.records = [record(port: 8080), record(port: 3000)]
    for order in PortSortOrder.allCases {
      store.sortOrder = order
      #expect(store.filteredOtherRecords.map(\.port) == [3000, 8080])
    }
  }

  private func finishAction(_ store: PortDashboardStore) async throws {
    for _ in 0..<100 where store.isPerformingAction {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(!store.isPerformingAction)
  }

  private func record(port: Int) -> PortRecord {
    PortRecord(port: port, listeners: [PortListener(
      port: port, pid: 42, processName: "node", command: "node server.js",
      user: "test", transport: .tcp, endpoint: "127.0.0.1:\(port)",
      state: "LISTEN", isOwnedByCurrentUser: true
    )])
  }
}
