---
title: DependencyScope
lang: ko-KR
---

# DependencyScope

의존성 스코프를 정의하는 프로토콜입니다.
Needle 스타일의 컴파일 타임 검증을 위한 기반 프로토콜로,
각 모듈의 의존성과 제공하는 서비스를 명시적으로 정의합니다.

```swift
public protocol DependencyScope {
  /// 이 스코프가 필요로 하는 의존성들의 타입
  associatedtype Dependencies
}
```

  /// 이 스코프가 제공하는 서비스들의 타입
  /// 의존성 검증을 수행합니다.
  /// - Returns: 모든 의존성이 유효한 경우 true
의존성이 없는 경우 사용하는 타입입니다.

```swift
public struct EmptyDependencies {
  public init() {}
}
```

  /// 기본 검증 구현
  /// 의존성과 제공 타입 간의 관계를 검증합니다.
의존성 검증 실패 시 발생하는 오류입니다.

```swift
public enum DependencyValidationError: Error, CustomStringConvertible {
  case missingDependency(String)
  case circularDependency(String)
  case typeMismatch(expected: String, actual: String)
}
```

의존성 검증을 위한 헬퍼 유틸리티입니다.

```swift
public struct DependencyValidation {
}
```

  /// 특정 타입의 의존성이 등록되어 있는지 확인합니다.
  /// - Parameter type: 확인할 의존성 타입
  /// - Returns: 등록 여부
  /// 여러 의존성이 모두 등록되어 있는지 확인합니다.
  /// - Parameter types: 확인할 의존성 타입들
  /// - Returns: 모든 의존성이 등록되어 있으면 true
  /// 의존성 그래프에 순환 참조가 있는지 확인합니다.
  /// - Parameter startType: 검사를 시작할 타입
  /// - Returns: 순환 참조 여부
