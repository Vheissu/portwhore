import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
  private let store: PortDashboardStore
  private let statusItem: NSStatusItem
  private let popover = NSPopover()

  init(store: PortDashboardStore) {
    self.store = store
    self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    super.init()
    configurePopover()
    configureStatusItem()
    store.onStatusChange = { [weak self] in
      self?.updateButtonAppearance()
    }
    updateButtonAppearance()
  }
  private func configurePopover() {
    popover.behavior = .transient
    popover.animates = true
    popover.contentSize = NSSize(width: 448, height: 640)
    popover.contentViewController = NSHostingController(
      rootView: DashboardView(store: store)
        .frame(width: 448, height: 640)
    )
  }

  private func configureStatusItem() {
    guard let button = statusItem.button else {
      return
    }

    button.target = self
    button.action = #selector(togglePopover(_:))
    button.imagePosition = .imageLeading
    button.toolTip = "Portwhore"
    button.setAccessibilityLabel("Portwhore")
  }

  private func updateButtonAppearance() {
    guard let button = statusItem.button else {
      return
    }

    let snapshot = store.statusSnapshot
    button.image = PortwhoreStatusImage.make(tone: snapshot.tone)
    button.attributedTitle = NSAttributedString(
      string: snapshot.text,
      attributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .heavy),
        .foregroundColor: NSColor.labelColor
      ]
    )
    button.toolTip = snapshot.accessibilityLabel
    button.setAccessibilityLabel(snapshot.accessibilityLabel)
  }

  @objc private func togglePopover(_ sender: AnyObject?) {
    guard let button = statusItem.button else {
      return
    }

    if popover.isShown {
      popover.performClose(sender)
    } else {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      popover.contentViewController?.view.window?.becomeKey()
    }
  }
}
