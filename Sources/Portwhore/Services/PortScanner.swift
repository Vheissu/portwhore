import Foundation

struct PortScanner: Sendable {
  func scan() throws -> [PortRecord] {
    let currentUser = NSUserName()
    let tcpListeners = try readListeners(arguments: ["-nP", "-iTCP", "-sTCP:LISTEN"], transport: .tcp)
    let udpListeners = try readListeners(arguments: ["-nP", "-iUDP"], transport: .udp)
    let merged = deduplicate(tcpListeners + udpListeners)
    let commandsByPID = try lookupCommands(for: Set(merged.map(\.pid)))

    let listeners = merged.map { raw in
      PortListener(
        port: raw.port,
        pid: raw.pid,
        processName: raw.processName,
        command: commandsByPID[raw.pid] ?? raw.processName,
        user: raw.user,
        transport: raw.transport,
        endpoint: raw.endpoint,
        state: raw.state,
        isOwnedByCurrentUser: raw.user == currentUser
      )
    }

    let grouped = Dictionary(grouping: listeners, by: \.port)

    return grouped.keys.sorted().compactMap { port in
      guard let records = grouped[port], !records.isEmpty else {
        return nil
      }

      let sortedListeners = records.sorted {
        if $0.isOwnedByCurrentUser != $1.isOwnedByCurrentUser {
          return $0.isOwnedByCurrentUser && !$1.isOwnedByCurrentUser
        }

        if $0.processName != $1.processName {
          return $0.processName.localizedCaseInsensitiveCompare($1.processName) == .orderedAscending
        }

        return $0.pid < $1.pid
      }

      return PortRecord(port: port, listeners: sortedListeners)
    }
  }

  private func readListeners(arguments: [String], transport: NetworkTransport) throws -> [RawPortListener] {
    let output: String
    do {
      output = try CommandRunner.run(executable: "/usr/sbin/lsof", arguments: arguments)
    } catch let CommandRunnerError.failed(status, _) where status == 1 {
      return []
    }

    let lines = output.split(separator: "\n", omittingEmptySubsequences: true)

    guard lines.count > 1 else {
      return []
    }

    return lines.dropFirst().compactMap { line in
      parse(line: String(line), transport: transport)
    }
  }

  private func parse(line: String, transport: NetworkTransport) -> RawPortListener? {
    let columns = line.split(
      maxSplits: 8,
      omittingEmptySubsequences: true,
      whereSeparator: \.isWhitespace
    )

    guard columns.count >= 9, let pid = Int(columns[1]) else {
      return nil
    }

    let processName = String(columns[0])
    let user = String(columns[2])
    let endpoint = String(columns[8])

    guard let port = Self.extractPort(from: endpoint) else {
      return nil
    }

    return RawPortListener(
      port: port,
      pid: pid,
      processName: processName,
      user: user,
      transport: transport,
      endpoint: Self.cleanEndpoint(endpoint),
      state: Self.extractState(from: endpoint)
    )
  }

  private static func cleanEndpoint(_ endpoint: String) -> String {
    if let range = endpoint.range(of: " (") {
      return String(endpoint[..<range.lowerBound])
    }
    return endpoint
  }

  private static func extractPort(from endpoint: String) -> Int? {
    let trimmed = cleanEndpoint(endpoint)
    guard let range = trimmed.range(of: #":(\d+)$"#, options: .regularExpression) else {
      return nil
    }

    let value = trimmed[range].dropFirst()
    return Int(value)
  }

  private static func extractState(from endpoint: String) -> String? {
    guard let range = endpoint.range(of: #"\(([^)]+)\)"#, options: .regularExpression) else {
      return nil
    }

    return String(endpoint[range])
      .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
  }

  private func deduplicate(_ listeners: [RawPortListener]) -> [RawPortListener] {
    var seen = Set<String>()
    var unique: [RawPortListener] = []

    for listener in listeners {
      let key = "\(listener.transport.rawValue)-\(listener.port)-\(listener.pid)"
      if seen.insert(key).inserted {
        unique.append(listener)
      }
    }

    return unique
  }

  private func lookupCommands(for pids: Set<Int>) throws -> [Int: String] {
    guard !pids.isEmpty else {
      return [:]
    }

    let pidList = pids.sorted().map(String.init).joined(separator: ",")
    let output = try CommandRunner.run(
      executable: "/bin/ps",
      arguments: ["-o", "pid=", "-o", "command=", "-p", pidList]
    )

    var commandsByPID: [Int: String] = [:]

    for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      let columns = trimmed.split(
        maxSplits: 1,
        omittingEmptySubsequences: true,
        whereSeparator: \.isWhitespace
      )

      guard let pidText = columns.first, let pid = Int(pidText) else {
        continue
      }

      let command = columns.count > 1 ? String(columns[1]) : ""
      commandsByPID[pid] = command
    }

    return commandsByPID
  }
}

private struct RawPortListener: Hashable, Sendable {
  let port: Int
  let pid: Int
  let processName: String
  let user: String
  let transport: NetworkTransport
  let endpoint: String
  let state: String?
}
