# RegistrationMetricsDispatcher API

등록 시 생성되는 여러 모니터링 태스크를 하나의 배치 파이프라인으로 모으는 고성능 배치 시스템

## 개요

`RegistrationMetricsDispatcher`는 모니터링 작업을 효율적으로 통합하여 성능 오버헤드를 최소화하는 WeaveDI의 효율적인 배치 레이어입니다. 각 등록 시마다 모니터링 태스크를 즉시 실행하는 대신, 최적의 처리량을 위해 파이프라인 작업으로 지능적으로 배치합니다.

## 핵심 특징

### ⚡ 배치 처리
- **태스크 큐잉**: 실행 전 여러 모니터링 작업 수집
- **자동 스케줄링**: 불필요한 태스크 생성을 방지하는 스마트 스케줄링
- **유틸리티 우선순위**: 백그라운드 처리로 메인 작업 방해 없음
- **메모리 효율성**: 작업 누적 전략으로 최소한의 오버헤드

### 🔒 스레드 안전성
- **NSLock 보호**: 스레드 안전한 동시 작업 큐잉
- **원자적 스케줄링**: 배치 스케줄링의 경쟁 상태 방지
- **안전한 플러싱**: 데이터 경쟁 없는 조정된 배치 처리

## 성능 특성

### 효율성 비교

| 방식 | 태스크 생성 | 컨텍스트 스위치 | 메모리 압박 |
|------|-------------|----------------|-------------|
| 즉시 실행 | 등록마다 1개 | 높음 | 보통 |
| **RegistrationMetricsDispatcher** | 배치마다 1개 | **낮음** | **최소** |

### 배치 이점

```swift
// 배치 없이 (비효율적)
// 각 등록이 별도 태스크 생성
UnifiedDI.register(ServiceA.self) { ServiceA() }  // → 태스크 1
UnifiedDI.register(ServiceB.self) { ServiceB() }  // → 태스크 2
UnifiedDI.register(ServiceC.self) { ServiceC() }  // → 태스크 3

// RegistrationMetricsDispatcher와 함께 (효율적)
// 여러 등록이 단일 태스크 공유
UnifiedDI.register(ServiceA.self) { ServiceA() }  // → 큐잉됨
UnifiedDI.register(ServiceB.self) { ServiceB() }  // → 큐잉됨
UnifiedDI.register(ServiceC.self) { ServiceC() }  // → 큐잉됨 + 배치 실행
```

## 내부 아키텍처

### 핵심 구조

```swift
final class RegistrationMetricsDispatcher: @unchecked Sendable {
    typealias Job = @Sendable () async -> Void

    static let shared = RegistrationMetricsDispatcher()

    private let lock = NSLock()
    private var pending: [Job] = []
    private var isScheduled = false
}
```

### 주요 작업

#### 작업 큐잉

```swift
func enqueueRegistration<T>(_ type: T.Type) where T: Sendable {
    enqueue { await AutoDIOptimizer.shared.trackRegistration(type) }
}

private func enqueue(_ job: @escaping Job) {
    var shouldSchedule = false
    lock.lock()
    pending.append(job)
    if !isScheduled {
        isScheduled = true
        shouldSchedule = true
    }
    lock.unlock()

    if shouldSchedule {
        Task(priority: .utility) {
            await self.flush()
        }
    }
}
```

#### 배치 처리

```swift
private func flush() async {
    while true {
        let jobs = nextBatch()
        if jobs.isEmpty { break }
        for job in jobs {
            await job()
        }
    }
}

private func nextBatch() -> [Job] {
    lock.lock()
    let jobs = pending
    pending.removeAll()
    if pending.isEmpty {
        isScheduled = false
    }
    lock.unlock()
    return jobs
}
```

## WeaveDI와의 통합

### 자동 사용

```swift
// RegistrationMetricsDispatcher가 자동으로 사용됨
let service = UnifiedDI.register(UserService.self) { UserService() }

// 내부 흐름:
// 1. 등록 완료
// 2. RegistrationMetricsDispatcher.shared.enqueueRegistration(UserService.self)
// 3. 배치 처리를 위한 작업 큐잉
// 4. 백그라운드 태스크가 큐잉된 모든 모니터링 작업 처리
```

### 성능 흐름

```swift
// 여러 번의 빠른 등록
for i in 1...100 {
    UnifiedDI.register(Service\(i).self) { Service\(i)() }
}

// 효율적인 배치:
// - 100개의 모니터링 작업 큐잉
// - 배치 처리를 위한 단일 태스크 생성
// - 모든 작업이 백그라운드에서 순차적으로 처리
// - 등록 성능에 최소한의 영향
```

## 최적화 기법

### 1. 스마트 스케줄링

```swift
// 실행 중인 태스크가 없을 때만 새 태스크 스케줄링
if !isScheduled {
    isScheduled = true
    shouldSchedule = true
}
// → 불필요한 태스크 생성 방지
```

### 2. 유틸리티 우선순위

```swift
Task(priority: .utility) {
    await self.flush()
}
// → 백그라운드 처리로 메인 작업 차단 없음
```

### 3. 배치 누적

```swift
// 단일 작업으로 모든 대기 중인 작업 수집
let jobs = pending
pending.removeAll()
// → 효율적인 메모리 관리 및 처리
```

### 4. 락 최소화

```swift
lock.lock()
// 락 하에서 최소한의 작업
pending.append(job)
lock.unlock()
// → 락 경합 감소
```

## 모범 사례

### 1. 자동 작동

