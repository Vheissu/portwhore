import Foundation

struct ProcessActionResult: Sendable {
  let killedPIDs: [Int]
  let failures: [String]

  var succeeded: Bool {
    !killedPIDs.isEmpty && failures.isEmpty
  }
}

struct ProcessController: Sendable {
  func freePort(_ record: PortRecord, force: Bool) throws -> ProcessActionResult {
    let pids = record.uniquePIDs
    var killed: [Int] = []
    var failures: [String] = []

    for pid in pids {
      do {
        try terminate(pid: pid, force: force)
        killed.append(pid)
      } catch {
        failures.append("PID \(pid): \(error.localizedDescription)")
      }
    }

    return ProcessActionResult(killedPIDs: killed, failures: failures)
  }

  private func terminate(pid: Int, force: Bool) throws {
    let signal = force ? "-KILL" : "-TERM"
    _ = try CommandRunner.run(
      executable: "/bin/kill",
      arguments: [signal, String(pid)]
    )
  }
}
