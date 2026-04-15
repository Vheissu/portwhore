import Foundation

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
    process.waitUntilExit()

    let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
    let errorData = stderr.fileHandleForReading.readDataToEndOfFile()

    let output = String(decoding: outputData, as: UTF8.self)
    let errorOutput = String(decoding: errorData, as: UTF8.self)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard process.terminationStatus == 0 else {
      throw CommandRunnerError.failed(status: process.terminationStatus, message: errorOutput)
    }

    return output
  }
}
