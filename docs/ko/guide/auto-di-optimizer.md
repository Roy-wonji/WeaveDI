# 자동 DI 최적화

WeaveDI의 자동 최적화 시스템으로 성능을 극대화하세요.

## 개요

WeaveDI는 런타임에서 의존성 주입 패턴을 분석하고 자동으로 최적화를 제안하는 지능형 시스템을 제공합니다. 이 기능은 개발자가 수동으로 성능 튜닝을 하지 않아도 최적의 성능을 얻을 수 있도록 도와줍니다.

## 자동 최적화 기능

### 1. Actor Hop 최적화

앱 실행 중 Actor 간 전환을 분석하여 불필요한 hop을 제거합니다.

```swift
// 자동으로 최적화됨
@MainActor
class ViewController {
    @Inject var userService: UserService?
    
    func loadData() async {
        // WeaveDI가 자동으로 Actor hop을 최적화
        let data = await userService?.fetchData()
        updateUI(data) // MainActor에서 직접 실행
    }
}
```

### 2. 타입 안전성 분석

컴파일 타임과 런타임에서 타입 안전성 이슈를 자동으로 감지합니다.

```swift
// 런타임에서 자동 분석
class ServiceA {
    @Inject var serviceB: ServiceB? // nil 가능성 분석
    
    func doWork() {
        // WeaveDI가 serviceB가 nil인 경우를 추적
        serviceB?.process()
    }
}
```

### 3. 의존성 그래프 최적화

복잡한 의존성 그래프에서 비효율적인 패턴을 감지하고 개선안을 제시합니다.

```swift
// 순환 의존성 자동 감지
UnifiedDI.register(ServiceA.self) {
    ServiceA(serviceB: UnifiedDI.resolve(ServiceB.self)!)
}

UnifiedDI.register(ServiceB.self) {
    ServiceB(serviceA: UnifiedDI.resolve(ServiceA.self)!) // 순환 의존성 경고
}
```

## 활성화 방법

### 1. 기본 자동 최적화

```swift
// 앱 시작 시
@main
struct MyApp: App {
    init() {
        // 자동 최적화 활성화 (기본: 활성화됨)
        UnifiedDI.setAutoOptimization(true)
        
        // 로그 레벨 설정 (기본: .all)
        UnifiedDI.setLogLevel(.all)
    }
}
```

### 2. 고급 최적화 설정

```swift
// 세부 설정 가능
UnifiedDI.configureAutoOptimization {
    $0.enableActorHopOptimization = true
    $0.enableTypeSafetyAnalysis = true
    $0.enableDependencyGraphOptimization = true
    $0.enablePerformanceMonitoring = true
    $0.suggestionThreshold = 0.1 // 10% 이상 개선 시 제안
}
```

## 최적화 정보 확인

### 1. 사용 통계

```swift
// 전체 사용 통계
let stats = UnifiedDI.stats
print("총 등록 수: \(stats.totalRegistrations)")
print("총 해결 수: \(stats.totalResolutions)")
print("평균 해결 시간: \(stats.averageResolutionTime)ms")
print("메모리 사용량: \(stats.memoryUsage)MB")
```

### 2. Actor Hop 분석

```swift
// Actor hop 통계
let actorStats = UnifiedDI.actorHopStats
for (actorType, stats) in actorStats {
    print("Actor \(actorType):")
    print("  - 총 hop 수: \(stats.totalHops)")
    print("  - 평균 hop 시간: \(stats.averageHopTime)ms")
    print("  - 최적화 가능한 hop: \(stats.optimizableHops)")
}
```

### 3. 자동 최적화 제안

```swift
// 최적화 제안 확인
let optimizations = UnifiedDI.actorOptimizations
for (type, optimization) in optimizations {
    print("🚀 최적화 제안 - \(type):")
    print("   현재: \(optimization.current.description)")
    print("   제안: \(optimization.suggestion)")
    print("   예상 개선: \(optimization.expectedImprovement)%")
}
```

### 4. 타입 안전성 이슈

```swift
// 타입 안전성 분석 결과
let safetyIssues = UnifiedDI.typeSafetyIssues
for (type, issue) in safetyIssues {
    print("⚠️ 타입 안전성 이슈 - \(type):")
    print("   문제: \(issue.description)")
    print("   제안: \(issue.suggestion)")
    print("   심각도: \(issue.severity)")
}
```

## 자동 최적화 적용

### 1. 제안된 최적화 적용

```swift
// 모든 제안 자동 적용
UnifiedDI.applyAllOptimizations()

// 특정 타입에 대한 최적화만 적용
UnifiedDI.applyOptimization(for: UserService.self)

// 특정 임계값 이상의 최적화만 적용
UnifiedDI.applyOptimizations(threshold: 0.2) // 20% 이상 개선만
```

### 2. 수동 최적화 설정

```swift
// 특정 Actor에서 최적화 적용
@MainActor
class OptimizedViewController {
    @Inject var userService: UserService?
    
    init() {
        // 이 타입에 대해 Actor hop 최적화 강제 적용
        UnifiedDI.optimizeActorHop(for: UserService.self, on: MainActor.shared)
    }
}
```

## 성능 모니터링

### 1. 실시간 모니터링

```swift
// 성능 모니터링 활성화
UnifiedDI.startPerformanceMonitoring()

// 모니터링 콜백 설정
UnifiedDI.setPerformanceCallback { metrics in
    print("실시간 성능 지표:")
    print("  - 해결 속도: \(metrics.resolutionSpeed)req/s")
    print("  - 메모리 사용량: \(metrics.memoryUsage)MB")
    print("  - Actor hop 지연: \(metrics.actorHopLatency)ms")
}
```

