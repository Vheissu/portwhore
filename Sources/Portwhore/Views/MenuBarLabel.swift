import SwiftUI

struct MenuBarLabel: View {
  let totalListeners: Int
  let occupiedWatchedPorts: Int
  let hasError: Bool

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: hasError ? "bolt.horizontal.circle.fill" : "point.3.connected.trianglepath.dotted")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(hasError ? PortwhorePalette.warning : PortwhorePalette.free)

      if totalListeners > 0 {
        Text("\(totalListeners)")
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundStyle(.primary)
      } else if occupiedWatchedPorts > 0 {
        Text("\(occupiedWatchedPorts)")
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundStyle(.primary)
      }
    }
  }
}
