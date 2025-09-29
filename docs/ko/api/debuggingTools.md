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
    @Inject var logger: LoggerProtocol?

    func performOperation() {
        // 디버깅이 이 해결을 자동으로 추적
        logger?.info("작업 수행됨")
    }
}
```

## 핵심 디버깅 기능

### 컨테이너 상태 검사

#### `WeaveDI.Container.printDependencyGraph()`

**목적**: 등록된 모든 의존성과 그들의 관계를 시각화하여 완전한 의존성 그래프를 출력합니다. 이는 애플리케이션의 의존성 구조를 이해하고 잠재적인 문제를 식별하는 데 매우 유용합니다.

**사용 시기**:
- 개발 중 의존성 등록을 검증할 때
- 누락되거나 잘못된 의존성을 디버깅할 때
- 복잡한 의존성 체인을 이해하고자 할 때
- 문서화 및 아키텍처 검토 시

**매개변수**: 없음

**반환값**: Void (콘솔에 출력)

**출력 형식 예시**:
```
📊 WeaveDI 의존성 그래프
┌─ ServiceType → ConcreteImplementation
├─ AnotherService → Implementation
│   ├── depends on: ServiceType
│   └── depends on: ThirdService
```

**성능 영향**: 최소한의 성능 오버헤드 (개발 환경에서만 사용 권장)

**스레드 안전성**: 모든 그래프 출력 작업은 스레드 안전합니다

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
📊 WeaveDI 의존성 그래프
┌─ LoggerProtocol → FileLogger
├─ CounterRepository → UserDefaultsCounterRepository
└─ CounterService → CounterService
    ├── depends on: LoggerProtocol
    └── depends on: CounterRepository
```

#### `WeaveDI.Container.getDependencyInfo(_:)`

**목적**: 특정 등록된 의존성에 대한 포괄적인 메타데이터를 검색합니다. 타입, 범위, 등록 시간, 의존성 관계를 포함한 상세 정보를 제공합니다.

**사용 시기**:
- 개별 의존성 구성을 검사할 때
- 의존성 해결 문제를 해결할 때
- 특정 서비스의 성능 분석 시
- 의존성 등록 세부사항을 확인할 때

**매개변수**:
- `type: Any.Type` - 검사할 의존성의 타입

**반환값**: `DependencyInfo` 구조체 (다음 정보 포함):
- `type`: 의존성 타입
- `scope`: 등록 범위 (싱글톤, 일시적 등)
- `dependencies`: 이 의존성이 의존하는 타입들의 배열
- `registrationTime`: 의존성이 등록된 시간
- `instanceCount`: 생성된 인스턴스 수
- `lastAccessTime`: 마지막 접근 시간

**사용 예시 및 분석**:
- **성능 분석**: 해결 시간과 인스턴스 수를 통한 성능 병목 식별
- **메모리 분석**: 인스턴스 수를 통한 메모리 사용량 추적
- **의존성 추적**: 의존성 체인 분석으로 복잡도 파악

특정 의존성에 대한 자세한 정보를 가져옵니다:

```swift
let info = WeaveDI.Container.getDependencyInfo(CounterService.self)
print("타입: \\(info.type)")
print("범위: \\(info.scope)")
print("의존성: \\(info.dependencies)")
print("등록 시간: \\(info.registrationTime)")
```

### 해결 추적

#### `WeaveDI.Container.enableResolutionTracing()`

의존성 해결의 상세한 추적을 활성화합니다:

```swift
// 추적 활성화
WeaveDI.Container.enableResolutionTracing()

class CounterViewModel: ObservableObject {
    @Inject var repository: CounterRepository?
    @Inject var logger: LoggerProtocol?

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
  └── ✅ 찾음: UserDefaultsCounterRepository (0.2ms)
🔍 [RESOLUTION] LoggerProtocol 해결 중
  └── ✅ 찾음: FileLogger (0.1ms)
```

### 성능 프로파일링

#### `WeaveDI.Container.enablePerformanceProfiling()`

의존성 해결 성능을 프로파일합니다:

```swift
WeaveDI.Container.enablePerformanceProfiling()

// 프로파일링 데이터가 자동으로 수집됨
let viewModel = CounterViewModel() // 해결 시간 추적됨

// 성능 보고서 가져오기
let report = WeaveDI.Container.getPerformanceReport()
print("총 해결 수: \\(report.totalResolutions)")
print("평균 해결 시간: \\(report.averageResolutionTime)ms")
print("가장 느린 의존성: \\(report.slowestDependency)")
```

## 튜토리얼의 실제 예제

### CountApp 디버깅 설정

우리 튜토리얼 CountApp을 기반으로 포괄적인 디버깅을 구현하는 방법입니다:

