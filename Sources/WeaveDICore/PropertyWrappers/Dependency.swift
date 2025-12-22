import Foundation

public protocol InjectedKey {
  associatedtype Value: Sendable
  static var liveValue: Value { get }
  static var testValue: Value { get }
  static var previewValue: Value { get }
}

// MARK: - Dependency Values

/// 모든 의존성은 이 구조체를 통해 관리됩니다.
public struct InjectedValues: @unchecked Sendable {
  private var storage: [ObjectIdentifier: Any] = [:]

  public init() {}

  public subscript<Key: InjectedKey>(
    _ keyType: Key.Type
  ) -> Key.Value {
    get {
      let key = ObjectIdentifier(keyType)
      return storage[key] as? Key.Value ?? Key.liveValue
    }
    set {
      let key = ObjectIdentifier(keyType)
      storage[key] = newValue
    }
  }
}

// MARK: - Dependency Property Wrapper

@propertyWrapper
public struct Injected<T>: @unchecked Sendable where T: Sendable {
  private let keyPath: WritableKeyPath<InjectedValues, T>

  public init(_ keyPath: WritableKeyPath<InjectedValues, T>) {
    self.keyPath = keyPath
  }

  public var wrappedValue: T {
    InjectedManager.current[keyPath: keyPath]
  }
}

// MARK: - TCA-style Compatibility

public typealias DependencyKey = InjectedKey
public typealias DependencyValues = InjectedValues
public typealias DependencyManager = InjectedManager

@propertyWrapper
public struct Dependency<T>: @unchecked Sendable where T: Sendable {
  private let keyPath: WritableKeyPath<InjectedValues, T>

  public init(_ keyPath: WritableKeyPath<InjectedValues, T>) {
    self.keyPath = keyPath
  }

  public var wrappedValue: T {
    InjectedManager.current[keyPath: keyPath]
  }
}

// MARK: - Dependency Manager

public enum InjectedManager {
  @TaskLocal
  private static var taskLocalValues: InjectedValues?
  private nonisolated(unsafe) static var globalValues = InjectedValues()

  public static var current: InjectedValues {
    taskLocalValues ?? globalValues
  }

  public static func setCurrent(_ values: InjectedValues) {
    globalValues = values
  }

  /// 의존성 값들을 설정하고 작업을 실행합니다.
  public static func withDependencies<R>(
    _ updateValues: (inout InjectedValues) -> Void,
    operation: () throws -> R
  ) rethrows -> R {
    var values = current
    updateValues(&values)
    return try $taskLocalValues.withValue(values, operation: operation)
  }

  /// 비동기 버전: 의존성 값들을 설정하고 작업을 실행합니다.
  public static func withDependencies<R>(
    _ updateValues: (inout InjectedValues) -> Void,
    operation: () async throws -> R
  ) async rethrows -> R {
    var values = current
    updateValues(&values)
    return try await $taskLocalValues.withValue(values, operation: operation)
  }
}

// MARK: - Convenience Extensions

extension InjectedValues {
  public mutating func set<Key: InjectedKey>(_ keyType: Key.Type, to value: Key.Value) {
    self[keyType] = value
  }
}
