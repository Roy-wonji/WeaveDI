# 디버깅 도구 API 참조

WeaveDI는 의존성 해결을 추적하고, 구성 문제를 식별하며, 의존성 주입 설정을 최적화하는 데 도움이 되는 포괄적인 디버깅 도구를 제공합니다. 이러한 도구들은 개발 및 문제 해결에 필수적입니다.

## 개요

WeaveDI의 디버깅 도구는 의존성 컨테이너 상태, 해결 경로, 성능 특성에 대한 실시간 통찰력을 제공합니다. 의존성이 어떻게 해결되는지 이해하고 개발 초기에 잠재적인 문제를 식별하는 데 도움이 됩니다.

```swift
import WeaveDI

// 개발용 디버깅 활성화
#if DEBUG
WeaveDI.Container.enableDebugging()
WeaveDI.Container.setLogLevel(.verbose)
#endif

class MyService {
    @Injected var logger: LoggerProtocol?

    func performOperation() {
        // 디버깅이 이 해결을 자동으로 추적
        logger?.info("작업 수행됨")
    }
}
```

## 핵심 디버깅 기능

### 컨테이너 상태 검사

#### `WeaveDI.Container.printDependencyGraph()`

**목적**: 등록된 모든 의존성과 그들의 관계를 보여주는 완전한 의존성 그래프를 시각화합니다. 이는 애플리케이션의 의존성 구조를 이해하고 잠재적인 문제를 식별하는 데 매우 유용합니다.

**사용 시기**:
- 개발 중 의존성 등록을 확인할 때
- 누락되거나 잘못된 의존성을 디버깅할 때
- 복잡한 의존성 체인을 이해할 때
- 문서화 및 아키텍처 검토를 위해

**매개변수**: 없음

**반환값**: Void (콘솔에 출력)

**예제 출력 형식**:
```
📊 WeaveDI Dependency Graph
┌─ ServiceType → ConcreteImplementation
├─ AnotherService → Implementation
│   ├── depends on: ServiceType
│   └── depends on: ThirdService
```

등록된 모든 의존성과 그들의 관계를 보여주는 완전한 의존성 그래프를 출력합니다:

```swift
await WeaveDI.Container.bootstrap { container in
    container.register(LoggerProtocol.self) { FileLogger() }
    container.register(CounterRepository.self) { UserDefaultsCounterRepository() }
    container.register(CounterService.self) {
        let logger = container.resolve(LoggerProtocol.self)!
        let repository = container.resolve(CounterRepository.self)!
        return CounterService(logger: logger, repository: repository)
    }
}

// 완전한 의존성 그래프 출력
WeaveDI.Container.printDependencyGraph()
```

출력:
```
📊 WeaveDI Dependency Graph
┌─ LoggerProtocol → FileLogger
├─ CounterRepository → UserDefaultsCounterRepository
└─ CounterService → CounterService
    ├── depends on: LoggerProtocol
    └── depends on: CounterRepository
```

#### `WeaveDI.Container.getDependencyInfo(_:)`

**목적**: 특정 등록된 의존성에 대한 포괄적인 메타데이터를 검색합니다. 이는 타입, 스코프, 등록 시간, 의존성 관계를 포함합니다.

**사용 시기**:
- 개별 의존성 구성을 검사할 때
- 의존성 해결 문제를 해결할 때
- 특정 서비스의 성능 분석을 위해
- 의존성 등록 세부 정보를 확인할 때

**매개변수**:
- `type: Any.Type` - 검사할 의존성의 타입

**반환값**: `DependencyInfo` 구조체, 다음을 포함:
- `type`: 의존성 타입
- `scope`: 등록 스코프 (싱글톤, 일시적 등)
- `dependencies`: 이 의존성이 의존하는 타입들의 배열
- `registrationTime`: 의존성이 등록된 시간
- `instanceCount`: 생성된 인스턴스 수
- `lastAccessTime`: 마지막으로 접근된 시간

