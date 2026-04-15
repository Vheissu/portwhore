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
  static func make(tone: PortwhoreStatusTone) -> NSImage {
    let size = NSSize(width: 18, height: 14)
    let image = NSImage(size: size, flipped: false) { rect in
      NSColor.clear.setFill()
      rect.fill()

      // -- Lips shape --
      NSColor.labelColor.setFill()

      let lips = NSBezierPath()

      // Left corner of mouth
      lips.move(to: NSPoint(x: 1, y: 7))

      // Upper lip – left hump
      lips.curve(
        to: NSPoint(x: 5.5, y: 11.5),
        controlPoint1: NSPoint(x: 1, y: 9.5),
        controlPoint2: NSPoint(x: 3, y: 11.5)
      )

      // Cupid's bow – dip to center
      lips.curve(
        to: NSPoint(x: 9, y: 9.5),
        controlPoint1: NSPoint(x: 7, y: 11.5),
        controlPoint2: NSPoint(x: 8, y: 9.5)
      )

      // Upper lip – right hump
      lips.curve(
        to: NSPoint(x: 12.5, y: 11.5),
        controlPoint1: NSPoint(x: 10, y: 9.5),
        controlPoint2: NSPoint(x: 11, y: 11.5)
      )

      // Right corner
      lips.curve(
        to: NSPoint(x: 17, y: 7),
        controlPoint1: NSPoint(x: 15, y: 11.5),
        controlPoint2: NSPoint(x: 17, y: 9.5)
      )

      // Lower lip – right side down to bottom
      lips.curve(
        to: NSPoint(x: 9, y: 1.5),
        controlPoint1: NSPoint(x: 17, y: 3.5),
        controlPoint2: NSPoint(x: 13.5, y: 1.5)
      )

      // Lower lip – bottom back up to left corner
      lips.curve(
        to: NSPoint(x: 1, y: 7),
        controlPoint1: NSPoint(x: 4.5, y: 1.5),
        controlPoint2: NSPoint(x: 1, y: 3.5)
      )

      lips.close()
      lips.fill()

      // -- Mouth line (cut through the fill) --
      if let ctx = NSGraphicsContext.current {
        ctx.compositingOperation = .destinationOut

        let mouth = NSBezierPath()
        mouth.lineWidth = 0.8
        mouth.lineCapStyle = .round
        mouth.move(to: NSPoint(x: 2.5, y: 7))
        mouth.curve(
          to: NSPoint(x: 15.5, y: 7),
          controlPoint1: NSPoint(x: 6, y: 6.2),
          controlPoint2: NSPoint(x: 12, y: 6.2)
        )
        NSColor.white.setStroke()
        mouth.stroke()

        ctx.compositingOperation = .sourceOver
      }

      // -- State badges --
      switch tone {
      case .idle:
        break

      case .active:
        NSColor.systemGreen.setFill()
        NSBezierPath(ovalIn: NSRect(x: 13.8, y: 9.5, width: 3.2, height: 3.2)).fill()

      case .warning:
        NSColor.systemRed.setFill()
        let tri = NSBezierPath()
        tri.move(to: NSPoint(x: 15.4, y: 13))
        tri.line(to: NSPoint(x: 17.2, y: 9.5))
        tri.line(to: NSPoint(x: 13.6, y: 9.5))
        tri.close()
        tri.fill()
      }

      return true
    }

    image.isTemplate = false
    image.size = size
    return image
  }
}
