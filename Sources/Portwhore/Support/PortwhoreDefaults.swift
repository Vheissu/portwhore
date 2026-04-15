import Foundation

enum PortwhoreDefaults {
  private static let watchedPortsKey = "pw_watchedPorts"
  private static let portLabelsKey = "pw_portLabels"
  private static let refreshIntervalKey = "pw_refreshInterval"
  private static let defaultWatchedPorts = [3000, 3001, 5173, 5432, 6379, 8000, 8080, 8081, 9000, 9229]

  static var watchedPorts: [Int] {
    get {
      guard let stored = UserDefaults.standard.array(forKey: watchedPortsKey) as? [Int] else {
        return defaultWatchedPorts
      }
      return stored
    }
    set { UserDefaults.standard.set(newValue, forKey: watchedPortsKey) }
  }

  static var portLabels: [Int: String] {
    get {
      guard let stored = UserDefaults.standard.dictionary(forKey: portLabelsKey) as? [String: String] else {
        return [:]
      }
      var result: [Int: String] = [:]
      for (key, value) in stored {
        if let port = Int(key) {
          result[port] = value
        }
      }
      return result
    }
    set {
      var stringKeyed: [String: String] = [:]
      for (key, value) in newValue {
        stringKeyed[String(key)] = value
      }
      UserDefaults.standard.set(stringKeyed, forKey: portLabelsKey)
    }
  }

  static var refreshInterval: TimeInterval {
    get {
      let stored = UserDefaults.standard.double(forKey: refreshIntervalKey)
      return stored > 0 ? stored : 5.0
    }
    set { UserDefaults.standard.set(newValue, forKey: refreshIntervalKey) }
  }

  static func resetToDefaults() {
    UserDefaults.standard.removeObject(forKey: watchedPortsKey)
    UserDefaults.standard.removeObject(forKey: portLabelsKey)
    UserDefaults.standard.removeObject(forKey: refreshIntervalKey)
  }
}