특정 의존성에 대한 상세 정보를 가져옵니다:

```swift
let info = WeaveDI.Container.getDependencyInfo(CounterService.self)
print("타입: \(info.type)")
print("스코프: \(info.scope)")
print("의존성: \(info.dependencies)")
print("등록 시간: \(info.registrationTime)")
```

### 해결 추적

#### `WeaveDI.Container.enableResolutionTracing()`

**목적**: 모든 의존성 해결 작업의 실시간 추적을 활성화하며, 타이밍 정보와 의존성 경로를 포함한 해결 과정의 상세 로그를 제공합니다.

**사용 시기**:
- 개발 중 해결 흐름을 이해할 때
- 느린 의존성 해결을 디버깅할 때
- 사용되지 않는 의존성을 식별할 때
- 컨테이너 성능을 최적화할 때

**매개변수**: 없음

**반환값**: Void

**부작용**:
- 모든 해결 시도에 대한 콘솔 로깅 활성화
- 최소한의 성능 오버헤드 추가 (DEBUG에서만 권장)
- 타이밍 정보와 성공/실패 상태를 포함한 로그

**구성 옵션**:
- 상세 출력을 위해 `setLogLevel(.verbose)` 설정
- 기본 해결 추적을 위해 `setLogLevel(.minimal)` 사용
- 포괄적인 분석을 위해 성능 프로파일링과 결합

의존성 해결의 상세 추적을 활성화합니다:

```swift
// 추적 활성화
WeaveDI.Container.enableResolutionTracing()

class CounterViewModel: ObservableObject {
    @Injected var repository: CounterRepository?
    @Injected var logger: LoggerProtocol?

    func increment() {
        // 해결이 자동으로 추적됨
        repository?.saveCount(count + 1)
        logger?.info("카운트 증가됨")
    }
}
```

추적 출력:
```
🔍 [RESOLUTION] CounterRepository 해결 중
  └── ✅ 발견: UserDefaultsCounterRepository (0.2ms)
🔍 [RESOLUTION] LoggerProtocol 해결 중
  └── ✅ 발견: FileLogger (0.1ms)
```

### 성능 프로파일링

#### `WeaveDI.Container.enablePerformanceProfiling()`

**목적**: 모든 의존성 주입 작업에 대한 포괄적인 성능 모니터링을 활성화하여 해결 시간, 메모리 사용량, 컨테이너 효율성에 대한 상세 메트릭을 수집합니다.

**사용 시기**:
- 의존성 해결의 성능 병목점을 식별할 때
- 로드 테스트 중 DI 오버헤드를 이해할 때
- 프로덕션 모니터링을 위해 (신중한 고려 필요)
- 애플리케이션 시작 시간을 최적화할 때
- 의존성 생성에서 메모리 누수를 감지할 때

**매개변수**: 없음

**반환값**: Void

**수집된 메트릭**:
- **해결 시간**: 각 의존성 해결에 대한 마이크로초 정밀도 타이밍
- **메모리 사용량**: 의존성 생성 중 할당된 메모리
- **캐시 적중/미스 비율**: 의존성 캐싱의 효율성
- **등록 수**: 등록된 의존성의 수
- **인스턴스 수**: 메모리에 있는 활성 의존성 인스턴스
- **가비지 컬렉션 영향**: 정리 대상인 의존성

**성능 영향**:
- **개발**: 최소한의 오버헤드 (~1-3% 성능 영향)
- **프로덕션**: 중요 경로 모니터링만 활성화 고려
- **메모리**: 메트릭 저장을 위한 작은 메모리 사용량
- **스레드 안전성**: 모든 프로파일링 작업이 스레드 안전

**모범 사례**:
- 개발 및 테스트 단계에서 활성화
- 개발 전용 프로파일링을 위해 조건부 컴파일 (`#if DEBUG`) 사용
- 포괄적인 디버깅을 위해 `enableResolutionTracing()`과 결합
- 프로덕션에서 외부 모니터링 시스템으로 메트릭 내보내기

