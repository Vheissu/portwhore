import AppKit
import SwiftUI

struct WatchedPortRowView: View {
  let slot: WatchedPortSlot
  @Bindable var store: PortDashboardStore

  var body: some View {
    if let record = slot.record {
      ActivePortRowView(record: record, store: store)
    } else {
      FreePortRowView(
        port: slot.port,
        label: store.portLabels[slot.port]
      )
    }
  }
}

struct ActivePortRowView: View {
  let record: PortRecord
  @Bindable var store: PortDashboardStore

  private var label: String? { store.portLabels[record.port] }
  private var wellKnown: String? { WellKnownPorts.description(for: record.port) }
  private var tone: PortOwnershipTone { record.ownershipTone }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center, spacing: 10) {
        PortBadge(port: record.port, tone: tone)

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text(record.displayTitle)
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.primary)
              .lineLimit(1)

            TransportTag(text: record.transportLabel)
          }

          if let label {
            Text(label)
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(tone.color)
              .lineLimit(1)
          } else if let wellKnown {
            Text(wellKnown)
              .font(.system(size: 11))
              .foregroundStyle(PortwhorePalette.textSecondary)
              .lineLimit(1)
          }

          Text(record.subtitle)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(PortwhorePalette.textSecondary)
            .lineLimit(1)
        }

        Spacer(minLength: 4)

        Button(record.primaryActionTitle) {
          store.freePort(record, force: false)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(tone.color)

        portMenu
      }

      if store.editingLabelForPort == record.port {
        labelEditor
      }

      if record.hasMultipleListeners {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(record.listeners.dropFirst()) { listener in
            HStack(spacing: 6) {
              Circle()
                .fill(PortwhorePalette.textMuted)
                .frame(width: 3, height: 3)

              Text("\(listener.processName) · PID \(listener.pid)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(PortwhorePalette.textSecondary)

              Text(listener.transport.rawValue)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(PortwhorePalette.textMuted)

              Spacer(minLength: 4)

              Text(listener.user)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(PortwhorePalette.textMuted)
            }
          }
        }
        .padding(.leading, 52)
      }

      Text(record.primary.endpoint)
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(PortwhorePalette.textMuted)
        .lineLimit(1)
        .padding(.leading, 52)
    }
    .padding(10)
    .background(rowBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(tone == .free ? PortwhorePalette.separator : tone.color.opacity(0.25), lineWidth: 1)
    )
  }

  // MARK: - Port Menu

  private var portMenu: some View {
    Menu {
      if label != nil {
        Button("Edit Label…") {
          store.editingLabelText = label ?? ""
          store.editingLabelForPort = record.port
        }
        Button("Remove Label") {
          store.setPortLabel(record.port, label: nil)
        }
      } else {
        Button("Set Label…") {
          store.editingLabelText = ""
          store.editingLabelForPort = record.port
        }
      }

      Divider()

      Button("Copy Port") {
        Pasteboard.copy(String(record.port))
      }
      Button("Copy PID") {
        Pasteboard.copy(record.uniquePIDs.map(String.init).joined(separator: ", "))
      }
      Button("Copy Command") {
        let commands = record.listeners.map(\.trimmedCommand).joined(separator: "\n")
        Pasteboard.copy(commands)
      }
      Button("Copy Endpoint") {
        Pasteboard.copy(record.primary.endpoint)
      }
      Button("Copy Kill Command") {
        let pids = record.uniquePIDs.map(String.init).joined(separator: " ")
        let needsSudo = !record.listeners.allSatisfy(\.isOwnedByCurrentUser)
        let cmd = needsSudo ? "sudo kill -9 \(pids)" : "kill -9 \(pids)"
        Pasteboard.copy(cmd)
      }

      Divider()

      Button("Open in Browser") {
        if let url = URL(string: "http://localhost:\(record.port)") {
          NSWorkspace.shared.open(url)
        }
      }

      Divider()

      Button("Force Kill", role: .destructive) {
        store.freePort(record, force: true)
      }
    } label: {
      Image(systemName: "ellipsis")
        .foregroundStyle(PortwhorePalette.textSecondary)
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
  }

  // MARK: - Label Editor

  private var labelEditor: some View {
    HStack(spacing: 8) {
      Image(systemName: "tag")
        .font(.system(size: 11))
        .foregroundStyle(PortwhorePalette.accent)

      TextField("Label this port", text: $store.editingLabelText)
        .textFieldStyle(.plain)
        .font(.system(size: 12))
        .onSubmit {
          store.setPortLabel(record.port, label: store.editingLabelText)
          store.editingLabelForPort = nil
        }

      Button("Save") {
        store.setPortLabel(record.port, label: store.editingLabelText)
        store.editingLabelForPort = nil
      }
      .controlSize(.small)
      .buttonStyle(.borderedProminent)

      Button("Cancel") {
        store.editingLabelForPort = nil
      }
      .controlSize(.small)
      .buttonStyle(.bordered)
    }
    .padding(8)
    .background(PortwhorePalette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
  }

  // MARK: - Styling

  private var rowBackground: Color {
    tone == .free ? PortwhorePalette.surface.opacity(0.5) : tone.color.opacity(0.08)
  }
}

// MARK: - Port Badge

struct PortBadge: View {
  let port: Int
  let tone: PortOwnershipTone

  var body: some View {
    Text(verbatim: "\(port)")
      .font(.system(size: 15, weight: .semibold, design: .monospaced))
      .foregroundStyle(tone == .free ? PortwhorePalette.textMuted : tone.color)
      .frame(minWidth: 46)
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(
        (tone == .free ? PortwhorePalette.free.opacity(0.10) : tone.color.opacity(0.15)),
        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
      )
  }
}

// MARK: - Transport Tag

struct TransportTag: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 9, weight: .semibold, design: .monospaced))
      .foregroundStyle(PortwhorePalette.textSecondary)
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background(PortwhorePalette.surface, in: Capsule())
  }
}

// MARK: - Free Port Row

struct FreePortRowView: View {
  let port: Int
  let label: String?

  var body: some View {
    HStack(spacing: 10) {
      PortBadge(port: port, tone: .free)

      VStack(alignment: .leading, spacing: 2) {
        Text("Free")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(PortwhorePalette.textSecondary)

        if let label {
          Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(PortwhorePalette.textMuted)
            .lineLimit(1)
        } else if let wellKnown = WellKnownPorts.description(for: port) {
          Text(wellKnown)
            .font(.system(size: 11))
            .foregroundStyle(PortwhorePalette.textMuted)
            .lineLimit(1)
        }
      }

      Spacer()

      Image(systemName: "checkmark.circle")
        .font(.system(size: 14))
        .foregroundStyle(PortwhorePalette.mine.opacity(0.5))
    }
    .padding(10)
    .background(PortwhorePalette.surface.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(PortwhorePalette.separator, lineWidth: 1)
    )
  }
}
