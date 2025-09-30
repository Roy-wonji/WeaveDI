---
title: SimpleKeyPathRegistry
lang: en-US
---

# SimpleKeyPathRegistry

간단한 KeyPath 기반 의존성 등록 시스템
## 사용법:
```swift
// 1. 기본 등록
SimpleKeyPathRegistry.register(\.userService) { UserServiceImpl() }
// 2. 조건부 등록
SimpleKeyPathRegistry.registerIf(\.analytics, condition: !isDebug) {
    AnalyticsServiceImpl()
}
```

```swift
public enum SimpleKeyPathRegistry {
}
```

  /// KeyPath 기반 기본 등록
  /// KeyPath 기반 조건부 등록
  /// KeyPath 기반 인스턴스 등록
  /// Debug 환경에서만 등록
  /// Release 환경에서만 등록
  /// 특정 KeyPath의 등록 상태 확인
  /// KeyPath에서 이름 추출
안전한 DependencyKey 패턴을 위한 헬퍼

```swift
public enum SimpleSafeDependencyRegister {
}
```

  /// KeyPath로 안전하게 의존성 해결
  /// KeyPath로 의존성 해결 (기본값 포함)
