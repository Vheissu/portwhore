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

enum PortwhoreStatusImage {
  private static let lipsRed = NSColor(red: 0.93, green: 0.11, blue: 0.22, alpha: 1.0)
  private static let lipsOutline = NSColor(red: 0.45, green: 0.0, blue: 0.08, alpha: 1.0)
  private static let lipsDim = NSColor(red: 0.6, green: 0.15, blue: 0.22, alpha: 0.75)
  private static let lipsDimOutline = NSColor(red: 0.3, green: 0.05, blue: 0.1, alpha: 0.75)
  private static let lipsHighlight = NSColor(red: 1.0, green: 0.55, blue: 0.6, alpha: 0.7)

  static func make(tone: PortwhoreStatusTone) -> NSImage {
    let size = NSSize(width: 22, height: 18)
    let image = NSImage(size: size, flipped: false) { rect in
      NSColor.clear.setFill()
      rect.fill()

      let fill: NSColor
      let stroke: NSColor
      switch tone {
      case .idle:
        fill = lipsDim
        stroke = lipsDimOutline
      case .active, .warning:
        fill = lipsRed
        stroke = lipsOutline
      }

      // -- Upper lip --
      let upper = NSBezierPath()

      // Left corner
      upper.move(to: NSPoint(x: 1.5, y: 9))

      // Left hump rising
      upper.curve(
        to: NSPoint(x: 7, y: 15.5),
        controlPoint1: NSPoint(x: 1.5, y: 12.5),
        controlPoint2: NSPoint(x: 4, y: 15.5)
      )

      // Cupid's bow – deep V dip to center
      upper.curve(
        to: NSPoint(x: 11, y: 11.5),
        controlPoint1: NSPoint(x: 9, y: 15.5),
        controlPoint2: NSPoint(x: 10, y: 11.5)
      )

      // Right hump rising
      upper.curve(
        to: NSPoint(x: 15, y: 15.5),
        controlPoint1: NSPoint(x: 12, y: 11.5),
        controlPoint2: NSPoint(x: 13, y: 15.5)
      )

      // Right corner
      upper.curve(
        to: NSPoint(x: 20.5, y: 9),
        controlPoint1: NSPoint(x: 18, y: 15.5),
        controlPoint2: NSPoint(x: 20.5, y: 12.5)
      )

      // Close along mouth line
      upper.curve(
        to: NSPoint(x: 1.5, y: 9),
        controlPoint1: NSPoint(x: 15, y: 7.5),
        controlPoint2: NSPoint(x: 7, y: 7.5)
      )
      upper.close()

      fill.setFill()
      upper.fill()
      stroke.setStroke()
      upper.lineWidth = 1.2
      upper.lineCapStyle = .round
      upper.lineJoinStyle = .round
      upper.stroke()

      // -- Lower lip --
      let lower = NSBezierPath()

      // Left corner (gap below upper)
      lower.move(to: NSPoint(x: 2.5, y: 8))

      // Mouth line curve top edge
      lower.curve(
        to: NSPoint(x: 19.5, y: 8),
        controlPoint1: NSPoint(x: 7.5, y: 6.8),
        controlPoint2: NSPoint(x: 14.5, y: 6.8)
      )

      // Right side sweeping down
      lower.curve(
        to: NSPoint(x: 11, y: 1.5),
        controlPoint1: NSPoint(x: 19.5, y: 4),
        controlPoint2: NSPoint(x: 16, y: 1.5)
      )

      // Bottom center back up to left
      lower.curve(
        to: NSPoint(x: 2.5, y: 8),
        controlPoint1: NSPoint(x: 6, y: 1.5),
        controlPoint2: NSPoint(x: 2.5, y: 4)
      )
      lower.close()

      fill.setFill()
      lower.fill()
      stroke.setStroke()
      lower.lineWidth = 1.2
      lower.lineCapStyle = .round
      lower.lineJoinStyle = .round
      lower.stroke()

      // -- Shine highlight on lower lip --
      lipsHighlight.setFill()
      let shine = NSBezierPath(ovalIn: NSRect(x: 9, y: 3, width: 5, height: 3))
      shine.fill()

      // -- State badge --
      switch tone {
      case .idle:
        break
      case .active:
        // Green dot
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 16.2, y: 12.2, width: 5.3, height: 5.3)).fill()
        NSColor.systemGreen.setFill()
        NSBezierPath(ovalIn: NSRect(x: 16.8, y: 12.8, width: 4.1, height: 4.1)).fill()
      case .warning:
        // Yellow warning dot
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 16.2, y: 12.2, width: 5.3, height: 5.3)).fill()
        NSColor.systemYellow.setFill()
        NSBezierPath(ovalIn: NSRect(x: 16.8, y: 12.8, width: 4.1, height: 4.1)).fill()
      }

      return true
    }

    image.isTemplate = false
    image.size = size
    return image
  }
}
