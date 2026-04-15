import SwiftUI

struct DashboardView: View {
  let store: PortDashboardStore

  var body: some View {
    ZStack {
      PortwhorePalette.background.ignoresSafeArea()

      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 14) {
          headerBar

          if let msg = store.lastActionMessage {
            actionBanner(msg)
          }

          if let err = store.lastError {
            errorBanner(err)
          }

          sectionCard(
            title: "Hot Ports",
            subtitle: "\(store.occupiedWatchedPorts.count) busy · \(store.watchedPorts.count - store.occupiedWatchedPorts.count) free"
          ) {
            VStack(spacing: 6) {
              ForEach(store.watchedSlots) { slot in
                WatchedPortRowView(slot: slot) { record, force in
                  store.freePort(record, force: force)
                }
              }
            }
          }

          if !store.otherRecords.isEmpty {
            sectionCard(
              title: "Other Listeners",
              subtitle: "\(store.otherRecords.count) active"
            ) {
              VStack(spacing: 6) {
                ForEach(store.otherRecords) { record in
                  ActivePortRowView(record: record) { target, force in
                    store.freePort(target, force: force)
                  }
                }
              }
            }
          }
        }
        .padding(16)
      }
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
    }
    .font(.system(size: 11, weight: .medium, design: .monospaced))
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