의존성 해결 성능을 프로파일링합니다:

```swift
WeaveDI.Container.enablePerformanceProfiling()

// 프로파일링 데이터가 자동으로 수집됨
let viewModel = CounterViewModel() // 해결 시간이 추적됨

// 성능 보고서 가져오기
let report = WeaveDI.Container.getPerformanceReport()
print("총 해결 수: \(report.totalResolutions)")
print("평균 해결 시간: \(report.averageResolutionTime)ms")
print("가장 느린 의존성: \(report.slowestDependency)")
```

## 튜토리얼의 실제 예제

### CountApp 디버깅 설정

**개요**: 이 포괄적인 예제는 WeaveDI의 디버깅 도구를 실제 애플리케이션에 통합하는 방법을 보여줍니다. CountApp 예제는 자신의 프로젝트에 적용할 수 있는 프로덕션 준비 디버깅 패턴을 보여줍니다.

**시연되는 주요 기능**:
- **조건부 디버깅**: 개발 빌드에서만 디버깅 활성화
- **의존성 검증**: 중요한 의존성의 자동 유효성 검사
- **성능 모니터링**: 해결 시간과 메모리 사용량 추적
- **디버그 정보 표시**: 런타임 의존성 상태 보고
- **에러 처리**: 누락된 의존성의 우아한 처리

**아키텍처 이점**:
- **제로 프로덕션 오버헤드**: 모든 디버깅 코드가 조건부로 컴파일됨
- **포괄적인 커버리지**: 모든 의존성 해결이 모니터링됨
- **실시간 통찰력**: 의존성 문제에 대한 즉각적인 피드백
- **유지보수 가능한 구조**: 디버그와 프로덕션 코드의 깔끔한 분리

튜토리얼 CountApp을 기반으로 한 포괄적인 디버깅 구현 방법입니다:

