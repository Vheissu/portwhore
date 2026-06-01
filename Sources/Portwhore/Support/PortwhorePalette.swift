import SwiftUI

/// Semantic palette. Surfaces and text use system colors so the app adapts to
/// Light / Dark / Increase Contrast and respects the user's accent color.
/// Color is reserved for *meaning* (port ownership), not decoration.
enum PortwhorePalette {
  // MARK: Surfaces

  static let background = Color(nsColor: .windowBackgroundColor)
  static let surface = Color(nsColor: .controlBackgroundColor)
  static let separator = Color(nsColor: .separatorColor)

  // MARK: Text

  static let textSecondary = Color.secondary
  static let textMuted = Color(nsColor: .tertiaryLabelColor)

  // MARK: Interactive — follows System Settings → Appearance accent

  static let accent = Color.accentColor

  // MARK: Ownership semantics
  //
  // green  → every listener is yours, safe to stop
  // orange → shared with another user
  // red    → owned by root / protected
  // muted  → free

  static let mine = Color.green
  static let shared = Color.orange
  static let protected = Color.red
  static let free = Color.secondary
}

extension PortOwnershipTone {
  /// The semantic color that represents this ownership state.
  var color: Color {
    switch self {
    case .mine: return PortwhorePalette.mine
    case .shared: return PortwhorePalette.shared
    case .protected: return PortwhorePalette.protected
    case .free: return PortwhorePalette.free
    }
  }
}
