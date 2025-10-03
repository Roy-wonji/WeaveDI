import Foundation

/// Lifecycle options for dependencies declared inside a `@Component`.
public enum ProvideScope: String, Sendable {
  case transient
  case singleton
}

/// Property wrapper used inside `@Component` types to mark dependencies that
/// should be registered with WeaveDI.
@propertyWrapper
public struct Provide<Value> {
  public let scope: ProvideScope
  private var value: Value

  public init(wrappedValue: Value, scope: ProvideScope = .transient) {
    self.scope = scope
    self.value = wrappedValue
  }

  public var wrappedValue: Value {
    get { value }
    set { value = newValue }
  }
}
