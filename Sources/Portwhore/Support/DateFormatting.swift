import Foundation

enum DateFormatting {
  static func relativeString(for date: Date?) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short

    guard let date else {
      return "Starting up"
    }

    return formatter.localizedString(for: date, relativeTo: Date())
  }
}