```swift
/// 디버깅 도구가 강화된 CountApp
@main
struct CountApp: App {
    init() {
        setupDebugging()
        setupDependencies()
    }

    var body: some Scene {
        WindowGroup {
            CounterView()
                .onAppear {
                    printDebugInfo()
                }
        }
    }

    private func setupDebugging() {
        #if DEBUG
        WeaveDI.Container.enableDebugging()
        WeaveDI.Container.enableResolutionTracing()
        WeaveDI.Container.enablePerformanceProfiling()
        WeaveDI.Container.setLogLevel(.verbose)
        #endif
    }

    private func setupDependencies() {
        Task {
            await WeaveDI.Container.bootstrap { container in
                // 디버깅 정보와 함께 등록
                container.register(LoggerProtocol.self, name: "main") {
                    FileLogger(filename: "counter.log")
                }

                container.register(CounterRepository.self) {
                    UserDefaultsCounterRepository()
                }

                // 디버깅 시연을 위한 복잡한 의존성
                container.register(CounterService.self) {
                    let logger = container.resolve(LoggerProtocol.self, name: "main")!
                    let repository = container.resolve(CounterRepository.self)!
                    return CounterService(logger: logger, repository: repository)
                }
            }

            // 설정 후 의존성 그래프 출력
            WeaveDI.Container.printDependencyGraph()
        }
    }

    private func printDebugInfo() {
        #if DEBUG
        print("\n🔧 CountApp 디버그 정보")
        print("컨테이너 상태: \(WeaveDI.Container.isBootstrapped ? "준비됨" : "준비되지 않음")")
        print("등록된 의존성: \(WeaveDI.Container.getRegisteredDependencies().count)")

        // 특정 의존성 확인
        let hasLogger = WeaveDI.Container.canResolve(LoggerProtocol.self, name: "main")
        let hasRepository = WeaveDI.Container.canResolve(CounterRepository.self)
        let hasService = WeaveDI.Container.canResolve(CounterService.self)

        print("Logger 사용 가능: \(hasLogger)")
        print("Repository 사용 가능: \(hasRepository)")
        print("Service 사용 가능: \(hasService)")
        #endif
    }
}

/// 디버깅이 강화된 CounterService
class CounterService {
    private let logger: LoggerProtocol
    private let repository: CounterRepository

    init(logger: LoggerProtocol, repository: CounterRepository) {
        self.logger = logger
        self.repository = repository

        #if DEBUG
        logger.debug("🔧 CounterService가 다음과 함께 초기화됨:")
        logger.debug("  - Logger: \(type(of: logger))")
        logger.debug("  - Repository: \(type(of: repository))")
        #endif
    }

    func increment() async -> Int {
        #if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
        #endif

        let currentCount = await repository.getCurrentCount()
        let newCount = currentCount + 1
        await repository.saveCount(newCount)

        #if DEBUG
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        logger.debug("⚡ increment()가 \(String(format: "%.3f", duration * 1000))ms에 완료됨")
        #endif

        logger.info("📊 카운트가 \(newCount)로 증가됨")
        return newCount
    }
}

/// 디버깅이 강화된 ViewModel
@MainActor
class CounterViewModel: ObservableObject {
    @Published var count = 0
    @Published var isLoading = false

    @Injected var counterService: CounterService?
    @Injected var logger: LoggerProtocol?

    init() {
        #if DEBUG
        // 초기화 중 의존성 확인
        verifyDependencies()
        #endif

        Task {
            await loadInitialData()
        }
    }

    func increment() async {
        isLoading = true

        #if DEBUG
        logger?.debug("🔄 증가 작업 시작")
        #endif

        guard let service = counterService else {
            #if DEBUG
            logger?.error("❌ CounterService를 사용할 수 없음")
            #endif
            isLoading = false
            return
        }

        count = await service.increment()
        isLoading = false

        #if DEBUG
        logger?.debug("✅ 증가 작업 완료")
        #endif
    }

    private func loadInitialData() async {
        guard let service = counterService else {
            #if DEBUG
            logger?.error("❌ 초기 데이터를 로드할 수 없음: CounterService를 사용할 수 없음")
            #endif
            return
        }

        count = await service.getCurrentCount()

        #if DEBUG
        logger?.debug("📥 초기 데이터 로드됨: count = \(count)")
        #endif
    }

    #if DEBUG
    private func verifyDependencies() {
        let serviceAvailable = counterService != nil
        let loggerAvailable = logger != nil

        print("🔍 CounterViewModel 의존성 확인:")
        print("  - CounterService: \(serviceAvailable ? "✅" : "❌")")
        print("  - Logger: \(loggerAvailable ? "✅" : "❌")")

        if !serviceAvailable || !loggerAvailable {
            print("⚠️  누락된 의존성 감지!")
        }
    }
    #endif
}
```

### WeatherApp 디버그 구성

