import Darwin
import Foundation

struct ProcessActionResult: Sendable {
  /// Signalled successfully (or already gone).
  let killedPIDs: [Int]
  let failures: [String]
  /// Signalled, but still alive once the grace period ran out.
  var stillRunningPIDs: [Int] = []

  var succeeded: Bool {
    !killedPIDs.isEmpty && failures.isEmpty && stillRunningPIDs.isEmpty
  }
}

struct ProcessController: Sendable {
  var gracePeriod: Duration = .milliseconds(1500)

  func freePort(_ record: PortRecord, force: Bool) throws -> ProcessActionResult {
    try terminate(pids: record.uniquePIDs, force: force)
  }

  func terminate(pids: [Int], force: Bool) throws -> ProcessActionResult {
    let pids = Array(Set(pids)).sorted()
    var signalled: [Int] = []
    var failures: [String] = []

    for pid in pids {
      if let failure = Self.signal(pid: pid, force: force) {
        failures.append(failure)
      } else {
        signalled.append(pid)
      }
    }

    let survivors = waitForExit(of: signalled, timeout: force ? .milliseconds(500) : gracePeriod)
    return ProcessActionResult(killedPIDs: signalled, failures: failures, stillRunningPIDs: survivors)
  }

  /// Returns a failure message, or nil when the signal was delivered.
  private static func signal(pid: Int, force: Bool) -> String? {
    guard pid > 1 else {
      return "PID \(pid): refusing to signal a system root process."
    }

    if Darwin.kill(pid_t(pid), force ? SIGKILL : SIGTERM) == 0 {
      return nil
    }

    switch errno {
    case ESRCH:
      // Already exited: the port is free, which is what was asked for.
      return nil
    case EPERM:
      return "PID \(pid): permission denied. It belongs to another user; use Copy Kill Command and run it with sudo."
    case let code:
      return "PID \(pid): \(String(cString: strerror(code)))"
    }
  }

  private func waitForExit(of pids: [Int], timeout: Duration) -> [Int] {
    var remaining = pids
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)

    while !remaining.isEmpty {
      remaining.removeAll { !Self.isAlive($0) }
      guard !remaining.isEmpty, clock.now < deadline else { break }
      Thread.sleep(forTimeInterval: 0.1)
    }

    return remaining
  }

  static func isAlive(_ pid: Int) -> Bool {
    if Darwin.kill(pid_t(pid), 0) != 0 && errno != EPERM {
      return false
    }

    // An exited child whose parent hasn't reaped it yet still answers kill(0);
    // it no longer holds any sockets, so count it as gone.
    var info = proc_bsdinfo()
    let size = Int32(MemoryLayout<proc_bsdinfo>.size)
    if proc_pidinfo(Int32(pid), PROC_PIDTBSDINFO, 0, &info, size) == size {
      return info.pbi_status != UInt32(SZOMB)
    }
    return true
  }
}
