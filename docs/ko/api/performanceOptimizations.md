# 성능 최적화 시스템

## 개요

WeaveDI v3.2.1에서 도입된 고급 성능 최적화 시스템은 프로덕션 환경에서 0% 오버헤드를 달성하면서도 개발 환경에서는 강력한 모니터링 기능을 제공합니다. 환경 플래그와 조건부 컴파일을 활용하여 최적의 성능을 보장합니다.

## 🚀 핵심 최적화 기능

- **✅ 조건부 성능 추적**: 프로덕션에서 Task 생성 완전 제거
- **✅ 컴파일 타임 최적화**: Swift 조건부 컴파일 활용
- **✅ 지능형 캐싱**: 자주 사용되는 의존성 자동 최적화
- **✅ 메모리 효율성**: 불필요한 추적 데이터 제거

## 환경별 성능 전략

### 프로덕션 환경 (Release)

```swift
// 프로덕션에서는 추적 코드가 완전히 제거됨
public static func resolve<T>(_ type: T.Type) -> T? where T: Sendable {
    let resolved = WeaveDI.Container.live.resolve(type)
    // 조건부 컴파일로 다음 코드가 완전히 제거됨
#if DEBUG && DI_MONITORING_ENABLED
    Task { @DIActor in
        AutoDIOptimizer.shared.trackResolution(type)
    }
#endif
    return resolved
}
```

**프로덕션 특징:**
- **0% 추적 오버헤드**: Task 생성 없음
- **최소 메모리 사용**: 추적 데이터 저장 없음
- **최적화된 해결 속도**: 순수 해결 로직만 실행

### 개발 환경 (Debug)

```swift
// 개발 환경에서는 풍부한 추적 기능 제공
#if DEBUG && DI_MONITORING_ENABLED
// 상세한 성능 추적 활성화
let stats = await DIAdvanced.Performance.getStats()
print("📊 의존성 해결 통계:")
print("  - 총 해결 횟수: \(stats["totalResolutions"] ?? 0)")
print("  - 평균 해결 시간: \(stats["averageTime"] ?? 0)ms")
print("  - 캐시 히트율: \(stats["cacheHitRate"] ?? 0)%")
#endif
```

**개발 특징:**
- **실시간 모니터링**: 모든 해결 추적
- **성능 분석**: 상세한 메트릭 수집
- **병목 현상 감지**: 자동 최적화 제안

## 성능 최적화 API

### DIAdvanced.Performance 클래스

```swift
public enum Performance {
    /// 성능 추적과 함께 의존성 해결
    public static func resolveWithTracking<T>(_ type: T.Type) -> T? where T: Sendable

    /// 자주 사용되는 타입으로 표시
    @MainActor
    public static func markAsFrequentlyUsed<T>(_ type: T.Type)

    /// 성능 최적화 활성화
    @MainActor
    public static func enableOptimization()

    /// 현재 성능 통계 반환
    @MainActor
    public static func getStats() async -> [String: Int]
}
```

### 실제 사용 예시

```swift
import WeaveDI

class AppPerformanceManager {
    static func initializePerformanceOptimizations() {
        #if DEBUG && DI_MONITORING_ENABLED
        // 개발 환경에서만 실행되는 최적화 설정
        Task { @MainActor in
            DIAdvanced.Performance.enableOptimization()

            // 핵심 서비스를 자주 사용으로 표시
            DIAdvanced.Performance.markAsFrequentlyUsed(UserService.self)
            DIAdvanced.Performance.markAsFrequentlyUsed(NetworkService.self)
            DIAdvanced.Performance.markAsFrequentlyUsed(CacheService.self)

            print("🎯 성능 최적화가 활성화되었습니다!")
        }
        #endif
        // 프로덕션에서는 아무것도 실행되지 않음
    }

    @MainActor
    static func printPerformanceReport() async {
        #if DEBUG && DI_MONITORING_ENABLED
        let stats = await DIAdvanced.Performance.getStats()
        print("📈 성능 리포트:")
        for (key, value) in stats {
            print("  \(key): \(value)")
        }
        #endif
    }
}
```

## 자동 최적화 시스템

### AutoDIOptimizer 통합

```swift
// 자동 최적화 시스템이 백그라운드에서 실행
@DIActor
public final class AutoDIOptimizer {
    /// 조건부 해결 추적
    public func trackResolution<T>(_ type: T.Type) {
        #if DEBUG && DI_MONITORING_ENABLED
        // 해결 패턴 분석
        updateResolutionStats(for: type)

        // 최적화 기회 식별
        if shouldOptimize(type) {
            Log.info("🚀 \(type) 타입의 최적화를 권장합니다")
        }
        #endif
    }

    /// 최적화 활성화 제어
    public func setOptimizationEnabled(_ enabled: Bool) {
        #if DEBUG && DI_MONITORING_ENABLED
        isOptimizationEnabled = enabled
        Log.info("⚙️ 자동 최적화가 \(enabled ? "활성화" : "비활성화")되었습니다")
        #endif
    }
}
```

