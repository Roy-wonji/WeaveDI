---
title: Dependency
lang: en-US
---

# Dependency

WeaveDI의 강력한 의존성 주입 Property Wrapper
TCA의 @Dependency 스타일을 기반으로 WeaveDI에 최적화되었습니다.
### 사용법:
```swift
struct MyFeature: Reducer {
    @Injected(\.apiClient) var apiClient
    @Injected(\.database) var database
    @Injected(ExchangeUseCase.self) var exchangeUseCase  // 타입으로도 가능
}
// Extension으로 의존성 정의
extension InjectedValues {
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}
```

```swift
public struct Injected<Value> {
  private let keyPath: KeyPath<InjectedValues, Value>?
  private let keyType: (any InjectedKey.Type)?
}
```

  /// KeyPath를 사용한 초기화
  /// 타입을 직접 사용한 초기화
WeaveDI의 전역 의존성 컨테이너

```swift
public struct InjectedValues: Sendable {
  private var storage: [ObjectIdentifier: AnySendable] = [:]
}
```

  /// 현재 스레드의 InjectedValues
  /// Subscript for dependency access by type
Sendable wrapper for storage
의존성을 정의하기 위한 프로토콜

```swift
public protocol InjectedKey {
  associatedtype Value: Sendable
  static var liveValue: Value { get }
  static var testValue: Value { get }
}
```

특정 의존성을 오버라이드하여 실행

```swift
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
```

비동기 버전

```swift
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
```