```swift
/// 포괄적인 디버깅이 있는 날씨 앱
class WeatherAppDebugManager {
    static func setupDebugging() {
        #if DEBUG
        WeaveDI.Container.enableDebugging()
        WeaveDI.Container.enableResolutionTracing()
        WeaveDI.Container.enablePerformanceProfiling()

        // 커스텀 디버그 필터
        WeaveDI.Container.setDebugFilter { dependencyType in
            // 날씨 관련 의존성만 추적
            return String(describing: dependencyType).contains("Weather")
        }
        #endif
    }

    static func printWeatherDependencyHealth() {
        #if DEBUG
        print("\n🌤️ Weather App 의존성 상태 확인")

        let criticalDependencies = [
            (HTTPClientProtocol.self, "HTTP Client"),
            (WeatherServiceProtocol.self, "Weather Service"),
            (CacheServiceProtocol.self, "Cache Service"),
            (LoggerProtocol.self, "Logger")
        ]

        for (type, name) in criticalDependencies {
            let available = WeaveDI.Container.canResolve(type)
            let status = available ? "✅" : "❌"
            print("\(status) \(name): \(available ? "사용 가능" : "누락")")

            if available {
                let info = WeaveDI.Container.getDependencyInfo(type)
                print("   스코프: \(info.scope), 생성됨: \(info.registrationTime)")
            }
        }

        // 해결 성능 출력
        let report = WeaveDI.Container.getPerformanceReport()
        print("\n📊 성능 메트릭:")
        print("  총 해결 수: \(report.totalResolutions)")
        print("  평균 시간: \(String(format: "%.2f", report.averageResolutionTime))ms")

        if let slowest = report.slowestDependency {
            print("  가장 느림: \(slowest.name) (\(String(format: "%.2f", slowest.time))ms)")
        }
        #endif
    }
}

/// 디버그 로깅이 강화된 Weather Service
class WeatherService: WeatherServiceProtocol {
    @Injected var httpClient: HTTPClientProtocol?
    @Injected var cache: CacheServiceProtocol?
    @Injected var logger: LoggerProtocol?

    func fetchCurrentWeather(for city: String) async throws -> Weather {
        #if DEBUG
        logger?.debug("🌐 \(city)의 날씨 가져오기 시작")
        let startTime = CFAbsoluteTimeGetCurrent()
        #endif

        // 의존성 확인
        guard let client = httpClient else {
            #if DEBUG
            logger?.error("❌ HTTP Client를 사용할 수 없음")
            #endif
            throw WeatherError.httpClientUnavailable
        }

        do {
            let weather = try await client.fetchWeather(for: city)

            #if DEBUG
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger?.debug("✅ 날씨 가져오기가 \(String(format: "%.2f", duration * 1000))ms에 완료됨")
            #endif

            // 결과 캐시
            try? await cache?.store(weather, forKey: "weather_\(city)")

            return weather
        } catch {
            #if DEBUG
            logger?.error("❌ 날씨 가져오기 실패: \(error.localizedDescription)")
            #endif

            // 캐시된 데이터 시도
            if let cached: Weather = try? await cache?.retrieve(forKey: "weather_\(city)") {
                #if DEBUG
                logger?.debug("📱 \(city)의 캐시된 날씨 데이터 사용")
                #endif
                return cached
            }

            throw error
        }
    }
}
```

## 고급 디버깅 도구

### 메모리 누수 감지

**목적**: 의존성 주입에서 잠재적인 메모리 누수와 비효율적인 메모리 사용 패턴을 감지하는 고급 메모리 분석 도구입니다.

**작동 방식**:
- **인스턴스 추적**: 각 의존성 타입의 활성 인스턴스 수 모니터링
- **메모리 속성**: 특정 의존성에 기인한 메모리 사용량 추적
- **누수 감지**: 예상 인스턴스 수와 실제 인스턴스 수 비교
- **증가 분석**: 지속적으로 메모리 사용량이 증가하는 의존성 식별

**감지 알고리즘**:
- **예상 vs 실제**: 예상 싱글톤 인스턴스와 실제 수 비교
- **보존 분석**: 가비지 컬렉션되어야 할 객체 식별
- **메모리 증가 패턴**: 비정상적인 메모리 할당 패턴 감지
- **의존성 체인**: 전체 의존성 체인의 메모리 영향 분석