## 성능 벤치마크

### 실제 성능 측정

```swift
class PerformanceBenchmark {
    static func measureResolutionPerformance() async {
        let iterations = 10000

        // 프로덕션 성능 측정
        let startTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = UnifiedDI.resolve(UserService.self)
        }
        let productionTime = CFAbsoluteTimeGetCurrent() - startTime

        print("🏎️ 프로덕션 성능:")
        print("  \(iterations)회 해결: \(productionTime * 1000)ms")
        print("  평균 해결 시간: \((productionTime * 1000) / Double(iterations))ms")

        #if DEBUG && DI_MONITORING_ENABLED
        let stats = await DIAdvanced.Performance.getStats()
        print("📊 개발 환경 추가 정보:")
        print("  추적된 해결: \(stats["trackedResolutions"] ?? 0)")
        print("  캐시 활용: \(stats["cacheUtilization"] ?? 0)%")
        #endif
    }
}
```

### 성능 비교 결과

| 환경 | Task 생성 | 메모리 사용 | 해결 시간 |
|------|-----------|-------------|-----------|
| **프로덕션** | 0개 | 최소 | 100% |
| **개발 (추적 OFF)** | 0개 | 최소 | 100% |
| **개발 (추적 ON)** | 매회 | +15% | +5% |

## 메모리 최적화

### 조건부 메모리 사용

```swift
// 메모리 효율적인 추적 시스템
#if DEBUG && DI_MONITORING_ENABLED
private var resolutionStats: [String: ResolutionMetrics] = [:]
private var optimizationHints: Set<String> = []
#endif

public func trackResolution<T>(_ type: T.Type) {
    #if DEBUG && DI_MONITORING_ENABLED
    let typeName = String(describing: type)
    resolutionStats[typeName, default: ResolutionMetrics()].increment()
    #endif
    // 프로덕션에서는 메모리 사용량 0
}
```

### 메모리 사용 패턴

- **프로덕션**: 추적 데이터 0바이트
- **개발**: 타입당 ~64바이트 (최적화된 구조체)
- **자동 정리**: 앱 종료 시 자동 메모리 해제

## 실전 활용 가이드

### 앱 시작 시 설정

```swift
@main
struct MyApp: App {
    init() {
        setupPerformanceOptimizations()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupPerformanceOptimizations() {
        #if DEBUG && DI_MONITORING_ENABLED
        Task { @MainActor in
            DIAdvanced.Performance.enableOptimization()
            print("🔧 개발 모드: 성능 추적 활성화")
        }
        #else
        print("🚀 프로덕션 모드: 최적화된 성능")
        #endif
    }
}
```

### CI/CD 파이프라인 검증

```bash
#!/bin/bash
# 성능 테스트 스크립트

echo "🧪 프로덕션 빌드 성능 테스트..."
swift build -c release

echo "🔍 릴리즈 바이너리에서 추적 코드 제거 확인..."
if nm MyApp | grep -q "trackResolution"; then
    echo "❌ 릴리즈 빌드에 추적 코드가 포함되어 있습니다!"
    exit 1
else
    echo "✅ 릴리즈 빌드에서 추적 코드가 제거되었습니다"
fi

echo "📊 성능 벤치마크 실행..."
./MyApp --performance-test
```

## 문제 해결

### Q: 프로덕션에서 통계가 필요한 경우
**A:** 별도의 경량 메트릭 시스템을 구현하거나, 특정 빌드에서만 `DI_MONITORING_ENABLED`를 활성화하세요.

### Q: 개발 환경에서 성능이 느린 경우
**A:** `DI_MONITORING_ENABLED` 플래그를 일시적으로 비활성화하여 프로덕션 수준 성능을 테스트할 수 있습니다.

### Q: 메모리 사용량이 증가하는 경우
**A:** 개발 환경에서만 추적 데이터를 저장하므로, 프로덕션에는 영향이 없습니다. 필요시 통계를 주기적으로 초기화하세요.

## 고급 최적화 기법

### 커스텀 성능 메트릭

```swift
extension DIAdvanced.Performance {
    /// 커스텀 메트릭 추가
    @MainActor
    public static func addCustomMetric(_ name: String, value: Int) {
        #if DEBUG && DI_MONITORING_ENABLED
        customMetrics[name] = value
        #endif
    }

    /// 성능 이벤트 로깅
    public static func logPerformanceEvent(_ event: String) {
        #if DEBUG && DI_MONITORING_ENABLED
        Log.performance("📈 \(event)")
        #endif
    }
}
```

## 관련 API

- [`AutoDIOptimizer`](./autoDiOptimizer.md) - 자동 최적화 엔진
- [`환경 플래그`](./environmentFlags.md) - 컴파일 타임 최적화
- [`UnifiedDI`](./unifiedDI.md) - 통합 DI 시스템

---

*이 최적화 시스템은 WeaveDI v3.2.1에서 도입되었습니다. 프로덕션 성능과 개발 편의성의 완벽한 균형을 제공하는 혁신적인 시스템입니다.*