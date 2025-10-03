#if canImport(Dependencies)
import Dependencies

public extension DependencyValues {
  /// Access the WeaveDI container powering dependency resolution.
  var diContainer: DIContainer {
    get { self[DIContainerDependencyKey.self] }
    set { self[DIContainerDependencyKey.self] = newValue }
  }

  /// Retrieve or override values defined via WeaveDI's InjectedKey.
  subscript<K: InjectedKey>(_ key: K.Type) -> K.Value where K.Value: Sendable {
    get {
      if let override = self[InjectedOverrideKey<K>.self] {
        return override
      }
      return diContainer.resolve(K.Value.self) ?? K.liveValue
    }
    set {
      self[InjectedOverrideKey<K>.self] = newValue
    }
  }

  /// Convenience helper to resolve a type directly from the container.
  func resolve<T: Sendable>(_ type: T.Type) -> T? {
    diContainer.resolve(type)
  }
}

private enum DIContainerDependencyKey: DependencyKey {
  static var liveValue: DIContainer { DIContainer.shared }
  static var testValue: DIContainer { DIContainer.shared }
  static var previewValue: DIContainer { DIContainer.shared }
}

private enum InjectedOverrideKey<K: InjectedKey>: DependencyKey where K.Value: Sendable {
  static var liveValue: K.Value? { nil }
  static var testValue: K.Value? { nil }
  static var previewValue: K.Value? { nil }
}
#endif
