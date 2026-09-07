import Foundation
import Observation

@MainActor
@Observable
final class PortDashboardStore {
  // MARK: - Persisted settings

  var watchedPorts: [Int] = PortwhoreDefaults.watchedPorts
  var portLabels: [Int: String] = PortwhoreDefaults.portLabels
  var refreshInterval: TimeInterval = PortwhoreDefaults.refreshInterval

  // MARK: - Live state

  var records: [PortRecord] = []
  var isRefreshing = false
  var lastUpdated: Date?
  var lastScanError: String?
  var lastActionError: String?
  var isPerformingAction = false

  var lastError: String? {
    let errors = [lastScanError, lastActionError].compactMap { $0 }
    return errors.isEmpty ? nil : errors.joined(separator: "\n")
  }

  var hasCurrentScan: Bool { lastUpdated != nil && lastScanError == nil }
  var lastActionMessage: String?
  var onStatusChange: (() -> Void)?

  // MARK: - UI state

  var searchQuery = ""
  var sortOrder: PortSortOrder = .portNumber
  var showSettings = false
  var confirmKillAll = false
  var editingLabelForPort: Int?
  var editingLabelText = ""

  private let scan: @Sendable () throws -> [PortRecord]
  private let terminate: @Sendable ([Int], Bool) throws -> ProcessActionResult
  private var refreshTask: Task<Void, Never>?
  private var clearActionTask: Task<Void, Never>?

  init(
    startRefreshing: Bool = true,
    scan: @escaping @Sendable () throws -> [PortRecord] = { try PortScanner().scan() },
    terminate: @escaping @Sendable ([Int], Bool) throws -> ProcessActionResult = {
      try ProcessController().terminate(pids: $0, force: $1)
    }
  ) {
    self.scan = scan
    self.terminate = terminate
    if startRefreshing { restartRefreshLoop() }
  }

  // MARK: - Computed: slots & records

  var watchedSlots: [WatchedPortSlot] {
    let recordsByPort = Dictionary(records.map { ($0.port, $0) }, uniquingKeysWith: { first, _ in first })
    return watchedPorts.map { port in
      WatchedPortSlot(port: port, record: recordsByPort[port])
    }
  }

  var occupiedWatchedPorts: [Int] {
    watchedSlots.compactMap { $0.record == nil ? nil : $0.port }
  }

  var otherRecords: [PortRecord] {
    records.filter { !watchedPorts.contains($0.port) }
  }

  var killableCount: Int {
    records.filter { $0.listeners.allSatisfy(\.isOwnedByCurrentUser) }.count
  }

  var killableProcessCount: Int {
    Set(myRecords.flatMap(\.uniquePIDs)).count
  }

  var protectedCount: Int {
    records.filter { !$0.listeners.allSatisfy(\.isOwnedByCurrentUser) }.count
  }

  var myRecords: [PortRecord] {
    records.filter { $0.listeners.allSatisfy(\.isOwnedByCurrentUser) }
  }

  // MARK: - Filtered & sorted

