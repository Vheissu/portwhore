import SwiftUI

struct SettingsView: View {
  @Bindable var store: PortDashboardStore
  @State private var addPortText = ""
  @State private var addPortError: String?
  @State private var addLabelPortText = ""
  @State private var addLabelValueText = ""
  @State private var confirmReset = false

  private let intervals: [(String, TimeInterval)] = [
    ("2s", 2), ("5s", 5), ("10s", 10), ("30s", 30),
  ]

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()

      Form {
        watchedPortsSection
        refreshIntervalSection
        portLabelsSection

        Section {
          Button("Reset to Defaults", role: .destructive) {
            confirmReset = true
          }
        }
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
    }
    .background(.regularMaterial)
    .alert("Reset to defaults?", isPresented: $confirmReset) {
      Button("Cancel", role: .cancel) {}
      Button("Reset", role: .destructive) {
        store.resetWatchedPorts()
      }
    } message: {
      Text("This restores watched ports, labels, and the refresh interval to their defaults.")
    }
  }

  // MARK: - Header

  private var header: some View {
    HStack(spacing: 8) {
      Button {
        store.showSettings = false
      } label: {
        Label("Back", systemImage: "chevron.left")
          .labelStyle(.titleAndIcon)
      }
      .buttonStyle(.borderless)

      Spacer()

      Text("Settings")
        .font(.system(size: 13, weight: .semibold))

      Spacer()

      // Balance the leading button so the title stays centered.
      Label("Back", systemImage: "chevron.left")
        .labelStyle(.titleAndIcon)
        .hidden()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  // MARK: - Watched Ports

  private var watchedPortsSection: some View {
    Section {
      ForEach(store.watchedPorts, id: \.self) { port in
        HStack(spacing: 10) {
          Text(verbatim: "\(port)")
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .frame(width: 52, alignment: .leading)

          if let desc = WellKnownPorts.description(for: port) {
            Text(desc)
              .foregroundStyle(PortwhorePalette.textSecondary)
          }
          if let label = store.portLabels[port] {
            Text(label)
              .foregroundStyle(PortwhorePalette.accent)
          }

          Spacer()

          Button {
            store.removeWatchedPort(port)
          } label: {
            Image(systemName: "minus.circle.fill")
              .foregroundStyle(PortwhorePalette.textMuted)
          }
          .buttonStyle(.borderless)
          .help("Stop watching this port")
        }
      }

      HStack(spacing: 8) {
        TextField("Add port", text: $addPortText)
          .textFieldStyle(.roundedBorder)
          .frame(width: 120)
          .onSubmit { addWatchedPort() }
        Button("Add") { addWatchedPort() }
          .disabled(addPortText.trimmingCharacters(in: .whitespaces).isEmpty)
        if let error = addPortError {
          Text(error)
            .font(.system(size: 11))
            .foregroundStyle(PortwhorePalette.protected)
        }
        Spacer()
      }
    } header: {
      Text("Watched Ports")
    } footer: {
      Text("\(store.watchedPorts.count) ports pinned to the top of the dashboard.")
    }
  }

  private func addWatchedPort() {
    let trimmed = addPortText.trimmingCharacters(in: .whitespaces)
    guard let port = Int(trimmed), port >= 1, port <= 65535 else {
      addPortError = "1\u{2013}65535"
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
    Section("Refresh Interval") {
      Picker("Scan every", selection: refreshBinding) {
        ForEach(intervals, id: \.1) { label, interval in
          Text(label).tag(interval)
        }
      }
      .pickerStyle(.segmented)
    }
  }

  private var refreshBinding: Binding<TimeInterval> {
    Binding(
      get: { store.refreshInterval },
      set: { store.setRefreshInterval($0) }
    )
  }

  // MARK: - Port Labels

  private var portLabelsSection: some View {
    Section {
      if store.portLabels.isEmpty {
        Text("Use the menu on any port to add a label.")
          .foregroundStyle(PortwhorePalette.textSecondary)
      } else {
        ForEach(Array(store.portLabels.keys.sorted()), id: \.self) { port in
          HStack(spacing: 10) {
            Text(verbatim: "\(port)")
              .font(.system(size: 13, weight: .semibold, design: .monospaced))
              .foregroundStyle(PortwhorePalette.accent)
              .frame(width: 52, alignment: .leading)
            Text(store.portLabels[port] ?? "")
            Spacer()
            Button {
              store.setPortLabel(port, label: nil)
            } label: {
              Image(systemName: "xmark.circle.fill")
                .foregroundStyle(PortwhorePalette.textMuted)
            }
            .buttonStyle(.borderless)
          }
        }
      }

      HStack(spacing: 8) {
        TextField("Port", text: $addLabelPortText)
          .textFieldStyle(.roundedBorder)
          .frame(width: 70)
        TextField("Label", text: $addLabelValueText)
          .textFieldStyle(.roundedBorder)
          .onSubmit { addLabel() }
        Button("Add") { addLabel() }
          .disabled(addLabelPortText.trimmingCharacters(in: .whitespaces).isEmpty
                    || addLabelValueText.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    } header: {
      Text("Port Labels")
    } footer: {
      Text(store.portLabels.isEmpty ? "No labels set." : "\(store.portLabels.count) label(s) set.")
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
}
