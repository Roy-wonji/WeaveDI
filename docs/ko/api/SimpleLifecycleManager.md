---
title: SimpleLifecycleManager
lang: ko-KR
---

# SimpleLifecycleManager

간단한 모듈 생명주기 관리자

```swift
public actor SimpleLifecycleManager {
}
```

  /// 모듈 상태
  /// 모듈 상태 정보
  /// 시스템 건강 상태
  /// 특정 모듈 시작
  /// 특정 모듈 중지
  /// 특정 모듈 재시작
  /// 모든 모듈 상태 조회
  /// 시스템 건강 상태 조회
  /// 활성 모듈 목록 조회
  /// 에러 모듈 목록 조회
생명주기 관련 에러

```swift
public enum LifecycleError: Error, Sendable {
  case moduleNotRegistered(String)
  case invalidStateTransition(String)
}
```

