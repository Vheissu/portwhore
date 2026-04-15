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
  var lastError: String?
  var lastActionMessage: String?
  var onStatusChange: (() -> Void)?

  // MARK: - UI state

  var searchQuery = ""
  var sortOrder: PortSortOrder = .portNumber
  var showSettings = false
  var confirmKillAll = false
  var editingLabelForPort: Int?
  var editingLabelText = ""

  private let scanner = PortScanner()
  private let processController = ProcessController()
  private var refreshTask: Task<Void, Never>?
  private var clearActionTask: Task<Void, Never>?

  init() {
    refreshTask = Task { [weak self] in
      await self?.refreshLoop()
    }
  }

  // MARK: - Computed: slots & records

  var watchedSlots: [WatchedPortSlot] {
    watchedPorts.map { port in
      WatchedPortSlot(port: port, record: records.first(where: { $0.port == port }))
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

  var protectedCount: Int {
    records.filter { !$0.listeners.allSatisfy(\.isOwnedByCurrentUser) }.count
  }

  var myRecords: [PortRecord] {
    records.filter { $0.listeners.allSatisfy(\.isOwnedByCurrentUser) }
  }

  // MARK: - Filtered & sorted

  var filteredWatchedSlots: [WatchedPortSlot] {
    let slots = watchedSlots
    guard !searchQuery.isEmpty else { return slots }
    let query = searchQuery.lowercased()
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
    guard !searchQuery.isEmpty else { return sorted }
    let query = searchQuery.lowercased()
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
    }
    return false
  }

  private func sortRecords(_ records: [PortRecord]) -> [PortRecord] {
    switch sortOrder {
    case .portNumber:
      return records.sorted { $0.port < $1.port }
    case .processName:
      return records.sorted {
        $0.primary.processName.localizedCaseInsensitiveCompare($1.primary.processName) == .orderedAscending
      }
    case .pid:
      return records.sorted { $0.primary.pid < $1.primary.pid }
    }
  }

  // MARK: - Port actions

  func refreshNow() async {
    guard !isRefreshing else { return }
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
      notifyStatusChange()
    } catch {
      self.lastError = error.localizedDescription
      notifyStatusChange()
    }
  }

  func freePort(_ record: PortRecord, force: Bool = false) {
    Task { await performFreePort(record, force: force) }
  }

  func killAllMyPorts() {
    Task { await performKillAllMyPorts() }
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
    guard !watchedPorts.contains(port) else { return }
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
    if let label, !label.isEmpty {
      portLabels[port] = label
    } else {
      portLabels.removeValue(forKey: port)
    }
    PortwhoreDefaults.portLabels = portLabels
  }

  // MARK: - Refresh interval

  func setRefreshInterval(_ interval: TimeInterval) {
    refreshInterval = interval
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

  private func performFreePort(_ record: PortRecord, force: Bool) async {
    do {
      let processController = self.processController
      let result = try await Task.detached(priority: .userInitiated) {
        try processController.freePort(record, force: force)
      }.value

      if result.failures.isEmpty {
        let verb = force ? "Force-killed" : "Stopped"
        lastActionMessage = "\(verb) \(result.killedPIDs.count) process\(result.killedPIDs.count == 1 ? "" : "es") on \(record.port)."
        scheduleActionClear()
      } else if result.killedPIDs.isEmpty {
        lastError = result.failures.joined(separator: "\n")
      } else {
        lastActionMessage = "Freed part of \(record.port)."
        scheduleActionClear()
        lastError = result.failures.joined(separator: "\n")
      }

      await refreshNow()
    } catch {
      lastError = error.localizedDescription
      notifyStatusChange()
    }
  }

  private func performKillAllMyPorts() async {
    let targets = myRecords
    guard !targets.isEmpty else { return }

    var totalKilled = 0
    var allFailures: [String] = []

    for record in targets {
      do {
        let processController = self.processController
        let result = try await Task.detached(priority: .userInitiated) {
          try processController.freePort(record, force: false)
        }.value
        totalKilled += result.killedPIDs.count
        allFailures.append(contentsOf: result.failures)
      } catch {
        allFailures.append("Port \(record.port): \(error.localizedDescription)")
      }
    }

    if allFailures.isEmpty {
      lastActionMessage = "Stopped \(totalKilled) process\(totalKilled == 1 ? "" : "es") across \(targets.count) port(s)."
    } else {
      lastActionMessage = "Stopped \(totalKilled) process\(totalKilled == 1 ? "" : "es"). \(allFailures.count) failed."
      lastError = allFailures.joined(separator: "\n")
    }
    scheduleActionClear()
    await refreshNow()
  }

  private func refreshLoop() async {
    await refreshNow()
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(refreshInterval))
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
