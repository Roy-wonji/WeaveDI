---
title: TypeRegistry
lang: en-US
---

# TypeRegistry

Actor-based async registry for DIAsync.
Stores async factories without using GCD/locks.

```swift
public actor AsyncTypeRegistry {
  // Type-erased, sendable box to safely move values across concurrency domains
  public struct AnySendableBox: @unchecked Sendable {
    public let value: Any
    public init(_ v: Any) { self.value = v }
  }
}
```

  /// Register an async factory for a type (transient resolution)
  /// Resolve a type and return a sendable box
  /// Release a registration (factory)
  /// Clear all registrations (test-only recommended)
Needle 스타일의 자동 등록을 위한 타입 매핑 레지스트리입니다.

```swift
public final class AutoRegistrationRegistry: @unchecked Sendable {
  public static let shared = AutoRegistrationRegistry()
}
```

  /// 타입과 그 구현체를 등록합니다.
  /// 등록된 타입에 대한 인스턴스를 생성합니다.
  /// 타입이 등록되어 있는지 확인합니다.
  /// 등록된 타입에 대한 인스턴스를 해결합니다.
  /// 모든 등록된 타입을 출력합니다 (디버깅용)
  /// 등록된 타입 개수를 반환합니다.
  /// 등록된 모든 타입 이름을 반환합니다 (디버깅용)
  /// 여러 타입을 한번에 등록하는 편의 메서드입니다.
타입 등록을 위한 Result Builder입니다.

```swift
public struct TypeRegistrationBuilder {
  public static func buildBlock(_ components: TypeRegistration...) -> [TypeRegistration] {
    components
  }
}
```

개별 타입 등록을 나타내는 구조체입니다.

```swift
public struct TypeRegistration {
  private let registerFunc: (AutoRegistrationRegistry) -> Void
}
```

전역 함수로 자동 등록 설정을 간편하게 할 수 있습니다.

```swift
public func setupAutoRegistration() {
  // 사용자가 필요에 따라 타입들을 등록할 수 있습니다.
  // AutoRegistrationRegistry.shared.registerTypes {
  //     TypeRegistration(NetworkServiceProtocol.self) { DefaultNetworkService() }
  // }
}
```

