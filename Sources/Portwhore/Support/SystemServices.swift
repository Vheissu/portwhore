/// macOS processes that commonly hold ports developers expect to be free.
enum SystemServices {
  struct Service {
    let name: String
    let hint: String?
  }

  private static let services: [String: Service] = [
    "ControlCenter": Service(
      name: "AirPlay Receiver",
      hint: "To free this port, turn off AirPlay Receiver in System Settings › General › AirDrop & Handoff."
    ),
    "rapportd": Service(name: "Continuity", hint: nil),
    "sharingd": Service(name: "Sharing & AirDrop", hint: nil),
    "identityservicesd": Service(name: "Messages & FaceTime", hint: nil),
    "mDNSResponder": Service(name: "Bonjour", hint: nil),
    "remoted": Service(name: "Remote device services", hint: nil),
    "replicatord": Service(name: "Widget sync", hint: nil),
  ]

  static func service(for processName: String) -> Service? {
    services[processName]
  }
}
