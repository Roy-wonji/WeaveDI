---
title: DIAdvanced
lang: en-US
---

# DIAdvanced

## 개요
`DIAdvanced`는 Wonji Suh가 설계한 고급 의존성 주입 기능들을 제공합니다.
일반적인 사용에서는 필요하지 않지만, 특수한 요구사항이 있을 때 사용할 수 있습니다.
## 설계 철학
- **선택적 복잡성**: 필요할 때만 사용하는 고급 기능
- **명확한 분리**: 핵심 API와 분리하여 복잡도 최소화
- **실용적 접근**: 실제로 필요한 기능들만 제공

```swift
public enum DIAdvanced {
}
```

  /// 성능 최적화 관련 기능들
    /// 성능 추적과 함께 의존성을 해결합니다
    /// 자동 성능 최적화와 함께 의존성을 해결합니다.
    /// AutoDIOptimizer가 자동으로 사용 통계를 수집합니다.
    /// - Parameter type: 해결할 타입
    /// - Returns: 해결된 인스턴스 (없으면 nil)
    /// 자주 사용되는 타입으로 표시하여 성능을 최적화합니다
    /// - Parameter type: 최적화할 타입
    /// 성능 최적화를 활성화합니다
    /// 현재 성능 통계를 반환합니다
  /// 일괄 등록 관련 기능들
    /// 여러 의존성을 한번에 등록합니다
    /// - Parameter registrations: 등록할 의존성 목록
  /// 자동 의존성 감지 기능은 제거되었습니다.
  /// 대신 수동으로 의존성 그래프를 관리하거나 DependencyGraph를 사용하세요.
    /// 더 이상 지원되지 않습니다
    /// 더 이상 지원되지 않습니다
  /// 스코프 관리 관련 기능들
    /// 스코프 기반 등록 (동기)
    /// 스코프 기반 등록 (비동기)
    /// 특정 스코프의 모든 인스턴스를 해제합니다 (async)
    /// 특정 타입의 스코프 인스턴스를 해제합니다 (async)
일괄 등록을 위한 Result Builder

```swift
public struct BatchRegistrationBuilder {
  public static func buildBlock(_ components: BatchRegistration...) -> [BatchRegistration] {
    return components
  }
}
```

일괄 등록을 위한 등록 아이템

```swift
public struct BatchRegistration {
  private let registerAction: () -> Void
}
```

  /// 팩토리 기반 등록
  /// 기본값 포함 등록
  /// 조건부 등록
  /// 등록 실행