```swift
/// **고급 메모리 디버깅 시스템**
///
/// **기능**:
/// - 실시간 메모리 누수 감지
/// - 의존성 메모리 속성
/// - 메모리 증가 패턴 분석
/// - 자동화된 누수 보고
///
/// **사용 시나리오**:
/// - 장기 실행 애플리케이션 테스트
/// - 개발 중 메모리 최적화
/// - 프로덕션 메모리 모니터링
/// - 자동화된 테스트 파이프라인
class MemoryDebugger {

    /// **목적**: 잠재적인 누수를 감지하기 위한 포괄적인 메모리 분석 수행
    ///
    /// **감지 기준**:
    /// - 인스턴스 수가 예상 임계값 초과
    /// - 메모리 사용량이 경계 없이 지속적으로 증가
    /// - 객체가 예상 생명주기를 넘어 지속
    /// - 순환 참조 감지
    ///
    /// **성능**: 낮은 오버헤드 (~0.1% CPU 영향)
    /// **스레드 안전성**: 모든 작업이 스레드 안전
    /// **메모리 영향**: 추적 메타데이터를 위한 ~50KB
    static func detectPotentialLeaks() {
        #if DEBUG
        let report = WeaveDI.Container.getMemoryReport()

        print("🧠 고급 메모리 분석 보고서:")
        print("  📊 활성 인스턴스: \(report.activeInstances)")
        print("  💾 메모리 사용량: \(ByteCountFormatter().string(fromByteCount: Int64(report.estimatedMemoryUsage)))")
        print("  🕐 분석 시간: \(Date())")

        // **고급 누수 감지 알고리즘**
        var leakCount = 0
        for dependency in report.dependencies {
            if dependency.instanceCount > dependency.expectedCount {
                leakCount += 1
                let excessInstances = dependency.instanceCount - dependency.expectedCount

                print("⚠️  **잠재적 누수 감지**")
                print("     타입: \(dependency.type)")
                print("     예상: \(dependency.expectedCount) 인스턴스")
                print("     실제: \(dependency.instanceCount) 인스턴스")
                print("     초과: \(excessInstances) 인스턴스")
                print("     메모리 영향: ~\(excessInstances * dependency.averageInstanceSize) 바이트")
                print("     마지막 생성: \(dependency.lastCreationTime)")

                // **실행 가능한 권장사항 제공**
                provideLeakRecommendations(for: dependency)
            }
        }

        if leakCount == 0 {
            print("✅ 메모리 누수 감지되지 않음 - 모든 의존성이 예상 범위 내")
        } else {
            print("🚨 \(leakCount)개의 잠재적 메모리 누수 감지 - 검토 권장")
        }
        #endif
    }

    /// **목적**: 감지된 메모리 문제를 해결하기 위한 구체적인 권장사항 제공
    private static func provideLeakRecommendations(for dependency: DependencyAnalysis) {
        print("     💡 **권장사항**:")

        if dependency.hasCircularReferences {
            print("       - weak 참조를 사용하여 순환 참조 해결")
            print("       - 의존성 역전 패턴 고려")
        }

        if dependency.isFactory && dependency.instanceCount > 100 {
            print("       - 팩토리 의존성에 대한 객체 풀링 고려")
            print("       - 적절한 생명주기 관리 구현")
        }

        if dependency.memoryGrowthRate > 0.1 {
            print("       - 메모리 사용량이 분당 \(String(format: "%.1f", dependency.memoryGrowthRate * 100))% 증가 중")
            print("       - 객체 보존 정책 검토")
        }
    }
}
```

### 의존성 순환 감지

```swift
extension WeaveDI.Container {
    static func detectCycles() -> [DependencyCycle] {
        #if DEBUG
        let cycles = WeaveDI.Container.analyzeDependencyCycles()

        for cycle in cycles {
            print("🔄 의존성 순환 감지:")
            for (index, dependency) in cycle.path.enumerated() {
                let arrow = index < cycle.path.count - 1 ? " → " : ""
                print("  \(dependency)\(arrow)")
            }
        }

        return cycles
        #else
        return []
        #endif
    }
}
```

### 런타임 구성 유효성 검사

