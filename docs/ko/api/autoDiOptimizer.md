# 자동 DI 최적화

WeaveDI의 자동 의존성 그래프 생성 및 성능 최적화 시스템입니다.

## 개요

WeaveDI는 의존성 관계를 자동으로 추적하고 추가 설정 없이 성능을 최적화하는 지능형 시스템을 제공합니다. 백그라운드에서 자동으로 실행되어 사용 패턴을 모니터링하고 실시간 최적화 제안을 제공합니다.

## 자동 기능들

### 🔄 자동 의존성 그래프 생성

의존성이 등록되거나 해결될 때마다 의존성 그래프가 자동으로 업데이트됩니다.

```swift
// 단순히 등록하면 자동으로 그래프에 추가됩니다
let service = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}

// LogMacro를 통해 자동 생성된 그래프가 자동으로 로깅됩니다
// 별도 호출 불필요 - 자동 로깅: 📊 Auto tracking registration: UserService
```

### 🎯 자동 Actor Hop 감지 및 최적화

의존성 해결 중 Actor hop 패턴을 자동으로 감지하고 Swift Concurrency 최적화 제안을 제공합니다.

```swift
// 단순히 해결하면 Actor hop이 자동으로 감지됩니다
let service = await UnifiedDI.resolveAsync(UserService.self)

// 자동 로그 (5회 이상 hop 발생 시):
// 🎯 Actor optimization suggestion for UserService: MainActor로 이동 권장 (hops: 12, avg: 85.3ms)
```

### 🔒 자동 타입 안전성 검증

런타임에서 타입 안전성 문제를 자동으로 감지하고 안전하게 처리합니다. Swift 6 Sendable 준수성을 특히 중점적으로 체크합니다.

```swift
// 해결 중 타입 안전성이 자동으로 검증됩니다
let service = UnifiedDI.resolve(UserService.self)

// 자동 로그 (문제 감지 시):
// 🔒 Type safety issue: UserService는 Sendable이 아닙니다
// 🚨 Auto safety check: UserService가 nil로 해결됨 - 의존성이 등록되지 않음
```

### ⚡ 자동 성능 최적화

사용 패턴을 분석하여 자주 사용되는 타입을 TypeID 캐싱을 통해 자동으로 최적화합니다.

```swift
// 여러 번 사용하면 자동으로 최적화됩니다
for _ in 1...15 {
    let service = UnifiedDI.resolve(UserService.self)
}

// 최적화된 타입이 자동으로 로깅됩니다
// 자동 로그: ⚡ Auto optimized: UserService (10 uses, 75% 더 빠른 해결)
```

### 📊 자동 사용 통계 수집

각 타입의 사용 빈도와 성능 지표가 자동으로 추적됩니다.

```swift
// 30초마다 사용 통계가 자동으로 로깅됩니다
// 자동 로그: 📊 [AutoDI] Current stats: ["UserService": 15, "DataRepository": 8]
// 성능 통계: 평균 해결 시간: 0.2ms (최적화됨), 0.8ms (최적화 안됨)
```

### ⚠️ 자동 순환 의존성 감지

의존성 등록 중 순환 의존성을 자동으로 감지하고 경고합니다.

```swift
// 순환 의존성이 존재하면 자동으로 감지되고 오류 로깅됩니다
// 자동 로그: ⚠️ Auto detected circular dependencies: {ServiceA -> ServiceB -> ServiceA}
```

## API 레퍼런스

### 자동 수집된 정보 접근

