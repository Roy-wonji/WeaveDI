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
    private let keyPath: KeyPath<InjectedValues, Value>
    private var cachedValue: Value?

    public init(_ keyPath: KeyPath<InjectedValues, Value>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: Value {
        mutating get {
            if let cached = cachedValue {
                return cached
            }
            let value = InjectedValues.current[keyPath: keyPath]
            cachedValue = value
            return value
        }
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

    /// Subscript for dependency access
    public subscript<Key: InjectedKey>(key: Key.Type) -> Key.Value where Key.Value: Sendable {
        get {
            if let value = storage[ObjectIdentifier(key)]?.value as? Key.Value {
                return value
            }
            return Key.liveValue
        }
        set {
            storage[ObjectIdentifier(key)] = AnySendable(newValue)
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
    static var testValue: Value {
        liveValue
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