---
title: RegistrationCore
lang: en-US
---

# RegistrationCore

`Module`은 DI(의존성 주입)를 위한 **단일 모듈**을 나타내는 구조체입니다.
이 타입을 사용하면, 특정 타입의 인스턴스를 `WeaveDI.Container`에
**비동기적으로 등록**하는 작업을 하나의 객체로 캡슐화할 수 있습니다.

```swift
public struct Module: Sendable {
  private let registrationClosure: @Sendable () async -> Void
  // Debug metadata for diagnostics and reporting
  internal let debugTypeName: String
  internal let debugFile: String
  internal let debugFunction: String
  internal let debugLine: Int
}
```

  /// Throwing variant kept for future expandability
RegisterModule의 핵심 기능만 포함한 깔끔한 버전

```swift
public struct RegisterModule: Sendable {
}
```

A lightweight helper to intentionally box non-Sendable values
for use inside @Sendable closures. Use with caution and only if
you can guarantee thread-safety of the underlying value.

```swift
public struct UncheckedSendableBox<T>: @unchecked Sendable {
  public let value: T
  public init(_ value: T) { self.value = value }
}
```

Convenience function to create an UncheckedSendableBox

```swift
public func unsafeSendable<T>(_ value: T) -> UncheckedSendableBox<T> {
  UncheckedSendableBox(value)
}
```

