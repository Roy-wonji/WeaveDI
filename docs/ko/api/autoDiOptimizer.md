---
title: AutoDIOptimizer
lang: ko-KR
---

# AutoDIOptimizer

자동 의존성 주입 최적화 시스템
핵심 추적 및 최적화 기능에 집중한 간소화된 시스템

## ⚠️ Thread Safety 참고사항
- 주로 앱 초기화 시 단일 스레드에서 사용됩니다
- 통계 데이터의 미세한 불일치는 기능에 영향을 주지 않습니다
- 높은 성능을 위해 복잡한 동기화를 제거했습니다

## 기본 사용법

```swift
import WeaveDI

// AutoDIOptimizer가 자동으로 등록 및 해결을 추적합니다
await WeaveDI.Container.bootstrap { container in
    container.register(UserService.self) {
        UserServiceImpl()
    }
}

// 통계 접근
let stats = await AutoDIOptimizer.shared.currentStats()
print("등록된 타입: \(stats.registeredTypes.count)")
print("해결된 타입: \(stats.resolvedTypes.count)")
```

## 핵심 API

```swift
@DIActor
public final class AutoDIOptimizer {
    public static let shared = AutoDIOptimizer()

    /// 타입 등록 추적
    public func trackRegistration<T>(_ type: T.Type)

    /// 최적화 힌트와 함께 타입 해결 추적
    public func trackResolution<T>(_ type: T.Type)

    /// 의존성 관계 추적
    public func trackDependency<From, To>(from: From.Type, to: To.Type)

    /// 현재 통계 가져오기
    public func currentStats() -> DIStatsSnapshot

    /// 최적화 제안 가져오기
    public func optimizationSuggestions() -> [String]

    /// 자주 사용되는 타입 (상위 N개)
    public func frequentlyUsedTypes(top: Int = 10) -> [(String, Int)]

    /// 순환 의존성 감지
    public func circularDependencies() -> Set<String>

    /// 최적화 활성화/비활성화
    public func setOptimizationEnabled(_ enabled: Bool)

    /// 로그 레벨 설정
    public func setLogLevel(_ level: LogLevel)

    /// 통계 초기화
    public func reset()
}
```

## 통계 스냅샷

```swift
public struct DIStatsSnapshot: Sendable {
    public let frequentlyUsed: [String: Int]
    public let registered: Set<String>
    public let resolved: Set<String>
    public let dependencies: [(from: String, to: String)]
    public let logLevel: LogLevel
    public let graphText: String
}
```

## 로깅 레벨

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

## 최적화 기능

### 자동 Hot Path 감지

AutoDIOptimizer는 자주 사용되는 타입(10회 이상 해결)을 자동으로 감지하고 싱글톤 최적화를 제안합니다:

```swift
// 타입이 10회 이상 해결되면 다음과 같이 표시됩니다:
// ⚡ 최적화 권장: UserService이 자주 사용됩니다 (싱글톤 고려)

// 싱글톤으로 등록하는 것을 고려하세요:
await WeaveDI.Container.bootstrap { container in
    container.register(UserService.self, scope: .singleton) {
        UserServiceImpl()
    }
}
```

### 순환 의존성 감지

```swift
// 순환 의존성 감지
let circular = await AutoDIOptimizer.shared.circularDependencies()
if !circular.isEmpty {
    print("⚠️ 순환 의존성이 감지되었습니다:")
    for cycle in circular {
        print("  - \(cycle)")
    }
}
```

### 사용 통계

```swift
// 자주 사용되는 타입 가져오기
let topTypes = await AutoDIOptimizer.shared.frequentlyUsedTypes(top: 5)
print("가장 많이 사용된 상위 5개 타입:")
for (typeName, count) in topTypes {
    print("  \(typeName): \(count)회")
}
```

## 고급 설정

### 디바운스 간격

통계 스냅샷이 얼마나 자주 생성되는지 제어합니다 (50-1000ms):

```swift
// 스냅샷 디바운스를 200ms로 설정
await AutoDIOptimizer.shared.setDebounceInterval(ms: 200)
```

### 커스텀 로그 레벨

```swift
// 에러만 로깅
await AutoDIOptimizer.shared.setLogLevel(.errors)

// 최적화만 로깅
await AutoDIOptimizer.shared.setLogLevel(.optimization)

// 모든 로깅 비활성화
await AutoDIOptimizer.shared.setLogLevel(.off)
```

## Actor 최적화

```swift
public struct ActorOptimization: Sendable {
    public let suggestion: String

    public init(suggestion: String) {
        self.suggestion = suggestion
    }
}
```

Actor 최적화 제안은 actor 격리로부터 이점을 얻을 수 있는 타입을 식별하는 데 도움을 줍니다:

```swift
// Actor 최적화 제안 가져오기
let suggestions = await AutoDIOptimizer.shared.actorOptimizationSuggestions()
for suggestion in suggestions {
    print("💡 \(suggestion.suggestion)")
}
```

## AutoMonitor와의 통합

AutoDIOptimizer는 모듈 생명주기 추적을 위해 `AutoMonitor`와 자동으로 통합됩니다:

```swift
// AutoDIOptimizer는 등록 시 AutoMonitor에 자동으로 알립니다
await WeaveDI.Container.bootstrap { container in
    container.register(MyService.self) {
        MyServiceImpl()  // AutoMonitor.shared.onModuleRegistered() 자동 호출
    }
}
```

## 모범 사례

1. **개발 중 최적화 활성화 유지**: 성능 병목 지점을 조기에 식별하는 데 도움이 됩니다
2. **자주 사용되는 타입 모니터링**: 10회 이상 해결되는 타입에 대해 싱글톤 스코프를 고려하세요
3. **순환 의존성 확인**: 개발 및 테스트 중에 확인을 실행하세요
4. **프로덕션용 로그 레벨 조정**: 프로덕션 빌드에서는 `.errors` 또는 `.off`를 사용하세요
5. **주기적으로 통계 검토**: `currentStats()`를 사용하여 DI 그래프를 이해하세요

## 참고 자료

- [AutoMonitor](./performanceMonitoring.md) - 모듈 생명주기 모니터링
- [DIActor](./diActor.md) - Actor 기반 스레드 안전 DI
- [Performance Monitoring](./performanceMonitoring.md) - 성능 추적 도구