```swift
// 🔄 자동 생성된 의존성 그래프
let graph = UnifiedDI.autoGraph
print("의존성들: \(graph.dependencies)")
print("그래프 구조: \(graph.visualization)")

// ⚡ 자동 최적화된 타입들
let optimizedTypes = UnifiedDI.optimizedTypes
print("최적화됨: \(optimizedTypes)")

// 📊 자동 수집된 사용 통계
let stats = UnifiedDI.stats
print("사용 횟수: \(stats)")

// ⚠️ 자동 감지된 순환 의존성
let circularDeps = UnifiedDI.circularDependencies
if !circularDeps.isEmpty {
    print("순환 의존성 감지됨: \(circularDeps)")
}

// 🎯 Actor 최적화 제안
let actorOptimizations = UnifiedDI.actorOptimizations
for suggestion in actorOptimizations {
    print("Actor 최적화: \(suggestion)")
}

// 🔒 타입 안전성 문제 목록
let typeSafetyIssues = UnifiedDI.typeSafetyIssues
for issue in typeSafetyIssues {
    print("타입 안전성 문제: \(issue)")
}

// 🛠️ 자동 수정된 타입들
let autoFixedTypes = UnifiedDI.autoFixedTypes
print("자동 수정됨: \(autoFixedTypes)")

// ⚡ Actor hop 통계
let actorHopStats = UnifiedDI.actorHopStats
print("Actor hops: \(actorHopStats)")

// 📊 비동기 성능 통계 (밀리초)
let asyncPerformanceStats = UnifiedDI.asyncPerformanceStats
print("비동기 성능: \(asyncPerformanceStats)")
```

### 최적화 제어

```swift
// 자동 최적화 비활성화 (기본값: 활성화)
UnifiedDI.setAutoOptimization(false)

// 특정 타입의 최적화 상태 확인
let isOptimized = UnifiedDI.isOptimized(UserService.self)
print("UserService 최적화됨: \(isOptimized)")

// 모든 통계를 초기화하고 새로 시작
UnifiedDI.resetStats()

// 특정 타입에 대해 강제 최적화
UnifiedDI.forceOptimize(UserService.self)
```

### 로깅 레벨 제어

**기본값**: 모든 로그가 활성화됨 (`.all`)

#### 사용 시나리오별 설정:

```swift
// ✅ 기본 상태: 모든 로그 출력 (개발 시 권장)
UnifiedDI.setLogLevel(.all)
// 📊 Auto tracking registration: UserService
// ⚡ Auto optimized: UserService (10 uses)
// 📊 [AutoDI] Current stats: {...}

// 📝 등록 추적만 보고 싶을 때
UnifiedDI.setLogLevel(.registration)
// 📊 Auto tracking registration: UserService (등록 로그만)

// ⚡ 성능 최적화 정보만 보고 싶을 때
UnifiedDI.setLogLevel(.optimization)
// ⚡ Auto optimized: UserService (10 uses) (최적화 로그만)

// ⚠️ 오류와 경고만 보고 싶을 때
UnifiedDI.setLogLevel(.errors)
// ⚠️ Auto detected circular dependencies: {...} (오류만)

// 🔇 모든 자동 로깅을 끄고 싶을 때 (프로덕션)
UnifiedDI.setLogLevel(.off)
// (로그 없음)

// 🔄 기본값으로 재설정
UnifiedDI.setLogLevel(.all)

// 📋 현재 설정 확인
print("현재 로깅 레벨: \(UnifiedDI.logLevel)")
```

## 고급 사용법

### 커스텀 최적화 임계값

```swift
// 자동 최적화를 위한 커스텀 임계값 설정
UnifiedDI.setOptimizationThreshold(usageCount: 5, timeThreshold: 100) // 100ms

// 캐싱을 위한 메모리 제한 설정
UnifiedDI.setMemoryLimits(maxCachedTypes: 50, maxGraphNodes: 200)
```

### 성능 모니터링

```swift
// 상세한 성능 추적 활성화
UnifiedDI.enableDetailedProfiling(true)

// 상세한 성능 분석 보고서 가져오기
let performanceReport = UnifiedDI.getPerformanceReport()
print("해결 시간: \(performanceReport.resolutionTimes)")
print("Actor hop 오버헤드: \(performanceReport.actorHopOverhead)")
print("메모리 사용량: \(performanceReport.memoryUsage)")
```

### Instruments 통합

