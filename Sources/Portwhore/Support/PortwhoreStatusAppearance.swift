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

      NSColor.labelColor.setStroke()
      NSColor.labelColor.setFill()

      let bodyRect = NSRect(x: 1.25, y: 1.75, width: 12.8, height: 9.2)
      let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 3.0, yRadius: 3.0)
      bodyPath.lineWidth = 1.75
      bodyPath.stroke()

      let portY = bodyRect.minY + 1.2
      for index in 0..<3 {
        let x = bodyRect.minX + 2.15 + CGFloat(index) * 3.2
        let slot = NSBezierPath(
          roundedRect: NSRect(x: x, y: portY, width: 1.95, height: 1.35),
          xRadius: 0.55,
          yRadius: 0.55
        )
        slot.fill()
      }

      let cable = NSBezierPath()
      cable.lineWidth = 1.5
      cable.lineCapStyle = .round
      cable.lineJoinStyle = .round
      cable.move(to: NSPoint(x: bodyRect.minX + 0.95, y: bodyRect.maxY - 1.4))
      cable.curve(
        to: NSPoint(x: bodyRect.midX + 1.0, y: bodyRect.maxY + 0.15),
        controlPoint1: NSPoint(x: bodyRect.minX + 2.75, y: bodyRect.maxY + 2.1),
        controlPoint2: NSPoint(x: bodyRect.midX - 0.2, y: bodyRect.maxY + 0.85)
      )
      cable.line(to: NSPoint(x: bodyRect.midX + 3.6, y: bodyRect.maxY + 0.15))
      cable.stroke()

      let plug = NSBezierPath(
        roundedRect: NSRect(x: bodyRect.midX + 3.05, y: bodyRect.maxY - 0.5, width: 3.0, height: 1.7),
        xRadius: 0.7,
        yRadius: 0.7
      )
      plug.fill()

      switch tone {
      case .idle:
        break
      case .active:
        NSColor.systemGreen.setFill()
        let badge = NSBezierPath(ovalIn: NSRect(x: 13.8, y: 8.7, width: 3.1, height: 3.1))
        badge.fill()
      case .warning:
        NSColor.systemRed.setFill()
        let badge = NSBezierPath()
        badge.move(to: NSPoint(x: 15.35, y: 12.2))
        badge.line(to: NSPoint(x: 17.0, y: 9.0))
        badge.line(to: NSPoint(x: 13.7, y: 9.0))
        badge.close()
        badge.fill()
      }

      return true
    }

    image.isTemplate = false
    image.size = size
    return image
  }
}