### 2. 성능 리포트

```swift
// 주기적 성능 리포트
UnifiedDI.generatePerformanceReport { report in
    print("=== 성능 리포트 ===")
    print("기간: \(report.period)")
    print("총 해결 수: \(report.totalResolutions)")
    print("평균 해결 시간: \(report.averageResolutionTime)ms")
    print("메모리 효율성: \(report.memoryEfficiency)%")
    print("Actor 최적화 효과: \(report.actorOptimizationEffect)%")
}
```

## 커스텀 최적화 규칙

### 1. 사용자 정의 최적화

```swift
// 커스텀 최적화 규칙 추가
UnifiedDI.addOptimizationRule { context in
    // 특정 조건에서 최적화 적용
    if context.type.isSubclass(of: UIViewController.self) {
        return ActorOptimization.mainActor
    }
    
    if context.type.conformsTo(NetworkService.protocol) {
        return ActorOptimization.backgroundQueue
    }
    
    return nil
}
```

### 2. 최적화 조건 설정

```swift
// 최적화 적용 조건
UnifiedDI.setOptimizationCondition { context in
    // 디버그 모드에서만 최적화 제안
    #if DEBUG
    return true
    #else
    // 릴리스 모드에서는 확실한 최적화만
    return context.expectedImprovement > 0.3
    #endif
}
```

## 최적화 사례

### 1. MainActor UI 최적화

```swift
// Before: Actor hop 발생
@MainActor
class BeforeViewController {
    func loadData() async {
        let service = UnifiedDI.resolve(UserService.self) // Background thread
        let data = await service?.fetchData() // Actor hop 발생
        await MainActor.run {
            updateUI(data) // 다시 MainActor로 전환
        }
    }
}

// After: 자동 최적화 적용
@MainActor  
class AfterViewController {
    @Inject var userService: UserService? // 자동으로 MainActor에 최적화
    
    func loadData() async {
        let data = await userService?.fetchData() // Actor hop 없음
        updateUI(data) // 이미 MainActor에서 실행
    }
}
```

### 2. 메모리 최적화

```swift
// 메모리 사용량 자동 최적화
class MemoryOptimizedService {
    @Inject var cacheService: CacheService? // 자동 약한 참조 적용
    @Factory var processor: DataProcessor   // 필요시에만 생성
    
    func processData(_ data: Data) {
        // WeaveDI가 메모리 사용 패턴을 분석하고 최적화
        let result = processor.process(data)
        cacheService?.store(result)
    }
}
```

### 3. 의존성 체인 최적화

```swift
// 복잡한 의존성 체인 자동 최적화
UnifiedDI.register(ServiceA.self) {
    ServiceA(
        serviceB: UnifiedDI.resolve(ServiceB.self)!,
        serviceC: UnifiedDI.resolve(ServiceC.self)!
    )
}

// WeaveDI가 자동으로 최적화된 팩토리 체인 생성:
// ServiceA -> ServiceB, ServiceC (병렬 해결)
```

## 디버깅 및 문제 해결

### 1. 최적화 디버그 로그

```swift
// 상세 디버그 로그 활성화
UnifiedDI.setLogLevel(.verbose)

// 특정 타입에 대한 최적화 로그만
UnifiedDI.enableDebugLog(for: UserService.self)
```

### 2. 최적화 성능 측정

```swift
// 최적화 전후 성능 비교
let beforeMetrics = UnifiedDI.measurePerformance {
    // 최적화 전 코드
    let service = UnifiedDI.resolve(UserService.self)
}

UnifiedDI.applyOptimization(for: UserService.self)

let afterMetrics = UnifiedDI.measurePerformance {
    // 최적화 후 코드  
    let service = UnifiedDI.resolve(UserService.self)
}

let improvement = (beforeMetrics.time - afterMetrics.time) / beforeMetrics.time
print("성능 개선: \(improvement * 100)%")
```

## 모범 사례

### 1. 점진적 최적화 적용

```swift
// 단계별 최적화 적용
class GradualOptimization {
    static func applyPhase1() {
        // 1단계: Actor 최적화만
        UnifiedDI.applyActorOptimizations()
    }
    
    static func applyPhase2() {
        // 2단계: 메모리 최적화 추가
        UnifiedDI.applyMemoryOptimizations()
    }
    
    static func applyPhase3() {
        // 3단계: 전체 최적화 적용
        UnifiedDI.applyAllOptimizations()
    }
}
```

### 2. 모니터링 기반 최적화

```swift
// 실제 사용 패턴에 따른 동적 최적화
UnifiedDI.enableAdaptiveOptimization { statistics in
    if statistics.actorHopLatency > 10.0 { // 10ms 이상
        return .aggressiveActorOptimization
    }
    
    if statistics.memoryUsage > 100.0 { // 100MB 이상
        return .memoryOptimization
    }
    
    return .balanced
}
```

## 관련 문서

- [런타임 최적화](/ko/guide/runtime-optimization) - 수동 성능 최적화
- [벤치마크](/ko/guide/benchmarks) - 성능 측정 결과
- [코어 API](/ko/api/core-apis) - API 성능 특성

자동 최적화로 WeaveDI의 성능을 극대화하고 개발 생산성을 향상시켜보세요! 🚀