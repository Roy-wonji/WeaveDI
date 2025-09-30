---
title: RegistrationExtensions
lang: en-US
---

# RegistrationExtensions

  /// 인터페이스 패턴을 한번에 등록하는 시스템
  /// 여러 인터페이스를 한번에 등록하는 시스템
  /// 타입 안전한 간편 스코프 등록
벌크 등록을 위한 빌더

```swift
public struct BulkRegistrationBuilder {
  public static func buildBlock(_ components: BulkRegistrationEntry...) -> [BulkRegistrationEntry] {
    Array(components)
  }
}
```

벌크 등록 엔트리

```swift
public struct BulkRegistrationEntry {
  private let createModulesFunc: (RegisterModule) -> [() -> Module]
}
```

간편한 스코프 등록을 위한 빌더

```swift
public struct EasyScopeBuilder {
  public static func buildBlock(_ components: RegisterEasyScopeEntry...) -> [RegisterEasyScopeEntry] {
    Array(components)
  }
}
```

간편한 스코프 엔트리

```swift
public struct RegisterEasyScopeEntry {
  private let moduleFactory: () -> Module
}
```

벌크 등록을 위한 연산자

```swift
public func =><Interface>(
  lhs: Interface.Type,
  rhs: (
    repository: @Sendable () -> Interface,
    useCase: @Sendable (Interface) -> Interface,
    fallback: @Sendable () -> Interface
  )
) -> BulkRegistrationEntry where Interface: Sendable {
  BulkRegistrationEntry(
    interfaceType: lhs,
    repository: rhs.repository,
    useCase: rhs.useCase,
    fallback: rhs.fallback
  )
}
```

전역 함수로 더욱 간편한 등록

```swift
public func register<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) -> RegisterEasyScopeEntry where T: Sendable {
  RegisterEasyScopeEntry(type: type, factory: factory)
}
```

사용자를 위한 전역 인터페이스 등록 함수

```swift
public func registerInterface<Interface>(
  _ interfaceType: Interface.Type,
  repository: @Sendable @escaping () -> Interface,
  useCase: @Sendable @escaping (Interface) -> Interface,
  fallback: @Sendable @escaping () -> Interface
) -> [() -> Module] where Interface: Sendable {
  let registerModule = RegisterModule()
  return registerModule.interface(
    interfaceType,
    repository: repository,
    useCase: useCase,
    fallback: fallback
  )
}
```