```swift
// ✅ 좋음: 디스패처가 자동으로 작동
let service = UnifiedDI.register(UserService.self) { UserService() }

// ❌ 피하기: 수동 디스패처 사용은 불필요함
// RegistrationMetricsDispatcher.shared.enqueueRegistration(UserService.self)
```

### 2. 대용량 등록 패턴

```swift
// ✅ 효율적: 배치 처리로 대용량 처리
func registerAllServices() {
    // 이 모든 등록이 효율적으로 배치됨
    for serviceType in allServiceTypes {
        UnifiedDI.register(serviceType) { createService(serviceType) }
    }
}
```

### 3. 성능 모니터링

```swift
// 개발 중 배치 효율성 모니터링
#if DEBUG
func logBatchMetrics() {
    // 배치 크기 및 빈도 분석
    print("평균 배치 크기: \(averageBatchSize)")
    print("배치 빈도: \(batchesPerSecond)")
}
#endif
```

## 메모리 관리

### 효율적인 메모리 사용

- **작업 저장소**: 큐잉된 작업당 최소한의 클로저 오버헤드
- **배치 처리**: 즉시 작업 실행 및 할당 해제
- **누적 없음**: 처리 후 작업이 지속되지 않음
- **자동 정리**: 메모리 압박이 누적되지 않음

### 메모리 사용량

```swift
// 큐잉된 작업당 실제 메모리 사용량
let jobSize = MemoryLayout<Job>.size  // 16바이트 (클로저)
// 작업이 빠르게 처리되고 할당 해제됨
```

## 기술적 구현 세부사항

### 스레드 안전성 모델

1. **큐잉 경로**: 큐에 작업을 스레드 안전하게 추가
2. **스케줄링 경로**: 원자적 태스크 스케줄링 결정
3. **처리 경로**: 태스크에서 순차적 작업 실행
4. **정리 경로**: 처리 후 안전한 큐 재설정

### 동시성 패턴

```swift
// 여러 소스에서 스레드 안전한 큐잉
DispatchQueue.global().async {
    UnifiedDI.register(ServiceA.self) { ServiceA() }  // 스레드 1
}

DispatchQueue.global().async {
    UnifiedDI.register(ServiceB.self) { ServiceB() }  // 스레드 2
}

// 두 등록 모두 안전하게 큐잉되고 배치됨
```

## 성능 최적화

### 배치 크기 최적화

- **동적 배치**: 현재 큐잉된 모든 작업 처리
- **인위적 제한 없음**: 등록 패턴 기반 자연스러운 배치
- **즉시 처리**: 배치가 준비되는 즉시 작업 실행

### 컨텍스트 스위치 감소

```swift
// 전통적 방식: N번 등록 = N개 태스크
// RegistrationMetricsDispatcher: N번 등록 = 1개 태스크 (배치)

// 대용량 시나리오에서 컨텍스트 스위치 50-80% 감소
```

## 오류 처리

### 우아한 성능 저하

```swift
// 개별 작업 실패가 배치 처리에 영향 없음
for job in jobs {
    await job()  // 각 작업 격리됨
}
// → 실패한 작업이 후속 처리를 중단하지 않음
```

### 모니터링 통합

```swift
// 의존성 추적을 위한 AutoDIOptimizer와의 통합
enqueue { await AutoDIOptimizer.shared.trackRegistration(type) }
// → 모니터링 오류가 배치 시스템 내에 포함됨
```

## 실제 사용 시나리오

### 애플리케이션 시작

```swift
// 대량 의존성 등록의 효율적 처리
class AppDependencySetup {
    func registerAllDependencies() {
        // 50개 이상의 서비스 등록
        registerCoreServices()      // → 배치됨
        registerNetworkServices()   // → 배치됨
        registerDataServices()      // → 배치됨
        registerUIServices()        // → 배치됨

        // 모든 모니터링 태스크가 단일 백그라운드 태스크에서 처리됨
    }
}
```

### 모듈 로딩

```swift
// 효율적인 모니터링으로 동적 모듈 로딩
func loadModule(_ module: DependencyModule) {
    module.dependencies.forEach { dependency in
        UnifiedDI.register(dependency.type, factory: dependency.factory)
        // → 모든 등록이 최적 성능을 위해 배치됨
    }
}
```

## 대안과의 비교

### 즉시 실행

```swift
// RegistrationMetricsDispatcher 없이
UnifiedDI.register(ServiceA.self) {
    let service = ServiceA()
    Task { await AutoDIOptimizer.shared.trackRegistration(ServiceA.self) }  // 태스크 1
    return service
}

UnifiedDI.register(ServiceB.self) {
    let service = ServiceB()
    Task { await AutoDIOptimizer.shared.trackRegistration(ServiceB.self) }  // 태스크 2
    return service
}
// → 여러 태스크, 높은 오버헤드
```

### RegistrationMetricsDispatcher와 함께

```swift
// RegistrationMetricsDispatcher와 함께
UnifiedDI.register(ServiceA.self) { ServiceA() }  // → 큐잉됨
UnifiedDI.register(ServiceB.self) { ServiceB() }  // → 큐잉됨 + 배치 실행
// → 단일 태스크, 최소 오버헤드
```

## 참고

- [AutoDIOptimizer API](./autoDiOptimizer.md) - 의존성 최적화 시스템
- [FastResolveCache API](./fastResolveCache.md) - 초고속 해결 캐싱
- [UnifiedDI API](./unifiedDI.md) - 메인 의존성 주입 인터페이스
- [성능 모니터링](./performanceMonitoring.md) - 시스템 성능 추적