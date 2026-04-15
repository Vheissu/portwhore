import AppKit
import SwiftUI

final class PortwhoreAppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    // This app is intentionally menu-bar-only.
    NSApp.setActivationPolicy(.accessory)
  }
}

@main
struct PortwhoreApp: App {
  @NSApplicationDelegateAdaptor(PortwhoreAppDelegate.self) private var appDelegate
  @State private var store = PortDashboardStore()

  var body: some Scene {
    MenuBarExtra {
      DashboardView(store: store)
        .frame(width: 448, height: 640)
    } label: {
      MenuBarLabel(
        totalListeners: store.records.count,
        occupiedWatchedPorts: store.occupiedWatchedPorts.count,
        hasError: store.lastError != nil
      )
    }
    .menuBarExtraStyle(.window)
  }
}
