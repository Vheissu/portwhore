import AppKit

enum PortwhoreStatusTone: Sendable {
  case idle
  case active
  case warning
}

struct PortwhoreStatusSnapshot: Sendable {
  let tone: PortwhoreStatusTone
  let text: String
  let accessibilityLabel: String
}

/// The menu-bar glyph: a lipstick kiss. Deliberately cheeky — it's the brand.
/// Drawn in color (not a template image) so the joke survives in light and dark
/// menu bars. Lit and saturated when ports are active, a muted dusty rose when idle.
enum PortwhoreStatusImage {
  // Active: a classic lipstick red — rich, not fire-engine neon.
  private static let lipsActive = NSColor(red: 0.85, green: 0.11, blue: 0.23, alpha: 1.0)
  private static let seamActive = NSColor(red: 0.48, green: 0.03, blue: 0.12, alpha: 1.0)
  // Idle: desaturated, slightly transparent — clearly "asleep".
  private static let lipsIdle = NSColor(red: 0.52, green: 0.34, blue: 0.39, alpha: 0.82)
  private static let seamIdle = NSColor(red: 0.32, green: 0.18, blue: 0.22, alpha: 0.82)
  private static let shine = NSColor.white.withAlphaComponent(0.22)

  static func make(tone: PortwhoreStatusTone) -> NSImage {
    let size = NSSize(width: 22, height: 18)
    let image = NSImage(size: size, flipped: false) { rect in
      NSColor.clear.setFill()
      rect.fill()

      let isLit = tone != .idle
      let lips = isLit ? lipsActive : lipsIdle
      let seam = isLit ? seamActive : seamIdle

      // -- Upper lip: symmetric cupid's bow around center x = 11 --
      let upper = NSBezierPath()
      upper.move(to: NSPoint(x: 2, y: 9))
      upper.curve(to: NSPoint(x: 7, y: 14.8),
                  controlPoint1: NSPoint(x: 2, y: 12.6),
                  controlPoint2: NSPoint(x: 4.4, y: 14.8))
      upper.curve(to: NSPoint(x: 11, y: 11.7),
                  controlPoint1: NSPoint(x: 9.2, y: 14.8),
                  controlPoint2: NSPoint(x: 10.1, y: 11.7))
      upper.curve(to: NSPoint(x: 15, y: 14.8),
                  controlPoint1: NSPoint(x: 11.9, y: 11.7),
                  controlPoint2: NSPoint(x: 12.8, y: 14.8))
      upper.curve(to: NSPoint(x: 20, y: 9),
                  controlPoint1: NSPoint(x: 17.6, y: 14.8),
                  controlPoint2: NSPoint(x: 20, y: 12.6))
      upper.curve(to: NSPoint(x: 2, y: 9),
                  controlPoint1: NSPoint(x: 15, y: 7.7),
                  controlPoint2: NSPoint(x: 7, y: 7.7))
      upper.close()

      // -- Lower lip: full and rounded --
      let lower = NSBezierPath()
      lower.move(to: NSPoint(x: 2.6, y: 8.4))
      lower.curve(to: NSPoint(x: 19.4, y: 8.4),
                  controlPoint1: NSPoint(x: 7.6, y: 7.4),
                  controlPoint2: NSPoint(x: 14.4, y: 7.4))
      lower.curve(to: NSPoint(x: 11, y: 2),
                  controlPoint1: NSPoint(x: 19.4, y: 4.6),
                  controlPoint2: NSPoint(x: 15.6, y: 2))
      lower.curve(to: NSPoint(x: 2.6, y: 8.4),
                  controlPoint1: NSPoint(x: 6.4, y: 2),
                  controlPoint2: NSPoint(x: 2.6, y: 4.6))
      lower.close()

      lips.setFill()
      upper.fill()
      lower.fill()

      // -- Mouth seam: a single thin parting line --
      let mouth = NSBezierPath()
      mouth.move(to: NSPoint(x: 3, y: 8.7))
      mouth.curve(to: NSPoint(x: 19, y: 8.7),
                  controlPoint1: NSPoint(x: 8, y: 7.7),
                  controlPoint2: NSPoint(x: 14, y: 7.7))
      seam.setStroke()
      mouth.lineWidth = 0.9
      mouth.lineCapStyle = .round
      mouth.stroke()

      // -- Soft gloss on the lower lip --
      shine.setFill()
      NSBezierPath(ovalIn: NSRect(x: 8.5, y: 3.4, width: 5, height: 2.2)).fill()

      // -- Status accent: a small dot with a cohesive dark-red ring --
      switch tone {
      case .idle:
        break
      case .active, .warning:
        let dotColor: NSColor = tone == .active ? .systemGreen : .systemYellow
        let center = NSPoint(x: 18, y: 14)
        seamActive.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 3.1, y: center.y - 3.1, width: 6.2, height: 6.2)).fill()
        dotColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 2.3, y: center.y - 2.3, width: 4.6, height: 4.6)).fill()
      }

      return true
    }

    image.isTemplate = false
    image.size = size
    return image
  }
}
