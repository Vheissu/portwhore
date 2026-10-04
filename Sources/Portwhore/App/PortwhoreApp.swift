import AppKit
import SwiftUI

@MainActor
final class PortwhoreAppDelegate: NSObject, NSApplicationDelegate {
  let store = PortDashboardStore()
  private var statusBarController: StatusBarController?

  private static let showPopoverNotification = Notification.Name("com.dwayne.portwhore.showPopover")

  func applicationDidFinishLaunching(_ notification: Notification) {
    // A second copy would add a second menu bar icon; hand off to the first.
    if let bundleID = Bundle.main.bundleIdentifier,
       NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
         .contains(where: { $0 != .current }) {
      DistributedNotificationCenter.default().postNotificationName(
        Self.showPopoverNotification, object: nil, deliverImmediately: true
      )
      NSApp.terminate(nil)
      return
    }

    NSApp.setActivationPolicy(.accessory)
    statusBarController = StatusBarController(store: store)
    DistributedNotificationCenter.default().addObserver(
      forName: Self.showPopoverNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.statusBarController?.showPopover()
      }
    }
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
