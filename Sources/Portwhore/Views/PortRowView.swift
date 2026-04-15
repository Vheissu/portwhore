import SwiftUI

struct WatchedPortRowView: View {
  let slot: WatchedPortSlot
  let onFree: (PortRecord, Bool) -> Void

  var body: some View {
    if let record = slot.record {
      ActivePortRowView(record: record, onFree: onFree)
    } else {
      FreePortRowView(port: slot.port)
    }
  }
}

struct ActivePortRowView: View {
  let record: PortRecord
  let onFree: (PortRecord, Bool) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center, spacing: 10) {
        portBadge

        VStack(alignment: .leading, spacing: 2) {
          Text(record.displayTitle)
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .lineLimit(1)

          Text(record.subtitle)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(PortwhorePalette.textSecondary)
            .lineLimit(1)
        }

        Spacer(minLength: 4)

        Button(record.primaryActionTitle) {
          onFree(record, false)
        }
        .buttonStyle(ActionPillButtonStyle(tone: record.ownershipTone))

        Menu {
          Button("Copy PID") {
            Pasteboard.copy(record.uniquePIDs.map(String.init).joined(separator: ", "))
          }

          Button("Copy Command") {
            let commands = record.listeners.map(\.trimmedCommand).joined(separator: "\n")
            Pasteboard.copy(commands)
          }

          Divider()

          Button("Force Kill") {
            onFree(record, true)
          }
        } label: {
          Image(systemName: "ellipsis")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(PortwhorePalette.textMuted)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
      }

      if record.hasMultipleListeners {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(record.listeners.dropFirst()) { listener in
            HStack(spacing: 6) {
              Circle()
                .fill(PortwhorePalette.textMuted)
                .frame(width: 3, height: 3)

              Text("\(listener.processName) · PID \(listener.pid)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(PortwhorePalette.textSecondary)

              Spacer(minLength: 4)

              Text(listener.user)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(PortwhorePalette.textMuted)
            }
          }
        }
        .padding(.leading, 52)
      }
    }
    .padding(12)
    .background(rowBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(borderColor, lineWidth: 1)
    )
  }

  private var portBadge: some View {
    Text(verbatim: "\(record.port)")
      .font(.system(size: 18, weight: .black, design: .monospaced))
      .foregroundStyle(badgeTextColor)
      .frame(minWidth: 48)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(badgeBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
  }

  private var rowBackground: Color {
    switch record.ownershipTone {
    case .mine:
      return Color(red: 0.02, green: 0.09, blue: 0.12)
    case .shared:
      return Color(red: 0.12, green: 0.10, blue: 0.03)
    case .protected:
      return Color(red: 0.14, green: 0.03, blue: 0.08)
    case .free:
      return PortwhorePalette.card
    }
  }

  private var borderColor: Color {
    switch record.ownershipTone {
    case .mine:
      return PortwhorePalette.action.opacity(0.20)
    case .shared:
      return PortwhorePalette.amber.opacity(0.20)
    case .protected:
      return PortwhorePalette.warning.opacity(0.25)
    case .free:
      return PortwhorePalette.cardStroke
    }
  }

  private var badgeBackground: Color {
    switch record.ownershipTone {
    case .mine:
      return PortwhorePalette.actionDeep
    case .shared:
      return PortwhorePalette.amberDeep
    case .protected:
      return PortwhorePalette.warningDeep
    case .free:
      return Color.white.opacity(0.06)
    }
  }

  private var badgeTextColor: Color {
    switch record.ownershipTone {
    case .mine:
      return PortwhorePalette.action
    case .shared:
      return PortwhorePalette.amber
    case .protected:
      return PortwhorePalette.warning
    case .free:
      return PortwhorePalette.free
    }
  }
}

struct FreePortRowView: View {
  let port: Int

  var body: some View {
    HStack(spacing: 10) {
      Text(verbatim: "\(port)")
        .font(.system(size: 18, weight: .black, design: .monospaced))
        .foregroundStyle(PortwhorePalette.free.opacity(0.5))
        .frame(minWidth: 48)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

      Text("Free")
        .font(.system(size: 13, weight: .medium, design: .monospaced))
        .foregroundStyle(PortwhorePalette.textMuted)

      Spacer()

      Image(systemName: "checkmark.circle")
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(PortwhorePalette.action.opacity(0.3))
    }
    .padding(12)
    .background(PortwhorePalette.card.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(Color.white.opacity(0.03), lineWidth: 1)
    )
  }
}

struct ActionPillButtonStyle: ButtonStyle {
  let tone: PortOwnershipTone

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 11, weight: .bold, design: .monospaced))
      .foregroundStyle(foregroundColor)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(backgroundColor.opacity(configuration.isPressed ? 0.75 : 1), in: Capsule())
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }

  private var backgroundColor: Color {
    switch tone {
    case .mine:
      return PortwhorePalette.action
    case .shared:
      return PortwhorePalette.amber
    case .protected:
      return PortwhorePalette.warning
    case .free:
      return Color.white.opacity(0.10)
    }
  }

  private var foregroundColor: Color {
    switch tone {
    case .mine:
      return Color.black
    case .shared:
      return Color.black
    case .protected:
      return Color.white
    case .free:
      return .white
    }
  }
}
