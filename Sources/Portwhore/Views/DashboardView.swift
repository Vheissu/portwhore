import SwiftUI

struct DashboardView: View {
  @Bindable var store: PortDashboardStore

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
    .animation(.easeInOut(duration: 0.2), value: store.showSettings)
    .alert("Stop all your processes?", isPresented: $store.confirmKillAll) {
      Button("Cancel", role: .cancel) {}
      Button("Stop All", role: .destructive) {
        store.killAllMyPorts()
      }
    } message: {
      Text("This stops \(store.killableCount) process(es) you own across every port.")
    }
  }

  // MARK: - Main Content

  private var mainContent: some View {
    VStack(spacing: 0) {
      header
      Divider()

      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 18) {
          controls

          if let msg = store.lastActionMessage {
            banner(msg, systemImage: "checkmark.circle.fill", tint: PortwhorePalette.mine)
          }
          if let err = store.lastError {
            banner(err, systemImage: "exclamationmark.triangle.fill", tint: PortwhorePalette.protected)
          }

          section(
            "Hot Ports",
            detail: "\(store.occupiedWatchedPorts.count) busy · \(store.watchedPorts.count - store.occupiedWatchedPorts.count) free"
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

          if !store.searchQuery.isEmpty && store.filteredWatchedSlots.isEmpty && store.filteredOtherRecords.isEmpty {
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
        chromeButton("doc.on.clipboard", help: "Copy Port List") { store.exportPortList() }
        Button {
          Task { await store.refreshNow() }
        } label: {
          Image(systemName: "arrow.clockwise")
            .symbolEffect(.rotate, isActive: store.isRefreshing)
        }
        .buttonStyle(.borderless)
        .help("Refresh")
        chromeButton("power", help: "Quit Portwhore") { NSApplication.shared.terminate(nil) }
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
  }

  private var statsLine: some View {
    HStack(spacing: 6) {
      statPill(count: store.records.count, label: "listening", tint: .secondary)
      statPill(count: store.killableCount, label: "yours", tint: PortwhorePalette.mine)
      statPill(count: store.protectedCount, label: "protected", tint: PortwhorePalette.protected)

      Spacer()

      if store.killableCount > 0 {
        Button(role: .destructive) {
          store.confirmKillAll = true
        } label: {
          Label("Stop All Mine", systemImage: "stop.circle")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(.red)
        .help("Stop every process you own")
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
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 12))
          .foregroundStyle(PortwhorePalette.textMuted)

        TextField("Search ports, processes, PIDs", text: $store.searchQuery)
          .textFieldStyle(.plain)
          .font(.system(size: 12))

        if !store.searchQuery.isEmpty {
          Button {
            store.searchQuery = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(PortwhorePalette.textMuted)
          }
          .buttonStyle(.borderless)
        }
      }
      .padding(.horizontal, 9)
      .padding(.vertical, 6)
      .background(PortwhorePalette.surface, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .stroke(PortwhorePalette.separator, lineWidth: 1)
      )

      HStack(spacing: 8) {
        Picker("Sort", selection: $store.sortOrder) {
          ForEach(PortSortOrder.allCases, id: \.self) { order in
            Text(order.rawValue).tag(order)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        if let lastUpdated = store.lastUpdated {
          Text(DateFormatting.relativeString(for: lastUpdated))
            .font(.system(size: 10))
            .foregroundStyle(PortwhorePalette.textMuted)
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
        .lineLimit(2)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
