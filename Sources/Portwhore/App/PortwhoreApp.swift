import AppKit
import SwiftUI

@MainActor
final class PortwhoreAppDelegate: NSObject, NSApplicationDelegate {
  let store = PortDashboardStore()
  private var statusBarController: StatusBarController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    statusBarController = StatusBarController(store: store)
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    statusBarController?.showPopover()
    return false
  }
}

@main
struct PortwhoreApp: App {
  @NSApplicationDelegateAdaptor(PortwhoreAppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      SettingsView(store: appDelegate.store, showsBackButton: false)
        .frame(width: 480, height: 600)
    }
  }
}