```swift
// Instruments 프로파일링을 위한 signpost 활성화
UnifiedDI.enableInstrumentsSignposts(true)

// 커스텀 signpost 카테고리
UnifiedDI.configureSignposts(
    categories: [.registration, .resolution, .optimization]
)
```

## 주요 특징

- **설정 불필요**: 아무런 설정 없이 자동으로 작동
- **백그라운드 실행**: 앱 성능에 영향을 주지 않고 비동기적으로 실행
- **실시간 업데이트**: 30초마다 지속적으로 모니터링하고 최적화
- **메모리 효율적**: 자주 사용되는 타입만 최적화 캐시에 유지
- **Swift 6 호환**: Sendable 및 엄격한 동시성 완전 지원

## 성능 영향

자동화 시스템은 최소한의 성능 영향을 갖도록 설계되었습니다:

- **등록 오버헤드**: 의존성당 < 0.1ms
- **해결 오버헤드**: 최적화된 타입에 대해 < 0.05ms
- **백그라운드 처리**: 낮은 우선순위로 비동기 실행
- **메모리 사용량**: 일반적인 애플리케이션에서 < 1MB

## 베스트 프랙티스

### 개발 환경

```swift
// 개발용 전체 로깅 활성화
#if DEBUG
UnifiedDI.setLogLevel(.all)
UnifiedDI.enableDetailedProfiling(true)
#endif
```

### 프로덕션 환경

```swift
// 프로덕션용 최소 로깅
#if !DEBUG
UnifiedDI.setLogLevel(.errors)
UnifiedDI.setAutoOptimization(true) // 최적화는 계속 활성화
#endif
```

### 테스트 환경

```swift
// 각 테스트마다 깨끗한 상태
override func setUp() async throws {
    await super.setUp()
    await UnifiedDI.releaseAll()
    UnifiedDI.resetStats()
}
```

## 문제 해결

### 높은 Actor Hop 수

자주 actor hop 경고가 나타날 때:

```swift
// Actor 최적화 제안 확인
let suggestions = UnifiedDI.actorOptimizations
for suggestion in suggestions {
    print("고려사항: \(suggestion.description)")
    // 예: "UI 작업을 위해 UserService를 @MainActor로 이동하세요"
}
```

### 메모리 사용량 우려

```swift
// 메모리 사용량 모니터링
let memoryStats = UnifiedDI.getMemoryStats()
if memoryStats.cacheSize > 10_000_000 { // 10MB
    UnifiedDI.clearOptimizationCache()
}
```

### 성능 저하

```swift
// 시간 경과에 따른 성능 비교
let baseline = UnifiedDI.getPerformanceBaseline()
let current = UnifiedDI.getCurrentPerformance()

if current.averageResolutionTime > baseline.averageResolutionTime * 1.5 {
    print("성능 저하 감지됨")
    UnifiedDI.resetOptimizations()
}
```

## 마이그레이션 가이드

### 수동 최적화에서 이전

이전에 수동 최적화를 사용하고 있었다면:

```swift
// 이전 (수동)
WeaveDI.Container.enableOptimization(for: UserService.self)
WeaveDI.Container.setCacheSize(100)

// 이후 (자동)
// 아무것도 필요 없음 - 자동 최적화가 이를 처리합니다
```

### 지원 중단된 API

다음 API들이 교체되었습니다:

| 지원 중단 (AutoDIOptimizer) | 교체 |
|---|---|
| `getCurrentStats()` | `UnifiedDI.stats` |
| `visualizeGraph()` | `UnifiedDI.autoGraph` |
| `getFrequentlyUsedTypes()` | `UnifiedDI.optimizedTypes` |
| `isOptimized(_:)` | `UnifiedDI.isOptimized(_:)` |

자동 시스템이 더 나은 성능을 제공하며 수동 개입이 필요 없습니다.

---

📖 **문서**: [한국어](appDiIntegration) | [English](../api/appDiIntegration)