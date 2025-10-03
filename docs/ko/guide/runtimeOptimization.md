# 런타임 핫패스 최적화

WeaveDI v3.1.0에서 도입된 고성능 런타임 최적화 시스템에 대해 알아보세요.

## 개요

런타임 핫패스 최적화는 의존성 주입의 성능 병목을 제거하기 위해 설계된 고급 최적화 시스템입니다.

### 핵심 최적화 기술

1. **TypeID + 인덱스 접근**
   - `ObjectIdentifier` → `Int` 슬롯 매핑
   - 딕셔너리 조회 대신 O(1) 배열 인덱스 접근
   - 메모리 접근 패턴 최적화

2. **스냅샷/락-프리 읽기**
   - 불변 Storage 클래스 기반 스냅샷 방식
   - 읽기 경합 완전 제거
   - 쓰기 시에만 락 사용

3. **인라인 최적화**
   - `@inlinable` + `@inline(__always)` 적용
   - `@_alwaysEmitIntoClient`로 크로스 모듈 최적화
   - 함수 호출 오버헤드 감소

4. **팩토리 체인 제거**
   - 중간 팩토리 단계 없는 직접 호출 경로
   - 의존성 체인 평탄화
   - 다단계 팩토리 비용 제거

5. **스코프별 정적 스토리지**
   - singleton/session/request 스코프 분리
   - 원자적 once 초기화
   - 경쟁 상태 제거

## 사용법

### 자동 최적화

UnifiedRegistry 최적화는 WeaveDI v3.2.0+에서 **자동으로 활성화**됩니다. 별도 설정 불필요:

```swift
import WeaveDI

// ✅ 최적화가 자동으로 적용됨
let service = UnifiedDI.resolve(UserService.self)

// ✅ DIContainer도 UnifiedRegistry 최적화 혜택을 받음
let container = WeaveDI.Container()
let service2 = container.resolve(UserService.self)
```

### 성능 검증

```swift
// 최적화 상태 확인
let isOptimized = await UnifiedRegistry.shared.isOptimizationEnabled
print("최적화 활성화됨: \(isOptimized)")

// 최적화 비활성화
await UnifiedRegistry.shared.disableOptimization()
```

## 성능 향상

| 시나리오 | 향상도 | 설명 |
|----------|--------|------|
| 단일 스레드 해결 | 50-80% 빠름 | TypeID + 직접 접근 |
| 멀티 스레드 읽기 | 2-3배 처리량 | 락-프리 스냅샷 |
| 복잡한 의존성 | 20-40% 빠름 | 체인 평탄화 |

## 벤치마크

포함된 벤치마크를 실행하여 성능 향상을 측정하세요:

```bash
swift run -c release Benchmarks --count 100k --quick
```

## 호환성

- **100% API 호환성**: 기존 코드 변경 불필요
- **선택적 최적화**: 언제든지 활성화/비활성화 가능
- **점진적 마이그레이션**: 단계별 적용 지원
- **무중단 변경**: 기존 동작 완전 보존

## 내부 구현

최적화는 다음 파일들에 구현되어 있습니다:

- `OptimizedTypeRegistry.swift` - TypeID 시스템
- `AtomicStorage.swift` - 락-프리 스토리지
- `DirectCallRegistry.swift` - 직접 호출 경로
- `OptimizedScopeStorage.swift` - 스코프 최적화

## 관련 문서

- [성능 최적화 가이드](/ko/guide/runtimeOptimization)
- [벤치마크 문서](/ko/guide/benchmarks)
- [UnifiedDI API](/ko/guide/unifiedDi)
