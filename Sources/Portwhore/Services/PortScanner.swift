import Darwin
import Foundation

struct PortScanner: Sendable {
  // -F emits one field per line, so names with spaces parse cleanly and +c 0
  // keeps them untruncated ("ControlCenter", not "ControlCe").
  private static let fieldArguments = ["-nP", "+c", "0", "-F", "pcuLnT"]

  func scan() throws -> [PortRecord] {
    let currentUID = Int(getuid())
    let tcpListeners = try readListeners(arguments: ["-iTCP", "-sTCP:LISTEN"], transport: .tcp)
    let udpListeners = try readListeners(arguments: ["-iUDP"], transport: .udp)
    let merged = deduplicate(tcpListeners + udpListeners)
    let pids = Set(merged.map(\.pid))
    let commandsByPID = try lookupCommands(for: pids)
    let pathsByPID = Dictionary(uniqueKeysWithValues: pids.map { ($0, Self.executablePath(for: $0)) })

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
        isOwnedByCurrentUser: raw.uid == currentUID,
        isSystemService: PortScannerParsing.isSystemExecutable(pathsByPID[raw.pid] ?? nil)
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
      output = try CommandRunner.run(
        executable: "/usr/sbin/lsof",
        arguments: Self.fieldArguments + arguments
      )
    } catch let CommandRunnerError.failed(status, message) where status == 1 && message.isEmpty {
      return []
    }

    return PortScannerParsing.parseFieldOutput(output, transport: transport)
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
    let output: String
    do {
      output = try CommandRunner.run(
        executable: "/bin/ps",
        arguments: ["-o", "pid=", "-o", "command=", "-p", pidList]
      )
    } catch let CommandRunnerError.failed(status, _) where status == 1 {
      return [:]
    }

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

  /// The real executable path; unlike argv it can't be rewritten by the process.
  private static func executablePath(for pid: Int) -> String? {
    var buffer = [UInt8](repeating: 0, count: Int(MAXPATHLEN) * 4)
    let length = proc_pidpath(Int32(pid), &buffer, UInt32(buffer.count))
    guard length > 0 else { return nil }
    return String(decoding: buffer.prefix(Int(length)), as: UTF8.self)
  }
}

enum PortScannerParsing {
  private static let systemPathPrefixes = ["/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/"]

  /// Parses `lsof -F pcuLnT` output. Each `p` line starts a process; each `n`
  /// line is one of its sockets, followed by that socket's `T` state fields.
  static func parseFieldOutput(_ output: String, transport: NetworkTransport) -> [RawPortListener] {
    var listeners: [RawPortListener] = []
    var pid: Int?
    var processName = ""
    var uid: Int?
    var login: String?
    var endpoint: String?
    var state: String?

    func flushSocket() {
      defer {
        endpoint = nil
        state = nil
      }
      guard let pid, let uid, let endpoint,
            let listener = makeListener(
              pid: pid, processName: processName, uid: uid, login: login,
              endpoint: endpoint, state: state, transport: transport
            ) else {
        return
      }
      listeners.append(listener)
    }

    for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
      guard let field = line.first else { continue }
      let value = String(line.dropFirst())

      switch field {
      case "p":
        flushSocket()
        pid = Int(value)
        processName = ""
        uid = nil
        login = nil
      case "c":
        processName = value
      case "u":
        uid = Int(value)
      case "L":
        login = value
      case "f":
        flushSocket()
      case "n":
        endpoint = value
      case "T":
        if value.hasPrefix("ST=") {
          state = String(value.dropFirst(3))
        }
      default:
        continue
      }
    }
    flushSocket()

    return listeners
  }

  private static func makeListener(
    pid: Int,
    processName: String,
    uid: Int,
    login: String?,
    endpoint: String,
    state: String?,
    transport: NetworkTransport
  ) -> RawPortListener? {
    // A connected UDP socket (local->remote) is an outbound client such as a
    // browser's QUIC connection, not something listening for you.
    guard !endpoint.contains("->"), let port = extractPort(from: endpoint) else {
      return nil
    }

    return RawPortListener(
      port: port,
      pid: pid,
      processName: processName.isEmpty ? "PID \(pid)" : processName,
      uid: uid,
      user: login ?? String(uid),
      transport: transport,
      endpoint: cleanEndpoint(endpoint),
      state: state ?? extractState(from: endpoint)
    )
  }

  static func isSystemExecutable(_ path: String?) -> Bool {
    guard let path else { return false }
    return systemPathPrefixes.contains { path.hasPrefix($0) }
  }

  static func cleanEndpoint(_ endpoint: String) -> String {
    if let range = endpoint.range(of: " (") {
      return String(endpoint[..<range.lowerBound])
    }
    return endpoint
  }

  static func extractPort(from endpoint: String) -> Int? {
    let trimmed = cleanEndpoint(endpoint).components(separatedBy: "->")[0]
    guard let range = trimmed.range(of: #":(\d+)$"#, options: .regularExpression) else {
      return nil
    }

    let value = trimmed[range].dropFirst()
    guard let port = Int(value), PortValidation.isValidPort(port) else { return nil }
    return port
  }

  static func extractState(from endpoint: String) -> String? {
    guard let range = endpoint.range(of: #"\(([^)]+)\)"#, options: .regularExpression) else {
      return nil
    }

    return String(endpoint[range])
      .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
  }
}

struct RawPortListener: Hashable, Sendable {
  let port: Int
  let pid: Int
  let processName: String
  let uid: Int
  let user: String
  let transport: NetworkTransport
  let endpoint: String
  let state: String?
}
