# 런타임 핫패스 최적화

WeaveDI v3.1.0에서 도입된 고성능 런타임 최적화 시스템에 대해 알아보세요.

## 개요

런타임 핫패스 최적화는 의존성 주입의 성능 병목을 해결하기 위해 설계된 고급 최적화 시스템입니다.

### 주요 최적화 기술

1. **TypeID + 인덱스 접근**
   - `ObjectIdentifier` → `Int` 슬롯 매핑
   - 딕셔너리 탐색 대신 O(1) 배열 인덱스 접근
   - 메모리 접근 패턴 최적화

2. **스냅샷/락-프리 읽기**
   - 불변 Storage 클래스 기반 스냅샷 방식
   - 읽기 경합 완전 제거
   - 쓰기 시에만 락 사용

3. **인라인 최적화**
   - `@inlinable` + `@inline(__always)` 적용
   - `@_alwaysEmitIntoClient`로 크로스 모듈 최적화
   - 함수 호출 오버헤드 축소

4. **팩토리 체이닝 제거**
   - 중간 팩토리 단계 없는 직접 호출 경로
   - 의존성 체인 플래튼화
   - 다단계 팩토리 비용 제거

5. **스코프별 정적 저장소**
   - 싱글톤/세션/요청 스코프 분리
   - 원자적 once 초기화
   - 경합 조건 제거

## 사용법

### 최적화 활성화

```swift
import WeaveDI

// 최적화 모드 활성화
await UnifiedRegistry.shared.enableOptimization()

// 기존 코드는 변경 없이 성능 향상
let service = await UnifiedDI.resolve(UserService.self)
```

### 최적화 확인

```swift
// 최적화 상태 확인
let isOptimized = await UnifiedRegistry.shared.isOptimizationEnabled
print("최적화 활성화: \(isOptimized)")

// 최적화 비활성화
await UnifiedRegistry.shared.disableOptimization()
```

## 성능 향상

| 시나리오 | 개선율 | 설명 |
|---------|--------|------|
| 단일 스레드 resolve | 50-80% | TypeID + 직접 접근 |
| 멀티스레드 읽기 | 2-3배 | 락-프리 스냅샷 |
| 복잡한 의존성 | 20-40% | 체인 플래튼화 |

## 벤치마크

프로젝트에 포함된 벤치마크를 실행하여 성능 향상을 측정할 수 있습니다:

```bash
swift run -c release Benchmarks --count 100k --quick
```

## 호환성

- **100% API 호환성**: 기존 코드 변경 없음
- **옵트인 최적화**: 언제든 활성화/비활성화 가능
- **점진적 마이그레이션**: 단계별 적용 지원
- **제로 브레이킹 체인지**: 기존 동작 완전 보장

## 내부 구현

최적화는 다음 파일들에서 구현됩니다:

- `OptimizedTypeRegistry.swift` - TypeID 시스템
- `AtomicStorage.swift` - 락-프리 저장소
- `DirectCallRegistry.swift` - 직접 호출 경로
- `OptimizedScopeStorage.swift` - 스코프 최적화

## 참고 자료

- [성능 최적화 가이드](../../PERFORMANCE-OPTIMIZATION.md)
- [벤치마크 문서](Benchmarks.md)
- [UnifiedDI API](UnifiedDI.md)

---

📖 **문서**: [한국어](RuntimeOptimization) | [English](../en.lproj/RuntimeOptimization)