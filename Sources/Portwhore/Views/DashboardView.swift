import SwiftUI

struct DashboardView: View {
  @Bindable var store: PortDashboardStore
  @State private var searchFocusRequest = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      if store.showSettings {
        SettingsView(store: store)
          .transition(.move(edge: .trailing).combined(with: .opacity))
      } else {
        mainContent
          .transition(.move(edge: .leading).combined(with: .opacity))
      }
    }
    .background(.regularMaterial)
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: store.showSettings)
    .alert("Stop your hot ports?", isPresented: $store.confirmKillAll) {
      Button("Cancel", role: .cancel) {}
      Button("Stop", role: .destructive) {
        store.stopHotPorts()
      }
    } message: {
      Text(bulkStopMessage)
    }
  }

  private var bulkStopMessage: String {
    let ports = store.bulkStopRecords.map { String($0.port) }.joined(separator: ", ")
    let count = store.bulkStopProcessCount
    return "Sends a stop request to \(count) process\(count == 1 ? "" : "es") on port\(store.bulkStopRecords.count == 1 ? "" : "s") \(ports). Other listeners are left alone."
  }

  // MARK: - Main Content

  private var mainContent: some View {
    VStack(spacing: 0) {
      header
      Divider()
      controls
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          if let msg = store.lastActionMessage {
            banner(msg, systemImage: "checkmark.circle.fill", tint: PortwhorePalette.mine)
          }
          if !store.unresponsivePIDs.isEmpty {
            unresponsiveBanner
          }
          if let err = store.lastError {
            banner(err, systemImage: "exclamationmark.triangle.fill", tint: PortwhorePalette.protected)
            if store.lastActionError != nil {
              Button("Dismiss action error") { store.dismissActionError() }
                .buttonStyle(.borderless)
            }
          }

          section(
            "Hot Ports",
            detail: store.hasCurrentScan
              ? "\(store.occupiedWatchedPorts.count) busy · \(store.watchedPorts.count - store.occupiedWatchedPorts.count) free"
              : "Waiting for a successful scan"
          ) {
            ForEach(store.filteredWatchedSlots) { slot in
              WatchedPortRowView(slot: slot, store: store)
            }
          }

          if !store.filteredOtherRecords.isEmpty {
            section("Other Listeners", detail: "\(store.filteredOtherRecords.count) active") {
              ForEach(store.filteredOtherRecords) { record in
                ActivePortRowView(record: record, store: store)
              }
            }
          }

          if !store.normalizedSearchQuery.isEmpty && store.filteredWatchedSlots.isEmpty && store.filteredOtherRecords.isEmpty {
            emptyState
          }
        }
        .padding(16)
      }
    }
  }

  // MARK: - Header

  private var header: some View {
    VStack(spacing: 10) {
      HStack(spacing: 8) {
        Text("Portwhore")
          .font(.system(size: 15, weight: .semibold))

        Spacer()

        chromeButton("gearshape", help: "Settings") { store.showSettings = true }
          .keyboardShortcut(",")
        chromeButton("doc.on.clipboard", help: "Copy Port List") { store.exportPortList() }
          .keyboardShortcut("c", modifiers: [.command, .shift])
        Button {
          Task { await store.refreshNow() }
        } label: {
          Image(systemName: "arrow.clockwise")
            .symbolEffect(.rotate, isActive: store.isRefreshing && !reduceMotion)
        }
        .buttonStyle(.borderless)
        .help("Refresh")
        .accessibilityLabel("Refresh")
        .keyboardShortcut("r")
        .disabled(store.isRefreshing)
        chromeButton("power", help: "Quit Portwhore") { NSApplication.shared.terminate(nil) }
          .keyboardShortcut("q")
      }

      statsLine
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  private func chromeButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
    }
    .buttonStyle(.borderless)
    .help(help)
    .accessibilityLabel(help)
  }

  private var statsLine: some View {
    HStack(spacing: 6) {
      statPill(count: store.records.count, label: "listening", tint: .secondary)
      statPill(count: store.killableCount, label: "yours", tint: PortwhorePalette.mine)
      statPill(count: store.protectedCount, label: "protected", tint: PortwhorePalette.protected)

      Spacer()

      if !store.bulkStopRecords.isEmpty {
        Button(role: .destructive) {
          store.confirmKillAll = true
        } label: {
          Label("Stop Hot Ports", systemImage: "stop.circle")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(.red)
        .help("Stop your processes on watched ports")
        .disabled(store.isPerformingAction || !store.hasCurrentScan)
      }
    }
    .font(.system(size: 11))
  }

  private func statPill(count: Int, label: String, tint: Color) -> some View {
    HStack(spacing: 4) {
      Text(verbatim: "\(count)")
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(tint)
      Text(label)
        .foregroundStyle(PortwhorePalette.textSecondary)
    }
  }

  // MARK: - Controls (search + sort)

  private var controls: some View {
    VStack(spacing: 10) {
      PortSearchField(text: $store.searchQuery, focusRequest: searchFocusRequest)
        .frame(height: 24)
        .background {
          Button("Find") { searchFocusRequest += 1 }
            .keyboardShortcut("f")
            .hidden()
        }

      HStack(spacing: 8) {
        Picker("Sort", selection: $store.sortOrder) {
          ForEach(PortSortOrder.allCases, id: \.self) { order in
            Text(order.rawValue).tag(order)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        TimelineView(.periodic(from: .now, by: 1)) { _ in
          Text(store.isRefreshing ? "Scanning…" : store.lastScanError != nil ? "Scan failed" : DateFormatting.relativeString(for: store.lastUpdated))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize()
        }
      }
    }
  }

  // MARK: - Banner

  private func banner(_ message: String, systemImage: String, tint: Color) -> some View {
    HStack(spacing: 8) {
      Image(systemName: systemImage)
        .foregroundStyle(tint)
      Text(message)
        .font(.system(size: 12))
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
  }

  private var unresponsiveBanner: some View {
    let pids = store.unresponsivePIDs
    let list = pids.map(String.init).joined(separator: ", ")
    let message = pids.count == 1
      ? "PID \(list) is still running after a stop request."
      : "PIDs \(list) are still running after a stop request."

    return VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: "hourglass")
          .foregroundStyle(PortwhorePalette.shared)
        Text(message)
          .font(.system(size: 12))
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
      }
      HStack(spacing: 8) {
        Button("Force Kill", role: .destructive) { store.forceKillUnresponsive() }
          .buttonStyle(.bordered)
          .tint(.red)
          .disabled(store.isPerformingAction)
        Button("Dismiss") { store.dismissUnresponsive() }
          .buttonStyle(.borderless)
      }
      .controlSize(.small)
      .padding(.leading, 24)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(PortwhorePalette.shared.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
  }

  // MARK: - Section

  private func section<Content: View>(
    _ title: String,
    detail: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(title.uppercased())
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(PortwhorePalette.textSecondary)
          .kerning(0.4)
        Text(detail)
          .font(.system(size: 11))
          .foregroundStyle(PortwhorePalette.textMuted)
        Spacer(minLength: 0)
      }
      .padding(.leading, 2)

      VStack(spacing: 6) {
        content()
      }
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 22, weight: .light))
        .foregroundStyle(PortwhorePalette.textMuted)
      Text("No matches for \u{201C}\(store.searchQuery)\u{201D}")
        .font(.system(size: 12))
        .foregroundStyle(PortwhorePalette.textSecondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
  }
}
