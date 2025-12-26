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

  /// 🚀 **TCA 스타일 지원**: DependencyKey 패턴을 위한 subscript
  ///
  /// 사용자가 extension SignUpUseCaseImpl: DependencyKey 패턴을 사용할 때
  /// DependencyValues에서 self[SignUpUseCaseImpl.self] 형태로 접근 가능
  public subscript<T: Sendable>(dependencyKeyType: T.Type) -> T {
    get {
      // 1. UnifiedDI에서 먼저 조회
      if let resolved = UnifiedDI.resolve(dependencyKeyType, logOnMiss: false) {
        return resolved
      }

      // 2. storage에서 조회
      let key = ObjectIdentifier(dependencyKeyType)
      if let stored = storage[key] as? T {
        return stored
      }

      // 3. liveValue 시도 (DependencyKey conformance 확인)
      if let dependencyKey = dependencyKeyType as? any InjectedKey.Type {
        let liveValue = dependencyKey.liveValue
        if let typedValue = liveValue as? T {
          return typedValue
        }
      }

      fatalError("🚨 [WeaveDI] \(dependencyKeyType) 의존성을 찾을 수 없습니다!")
    }
    set {
      let key = ObjectIdentifier(dependencyKeyType)
      storage[key] = newValue

      // UnifiedDI에도 등록해서 @Injected에서 사용 가능하게 함
      _ = UnifiedDI.register(dependencyKeyType) { newValue }
    }
  }
}

// MARK: - Enhanced Dependency Property Wrapper

/// 🚀 **개선된 @Injected** - TCA 스타일로 타입만으로 간단하게!
///
/// ### Before (복잡함):
/// ```swift
/// @Injected(\.userService) var userService: UserService
/// ```
///
/// ### After (간단함):
/// ```swift
/// @Injected var userService: UserService  // 끝!
/// ```
@propertyWrapper
public struct Injected<T>: @unchecked Sendable where T: Sendable {
  private let keyPath: WritableKeyPath<InjectedValues, T>?
  private let type: T.Type

  // MARK: - 초기화

  /// 🎯 **타입만으로 간단하게!** (새 방식 - 권장)
  ///
  /// UnifiedDI에 등록된 타입을 자동으로 해결합니다.
  ///
  /// ### 사용법:
  /// ```swift
  /// @Injected var userService: UserService
  /// @Injected var repository: Repository
  /// ```
  public init() where T: Sendable {
    self.type = T.self
    self.keyPath = nil
  }

  /// 🔄 **KeyPath 방식** (TCA 완전 호환!)
  ///
  /// InjectedValues(=DependencyValues)의 KeyPath를 사용하는 방식입니다.
  /// TCA에서 정의한 DependencyValues extension을 바로 사용할 수 있습니다!
  ///
  /// ### 사용법:
  /// ```swift
  /// // TCA extension 정의
  /// extension DependencyValues {
  ///     var userService: UserService { ... }
  /// }
  ///
  /// @Injected(\.userService) var userService: UserService  // ✅ 바로 사용!
  /// ```
  public init(_ keyPath: WritableKeyPath<InjectedValues, T>) {
    self.type = T.self
    self.keyPath = keyPath
  }


  // MARK: - Property Wrapper 구현

  public var wrappedValue: T {
    get {
      if let keyPath = keyPath {
        // 🔄 기존 KeyPath 방식
        return InjectedManager.current[keyPath: keyPath]
      } else {
        // 🎯 새로운 타입 기반 방식
        return resolveFromUnifiedDI()
      }
    }
  }

  // MARK: - Private 구현

  /// UnifiedDI와 InjectedValues에서 동기화된 해결
  private func resolveFromUnifiedDI() -> T {
    // 1. UnifiedDI에서 먼저 시도
    if let resolved = UnifiedDI.resolve(type, logOnMiss: false) {
      return resolved
    }

    // 2. InjectedValues에서 타입 기반으로 시도 (🔄 @Dependency 동기화!)
    if let resolved = tryResolveFromInjectedValues() {
      return resolved
    }

    // 3. 모두 실패하면 명확한 에러
    fatalError("""
        🚨 [WeaveDI] \(type) 의존성을 찾을 수 없습니다!

        💡 해결 방법:
        1. UnifiedDI 등록: UnifiedDI.register(\(type).self) { YourImplementation() }
        2. DependencyValues 등록: extension DependencyValues { var yourService: \(type) { ... } }
        3. 새 방식 등록: WeaveDI.register { YourImplementation() }

        🔍 등록이 해결보다 먼저 수행되었는지 확인하세요.
        """)
  }

  /// InjectedValues에서 타입 기반 해결 시도
  private func tryResolveFromInjectedValues() -> T? {
    let current = InjectedManager.current

    // 타입 기반으로 InjectedValues에서 해결 시도
    let resolved = current[type]
    return resolved
  }
}

// MARK: - 🚨 중요: Dependency 타입은 완전히 제거됨
//
// ComposableArchitecture와의 충돌을 방지하기 위해
// WeaveDI의 모든 Dependency 관련 타입을 제거했습니다.
//
// 대신 사용하세요:
// - @Injected var service: ServiceType
// - @ComposableArchitecture.Dependency(\.service) var service
//

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