```swift
/// 디버깅 도구가 향상된 CountApp
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
        print("\\n🔧 CountApp 디버그 정보")
        print("컨테이너 상태: \\(WeaveDI.Container.isBootstrapped ? "준비됨" : "준비 안됨")")
        print("등록된 의존성: \\(WeaveDI.Container.getRegisteredDependencies().count)개")

        // 특정 의존성 확인
        let hasLogger = WeaveDI.Container.canResolve(LoggerProtocol.self, name: "main")
        let hasRepository = WeaveDI.Container.canResolve(CounterRepository.self)
        let hasService = WeaveDI.Container.canResolve(CounterService.self)

        print("Logger 사용 가능: \\(hasLogger)")
        print("Repository 사용 가능: \\(hasRepository)")
        print("Service 사용 가능: \\(hasService)")
        #endif
    }
}

/// 디버깅이 향상된 CounterService
class CounterService {
    private let logger: LoggerProtocol
    private let repository: CounterRepository

    init(logger: LoggerProtocol, repository: CounterRepository) {
        self.logger = logger
        self.repository = repository

        #if DEBUG
        logger.debug("🔧 CounterService 초기화됨:")
        logger.debug("  - Logger: \\(type(of: logger))")
        logger.debug("  - Repository: \\(type(of: repository))")
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
        logger.debug("⚡ increment() \\(String(format: "%.3f", duration * 1000))ms에 완료")
        #endif

        logger.info("📊 카운트가 \\(newCount)로 증가됨")
        return newCount
    }
}

/// 디버깅이 향상된 ViewModel
@MainActor
class CounterViewModel: ObservableObject {
    @Published var count = 0
    @Published var isLoading = false

    @Inject var counterService: CounterService?
    @Inject var logger: LoggerProtocol?

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
            logger?.error("❌ CounterService 사용 불가")
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
            logger?.error("❌ 초기 데이터 로드 불가: CounterService 사용 불가")
            #endif
            return
        }

        count = await service.getCurrentCount()

        #if DEBUG
        logger?.debug("📥 초기 데이터 로드됨: count = \\(count)")
        #endif
    }

    #if DEBUG
    private func verifyDependencies() {
        let serviceAvailable = counterService != nil
        let loggerAvailable = logger != nil

        print("🔍 CounterViewModel 의존성 확인:")
        print("  - CounterService: \\(serviceAvailable ? "✅" : "❌")")
        print("  - Logger: \\(loggerAvailable ? "✅" : "❌")")

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

        // 사용자 정의 디버그 필터
        WeaveDI.Container.setDebugFilter { dependencyType in
            // 날씨 관련 의존성만 추적
            return String(describing: dependencyType).contains("Weather")
        }
        #endif
    }

    static func printWeatherDependencyHealth() {
        #if DEBUG
        print("\\n🌤️ 날씨 앱 의존성 상태 확인")

        let criticalDependencies = [
            (HTTPClientProtocol.self, "HTTP Client"),
            (WeatherServiceProtocol.self, "Weather Service"),
            (CacheServiceProtocol.self, "Cache Service"),
            (LoggerProtocol.self, "Logger")
        ]

        for (type, name) in criticalDependencies {
            let available = WeaveDI.Container.canResolve(type)
            let status = available ? "✅" : "❌"
            print("\\(status) \\(name): \\(available ? "사용 가능" : "누락")")

            if available {
                let info = WeaveDI.Container.getDependencyInfo(type)
                print("   범위: \\(info.scope), 생성됨: \\(info.registrationTime)")
            }
        }

        // 해결 성능 출력
        let report = WeaveDI.Container.getPerformanceReport()
        print("\\n📊 성능 메트릭:")
        print("  총 해결 수: \\(report.totalResolutions)")
        print("  평균 시간: \\(String(format: "%.2f", report.averageResolutionTime))ms")

        if let slowest = report.slowestDependency {
            print("  가장 느림: \\(slowest.name) (\\(String(format: "%.2f", slowest.time))ms)")
        }
        #endif
    }
}

/// 디버그 로깅이 향상된 날씨 서비스
class WeatherService: WeatherServiceProtocol {
    @Inject var httpClient: HTTPClientProtocol?
    @Inject var cache: CacheServiceProtocol?
    @Inject var logger: LoggerProtocol?

    func fetchCurrentWeather(for city: String) async throws -> Weather {
        #if DEBUG
        logger?.debug("🌐 \\(city)의 날씨 가져오기 시작")
        let startTime = CFAbsoluteTimeGetCurrent()
        #endif

        // 의존성 확인
        guard let client = httpClient else {
            #if DEBUG
            logger?.error("❌ HTTP Client 사용 불가")
            #endif
            throw WeatherError.httpClientUnavailable
        }

        do {
            let weather = try await client.fetchWeather(for: city)

            #if DEBUG
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger?.debug("✅ 날씨 가져오기 \\(String(format: "%.2f", duration * 1000))ms에 완료")
            #endif

            // 결과 캐시
            try? await cache?.store(weather, forKey: "weather_\\(city)")

            return weather
        } catch {
            #if DEBUG
            logger?.error("❌ 날씨 가져오기 실패: \\(error.localizedDescription)")
            #endif

            // 캐시된 데이터 시도
            if let cached: Weather = try? await cache?.retrieve(forKey: "weather_\\(city)") {
                #if DEBUG
                logger?.debug("📱 \\(city)의 캐시된 날씨 데이터 사용")
                #endif
                return cached
            }

            throw error
        }
    }
}
```

