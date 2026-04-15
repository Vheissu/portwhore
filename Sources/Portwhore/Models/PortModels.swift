import Foundation

enum NetworkTransport: String, Hashable, Sendable {
  case tcp = "TCP"
  case udp = "UDP"
}

enum PortOwnershipTone: Sendable {
  case free
  case mine
  case shared
  case protected
}

struct PortListener: Identifiable, Hashable, Sendable {
  let port: Int
  let pid: Int
  let processName: String
  let command: String
  let user: String
  let transport: NetworkTransport
  let endpoint: String
  let state: String?
  let isOwnedByCurrentUser: Bool

  var id: String {
    "\(transport.rawValue)-\(port)-\(pid)"
  }

  var trimmedCommand: String {
    let compact = command.replacingOccurrences(of: "\n", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if compact.isEmpty {
      return processName
    }
    return compact
  }
}

struct PortRecord: Identifiable, Hashable, Sendable {
  let port: Int
  let listeners: [PortListener]

  var id: Int {
    port
  }

  var primary: PortListener {
    listeners[0]
  }

  var hasMultipleListeners: Bool {
    listeners.count > 1
  }

  var uniqueUsers: [String] {
    Array(Set(listeners.map(\.user))).sorted()
  }

  var uniquePIDs: [Int] {
    Array(Set(listeners.map(\.pid))).sorted()
  }

  var ownershipTone: PortOwnershipTone {
    guard !listeners.isEmpty else {
      return .free
    }

    if listeners.allSatisfy(\.isOwnedByCurrentUser) {
      return .mine
    }

    if listeners.contains(where: { $0.user == "root" }) {
      return .protected
    }

    return .shared
  }

  var primaryActionTitle: String {
    hasMultipleListeners ? "Free Port" : "Stop"
  }

  var displayTitle: String {
    if hasMultipleListeners {
      return "\(primary.processName) +\(listeners.count - 1)"
    }
    return primary.processName
  }

  var subtitle: String {
    let userLabel = uniqueUsers.joined(separator: ", ")
    if hasMultipleListeners {
      return "\(uniquePIDs.count) processes • \(userLabel)"
    }
    return "PID \(primary.pid) • \(userLabel)"
  }
}

struct WatchedPortSlot: Identifiable, Hashable, Sendable {
  let port: Int
  let record: PortRecord?

  var id: Int {
    port
  }
}