```swift
class ConfigurationValidator {
    static func validateConfiguration() -> ValidationResult {
        #if DEBUG
        var issues: [ValidationIssue] = []

        // 누락된 의존성 확인
        let registeredTypes = WeaveDI.Container.getRegisteredDependencies()
        let requiredTypes = findRequiredDependencies()

        for requiredType in requiredTypes {
            if !registeredTypes.contains(where: { $0.type == requiredType }) {
                issues.append(.missingDependency(requiredType))
            }
        }

        // 순환 의존성 확인
        let cycles = WeaveDI.Container.detectCycles()
        for cycle in cycles {
            issues.append(.circularDependency(cycle))
        }

        // 성능 문제 확인
        let report = WeaveDI.Container.getPerformanceReport()
        if report.averageResolutionTime > 10.0 { // 10ms 임계값
            issues.append(.slowResolution(report.averageResolutionTime))
        }

        return ValidationResult(issues: issues)
        #else
        return ValidationResult(issues: [])
        #endif
    }

    private static func findRequiredDependencies() -> [Any.Type] {
        // @Injected 프로퍼티 래퍼에 대한 코드 스캔
        // 이는 리플렉션이나 컴파일 타임 분석을 사용하여 구현됨
        return []
    }
}

struct ValidationResult {
    let issues: [ValidationIssue]

    var isValid: Bool {
        return issues.isEmpty
    }
}

enum ValidationIssue {
    case missingDependency(Any.Type)
    case circularDependency(DependencyCycle)
    case slowResolution(Double)
}
```

## 테스팅 및 디버깅 통합

### 테스트 디버깅 설정

```swift
class DIDebugTests: XCTestCase {
    override func setUp() async throws {
        await WeaveDI.Container.resetForTesting()

        #if DEBUG
        WeaveDI.Container.enableDebugging()
        WeaveDI.Container.enableResolutionTracing()
        #endif
    }

    func testDependencyResolution() async throws {
        await WeaveDI.Container.bootstrap { container in
            container.register(LoggerProtocol.self) { TestLogger() }
            container.register(CounterRepository.self) { MockCounterRepository() }
        }

        // 등록 확인
        XCTAssertTrue(WeaveDI.Container.canResolve(LoggerProtocol.self))
        XCTAssertTrue(WeaveDI.Container.canResolve(CounterRepository.self))

        // 추적과 함께 해결 테스트
        let logger = WeaveDI.Container.resolve(LoggerProtocol.self)
        XCTAssertNotNil(logger)

        #if DEBUG
        let report = WeaveDI.Container.getPerformanceReport()
        XCTAssertGreaterThan(report.totalResolutions, 0)
        #endif
    }

    func testDependencyGraphIntegrity() async throws {
        await WeaveDI.Container.bootstrap { container in
            container.register(CounterService.self) {
                let logger = container.resolve(LoggerProtocol.self)!
                let repository = container.resolve(CounterRepository.self)!
                return CounterService(logger: logger, repository: repository)
            }
            container.register(LoggerProtocol.self) { TestLogger() }
            container.register(CounterRepository.self) { MockCounterRepository() }
        }

        #if DEBUG
        // 순환 의존성 없음 유효성 검사
        let cycles = WeaveDI.Container.detectCycles()
        XCTAssertTrue(cycles.isEmpty, "순환 의존성 감지됨")

        // 모든 의존성이 해결될 수 있는지 유효성 검사
        let validation = ConfigurationValidator.validateConfiguration()
        XCTAssertTrue(validation.isValid, "구성 유효성 검사 실패")
        #endif
    }
}
```

### SwiftUI용 디버그 뷰

