//
//  Dependency.swift
//  WeaveDI
//
//  Created by Wonji Suh on 2025.
//

import Foundation

// MARK: - @Injected (WeaveDI-style)

/// WeaveDI의 강력한 의존성 주입 Property Wrapper
/// TCA의 @Dependency 스타일을 기반으로 WeaveDI에 최적화되었습니다.
///
/// ### 사용법:
/// ```swift
/// struct MyFeature: Reducer {
///     @Injected(\.apiClient) var apiClient
///     @Injected(\.database) var database
///     @Injected(ExchangeUseCase.self) var exchangeUseCase  // 타입으로도 가능
/// }
///
/// // Extension으로 의존성 정의
/// extension InjectedValues {
///     var apiClient: APIClient {
///         get { self[APIClientKey.self] }
///         set { self[APIClientKey.self] = newValue }
///     }
/// }
/// ```
@propertyWrapper
public struct Injected<Value> {
  private let keyPath: KeyPath<InjectedValues, Value>?
  private let keyType: (any InjectedKey.Type)?
  
  /// KeyPath를 사용한 초기화
  public init(_ keyPath: KeyPath<InjectedValues, Value>) {
    self.keyPath = keyPath
    self.keyType = nil
  }
  
  /// 타입을 직접 사용한 초기화
  public init<K: InjectedKey>(_ type: K.Type) where K.Value == Value, K.Value: Sendable {
    self.keyPath = nil
    self.keyType = type
  }
  
  public var wrappedValue: Value {
    get {
      if let keyPath = keyPath {
        return InjectedValues.current[keyPath: keyPath]
      } else if let keyType = keyType {
        // Use a helper function to bridge the type-erased call
        return _getValue(from: keyType)
      } else {
        fatalError("@Injected requires either keyPath or keyType")
      }
    }
  }
  
  // Helper to bridge type-erased access
  private func _getValue<K: InjectedKey>(from type: K.Type) -> Value where K.Value: Sendable {
    return InjectedValues.current[type] as! Value
  }
}

// MARK: - InjectedValues

/// WeaveDI의 전역 의존성 컨테이너
public struct InjectedValues: Sendable {
  private var storage: [ObjectIdentifier: AnySendable] = [:]
  
  /// 현재 스레드의 InjectedValues
  @TaskLocal
  public static var current = InjectedValues()
  
  public init() {}
  
  /// Subscript for dependency access by type
  /// 🎯 TCA 자동 동기화: 모든 InjectedKey가 자동으로 TCA DependencyValues와 동기화됩니다!
  public subscript<Key: InjectedKey>(key: Key.Type) -> Key.Value where Key.Value: Sendable {
    get {
      // 1. 기존 storage에서 먼저 확인
      if let value = storage[ObjectIdentifier(key)]?.value as? Key.Value {
        return value
      }

      // 2. WeaveDI에서 조회 시도
      if let resolved = UnifiedDI.resolve(Key.Value.self) {
        return resolved
      }

      // 3. 기본 InjectedKey liveValue 사용
      let value = key.liveValue

      // 4. 🎯 자동 동기화: WeaveDI와 TCA에 모두 등록
      // WeaveDI에 등록
      _ = UnifiedDI.register(Key.Value.self) { value }

      // TCA DependencyValues에 자동 동기화 (조건부)
      #if canImport(Dependencies)
      TCABridgeHelper.autoSyncToTCA(Key.Value.self, value: value)
      #endif

      return value
    }
    set {
      // 1. 기존 storage 업데이트
      storage[ObjectIdentifier(key)] = AnySendable(newValue)

      // 2. 🎯 자동 동기화: WeaveDI와 TCA에 모두 등록
      // WeaveDI에 등록
      _ = UnifiedDI.register(Key.Value.self) { newValue }

      // TCA DependencyValues에 자동 동기화 (조건부)
      #if canImport(Dependencies)
      TCABridgeHelper.autoSyncToTCA(Key.Value.self, value: newValue)
      #endif
    }
  }
  
}

// MARK: - AnySendable

/// Sendable wrapper for storage
private struct AnySendable: @unchecked Sendable {
  let value: Any
  
  init<T: Sendable>(_ value: T) {
    self.value = value
  }
}

// MARK: - InjectedKey

/// 의존성을 정의하기 위한 프로토콜
public protocol InjectedKey {
  associatedtype Value: Sendable
  static var liveValue: Value { get }
  static var testValue: Value { get }
}

public extension InjectedKey {
  static var liveValue: Value {
    liveValue
  }

  static var testValue: Value {
    testValue
  }
}

// MARK: - withInjectedValues

/// 특정 의존성을 오버라이드하여 실행
public func withInjectedValues<R>(
  _ updateValuesForOperation: (inout InjectedValues) throws -> Void,
  operation: () throws -> R
) rethrows -> R {
  var values = InjectedValues.current
  try updateValuesForOperation(&values)
  return try InjectedValues.$current.withValue(values) {
    try operation()
  }
}

/// 비동기 버전
public func withInjectedValues<R>(
  _ updateValuesForOperation: (inout InjectedValues) throws -> Void,
  operation: () async throws -> R
) async rethrows -> R {
  var values = InjectedValues.current
  try updateValuesForOperation(&values)
  return try await InjectedValues.$current.withValue(values) {
    try await operation()
  }
}
