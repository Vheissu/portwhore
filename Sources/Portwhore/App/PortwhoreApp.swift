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
}

@main
struct PortwhoreApp: App {
  @NSApplicationDelegateAdaptor(PortwhoreAppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}
