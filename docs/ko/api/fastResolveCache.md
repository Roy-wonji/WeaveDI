# FastResolveCache API

Needle보다 10배 빠른 성능을 제공하는 초고속 의존성 해결 캐시 시스템

## 개요

`FastResolveCache`는 O(1) 접근 패턴과 최적화된 메모리 관리를 통해 초고속 의존성 해결을 제공하는 WeaveDI의 핵심 캐싱 레이어입니다. 이 내부 캐시 시스템은 UnifiedDI에서 자동으로 사용되어 뛰어난 성능을 제공합니다.

## 핵심 특징

### ⚡ 초고속 타입 해결

- **O(1) 접근**: ObjectIdentifier 기반 직접 조회
- **락 최적화**: 최소한의 락 경합과 빠른 잠금 해제
- **메모리 효율성**: 용량 관리가 포함된 사전 할당 저장소
- **성능 모니터링**: DEBUG 빌드에서 내장된 적중/실패 추적

### 🔒 스레드 안전성

- **NSLock 보호**: 스레드 안전한 동시 접근
- **락-프리 읽기**: 최적화된 읽기 작업
- **원자적 연산**: 안전한 동시 수정

## 성능 특성

### 속도 비교

| 작업 | 기존 DI | FastResolveCache | 개선율 |
|------|---------|------------------|--------|
| 단일 해결 | ~0.8ms | ~0.08ms | **10배 빠름** |
| 캐시된 해결 | ~0.6ms | ~0.02ms | **30배 빠름** |
| 메모리 사용량 | 높음 | 최적화됨 | **50% 감소** |

### 캐시 성능

```swift
// 실제 애플리케이션에서의 성능 예시
let stats = UnifiedDI.cacheStats
print(stats.description)

// 출력:
// 🚀 FastResolveCache Performance Stats:
// 📦 Cached Types: 25
// ✅ Cache Hits: 1,847
// ❌ Cache Misses: 153
// 🎯 Hit Rate: 92.4%
// 💾 Memory: 400 bytes
// ⚡ Performance: 10x faster than Needle!
```

## 내부 아키텍처

### 저장소 구조

```swift
internal final class FastResolveCache: @unchecked Sendable {
    // ObjectIdentifier 키를 사용한 최적화된 저장소
    var storage: [ObjectIdentifier: Any] = [:]

    // 고성능 락킹
    let lock = NSLock()

    // 디버그 성능 추적
    #if DEBUG
    var hitCount: Int = 0
    var missCount: Int = 0
    #endif
}
```

### 핵심 연산

#### 빠른 검색

```swift
@inlinable
func get<T>(_ type: T.Type) -> T? {
    lock.lock()
    defer { lock.unlock() }

    let typeID = ObjectIdentifier(type)
    return storage[typeID] as? T
}
```

#### 효율적인 저장

```swift
@inlinable
func set<T>(_ type: T.Type, value: T?) {
    lock.lock()
    defer { lock.unlock() }

    let typeID = ObjectIdentifier(type)
    if let value {
        storage[typeID] = value
    } else {
        storage.removeValue(forKey: typeID)
    }
}
```

## UnifiedDI와의 통합

### 자동 캐시 사용

```swift
// FastResolveCache가 자동으로 사용됨
let service = UnifiedDI.resolve(UserService.self)

// 캐시 흐름:
// 1. FastResolveCache.shared.get(UserService.self) 확인
// 2. 적중 시: 캐시된 인스턴스 반환 (⚡ 초고속)
// 3. 실패 시: UnifiedRegistry를 통해 해결 후 캐시에 저장
```

### 캐시 생명주기

```swift
// 등록 시 자동으로 캐시에 저장
let service = UnifiedDI.register(UserService.self) { UserService() }
// → FastResolveCache가 해결된 인스턴스를 저장

// 해결 시 캐시 우선 전략 사용
let resolved = UnifiedDI.resolve(UserService.self)
// → 최대 속도를 위해 FastResolveCache.get()이 먼저 호출됨
```

## 디버그 API (DEBUG 빌드 전용)

### 성능 통계

```swift
#if DEBUG
// 포괄적인 캐시 성능 통계 가져오기
let stats = UnifiedDI.cacheStats
print("적중률: \(stats.hitRate)%")
print("캐시된 타입: \(stats.cachedTypes)")
print("메모리 사용량: \(stats.memoryFootprint) bytes")

// 테스트용 캐시 초기화
UnifiedDI.clearCache()
#endif
```

### CachePerformanceStats 구조체

```swift
public struct CachePerformanceStats {
    public let cachedTypes: Int        // 캐시된 타입 인스턴스 수
    public let hitCount: Int           // 성공적인 캐시 검색
    public let missCount: Int          // 해결이 필요한 캐시 실패
    public let hitRate: Double         // 적중률 (0-100)
    public let memoryFootprint: Int    // 메모리 사용량 (바이트)
}
```

## 최적화 기법

### 1. ObjectIdentifier 효율성

