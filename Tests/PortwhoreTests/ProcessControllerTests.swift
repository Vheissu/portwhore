import Foundation
import Testing
@testable import Portwhore

@Suite("Process control", .timeLimit(.minutes(1)))
struct ProcessControllerTests {
  @Test("Reports a stopped process as exited")
  func stopsCooperativeProcess() throws {
    let process = try launch("exec /bin/sleep 30")
    let pid = Int(process.processIdentifier)

    let result = try ProcessController().terminate(pids: [pid], force: false)

    #expect(result.killedPIDs == [pid])
    #expect(result.stillRunningPIDs.isEmpty)
    #expect(result.succeeded)
  }

  @Test("Reports a process that ignores SIGTERM, then force kills it")
  func reportsUnresponsiveProcess() throws {
    let process = try launch("trap '' TERM; while :; do /bin/sleep 1; done")
    let pid = Int(process.processIdentifier)
    defer { kill(pid_t(pid), SIGKILL) }

    let controller = ProcessController(gracePeriod: .milliseconds(300))
    let stop = try controller.terminate(pids: [pid], force: false)
    #expect(stop.stillRunningPIDs == [pid])
    #expect(!stop.succeeded)

    let kill = try controller.terminate(pids: [pid], force: true)
    #expect(kill.stillRunningPIDs.isEmpty)
  }

  @Test("Treats an already-exited PID as freed, not as an error")
  func toleratesMissingProcess() throws {
    let process = try launch("exit 0")
    process.waitUntilExit()
    let pid = Int(process.processIdentifier)

    let result = try ProcessController().terminate(pids: [pid], force: false)
    #expect(result.failures.isEmpty)
    #expect(!ProcessController.isAlive(pid))
  }

  @Test("Never signals launchd")
  func refusesLaunchd() throws {
    let result = try ProcessController().terminate(pids: [1], force: false)
    #expect(result.killedPIDs.isEmpty)
    #expect(result.failures.count == 1)
  }

  private func launch(_ script: String) throws -> Process {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", script]
    try process.run()
    // Give the shell time to install its trap before we signal it.
    Thread.sleep(forTimeInterval: 0.2)
    return process
  }
}
