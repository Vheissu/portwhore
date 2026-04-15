import SwiftUI

struct SettingsView: View {
  @Bindable var store: PortDashboardStore
  @State private var addPortText = ""
  @State private var addPortError: String?
  @State private var addLabelPortText = ""
  @State private var addLabelValueText = ""
  @State private var confirmReset = false

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 14) {
        settingsHeader
        watchedPortsSection
        refreshIntervalSection
        portLabelsSection
        resetSection
      }
      .padding(16)
    }
    .alert("Reset to Defaults?", isPresented: $confirmReset) {
      Button("Cancel", role: .cancel) {}
      Button("Reset", role: .destructive) {
        store.resetWatchedPorts()
      }
    } message: {
      Text("This will restore all settings to their defaults, including watched ports, labels, and refresh interval.")
    }
  }

  // MARK: - Header

  private var settingsHeader: some View {
    HStack(spacing: 10) {
      Button {
        store.showSettings = false
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "chevron.left")
            .font(.system(size: 11, weight: .bold))
          Text("Back")
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(PortwhorePalette.action)
      }
      .buttonStyle(.plain)

      Spacer()

      Text("Settings")
        .font(.system(size: 16, weight: .bold, design: .monospaced))
        .foregroundStyle(.white)

      Spacer()

      // Spacer button for symmetry
      Color.clear.frame(width: 60, height: 1)
    }
    .padding(14)
    .background(PortwhorePalette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(PortwhorePalette.cardStroke, lineWidth: 1)
    )
  }

  // MARK: - Watched Ports

  private var watchedPortsSection: some View {
    settingsSection(title: "Watched Ports", subtitle: "\(store.watchedPorts.count) ports") {
      VStack(spacing: 6) {
        ForEach(store.watchedPorts, id: \.self) { port in
          HStack(spacing: 10) {
            Text(verbatim: "\(port)")
              .font(.system(size: 14, weight: .bold, design: .monospaced))
              .foregroundStyle(.white)
              .frame(width: 60, alignment: .leading)

            if let desc = WellKnownPorts.description(for: port) {
              Text(desc)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(PortwhorePalette.textMuted)
            }

            if let label = store.portLabels[port] {
              Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PortwhorePalette.action.opacity(0.6))
            }

            Spacer()

            Button {
              store.removeWatchedPort(port)
            } label: {
              Image(systemName: "minus.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(PortwhorePalette.warning.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Remove from watched ports")
          }
          .padding(.vertical, 4)
          .padding(.horizontal, 10)
          .background(PortwhorePalette.card.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }

        // Add port
        HStack(spacing: 8) {
          TextField("Port number", text: $addPortText)
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .frame(width: 100)
            .onSubmit { addWatchedPort() }

          Button("Add") {
            addWatchedPort()
          }
          .buttonStyle(.plain)
          .font(.system(size: 11, weight: .bold, design: .monospaced))
          .foregroundStyle(PortwhorePalette.action)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(PortwhorePalette.actionDeep, in: Capsule())

          if let error = addPortError {
            Text(error)
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(PortwhorePalette.warning)
          }

          Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(PortwhorePalette.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(PortwhorePalette.action.opacity(0.15), lineWidth: 1)
        )
      }
    }
  }

  private func addWatchedPort() {
    let trimmed = addPortText.trimmingCharacters(in: .whitespaces)
    guard let port = Int(trimmed), port >= 1, port <= 65535 else {
      addPortError = "Enter 1\u{2013}65535"
      return
    }
    guard !store.watchedPorts.contains(port) else {
      addPortError = "Already watched"
      return
    }
    store.addWatchedPort(port)
    addPortText = ""
    addPortError = nil
  }

  // MARK: - Refresh Interval

  private var refreshIntervalSection: some View {
    let options: [(String, TimeInterval)] = [
      ("2s", 2), ("5s", 5), ("10s", 10), ("30s", 30),
    ]

    return settingsSection(title: "Refresh Interval", subtitle: "Current: \(Int(store.refreshInterval))s") {
      HStack(spacing: 6) {
        ForEach(options, id: \.1) { label, interval in
          Button {
            store.setRefreshInterval(interval)
          } label: {
            Text(label)
              .font(.system(size: 12, weight: store.refreshInterval == interval ? .bold : .medium, design: .monospaced))
              .foregroundStyle(store.refreshInterval == interval ? PortwhorePalette.action : PortwhorePalette.textMuted)
              .padding(.horizontal, 14)
              .padding(.vertical, 8)
              .background(
                store.refreshInterval == interval ? PortwhorePalette.actionDeep : Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
              )
              .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .stroke(
                    store.refreshInterval == interval ? PortwhorePalette.action.opacity(0.3) : Color.clear,
                    lineWidth: 1
                  )
              )
          }
          .buttonStyle(.plain)
        }
        Spacer()
      }
    }
  }

  // MARK: - Port Labels

  private var portLabelsSection: some View {
    settingsSection(
      title: "Port Labels",
      subtitle: store.portLabels.isEmpty ? "None set" : "\(store.portLabels.count) label(s)"
    ) {
      VStack(spacing: 6) {
        if store.portLabels.isEmpty {
          Text("No labels set. Use the menu on any port row to add a label.")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(PortwhorePalette.textMuted)
            .padding(.vertical, 8)
        } else {
          ForEach(Array(store.portLabels.keys.sorted()), id: \.self) { port in
            HStack(spacing: 10) {
              Text(verbatim: "\(port)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(PortwhorePalette.action)
                .frame(width: 60, alignment: .leading)

              Text(store.portLabels[port] ?? "")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)

              Spacer()

              Button {
                store.setPortLabel(port, label: nil)
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .font(.system(size: 14))
                  .foregroundStyle(PortwhorePalette.textMuted)
              }
              .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(PortwhorePalette.card.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
          }
        }

        // Add label
        HStack(spacing: 8) {
          TextField("Port", text: $addLabelPortText)
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .frame(width: 60)

          TextField("Label", text: $addLabelValueText)
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .onSubmit { addLabel() }

          Button("Add") { addLabel() }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(PortwhorePalette.action)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(PortwhorePalette.actionDeep, in: Capsule())

          Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(PortwhorePalette.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(PortwhorePalette.action.opacity(0.15), lineWidth: 1)
        )
      }
    }
  }

  private func addLabel() {
    guard let port = Int(addLabelPortText.trimmingCharacters(in: .whitespaces)),
          port >= 1, port <= 65535 else { return }
    let label = addLabelValueText.trimmingCharacters(in: .whitespaces)
    guard !label.isEmpty else { return }
    store.setPortLabel(port, label: label)
    addLabelPortText = ""
    addLabelValueText = ""
  }

  // MARK: - Reset

  private var resetSection: some View {
    HStack {
      Spacer()
      Button {
        confirmReset = true
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "arrow.counterclockwise")
            .font(.system(size: 11, weight: .semibold))
          Text("Reset to Defaults")
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(PortwhorePalette.warning)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(PortwhorePalette.warningDeep, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(PortwhorePalette.warning.opacity(0.2), lineWidth: 1)
        )
      }
      .buttonStyle(.plain)
      Spacer()
    }
    .padding(.top, 6)
  }

  // MARK: - Section Helper

  private func settingsSection<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(title)
          .font(.system(size: 14, weight: .bold, design: .monospaced))
          .foregroundStyle(.white)

        Text(subtitle)
          .font(.system(size: 11, weight: .medium, design: .monospaced))
          .foregroundStyle(PortwhorePalette.textMuted)
      }

      content()
    }
    .padding(12)
    .background(PortwhorePalette.card.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(PortwhorePalette.cardStroke, lineWidth: 1)
    )
  }
}
