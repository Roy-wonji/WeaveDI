import Foundation

/// Protocol adopted by structs annotated with `@Component`.
public protocol ComponentProtocol: Sendable {
  /// Required initializer for component instantiation.
  init()
  /// Register all dependencies provided by this component into the given container.
  static func registerAll(into container: DIContainer)
  /// Register into the shared container.
  static func registerAll()
}

public extension ComponentProtocol {
  static func registerAll() {
    registerAll(into: DIContainer.shared)
  }
}
