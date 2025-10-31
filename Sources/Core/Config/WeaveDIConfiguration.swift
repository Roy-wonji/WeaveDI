import Foundation

private struct WeaveDIConfigState {
  var optimizerEnabled: Bool = true
  var monitorEnabled: Bool = false
  var verboseLogging: Bool = false
  var registryAutoHealthCheckEnabled: Bool = true
  var registryAutoFixEnabled: Bool = true
  var registryHealthLoggingEnabled: Bool = false
  var injectedEnvironment: WeaveDIConfiguration.InjectedEnvironment = .automatic
}

/// Invariants: 모든 상태 접근은 `withLock`을 통해 수행되어야 하며, 해당 메서드는 내부
/// `NSLock`으로 직렬화된다.
private final class ConfigStorage: @unchecked Sendable {
  private var state: WeaveDIConfigState
  private let lock = NSLock()

  init(_ initial: WeaveDIConfigState = .init()) {
    state = initial
  }

  func withLock<T>(_ body: (inout WeaveDIConfigState) -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body(&state)
  }
}

public enum WeaveDIConfiguration {
  private static let storage = ConfigStorage()

  public enum InjectedEnvironment {
    case automatic
    case live
    case test
    case preview
  }

  public static var enableOptimizerTracking: Bool {
    get { storage.withLock { $0.optimizerEnabled } }
    set { storage.withLock { $0.optimizerEnabled = newValue } }
  }

  public static var enableAutoMonitor: Bool {
    get { storage.withLock { $0.monitorEnabled } }
    set {
      let previous = storage.withLock { state -> Bool in
        let oldValue = state.monitorEnabled
        state.monitorEnabled = newValue
        return oldValue
      }

      guard previous != newValue else { return }

      let flag = newValue

      Task { @DIActor in AutoMonitor.isEnabled = flag }

      Task { @MainActor in
        if flag {
          DIMonitor.shared.startMonitoring()
        } else {
          DIMonitor.shared.stopMonitoring()
        }
      }
    }
  }

  public static var enableVerboseLogging: Bool {
    get { storage.withLock { $0.verboseLogging } }
    set { storage.withLock { $0.verboseLogging = newValue } }
  }

  public static var enableRegistryAutoHealthCheck: Bool {
    get { storage.withLock { $0.registryAutoHealthCheckEnabled } }
    set { storage.withLock { $0.registryAutoHealthCheckEnabled = newValue } }
  }

  public static var enableRegistryAutoFix: Bool {
    get { storage.withLock { $0.registryAutoFixEnabled } }
    set { storage.withLock { $0.registryAutoFixEnabled = newValue } }
  }

  public static var enableRegistryHealthLogging: Bool {
    get { storage.withLock { $0.registryHealthLoggingEnabled } }
    set { storage.withLock { $0.registryHealthLoggingEnabled = newValue } }
  }

  public static var defaultInjectedEnvironment: InjectedEnvironment {
    get { storage.withLock { $0.injectedEnvironment } }
    set { storage.withLock { $0.injectedEnvironment = newValue } }
  }

  public static func applyFromEnvironment(
    optimizerKey: String = "WEAVEDI_ENABLE_OPTIMIZER",
    monitorKey: String = "WEAVEDI_ENABLE_MONITOR",
    verboseKey: String = "WEAVEDI_VERBOSE_LOGGING",
    registryHealthKey: String = "WEAVEDI_REGISTRY_AUTO_HEALTH",
    registryFixKey: String = "WEAVEDI_REGISTRY_AUTO_FIX",
    registryLogKey: String = "WEAVEDI_REGISTRY_HEALTH_LOGGING",
    injectedEnvKey: String = "WEAVEDI_INJECTED_ENV"
  ) {
    let env = ProcessInfo.processInfo.environment

    if let value = env[optimizerKey] {
      enableOptimizerTracking = parseBool(value, defaultValue: enableOptimizerTracking)
    }

    if let value = env[monitorKey] {
      enableAutoMonitor = parseBool(value, defaultValue: enableAutoMonitor)
    }

    if let value = env[verboseKey] {
      enableVerboseLogging = parseBool(value, defaultValue: enableVerboseLogging)
    }

    if let value = env[registryHealthKey] {
      enableRegistryAutoHealthCheck = parseBool(value, defaultValue: enableRegistryAutoHealthCheck)
    }

    if let value = env[registryFixKey] {
      enableRegistryAutoFix = parseBool(value, defaultValue: enableRegistryAutoFix)
    }

    if let value = env[registryLogKey] {
      enableRegistryHealthLogging = parseBool(value, defaultValue: enableRegistryHealthLogging)
    }

    if let value = env[injectedEnvKey]?.lowercased() {
      switch value {
      case "automatic":
        defaultInjectedEnvironment = .automatic
      case "live":
        defaultInjectedEnvironment = .live
      case "test":
        defaultInjectedEnvironment = .test
      case "preview":
        defaultInjectedEnvironment = .preview
      default:
        break
      }
    }
  }

  private static func parseBool(_ raw: String, defaultValue: Bool) -> Bool {
    let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch normalized {
      case "1", "true", "yes", "on": return true
      case "0", "false", "no", "off": return false
      default: return defaultValue
    }
  }

}
