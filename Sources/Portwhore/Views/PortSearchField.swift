import AppKit
import SwiftUI

struct PortSearchField: NSViewRepresentable {
  @Binding var text: String
  var focusRequest: Int

  func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

  func makeNSView(context: Context) -> NSSearchField {
    let field = NSSearchField()
    field.placeholderString = "Search ports, processes, PIDs"
    field.setAccessibilityLabel("Search ports, processes, PIDs")
    field.sendsSearchStringImmediately = true
    field.isAutomaticTextCompletionEnabled = false
    field.delegate = context.coordinator
    return field
  }

  func updateNSView(_ field: NSSearchField, context: Context) {
    context.coordinator.text = $text
    if field.stringValue != text { field.stringValue = text }
    if context.coordinator.focusRequest != focusRequest {
      context.coordinator.focusRequest = focusRequest
      field.window?.makeFirstResponder(field)
    }
  }

  final class Coordinator: NSObject, NSSearchFieldDelegate {
    var text: Binding<String>
    var focusRequest = 0

    init(text: Binding<String>) { self.text = text }

    func controlTextDidBeginEditing(_ notification: Notification) {
      guard let field = notification.object as? NSSearchField,
            let editor = field.currentEditor() as? NSTextView else { return }
      editor.isAutomaticTextReplacementEnabled = false
      editor.isAutomaticSpellingCorrectionEnabled = false
      editor.isAutomaticQuoteSubstitutionEnabled = false
      editor.isAutomaticDashSubstitutionEnabled = false
      editor.isAutomaticTextCompletionEnabled = false
    }

    func controlTextDidChange(_ notification: Notification) {
      guard let field = notification.object as? NSSearchField else { return }
      text.wrappedValue = field.stringValue
    }
  }
}
