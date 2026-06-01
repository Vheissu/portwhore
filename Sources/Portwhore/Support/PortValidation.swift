import Foundation

enum PortValidation {
  static let validPortRange = 1...65535
  static let allowedRefreshIntervals: [TimeInterval] = [2, 5, 10, 30]
  static let defaultRefreshInterval: TimeInterval = 5

  static func normalizedPort(from value: String) -> Int? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let port = Int(trimmed), isValidPort(port) else {
      return nil
    }
    return port
  }

  static func isValidPort(_ port: Int) -> Bool {
    validPortRange.contains(port)
  }

  static func sanitizedPorts(_ ports: [Int]) -> [Int] {
    Array(Set(ports.filter(isValidPort))).sorted()
  }

  static func sanitizedLabel(_ label: String?) -> String? {
    guard let label else {
      return nil
    }

    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  static func normalizedRefreshInterval(_ interval: TimeInterval) -> TimeInterval {
    allowedRefreshIntervals.contains(interval) ? interval : defaultRefreshInterval
  }
}