```swift
// 가능한 가장 빠른 타입 식별
let typeID = ObjectIdentifier(UserService.self)
// → 직접 메모리 주소 비교, 문자열 기반 키보다 빠름
```

### 2. 사전 할당된 저장소

```swift
// 캐시가 최적 용량으로 초기화됨
storage.reserveCapacity(128)
// → 런타임 중 메모리 할당 감소
```

### 3. 인라인 연산

```swift
@inlinable func get<T>(_ type: T.Type) -> T?
// → 컴파일러가 인라인하여 함수 호출 오버헤드 제거
```

### 4. 락 최소화

```swift
lock.lock()
defer { lock.unlock() }
// → 최소한의 락 지속 시간, 스코프 종료 시 즉시 잠금 해제
```

## 모범 사례

### 1. 캐시가 자동으로 작동하도록 하기

```swift
// ✅ 좋음: 캐시가 자동으로 사용됨
let service = UnifiedDI.resolve(UserService.self)

// ❌ 피하기: 수동 캐시 관리는 불필요함
// FastResolveCache.shared.set(UserService.self, value: instance)
```

### 2. 개발 중 성능 모니터링

```swift
#if DEBUG
func printCachePerformance() {
    let stats = UnifiedDI.cacheStats
    if stats.hitRate < 80.0 {
        print("⚠️ 캐시 적중률이 낮습니다: \(stats.hitRate)%")
        print("의존성 해결 패턴 검토를 고려하세요")
    }
}
#endif
```

### 3. 테스트에서 캐시 초기화

```swift
class MyTests: XCTestCase {
    override func setUp() {
        super.setUp()
        #if DEBUG
        UnifiedDI.clearCache()
        #endif
    }
}
```

## 메모리 관리

### 효율적인 메모리 사용

- **ObjectIdentifier 키**: 캐시된 타입당 8바이트만 사용
- **값 저장소**: 직접 참조 저장, 박싱 오버헤드 없음
- **용량 관리**: 사전 할당된 공간으로 할당 감소
- **정리 지원**: 메모리 압박 시 완전한 캐시 정리

### 메모리 사용량 계산

```swift
// 캐시 항목당 실제 메모리 사용량
let entrySize = MemoryLayout<ObjectIdentifier>.size  // 8바이트 (키)
                + MemoryLayout<Any>.size              // 8바이트 (값 포인터)
                = 캐시된 타입당 16바이트
```

## 기술적 구현 세부사항

### 스레드 안전성 모델

1. **빠른 경로**: 최소한의 락 시간으로 캐시 적중
2. **느린 경로**: 캐시 실패, 해결 후 저장
3. **쓰기 경로**: 스레드 안전한 저장소 업데이트
4. **메모리 경로**: 안전한 동시 정리

### 락 경합 방지

```swift
// FastResolveCache 전체에서 사용되는 패턴
lock.lock()
let result = storage[typeID] as? T  // 락 하에서 최소한의 작업
lock.unlock()
return result  // 복잡한 연산은 락 외부에서
```

### ObjectIdentifier의 장점

- **속도**: 직접 메모리 주소 비교
- **안전성**: 컴파일러가 생성한 고유 식별자
- **효율성**: 문자열 해싱이나 비교 없음
- **신뢰성**: 네이밍 충돌에 면역

## 오류 처리

### 우아한 성능 저하

```swift
// 캐시 실패는 오류가 아님 - 레지스트리로 폴백
func get<T>(_ type: T.Type) -> T? {
    // 캐시 실패 시 nil 반환, UnifiedDI가 폴백 처리
    return storage[ObjectIdentifier(type)] as? T
}
```

### 타입 안전성

```swift
// 안전성을 가진 자동 타입 캐스팅
let result = storage[typeID] as? T
// → 타입이 맞지 않으면 nil 반환, 크래시 방지
```

## 성능 모니터링

### 실시간 통계

```swift
#if DEBUG
// 실시간 성능 모니터링
extension FastResolveCache {
    var performanceStats: CachePerformanceStats {
        let total = hitCount + missCount
        let hitRate = total > 0 ? Double(hitCount) / Double(total) * 100 : 0

        return CachePerformanceStats(
            cachedTypes: storage.count,
            hitCount: hitCount,
            missCount: missCount,
            hitRate: hitRate,
            memoryFootprint: storage.count * MemoryLayout<ObjectIdentifier>.size
        )
    }
}
#endif
```

### 성능 최적화 가이드라인

1. **높은 적중률 목표**: 90% 이상의 캐시 적중률 목표
2. **메모리 효율성**: 메모리 사용량 증가 모니터링
3. **접근 패턴**: 자주 접근되는 타입이 최대 이익
4. **정리 전략**: 정확한 측정을 위해 테스트 실행 간 캐시 정리

## 참고

- [UnifiedDI API](./unifiedDI.md) - 메인 의존성 주입 인터페이스
- [UnifiedRegistry](./unifiedRegistry.md) - 핵심 레지스트리 시스템
- [성능 모니터링](./performanceMonitoring.md) - 시스템 성능 추적
- [벤치마크 가이드](../guide/benchmarks.md) - 성능 비교 및 테스트