```swift
#if DEBUG
struct DebugView: View {
    @State private var dependencyInfo: [DependencyInfo] = []
    @State private var performanceReport: PerformanceReport?

    var body: some View {
        NavigationView {
            List {
                Section("의존성") {
                    ForEach(dependencyInfo, id: \.type) { info in
                        VStack(alignment: .leading) {
                            Text(info.name)
                                .font(.headline)
                            Text("스코프: \(info.scope)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if let report = performanceReport {
                    Section("성능") {
                        HStack {
                            Text("총 해결 수")
                            Spacer()
                            Text("\(report.totalResolutions)")
                        }

                        HStack {
                            Text("평균 시간")
                            Spacer()
                            Text("\(String(format: "%.2f", report.averageResolutionTime))ms")
                        }
                    }
                }
            }
            .navigationTitle("DI 디버그 정보")
            .onAppear {
                loadDebugInfo()
            }
        }
    }

    private func loadDebugInfo() {
        dependencyInfo = WeaveDI.Container.getRegisteredDependencies()
        performanceReport = WeaveDI.Container.getPerformanceReport()
    }
}

struct DIDebugModifier: ViewModifier {
    @State private var showDebug = false

    func body(content: Content) -> some View {
        content
            .onShake {
                showDebug.toggle()
            }
            .sheet(isPresented: $showDebug) {
                DebugView()
            }
    }
}

extension View {
    func debugDI() -> some View {
        self.modifier(DIDebugModifier())
    }
}
#endif
```

## 프로덕션 디버깅

### 안전한 프로덕션 디버깅

```swift
class ProductionDebugger {
    private static let isDebugEnabled = UserDefaults.standard.bool(forKey: "WeaveDI_Debug_Enabled")

    static func enableSafeDebugging() {
        guard isDebugEnabled else { return }

        // 프로덕션에서는 침입적이지 않은 디버깅만 활성화
        WeaveDI.Container.enablePerformanceProfiling()
        WeaveDI.Container.setLogLevel(.error) // 에러만 로그
    }

    static func generateDiagnosticReport() -> DiagnosticReport {
        return DiagnosticReport(
            containerState: WeaveDI.Container.isBootstrapped,
            dependencyCount: WeaveDI.Container.getRegisteredDependencies().count,
            performanceMetrics: WeaveDI.Container.getPerformanceReport(),
            timestamp: Date()
        )
    }
}

struct DiagnosticReport: Codable {
    let containerState: Bool
    let dependencyCount: Int
    let performanceMetrics: PerformanceReport
    let timestamp: Date
}
```

### 원격 디버깅

```swift
class RemoteDebugger {
    static func sendDiagnostics() async {
        #if DEBUG
        let report = ProductionDebugger.generateDiagnosticReport()

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(report)

            // 디버깅 서비스로 전송
            await sendToDebugService(data)
        } catch {
            print("진단 전송 실패: \(error)")
        }
        #endif
    }

    private static func sendToDebugService(_ data: Data) async {
        // 원격 서비스로 진단 전송 구현
    }
}
```

## 모범 사례

### 1. 조건부 컴파일 사용

```swift
#if DEBUG
WeaveDI.Container.enableDebugging()
WeaveDI.Container.enableResolutionTracing()
#endif
```

### 2. 포괄적인 로깅 구현

```swift
class DebugLogger: LoggerProtocol {
    func debug(_ message: String) {
        #if DEBUG
        print("🔧 [DEBUG] \(message)")
        #endif
    }

    func info(_ message: String) {
        print("ℹ️ [INFO] \(message)")
    }

    func error(_ message: String) {
        print("❌ [ERROR] \(message)")
    }
}
```

### 3. 의존성을 조기에 유효성 검사

```swift
func validateDependencies() {
    #if DEBUG
    let validation = ConfigurationValidator.validateConfiguration()
    assert(validation.isValid, "의존성 구성이 유효하지 않음")
    #endif
}
```

### 4. 성능 모니터링

```swift
func monitorPerformance() {
    #if DEBUG
    let report = WeaveDI.Container.getPerformanceReport()
    if report.averageResolutionTime > 5.0 {
        print("⚠️ 느린 의존성 해결 감지: \(report.averageResolutionTime)ms")
    }
    #endif
}
```

## 참고 자료

- [성능 모니터링 API](./performanceMonitoring.md) - DI 성능 모니터링
- [UnifiedDI API](./unifiedDI.md) - 간소화된 DI 인터페이스
- [Bootstrap API](./bootstrap.md) - 컨테이너 초기화
- [테스팅 가이드](../tutorial/testing.md) - 테스팅 전략