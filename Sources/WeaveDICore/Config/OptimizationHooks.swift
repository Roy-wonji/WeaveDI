import Foundation

/// Optional optimization hooks installed by add-on modules.
public enum OptimizationHooks {
  private final class HookStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var trackRegistrationValue: (@Sendable (Any.Type) -> Void)?
    private var trackResolutionValue: (@Sendable (Any.Type) -> Void)?
    private var handleNilResolutionValue: (@Sendable (Any.Type) -> Void)?
    private var setOptimizationEnabledValue: (@Sendable (Bool) -> Void)?
    private var resetStatsValue: (@Sendable () -> Void)?
    private var setOptimizerLogLevelValue: (@Sendable (OptimizerLogLevel) -> Void)?
    private var setAutoMonitorEnabledValue: (@Sendable (Bool) -> Void)?
    private var onModuleRegisteredValue: (@Sendable (Any.Type) async -> Void)?

    private var recordAutoEdgeIfEnabledValue: (@Sendable (Any.Type) async -> Void)?
    private var beginResolutionValue: (@Sendable (Any.Type) async throws -> Void)?
    private var endResolutionValue: (@Sendable (Any.Type) async -> Void)?
    private var addGraphNodeValue: (@Sendable (Any.Type) async -> Void)?
    private var addGraphEdgeValue: (@Sendable (Any.Type, Any.Type, String?) async -> Void)?

    func getTrackRegistration() -> (@Sendable (Any.Type) -> Void)? {
      lock.lock()
      defer { lock.unlock() }
      return trackRegistrationValue
    }

    func setTrackRegistration(_ value: (@Sendable (Any.Type) -> Void)?) {
      lock.lock()
      trackRegistrationValue = value
      lock.unlock()
    }

    func getTrackResolution() -> (@Sendable (Any.Type) -> Void)? {
      lock.lock()
      defer { lock.unlock() }
      return trackResolutionValue
    }

    func setTrackResolution(_ value: (@Sendable (Any.Type) -> Void)?) {
      lock.lock()
      trackResolutionValue = value
      lock.unlock()
    }

    func getHandleNilResolution() -> (@Sendable (Any.Type) -> Void)? {
      lock.lock()
      defer { lock.unlock() }
      return handleNilResolutionValue
    }

    func setHandleNilResolution(_ value: (@Sendable (Any.Type) -> Void)?) {
      lock.lock()
      handleNilResolutionValue = value
      lock.unlock()
    }

    func getSetOptimizationEnabled() -> (@Sendable (Bool) -> Void)? {
      lock.lock()
      defer { lock.unlock() }
      return setOptimizationEnabledValue
    }

    func setSetOptimizationEnabled(_ value: (@Sendable (Bool) -> Void)?) {
      lock.lock()
      setOptimizationEnabledValue = value
      lock.unlock()
    }

    func getResetStats() -> (@Sendable () -> Void)? {
      lock.lock()
      defer { lock.unlock() }
      return resetStatsValue
    }

    func setResetStats(_ value: (@Sendable () -> Void)?) {
      lock.lock()
      resetStatsValue = value
      lock.unlock()
    }

    func getSetOptimizerLogLevel() -> (@Sendable (OptimizerLogLevel) -> Void)? {
      lock.lock()
      defer { lock.unlock() }
      return setOptimizerLogLevelValue
    }

    func setSetOptimizerLogLevel(_ value: (@Sendable (OptimizerLogLevel) -> Void)?) {
      lock.lock()
      setOptimizerLogLevelValue = value
      lock.unlock()
    }

    func getSetAutoMonitorEnabled() -> (@Sendable (Bool) -> Void)? {
      lock.lock()
      defer { lock.unlock() }
      return setAutoMonitorEnabledValue
    }

    func setSetAutoMonitorEnabled(_ value: (@Sendable (Bool) -> Void)?) {
      lock.lock()
      setAutoMonitorEnabledValue = value
      lock.unlock()
    }

    func getOnModuleRegistered() -> (@Sendable (Any.Type) async -> Void)? {
      lock.lock()
      defer { lock.unlock() }
      return onModuleRegisteredValue
    }

    func setOnModuleRegistered(_ value: (@Sendable (Any.Type) async -> Void)?) {
      lock.lock()
      onModuleRegisteredValue = value
      lock.unlock()
    }

