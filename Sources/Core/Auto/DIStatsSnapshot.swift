import Foundation

/// Immutable snapshot for DI stats/graph to support synchronous reads.
public struct DIStatsSnapshot: Sendable {
  public let frequentlyUsed: [String: Int]
  public let registered: Set<String>
  public let resolved: Set<String>
  public let dependencies: [(from: String, to: String)]
  public let logLevel: LogLevel
  public let graphText: String
  
  public init(
    frequentlyUsed: [String: Int] = [:],
    registered: Set<String> = [],
    resolved: Set<String> = [],
    dependencies: [(from: String, to: String)] = [],
    logLevel: LogLevel = .errors,
    graphText: String = ""
  ) {
    self.frequentlyUsed = frequentlyUsed
    self.registered = registered
    self.resolved = resolved
    self.dependencies = dependencies
    self.logLevel = logLevel
    self.graphText = graphText
  }
}

/// Thread-safe cache to expose last snapshot to synchronous callers.
public final class DIStatsCache: @unchecked Sendable {
  public static let shared = DIStatsCache()
  
  private var snapshot = DIStatsSnapshot()
  private let lock = NSLock()
  
  private init() {}
  
  public func write(_ new: DIStatsSnapshot) {
    lock.lock(); snapshot = new; lock.unlock()
  }
  
  public func read() -> DIStatsSnapshot {
    lock.lock(); let s = snapshot; lock.unlock(); return s
  }
}
