import Foundation
import Synchronization

enum CommandRunnerError: LocalizedError {
  case failed(status: Int32, message: String)

  var errorDescription: String? {
    switch self {
    case let .failed(status, message):
      let detail = message.isEmpty ? "The command returned a non-zero exit status." : message
      return "Command failed (\(status)): \(detail)"
    }
  }
}

enum CommandRunner {
  static func run(executable: String, arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()

    // Drain both pipes while the child runs: either pipe can fill and block it.
    let capturedError = Mutex(Data())
    let readers = DispatchGroup()
    readers.enter()
    DispatchQueue.global(qos: .utility).async {
      let data = stderr.fileHandleForReading.readDataToEndOfFile()
      capturedError.withLock { $0 = data }
      readers.leave()
    }

    let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    readers.wait()
    let errorData = capturedError.withLock { $0 }

    let output = String(decoding: outputData, as: UTF8.self)
    let errorOutput = String(decoding: errorData, as: UTF8.self)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard process.terminationStatus == 0 else {
      throw CommandRunnerError.failed(status: process.terminationStatus, message: errorOutput)
    }

    return output
  }
}