    func getRecordAutoEdgeIfEnabled() -> (@Sendable (Any.Type) async -> Void)? {
      lock.lock()
      defer { lock.unlock() }
      return recordAutoEdgeIfEnabledValue
    }

    func setRecordAutoEdgeIfEnabled(_ value: (@Sendable (Any.Type) async -> Void)?) {
      lock.lock()
      recordAutoEdgeIfEnabledValue = value
      lock.unlock()
    }

    func getBeginResolution() -> (@Sendable (Any.Type) async throws -> Void)? {
      lock.lock()
      defer { lock.unlock() }
      return beginResolutionValue
    }

    func setBeginResolution(_ value: (@Sendable (Any.Type) async throws -> Void)?) {
      lock.lock()
      beginResolutionValue = value
      lock.unlock()
    }

    func getEndResolution() -> (@Sendable (Any.Type) async -> Void)? {
      lock.lock()
      defer { lock.unlock() }
      return endResolutionValue
    }

    func setEndResolution(_ value: (@Sendable (Any.Type) async -> Void)?) {
      lock.lock()
      endResolutionValue = value
      lock.unlock()
    }

    func getAddGraphNode() -> (@Sendable (Any.Type) async -> Void)? {
      lock.lock()
      defer { lock.unlock() }
      return addGraphNodeValue
    }

    func setAddGraphNode(_ value: (@Sendable (Any.Type) async -> Void)?) {
      lock.lock()
      addGraphNodeValue = value
      lock.unlock()
    }

    func getAddGraphEdge() -> (@Sendable (Any.Type, Any.Type, String?) async -> Void)? {
      lock.lock()
      defer { lock.unlock() }
      return addGraphEdgeValue
    }

    func setAddGraphEdge(_ value: (@Sendable (Any.Type, Any.Type, String?) async -> Void)?) {
      lock.lock()
      addGraphEdgeValue = value
      lock.unlock()
    }
  }

  private static let storage = HookStorage()

  public static var trackRegistration: (@Sendable (Any.Type) -> Void)? {
    get { storage.getTrackRegistration() }
    set { storage.setTrackRegistration(newValue) }
  }

  public static var trackResolution: (@Sendable (Any.Type) -> Void)? {
    get { storage.getTrackResolution() }
    set { storage.setTrackResolution(newValue) }
  }

  public static var handleNilResolution: (@Sendable (Any.Type) -> Void)? {
    get { storage.getHandleNilResolution() }
    set { storage.setHandleNilResolution(newValue) }
  }

  public static var setOptimizationEnabled: (@Sendable (Bool) -> Void)? {
    get { storage.getSetOptimizationEnabled() }
    set { storage.setSetOptimizationEnabled(newValue) }
  }

  public static var resetStats: (@Sendable () -> Void)? {
    get { storage.getResetStats() }
    set { storage.setResetStats(newValue) }
  }

  public static var setOptimizerLogLevel: (@Sendable (OptimizerLogLevel) -> Void)? {
    get { storage.getSetOptimizerLogLevel() }
    set { storage.setSetOptimizerLogLevel(newValue) }
  }

  public static var setAutoMonitorEnabled: (@Sendable (Bool) -> Void)? {
    get { storage.getSetAutoMonitorEnabled() }
    set { storage.setSetAutoMonitorEnabled(newValue) }
  }

  public static var onModuleRegistered: (@Sendable (Any.Type) async -> Void)? {
    get { storage.getOnModuleRegistered() }
    set { storage.setOnModuleRegistered(newValue) }
  }

  public static var recordAutoEdgeIfEnabled: (@Sendable (Any.Type) async -> Void)? {
    get { storage.getRecordAutoEdgeIfEnabled() }
    set { storage.setRecordAutoEdgeIfEnabled(newValue) }
  }

  public static var beginResolution: (@Sendable (Any.Type) async throws -> Void)? {
    get { storage.getBeginResolution() }
    set { storage.setBeginResolution(newValue) }
  }

  public static var endResolution: (@Sendable (Any.Type) async -> Void)? {
    get { storage.getEndResolution() }
    set { storage.setEndResolution(newValue) }
  }

  public static var addGraphNode: (@Sendable (Any.Type) async -> Void)? {
    get { storage.getAddGraphNode() }
    set { storage.setAddGraphNode(newValue) }
  }

  public static var addGraphEdge: (@Sendable (Any.Type, Any.Type, String?) async -> Void)? {
    get { storage.getAddGraphEdge() }
    set { storage.setAddGraphEdge(newValue) }
  }
}
