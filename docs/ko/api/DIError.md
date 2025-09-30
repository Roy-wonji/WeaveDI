---
title: DIError
lang: ko-KR
---

# DIError

Dependency Injection 관련 에러를 나타내는 열거형입니다.

## 사용법:
```swift
do {
    let service = try DI.resolve(ServiceProtocol.self)
} catch DIError.dependencyNotFound(let message) {
    #logDebug("의존성을 찾을 수 없습니다: \(message)")
} catch {
    #logDebug("알 수 없는 오류: \(error)")
}
```

```swift
public enum DIError: Error, LocalizedError, CustomStringConvertible {
}
```

  /// 등록되지 않은 의존성을 해결하려고 시도한 경우
  /// 순환 의존성이 감지된 경우
  /// 의존성 등록에 실패한 경우
  /// 의존성 생성 중 오류가 발생한 경우
  /// 잘못된 구성으로 인한 오류
  /// 컨테이너가 아직 부트스트랩되지 않은 경우
  /// 내부 오류

```swift
public extension DIError {
}
```

  /// 의존성을 찾을 수 없는 오류를 생성합니다.
  /// 순환 의존성 오류를 생성합니다.
  /// 의존성 생성 실패 오류를 생성합니다.

```swift
public extension Result where Success: Any, Failure == DIError {
}
```

  /// 의존성 해결 결과에서 값을 안전하게 추출합니다.
  /// 실패 시 로그를 출력하고 nil을 반환합니다.
