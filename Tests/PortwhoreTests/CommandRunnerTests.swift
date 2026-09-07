import Testing
@testable import Portwhore

@Suite("Command output", .timeLimit(.minutes(1)))
struct CommandRunnerTests {
  @Test("Drains stdout and stderr beyond pipe capacity")
  func drainsBothPipes() throws {
    let output = try CommandRunner.run(
      executable: "/bin/sh",
      arguments: ["-c", "/usr/bin/head -c 262144 /dev/zero >&2; /usr/bin/head -c 262144 /dev/zero"]
    )
    #expect(output.utf8.count == 262144)
  }

  @Test("Preserves exit status and stderr after large output")
  func capturesFailure() {
    do {
      _ = try CommandRunner.run(
        executable: "/bin/sh",
        arguments: ["-c", "/usr/bin/head -c 262144 /dev/zero; printf 'permission denied' >&2; exit 7"]
      )
      Issue.record("Expected command failure")
    } catch let CommandRunnerError.failed(status, message) {
      #expect(status == 7)
      #expect(message == "permission denied")
    } catch {
      Issue.record(error)
    }
  }
}
