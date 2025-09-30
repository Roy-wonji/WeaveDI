---
title: SafeDIError
lang: en-US
---

# SafeDIError

안전한 의존성 주입을 위한 에러 타입

```swift
public enum SafeDIError: Error, LocalizedError, CustomStringConvertible {
}
```

  /// 의존성을 찾을 수 없는 경우
  /// 필수 의존성이 등록되지 않은 경우
  /// Factory를 찾을 수 없는 경우
  /// 순환 의존성이 탐지된 경우
  /// 의존성 해결 중 타임아웃
  /// 잘못된 설정
  /// 컨테이너가 초기화되지 않은 경우
  /// 개발자 친화적인 디버그 메시지
  /// 복구 가능한 에러인지 확인
안전한 의존성 해결 결과

```swift
public enum SafeResolutionResult<T> {
  case success(T)
  case failure(SafeDIError)
}
```

  /// 성공한 경우 값을 반환, 실패한 경우 nil
  /// 에러 정보
안전한 의존성 주입을 위한 프로토콜

```swift
public protocol SafeInjectable {
  /// 안전한 의존성 해결
  static func safeDependencyResolution() -> SafeResolutionResult<Self>
}
```

에러 복구 전략

```swift
public enum RecoveryStrategy<T> {
  case useDefault(T)
  case retry(maxAttempts: Int)
  case fallback(() throws -> T)
  case ignore
}
```

안전한 의존성 해결 헬퍼

```swift
public enum SafeDependencyResolver {
}
```

  /// 에러와 함께 안전한 해결
  /// 복구 전략과 함께 안전한 해결
