import Foundation
import Observation

@MainActor
@Observable
final class PortDashboardStore {
  let watchedPorts = [3000, 3001, 5173, 5432, 6379, 8000, 8080, 8081, 9000, 9229]

  var records: [PortRecord] = []
  var isRefreshing = false
  var lastUpdated: Date?
  var lastError: String?
  var lastActionMessage: String?

  private let scanner = PortScanner()
  private let processController = ProcessController()
  private var refreshTask: Task<Void, Never>?

  init() {
    refreshTask = Task { [weak self] in
      await self?.refreshLoop()
    }
  }

  var watchedSlots: [WatchedPortSlot] {
    watchedPorts.map { port in
      WatchedPortSlot(
        port: port,
        record: records.first(where: { $0.port == port })
      )
    }
  }

  var occupiedWatchedPorts: [Int] {
    watchedSlots.compactMap { slot in
      slot.record == nil ? nil : slot.port
    }
  }

  var otherRecords: [PortRecord] {
    records.filter { !watchedPorts.contains($0.port) }
  }

  var killableCount: Int {
    records.filter { $0.listeners.allSatisfy(\.isOwnedByCurrentUser) }.count
  }

  var protectedCount: Int {
    records.filter { !$0.listeners.allSatisfy(\.isOwnedByCurrentUser) }.count
  }

  func refreshNow() async {
    guard !isRefreshing else {
      return
    }

    isRefreshing = true
    defer { isRefreshing = false }

    do {
      let scanner = self.scanner
      let records = try await Task.detached(priority: .userInitiated) {
        try scanner.scan()
      }.value

      self.records = records
      self.lastUpdated = Date()
      self.lastError = nil
    } catch {
      self.lastError = error.localizedDescription
    }
  }

  func freePort(_ record: PortRecord, force: Bool = false) {
    Task {
      await performFreePort(record, force: force)
    }
  }

  private func performFreePort(_ record: PortRecord, force: Bool) async {
    do {
      let processController = self.processController
      let result = try await Task.detached(priority: .userInitiated) {
        try processController.freePort(record, force: force)
      }.value

      if result.failures.isEmpty {
        let verb = force ? "Force-killed" : "Stopped"
        lastActionMessage = "\(verb) \(result.killedPIDs.count) process" + (result.killedPIDs.count == 1 ? "" : "es") + " on \(record.port)."
      } else if result.killedPIDs.isEmpty {
        lastError = result.failures.joined(separator: "\n")
      } else {
        lastActionMessage = "Freed part of \(record.port)."
        lastError = result.failures.joined(separator: "\n")
      }

      await refreshNow()
    } catch {
      lastError = error.localizedDescription
    }
  }

  private func refreshLoop() async {
    await refreshNow()

    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(5))
      await refreshNow()
    }
  }
}
