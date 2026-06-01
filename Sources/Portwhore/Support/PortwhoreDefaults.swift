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
      return PortValidation.sanitizedPorts(stored)
    }
    set { UserDefaults.standard.set(PortValidation.sanitizedPorts(newValue), forKey: watchedPortsKey) }
  }

  static var portLabels: [Int: String] {
    get {
      guard let stored = UserDefaults.standard.dictionary(forKey: portLabelsKey) as? [String: String] else {
        return [:]
      }
      var result: [Int: String] = [:]
      for (key, value) in stored {
        if let port = Int(key),
           PortValidation.isValidPort(port),
           let label = PortValidation.sanitizedLabel(value) {
          result[port] = label
        }
      }
      return result
    }
    set {
      var stringKeyed: [String: String] = [:]
      for (key, value) in newValue {
        guard PortValidation.isValidPort(key),
              let label = PortValidation.sanitizedLabel(value) else {
          continue
        }
        stringKeyed[String(key)] = label
      }
      UserDefaults.standard.set(stringKeyed, forKey: portLabelsKey)
    }
  }

  static var refreshInterval: TimeInterval {
    get {
      let stored = UserDefaults.standard.double(forKey: refreshIntervalKey)
      return PortValidation.normalizedRefreshInterval(stored)
    }
    set { UserDefaults.standard.set(PortValidation.normalizedRefreshInterval(newValue), forKey: refreshIntervalKey) }
  }

  static func resetToDefaults() {
    UserDefaults.standard.removeObject(forKey: watchedPortsKey)
    UserDefaults.standard.removeObject(forKey: portLabelsKey)
    UserDefaults.standard.removeObject(forKey: refreshIntervalKey)
  }
}
