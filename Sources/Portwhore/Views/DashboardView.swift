import SwiftUI

struct DashboardView: View {
  let store: PortDashboardStore

  var body: some View {
    ZStack {
      background

      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 18) {
          headerCard

          sectionCard(
            title: "Hot Ports",
            subtitle: "\(store.occupiedWatchedPorts.count) busy • \(store.watchedPorts.count - store.occupiedWatchedPorts.count) free"
          ) {
            VStack(spacing: 10) {
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
              VStack(spacing: 10) {
                ForEach(store.otherRecords) { record in
                  ActivePortRowView(record: record) { target, force in
                    store.freePort(target, force: force)
                  }
                }
              }
            }
          }

          footerCard
        }
        .padding(18)
      }
    }
  }

  private var background: some View {
    ZStack {
      LinearGradient(
        colors: [PortwhorePalette.backgroundTop, PortwhorePalette.backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      RadialGradient(
        colors: [PortwhorePalette.glow.opacity(0.28), .clear],
        center: .topLeading,
        startRadius: 30,
        endRadius: 320
      )
      .blur(radius: 6)
    }
    .ignoresSafeArea()
  }

  private var headerCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 10) {
            Image(systemName: "ladybug.circle.fill")
              .font(.system(size: 26))
              .foregroundStyle(PortwhorePalette.free)

            Text("Portwhore")
              .font(.system(size: 30, weight: .black, design: .rounded))
              .foregroundStyle(.white)
          }

          Text("Your menu-bar control room for busy dev ports, daemon squatters, and quick process cleanup.")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(PortwhorePalette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 12)

        VStack(alignment: .trailing, spacing: 8) {
          statusPill(title: "\(store.records.count) listeners", tone: .mine)
          statusPill(title: "\(store.killableCount) yours", tone: .mine)
          statusPill(title: "\(store.protectedCount) protected", tone: .protected)
        }
      }

      Divider()
        .overlay(Color.white.opacity(0.12))

      HStack(spacing: 10) {
        Button {
          Task {
            await store.refreshNow()
          }
        } label: {
          Label(store.isRefreshing ? "Refreshing…" : "Refresh Scan", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.borderedProminent)
        .tint(PortwhorePalette.action)
        .disabled(store.isRefreshing)

        if let lastActionMessage = store.lastActionMessage {
          Text(lastActionMessage)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(PortwhorePalette.free)
            .lineLimit(2)
        } else {
          Text("Updated \(DateFormatting.relativeString(for: store.lastUpdated))")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(PortwhorePalette.textSecondary)
        }
      }

      if let lastError = store.lastError {
        Text(lastError)
          .font(.system(size: 11, weight: .medium, design: .rounded))
          .foregroundStyle(PortwhorePalette.warning)
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(PortwhorePalette.warningDeep.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
    }
    .padding(18)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .stroke(Color.white.opacity(0.10), lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(0.30), radius: 18, y: 12)
  }

  private var footerCard: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Tips")
          .font(.system(size: 13, weight: .bold, design: .rounded))
          .foregroundStyle(.white)

        Text("Use Stop for a clean `TERM`, or the overflow menu when a stubborn port needs a harder shove.")
          .font(.system(size: 12, weight: .medium, design: .rounded))
          .foregroundStyle(PortwhorePalette.textSecondary)
      }

      Spacer(minLength: 12)

      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }
      .buttonStyle(.bordered)
      .controlSize(.large)
    }
    .padding(18)
    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    )
  }

  private func sectionCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text(title)
          .font(.system(size: 19, weight: .bold, design: .rounded))
          .foregroundStyle(.white)

        Text(subtitle)
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .foregroundStyle(PortwhorePalette.textSecondary)
      }

      content()
    }
    .padding(16)
    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    )
  }

  private func statusPill(title: String, tone: PortOwnershipTone) -> some View {
    Text(title)
      .font(.system(size: 12, weight: .bold, design: .rounded))
      .foregroundStyle(pillForeground(for: tone))
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(pillBackground(for: tone), in: Capsule())
  }

  private func pillBackground(for tone: PortOwnershipTone) -> Color {
    switch tone {
    case .mine:
      return PortwhorePalette.actionDeep
    case .shared:
      return Color.orange.opacity(0.16)
    case .protected:
      return PortwhorePalette.warningDeep
    case .free:
      return Color.white.opacity(0.12)
    }
  }

  private func pillForeground(for tone: PortOwnershipTone) -> Color {
    switch tone {
    case .mine:
      return PortwhorePalette.action
    case .shared:
      return Color.orange
    case .protected:
      return PortwhorePalette.warning
    case .free:
      return .white
    }
  }
}
