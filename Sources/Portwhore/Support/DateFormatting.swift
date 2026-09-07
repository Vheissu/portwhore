import Foundation

enum DateFormatting {
  static func relativeString(for date: Date?) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short

    guard let date else {
      return "Starting up"
    }

    if Date().timeIntervalSince(date) < 1 {
      return "Just now"
    }

    return formatter.localizedString(for: date, relativeTo: Date())
  }
}