## 고급 디버깅 도구

### 메모리 누수 탐지

```swift
class MemoryDebugger {
    static func detectPotentialLeaks() {
        #if DEBUG
        let report = WeaveDI.Container.getMemoryReport()

        print("🧠 메모리 분석:")
        print("  활성 인스턴스: \\(report.activeInstances)")
        print("  메모리 사용량: \\(report.estimatedMemoryUsage) bytes")

        // 잠재적 메모리 누수 확인
        for dependency in report.dependencies {
            if dependency.instanceCount > dependency.expectedCount {
                print("⚠️  \\(dependency.type)에서 잠재적 누수: \\(dependency.instanceCount)개 인스턴스")
            }
        }
        #endif
    }
}
```

### 의존성 순환 탐지

```swift
extension WeaveDI.Container {
    static func detectCycles() -> [DependencyCycle] {
        #if DEBUG
        let cycles = WeaveDI.Container.analyzeDependencyCycles()

        for cycle in cycles {
            print("🔄 의존성 순환 탐지:")
            for (index, dependency) in cycle.path.enumerated() {
                let arrow = index < cycle.path.count - 1 ? " → " : ""
                print("  \\(dependency)\\(arrow)")
            }
        }

        return cycles
        #else
        return []
        #endif
    }
}
```

### 런타임 구성 검증

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
        // @Inject 프로퍼티 래퍼에 대한 코드 스캔
        // 이것은 리플렉션이나 컴파일 타임 분석을 사용하여 구현됨
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

## 테스팅과 디버깅 통합

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

        // 추적을 통한 해결 테스트
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
        // 순환 의존성 검증
        let cycles = WeaveDI.Container.detectCycles()
        XCTAssertTrue(cycles.isEmpty, "순환 의존성 탐지됨")

        // 모든 의존성이 해결될 수 있는지 검증
        let validation = ConfigurationValidator.validateConfiguration()
        XCTAssertTrue(validation.isValid, "구성 검증 실패")
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
                    ForEach(dependencyInfo, id: \\.type) { info in
                        VStack(alignment: .leading) {
                            Text(info.name)
                                .font(.headline)
                            Text("범위: \\(info.scope)")
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
                            Text("\\(report.totalResolutions)")
                        }

                        HStack {
                            Text("평균 시간")
                            Spacer()
                            Text("\\(String(format: "%.2f", report.averageResolutionTime))ms")
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

        // 프로덕션에서는 간섭하지 않는 디버깅만 활성화
        WeaveDI.Container.enablePerformanceProfiling()
        WeaveDI.Container.setLogLevel(.error) // 오류만 로그
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
            print("진단 전송 실패: \\(error)")
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
        print("🔧 [DEBUG] \\(message)")
        #endif
    }

    func info(_ message: String) {
        print("ℹ️ [INFO] \\(message)")
    }

    func error(_ message: String) {
        print("❌ [ERROR] \\(message)")
    }
}
```

### 3. 의존성을 일찍 검증

```swift
func validateDependencies() {
    #if DEBUG
    let validation = ConfigurationValidator.validateConfiguration()
    assert(validation.isValid, "의존성 구성이 잘못됨")
    #endif
}
```

### 4. 성능 모니터링

```swift
func monitorPerformance() {
    #if DEBUG
    let report = WeaveDI.Container.getPerformanceReport()
    if report.averageResolutionTime > 5.0 {
        print("⚠️ 느린 의존성 해결 탐지: \\(report.averageResolutionTime)ms")
    }
    #endif
}
```

## 참고 자료

- [성능 모니터링 API](./performanceMonitoring.md) - DI 성능 모니터링
- [UnifiedDI API](./unifiedDI.md) - 간소화된 DI 인터페이스
- [Bootstrap API](./bootstrap.md) - 컨테이너 초기화
- [테스팅 가이드](../tutorial/testing.md) - 테스팅 전략