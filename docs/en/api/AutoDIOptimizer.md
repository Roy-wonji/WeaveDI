---
title: AutoDIOptimizer
lang: en-US
---

# AutoDIOptimizer

자동 의존성 주입 최적화 시스템
핵심 추적 및 최적화 기능에 집중한 간소화된 시스템
## ⚠️ Thread Safety 참고사항
- 주로 앱 초기화 시 단일 스레드에서 사용됩니다
- 통계 데이터의 미세한 불일치는 기능에 영향을 주지 않습니다
- 높은 성능을 위해 복잡한 동기화를 제거했습니다

```swift
public final class AutoDIOptimizer {
}
```

  /// 디바운스 간격 설정 (50~1000ms 사이 허용, 기본 100ms)
  /// 의존성 등록 추적 (간단하게!)
  /// 의존성 해결 추적 (최적화 포함!)
  /// 의존성 관계 추적 (간단하게!)
  /// 등록된 타입 목록
  /// 해결된 타입 목록
  /// 의존성 관계 목록
  /// 간단한 통계
  /// 요약 정보 (최적화 정보 포함)
  /// 자주 사용되는 타입 TOP N
  /// 순환 의존성 간단 감지
  /// 최적화 제안
  /// 최적화 활성화/비활성화
  /// 특정 모듈 시작
  /// 특정 모듈 중지
  /// 특정 모듈 재시작
  /// 시스템 건강 상태
  /// 모든 정보 한번에 보기 (최적화 정보 포함)
  /// 초기화
  /// 현재 통계 (기존 API 호환)
  /// 그래프 시각화 (간단 버전)
  /// 자주 사용되는 타입들 (Set 버전)
  /// 감지된 순환 의존성 (Set 버전)
  /// 특정 타입이 최적화되었는지 확인
  /// 통계 초기화 (별칭)
  /// Actor 최적화 제안 (간단 버전)
  /// 타입 안전성 이슈 감지 (간단 버전)
  /// 자동 수정된 타입들 (간단 버전)
  /// Actor hop 통계 (간단 버전)
  /// 비동기 성능 통계 (간단 버전)
  /// 최근 그래프 변경사항 (간단 버전)
  /// 로그 레벨 설정
  /// 현재 로그 레벨
  /// Nil 해결 처리 (간단 버전)
  /// 설정 업데이트 (간단 버전)

```swift
public struct ActorOptimization: Sendable {
  public let suggestion: String
  public init(suggestion: String) { self.suggestion = suggestion }
}
```

로깅 레벨을 정의하는 열거형

```swift
public enum LogLevel: String, CaseIterable, Sendable {
  /// 모든 로그 출력 (기본값)
  case all = "all"
  /// 등록만 로깅
  case registration = "registration"
  /// 최적화만 로깅
  case optimization = "optimization"
  /// 에러만 로깅
  case errors = "errors"
  /// 로깅 끄기
  case off = "off"
}
```

