import SwiftUI

struct DashboardView: View {
  @Bindable var store: PortDashboardStore

  var body: some View {
    ZStack {
      PortwhorePalette.background.ignoresSafeArea()

      if store.showSettings {
        SettingsView(store: store)
          .transition(.move(edge: .trailing))
      } else {
        mainContent
          .transition(.move(edge: .leading))
      }
    }
    .animation(.easeInOut(duration: 0.2), value: store.showSettings)
    .alert("Kill All My Ports?", isPresented: $store.confirmKillAll) {
      Button("Cancel", role: .cancel) {}
      Button("Kill All", role: .destructive) {
        store.killAllMyPorts()
      }
    } message: {
      Text("This will stop \(store.killableCount) process(es) you own across all ports.")
    }
  }

  // MARK: - Main Content

  private var mainContent: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 14) {
        headerBar
        searchBar

        if let msg = store.lastActionMessage {
          actionBanner(msg)
        }

        if let err = store.lastError {
          errorBanner(err)
        }

        sortToolbar

        sectionCard(
          title: "Hot Ports",
          subtitle: "\(store.occupiedWatchedPorts.count) busy · \(store.watchedPorts.count - store.occupiedWatchedPorts.count) free"
        ) {
          VStack(spacing: 6) {
            ForEach(store.filteredWatchedSlots) { slot in
              WatchedPortRowView(slot: slot, store: store)
            }
          }
        }

        if !store.filteredOtherRecords.isEmpty {
          sectionCard(
            title: "Other Listeners",
            subtitle: "\(store.filteredOtherRecords.count) active"
          ) {
            VStack(spacing: 6) {
              ForEach(store.filteredOtherRecords) { record in
                ActivePortRowView(record: record, store: store)
              }
            }
          }
        }

        if !store.searchQuery.isEmpty && store.filteredWatchedSlots.isEmpty && store.filteredOtherRecords.isEmpty {
          HStack {
            Spacer()
            VStack(spacing: 6) {
              Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(PortwhorePalette.textMuted)
              Text("No matches for \"\(store.searchQuery)\"")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(PortwhorePalette.textMuted)
            }
            .padding(.vertical, 24)
            Spacer()
          }
        }
      }
      .padding(16)
    }
  }

  // MARK: - Header

  private var headerBar: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        Image(systemName: "network")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(PortwhorePalette.action)

        Text("Portwhore")
          .font(.system(size: 20, weight: .black, design: .monospaced))
          .foregroundStyle(.white)

        Spacer()

        Button {
          store.showSettings = true
        } label: {
          Image(systemName: "gearshape")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(PortwhorePalette.textSecondary)
        }
        .buttonStyle(.plain)
        .frame(width: 26, height: 26)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .help("Settings")

        Button {
          store.exportPortList()
        } label: {
          Image(systemName: "doc.on.clipboard")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(PortwhorePalette.textSecondary)
        }
        .buttonStyle(.plain)
        .frame(width: 26, height: 26)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .help("Export Port List")

        Button {
          Task { await store.refreshNow() }
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(PortwhorePalette.textSecondary)
            .symbolEffect(.rotate, isActive: store.isRefreshing)
        }
        .buttonStyle(.plain)
        .frame(width: 26, height: 26)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .help("Refresh")

        Button {
          NSApplication.shared.terminate(nil)
        } label: {
          Image(systemName: "power")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(PortwhorePalette.textMuted)
        }
        .buttonStyle(.plain)
        .frame(width: 26, height: 26)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .help("Quit Portwhore")
      }

      statsLine
    }
    .padding(14)
    .background(PortwhorePalette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(PortwhorePalette.cardStroke, lineWidth: 1)
    )
  }

  private var statsLine: some View {
    HStack(spacing: 4) {
      Text(verbatim: "\(store.records.count)")
        .fontWeight(.bold)
        .foregroundStyle(PortwhorePalette.action)
      Text("listening")
        .foregroundStyle(PortwhorePalette.textMuted)
      Text("·")
        .foregroundStyle(PortwhorePalette.textMuted.opacity(0.5))
        .padding(.horizontal, 2)
      Text(verbatim: "\(store.killableCount)")
        .fontWeight(.bold)
        .foregroundStyle(PortwhorePalette.action)
      Text("yours")
        .foregroundStyle(PortwhorePalette.textMuted)
      Text("·")
        .foregroundStyle(PortwhorePalette.textMuted.opacity(0.5))
        .padding(.horizontal, 2)
      Text(verbatim: "\(store.protectedCount)")
        .fontWeight(.bold)
        .foregroundStyle(PortwhorePalette.warning)
      Text("protected")
        .foregroundStyle(PortwhorePalette.textMuted)

      if store.killableCount > 0 {
        Spacer()
        Button {
          store.confirmKillAll = true
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "xmark.circle")
              .font(.system(size: 9, weight: .bold))
            Text("Kill All Mine")
          }
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .foregroundStyle(PortwhorePalette.warning)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(PortwhorePalette.warningDeep, in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Kill all processes you own")
      }
    }
    .font(.system(size: 11, weight: .medium, design: .monospaced))
  }

  // MARK: - Search

  private var searchBar: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(PortwhorePalette.textMuted)

      TextField("Search ports, processes, PIDs...", text: $store.searchQuery)
        .textFieldStyle(.plain)
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .foregroundStyle(.white)

      if !store.searchQuery.isEmpty {
        Button {
          store.searchQuery = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 12))
            .foregroundStyle(PortwhorePalette.textMuted)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(10)
    .background(PortwhorePalette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(PortwhorePalette.cardStroke, lineWidth: 1)
    )
  }

  // MARK: - Sort Toolbar

  private var sortToolbar: some View {
    HStack(spacing: 8) {
      Text("Sort:")
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(PortwhorePalette.textMuted)

      ForEach(PortSortOrder.allCases, id: \.self) { order in
        Button {
          store.sortOrder = order
        } label: {
          Text(order.rawValue)
            .font(.system(size: 10, weight: store.sortOrder == order ? .bold : .medium, design: .monospaced))
            .foregroundStyle(store.sortOrder == order ? PortwhorePalette.action : PortwhorePalette.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
              store.sortOrder == order ? PortwhorePalette.actionDeep : Color.white.opacity(0.03),
              in: Capsule()
            )
        }
        .buttonStyle(.plain)
      }

      Spacer()

      if let lastUpdated = store.lastUpdated {
        Text(DateFormatting.relativeString(for: lastUpdated))
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(PortwhorePalette.textMuted.opacity(0.6))
      }
    }
  }

  // MARK: - Banners

  private func actionBanner(_ message: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(PortwhorePalette.action)
      Text(message)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(2)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(PortwhorePalette.actionDeep, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(PortwhorePalette.action.opacity(0.2), lineWidth: 1)
    )
  }

  private func errorBanner(_ message: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(PortwhorePalette.warning)
      Text(message)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(2)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(PortwhorePalette.warningDeep, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(PortwhorePalette.warning.opacity(0.2), lineWidth: 1)
    )
  }

  // MARK: - Section Card

  private func sectionCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
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
