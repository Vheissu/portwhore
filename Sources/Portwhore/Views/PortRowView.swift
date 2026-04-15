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
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        portBadge

        VStack(alignment: .leading, spacing: 4) {
          Text(record.displayTitle)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)

          Text(record.subtitle)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(PortwhorePalette.textSecondary)

          Text(record.primary.trimmedCommand)
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .foregroundStyle(PortwhorePalette.textMuted)
            .lineLimit(1)
        }

        Spacer(minLength: 8)

        VStack(alignment: .trailing, spacing: 8) {
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
            Image(systemName: "ellipsis.circle")
              .font(.system(size: 18, weight: .medium))
              .foregroundStyle(PortwhorePalette.textSecondary)
          }
          .menuStyle(.borderlessButton)
          .menuIndicator(.hidden)
        }
      }

      if record.hasMultipleListeners {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(record.listeners.dropFirst()) { listener in
            HStack(spacing: 8) {
              Circle()
                .fill(PortwhorePalette.textMuted)
                .frame(width: 4, height: 4)

              Text("\(listener.processName) • PID \(listener.pid)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(PortwhorePalette.textSecondary)

              Spacer(minLength: 8)

              Text(listener.user)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(PortwhorePalette.textMuted)
            }
          }
        }
        .padding(.leading, 62)
      }
    }
    .padding(14)
    .background(backgroundGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(borderColor, lineWidth: 1)
    )
  }

  private var portBadge: some View {
    Text("\(record.port)")
      .font(.system(size: 24, weight: .black, design: .rounded))
      .foregroundStyle(badgeTextColor)
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(badgeBackground, in: Capsule())
  }

  private var backgroundGradient: LinearGradient {
    switch record.ownershipTone {
    case .mine:
      return LinearGradient(
        colors: [Color(red: 0.09, green: 0.22, blue: 0.16), Color(red: 0.05, green: 0.14, blue: 0.10)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    case .shared:
      return LinearGradient(
        colors: [Color(red: 0.16, green: 0.20, blue: 0.11), Color(red: 0.08, green: 0.11, blue: 0.07)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    case .protected:
      return LinearGradient(
        colors: [Color(red: 0.24, green: 0.11, blue: 0.12), Color(red: 0.10, green: 0.06, blue: 0.07)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    case .free:
      return LinearGradient(
        colors: [PortwhorePalette.card, PortwhorePalette.card],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
  }

  private var borderColor: Color {
    switch record.ownershipTone {
    case .mine:
      return PortwhorePalette.action.opacity(0.22)
    case .shared:
      return Color.orange.opacity(0.28)
    case .protected:
      return PortwhorePalette.warning.opacity(0.35)
    case .free:
      return PortwhorePalette.cardStroke
    }
  }

  private var badgeBackground: Color {
    switch record.ownershipTone {
    case .mine:
      return PortwhorePalette.actionDeep.opacity(0.88)
    case .shared:
      return Color.orange.opacity(0.16)
    case .protected:
      return PortwhorePalette.warningDeep.opacity(0.88)
    case .free:
      return Color.white.opacity(0.10)
    }
  }

  private var badgeTextColor: Color {
    switch record.ownershipTone {
    case .mine:
      return PortwhorePalette.action
    case .shared:
      return Color.orange.opacity(0.92)
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
    HStack(spacing: 12) {
      Text("\(port)")
        .font(.system(size: 24, weight: .black, design: .rounded))
        .foregroundStyle(PortwhorePalette.free)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: Capsule())

      VStack(alignment: .leading, spacing: 4) {
        Text("Free")
          .font(.system(size: 18, weight: .semibold, design: .rounded))
          .foregroundStyle(.white)

        Text("Ready for your next dev server")
          .font(.system(size: 12, weight: .medium, design: .rounded))
          .foregroundStyle(PortwhorePalette.textSecondary)
      }

      Spacer(minLength: 8)

      Image(systemName: "checkmark.seal.fill")
        .font(.system(size: 20))
        .foregroundStyle(PortwhorePalette.action)
    }
    .padding(14)
    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    )
  }
}

struct ActionPillButtonStyle: ButtonStyle {
  let tone: PortOwnershipTone

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .bold, design: .rounded))
      .foregroundStyle(foregroundColor)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(backgroundColor.opacity(configuration.isPressed ? 0.82 : 1), in: Capsule())
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }

  private var backgroundColor: Color {
    switch tone {
    case .mine:
      return PortwhorePalette.action
    case .shared:
      return Color.orange.opacity(0.84)
    case .protected:
      return PortwhorePalette.warning
    case .free:
      return Color.white.opacity(0.12)
    }
  }

  private var foregroundColor: Color {
    switch tone {
    case .mine:
      return PortwhorePalette.actionDeep
    case .shared:
      return Color.black.opacity(0.75)
    case .protected:
      return Color.white
    case .free:
      return .white
    }
  }
}