  var normalizedSearchQuery: String {
    searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  var filteredWatchedSlots: [WatchedPortSlot] {
    let slots = watchedSlots
    guard !normalizedSearchQuery.isEmpty else { return slots }
    let query = normalizedSearchQuery
    return slots.filter { slot in
      if String(slot.port).contains(query) { return true }
      if let label = portLabels[slot.port], label.lowercased().contains(query) { return true }
      if let desc = WellKnownPorts.description(for: slot.port), desc.lowercased().contains(query) { return true }
      guard let record = slot.record else { return false }
      return matchesSearch(record, query: query)
    }
  }

  var filteredOtherRecords: [PortRecord] {
    let sorted = sortRecords(otherRecords)
    guard !normalizedSearchQuery.isEmpty else { return sorted }
    let query = normalizedSearchQuery
    return sorted.filter { matchesSearch($0, query: query) }
  }

  private func matchesSearch(_ record: PortRecord, query: String) -> Bool {
    if String(record.port).contains(query) { return true }
    if let label = portLabels[record.port], label.lowercased().contains(query) { return true }
    if let desc = WellKnownPorts.description(for: record.port), desc.lowercased().contains(query) { return true }
    for listener in record.listeners {
      if listener.processName.lowercased().contains(query) { return true }
      if String(listener.pid).contains(query) { return true }
      if listener.user.lowercased().contains(query) { return true }
      if listener.command.lowercased().contains(query) { return true }
      if listener.transport.rawValue.lowercased().contains(query) { return true }
      if listener.endpoint.lowercased().contains(query) { return true }
    }
    return false
  }

  private func sortRecords(_ records: [PortRecord]) -> [PortRecord] {
    switch sortOrder {
    case .portNumber:
      return records.sorted { $0.port < $1.port }
    case .processName:
      return records.sorted {
        let comparison = $0.primary.processName.localizedCaseInsensitiveCompare($1.primary.processName)
        return comparison == .orderedSame ? $0.port < $1.port : comparison == .orderedAscending
      }
    case .pid:
      return records.sorted { ($0.primary.pid, $0.port) < ($1.primary.pid, $1.port) }
    }
  }

  // MARK: - Port actions

  func refreshNow() async {
    guard !isRefreshing else { return }
    isRefreshing = true
    defer { isRefreshing = false }

    do {
      let scan = self.scan
      let records = try await Task.detached(priority: .userInitiated) {
        try scan()
      }.value
      self.records = records
      self.lastUpdated = Date()
      self.lastScanError = nil
      notifyStatusChange()
    } catch {
      self.lastScanError = error.localizedDescription
      notifyStatusChange()
    }
  }

  func freePort(_ record: PortRecord, force: Bool = false) {
    guard !isPerformingAction else { return }
    isPerformingAction = true
    Task {
      defer { isPerformingAction = false }
      await performTermination(pids: record.uniquePIDs, force: force)
    }
  }

  func killAllMyPorts() {
    guard !isPerformingAction, !myRecords.isEmpty else { return }
    let pids = Array(Set(myRecords.flatMap(\.uniquePIDs))).sorted()
    isPerformingAction = true
    Task {
      defer { isPerformingAction = false }
      await performTermination(pids: pids, force: false)
    }
  }

  // MARK: - Export

  func exportPortList() {
    var lines: [String] = ["Port\tProcess\tPID\tUser\tTransport\tEndpoint\tCommand"]
    for record in records {
      for listener in record.listeners {
        let label = portLabels[record.port].map { " (\($0))" } ?? ""
        lines.append(
          "\(listener.port)\(label)\t\(listener.processName)\t\(listener.pid)\t\(listener.user)\t\(listener.transport.rawValue)\t\(listener.endpoint)\t\(listener.trimmedCommand)"
        )
      }
    }
    Pasteboard.copy(lines.joined(separator: "\n"))
    lastActionMessage = "Copied \(records.count) port(s) to clipboard."
    scheduleActionClear()
  }

  // MARK: - Watched port management

  func addWatchedPort(_ port: Int) {
    guard PortValidation.isValidPort(port), !watchedPorts.contains(port) else { return }
    watchedPorts.append(port)
    watchedPorts.sort()
    PortwhoreDefaults.watchedPorts = watchedPorts
  }

  func removeWatchedPort(_ port: Int) {
    watchedPorts.removeAll { $0 == port }
    PortwhoreDefaults.watchedPorts = watchedPorts
  }

  func resetWatchedPorts() {
    PortwhoreDefaults.resetToDefaults()
    watchedPorts = PortwhoreDefaults.watchedPorts
    portLabels = PortwhoreDefaults.portLabels
    refreshInterval = PortwhoreDefaults.refreshInterval
    restartRefreshLoop()
  }

  // MARK: - Labels

  func setPortLabel(_ port: Int, label: String?) {
    guard PortValidation.isValidPort(port) else {
      return
    }

    if let label = PortValidation.sanitizedLabel(label) {
      portLabels[port] = label
    } else {
      portLabels.removeValue(forKey: port)
    }
    PortwhoreDefaults.portLabels = portLabels
  }

  // MARK: - Refresh interval

  func setRefreshInterval(_ interval: TimeInterval) {
    refreshInterval = PortValidation.normalizedRefreshInterval(interval)
    PortwhoreDefaults.refreshInterval = interval
    restartRefreshLoop()
  }

  // MARK: - Status

  var statusSnapshot: PortwhoreStatusSnapshot {
    let tone: PortwhoreStatusTone
    if lastError != nil {
      tone = .warning
    } else if !records.isEmpty || !occupiedWatchedPorts.isEmpty {
      tone = .active
    } else {
      tone = .idle
    }

    let text: String
    if lastError != nil {
      text = "!"
    } else if !records.isEmpty {
      text = records.count > 99 ? "99+" : "\(records.count)"
    } else if !occupiedWatchedPorts.isEmpty {
      text = occupiedWatchedPorts.count > 99 ? "99+" : "\(occupiedWatchedPorts.count)"
    } else {
      text = "PW"
    }

    let accessibilityLabel: String
    switch tone {
    case .idle:
      accessibilityLabel = "Portwhore idle"
    case .active:
      accessibilityLabel = "Portwhore active with \(text) busy ports"
    case .warning:
      accessibilityLabel = "Portwhore warning"
    }

    return PortwhoreStatusSnapshot(
      tone: tone,
      text: text,
      accessibilityLabel: accessibilityLabel
    )
  }

  // MARK: - Private

  func dismissActionError() {
    lastActionError = nil
    notifyStatusChange()
  }

  private func performTermination(pids: [Int], force: Bool) async {
    lastActionError = nil
    lastActionMessage = nil
    clearActionTask?.cancel()
    do {
      let terminate = self.terminate
      let result = try await Task.detached(priority: .userInitiated) {
        try terminate(pids, force)
      }.value

      if !result.killedPIDs.isEmpty {
        let count = result.killedPIDs.count
        let action = force ? "force-kill" : "stop"
        lastActionMessage = "Sent \(action) request to \(count) process\(count == 1 ? "" : "es")."
        scheduleActionClear()
      }
      if !result.failures.isEmpty {
        lastActionError = result.failures.joined(separator: "\n")
      }
      notifyStatusChange()
      await refreshNow()
    } catch {
      lastActionError = error.localizedDescription
      notifyStatusChange()
    }
  }

  private func refreshLoop() async {
    await refreshNow()
    while !Task.isCancelled {
      do {
        try await Task.sleep(for: .seconds(refreshInterval))
      } catch {
        break
      }
      await refreshNow()
    }
  }

  private func restartRefreshLoop() {
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
      await self?.refreshLoop()
    }
  }

  private func scheduleActionClear() {
    clearActionTask?.cancel()
    clearActionTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(3))
      guard !Task.isCancelled else { return }
      self?.lastActionMessage = nil
    }
  }

  private func notifyStatusChange() {
    onStatusChange?()
  }
}
