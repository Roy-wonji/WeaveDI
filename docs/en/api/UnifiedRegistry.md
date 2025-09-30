---
title: UnifiedRegistry
lang: en-US
---

# UnifiedRegistry

## 개요
`UnifiedRegistry`는 모든 의존성 등록 및 해결을 통합 관리하는 중앙화된 시스템입니다.
기존의 분산된 Registry들(`TypeSafeRegistry`, `AsyncTypeRegistry`, `SimpleKeyPathRegistry`)을
하나로 통합하여 일관성과 성능을 개선합니다.
## 핵심 특징
### 🏗️ 통합된 저장소
- **동기 팩토리**: 즉시 생성되는 의존성
- **비동기 팩토리**: async 컨텍스트에서 생성되는 의존성
- **KeyPath 매핑**: 타입 안전한 KeyPath 기반 접근
### 🔒 동시성 안전성
- **Actor 기반**: Swift Concurrency를 활용한 데이터 경쟁 방지
- **Type-safe Keys**: ObjectIdentifier 기반 타입 안전한 키
- **Memory Safety**: 자동 메모리 관리 및 순환 참조 방지
### ⚡ 성능 최적화
- **지연 생성**: 실제 사용 시점까지 생성 지연
- **타입 추론**: 컴파일 타임 타입 최적화
- **성능 추적**: AutoDIOptimizer 자동 통합
## 사용 예시
### 기본 등록
```swift
let registry = UnifiedRegistry()
// 팩토리 등록
await registry.register(NetworkService.self) { DefaultNetworkService() }
// 비동기 팩토리 등록
await registry.registerAsync(CloudService.self) { await CloudServiceImpl() }
```
### 해결 (Resolution)
```swift
// 동기 해결
let service = await registry.resolve(NetworkService.self)
// 비동기 해결
let cloudService = await registry.resolveAsync(CloudService.self)
// KeyPath 기반 해결
let database = await registry.resolve(keyPath: \.database)
// 성능 추적과 함께 해결
let service = await registry.resolveWithPerformanceTracking(NetworkService.self)
```
### 조건부 등록
```swift
await registry.registerIf(
    AnalyticsService.self,
    condition: !isDebugMode,
    factory: { FirebaseAnalytics() },
    fallback: { MockAnalytics() }
)
```

```swift
public actor UnifiedRegistry {
}
```

  /// Type-erased, sendable box for storing values safely across concurrency boundaries
  /// Factory closure that produces instances
  /// 동기 팩토리 저장소 (매번 새 인스턴스 생성)
  /// 비동기 팩토리 저장소 (매번 새 인스턴스 생성)
  /// In-flight async singleton creation tasks (once-only semantics)
  /// KeyPath 매핑 (KeyPath String -> TypeIdentifier)
  /// 등록된 타입 통계 (디버깅 및 모니터링용)
  /// 동기 팩토리 등록 (매번 새 인스턴스 생성)
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - factory: 인스턴스를 생성하는 동기 클로저
  /// 비동기 팩토리 등록 (매번 새 인스턴스 생성)
  /// - Parameters:
  ///   - type: 등록할 타입
  ///   - factory: 인스턴스를 생성하는 비동기 클로저
  /// 비동기 싱글톤 등록 (최초 1회 생성 후 캐시)
  /// 내부 헬퍼: Async 싱글톤 박스 얻기/생성
  /// 조건부 등록 (동기)
  /// 조건부 등록 (비동기)
  /// KeyPath를 사용한 등록
  /// - Parameters:
  ///   - keyPath: WeaveDI.Container 내의 KeyPath
  ///   - factory: 인스턴스 생성 팩토리
  /// 비동기 컨텍스트에서 런타임 타입(Any.Type)으로 의존성을 해결합니다.
  /// - Parameter type: 해결할 런타임 타입
  /// - Returns: 해결된 인스턴스 (없으면 nil)
  /// 비동기 컨텍스트에서 런타임 타입(Any.Type)을 Sendable 박스로 해결합니다.
  /// - Parameter type: 해결할 런타임 타입
  /// - Returns: ValueBox(@unchecked Sendable)에 담긴 값 (없으면 nil)
  /// 비동기 의존성 해결
  /// - Parameter type: 해결할 타입
  /// - Returns: 해결된 인스턴스 (없으면 nil)
  /// KeyPath를 사용한 해결 (async)
  /// 특정 타입의 등록을 해제합니다
  /// - Parameter type: 해제할 타입
  /// 모든 등록을 해제합니다
  /// 특정 스코프의 인스턴스들을 모두 해제합니다.
  /// - Returns: 해제된 개수
  /// 특정 타입의 스코프 인스턴스를 해제합니다.
  /// - Returns: 해제 여부
  /// 등록된 타입들의 통계 정보 반환
  /// - Returns: 등록 통계
  /// 특정 타입이 등록되었는지 확인
  /// - Parameter type: 확인할 타입
  /// - Returns: 등록 여부
  /// 현재 등록된 모든 타입 이름 반환
  /// - Returns: 타입 이름 배열
  /// 등록 정보 업데이트
등록 타입

```swift
public enum RegistrationType {
  case syncFactory
  case asyncFactory
  case asyncSingleton
  case scopedFactory
  case scopedAsyncFactory
}
```

등록 정보

```swift
public struct RegistrationInfo {
  public let type: RegistrationType
  public let registrationCount: Int
  public let lastRegistrationDate: Date
}
```

  /// 런타임 최적화를 활성화합니다
  /// 런타임 최적화를 비활성화합니다
  /// 최적화 상태 확인
  /// 최적화된 해결 시도 (내부용)
  /// 최적화된 등록 (내부용)
간단한 최적화 관리자
글로벌 통합 Registry 인스턴스
WeaveDI.Container.live에서 내부적으로 사용

```swift
public let GlobalUnifiedRegistry = UnifiedRegistry()
public let GlobalUnifiedRegistry = UnifiedRegistry()
}
```

