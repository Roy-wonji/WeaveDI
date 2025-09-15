# 플러그인 시스템 가이드

DiContainer의 강력한 플러그인 시스템을 통해 의존성 주입 동작을 확장하고 커스터마이징할 수 있습니다.

## 📊 개요

플러그인 시스템의 주요 기능:
- 의존성 생성/해결 라이프사이클 훅
- 커스텀 로깅 및 모니터링
- 성능 추적 및 메트릭 수집
- 조건부 의존성 해결
- 테스트 환경 지원

## 🏗 플러그인 아키텍처

### 기본 플러그인 인터페이스
```swift
public protocol DIPlugin: Sendable {
    var name: String { get }
    var priority: Int { get }

    // 라이프사이클 훅
    func willRegister<T>(type: T.Type, factory: @escaping () -> T)
    func didRegister<T>(type: T.Type)
    func willResolve<T>(type: T.Type)
    func didResolve<T>(type: T.Type, instance: T)
    func resolutionFailed<T>(type: T.Type, error: Error)
}
```

### 전문화된 플러그인 타입
```swift
// 로깅 전용 플러그인
public protocol LoggingPlugin: DIPlugin {
    func logRegistration<T>(type: T.Type, timestamp: Date)
    func logResolution<T>(type: T.Type, duration: TimeInterval)
}

// 성능 모니터링 플러그인
public protocol PerformancePlugin: DIPlugin {
    func recordMetric(name: String, value: Double, tags: [String: String])
    func startTimer(name: String) -> TimerToken
    func endTimer(token: TimerToken)
}

// 조건부 해결 플러그인
public protocol ConditionalPlugin: DIPlugin {
    func shouldResolve<T>(type: T.Type, context: ResolutionContext) -> Bool
    func provideAlternative<T>(type: T.Type) -> T?
}
```

## 🚀 기본 사용법

### 1. 플러그인 등록
```swift
// 단일 플러그인 등록
PluginManager.shared.register(LoggingPlugin())

// 여러 플러그인 등록
PluginManager.shared.register([
    LoggingPlugin(),
    PerformancePlugin(),
    DebugPlugin()
])

// 우선순위 지정 등록
PluginManager.shared.register(CustomPlugin(), priority: 100)
```

### 2. 플러그인 비활성화/제거
```swift
// 특정 플러그인 비활성화
PluginManager.shared.disable("LoggingPlugin")

// 플러그인 제거
PluginManager.shared.unregister("LoggingPlugin")

// 모든 플러그인 제거
PluginManager.shared.unregisterAll()
```

## 📝 내장 플러그인

### 로깅 플러그인
```swift
// 기본 로깅 플러그인
let loggingPlugin = ExampleLoggingPlugin()
PluginManager.shared.register(loggingPlugin)

// 커스텀 로깅 설정
let customLogging = ExampleLoggingPlugin(
    logLevel: .debug,
    includeTimestamp: true,
    includeTypeInfo: true
)
PluginManager.shared.register(customLogging)
```

### 성능 모니터링 플러그인
```swift
// 성능 추적 플러그인
let performancePlugin = PerformanceMonitoringPlugin()
PluginManager.shared.register(performancePlugin)

// 메트릭 확인
let metrics = performancePlugin.getMetrics()
print("평균 해결 시간: \(metrics.averageResolutionTime)ms")
print("총 해결 횟수: \(metrics.totalResolutions)")
```

### 디버그 플러그인
```swift
// 개발 환경에서만 활성화
#if DEBUG
let debugPlugin = DebugInformationPlugin(
    trackDependencyChain: true,
    validateCircularDependencies: true,
    logMemoryUsage: true
)
PluginManager.shared.register(debugPlugin)
#endif
```

## 🛠 커스텀 플러그인 개발

### 기본 커스텀 플러그인
```swift
public class MyCustomPlugin: DIPlugin {
    public let name = "MyCustomPlugin"
    public let priority = 50

    public func willRegister<T>(type: T.Type, factory: @escaping () -> T) {
        #logInfo("등록 준비: \(T.self)")
    }

    public func didRegister<T>(type: T.Type) {
        #logInfo("등록 완료: \(T.self)")
    }

    public func willResolve<T>(type: T.Type) {
        #logDebug("해결 시작: \(T.self)")
    }

    public func didResolve<T>(type: T.Type, instance: T) {
        #logDebug("해결 완료: \(T.self)")
    }

    public func resolutionFailed<T>(type: T.Type, error: Error) {
        #logError("해결 실패: \(T.self) - \(error)")
    }
}
```

### 고급 로깅 플러그인
```swift
public class AdvancedLoggingPlugin: LoggingPlugin {
    public let name = "AdvancedLoggingPlugin"
    public let priority = 75

    private var resolutionTimes: [String: Date] = [:]
    private let queue = DispatchQueue(label: "logging-plugin")

    public func logRegistration<T>(type: T.Type, timestamp: Date) {
        let typeName = String(describing: T.self)
        #logInfo("📝 [\(timestamp)] 등록: \(typeName)")
    }

    public func logResolution<T>(type: T.Type, duration: TimeInterval) {
        let typeName = String(describing: T.self)
        #logDebug("⚡ 해결: \(typeName) (\(duration * 1000)ms)")
    }

    public func willResolve<T>(type: T.Type) {
        queue.async {
            self.resolutionTimes[String(describing: T.self)] = Date()
        }
    }

    public func didResolve<T>(type: T.Type, instance: T) {
        let typeName = String(describing: T.self)
        queue.async {
            if let startTime = self.resolutionTimes.removeValue(forKey: typeName) {
                let duration = Date().timeIntervalSince(startTime)
                self.logResolution(type: T.self, duration: duration)
            }
        }
    }
}
```

### 조건부 해결 플러그인
```swift
public class ConditionalResolutionPlugin: ConditionalPlugin {
    public let name = "ConditionalResolutionPlugin"
    public let priority = 90

    private let testMode: Bool

    public init(testMode: Bool = false) {
        self.testMode = testMode
    }

    public func shouldResolve<T>(type: T.Type, context: ResolutionContext) -> Bool {
        // 테스트 모드에서는 특정 타입들을 제한
        if testMode && String(describing: T.self).contains("Network") {
            return false
        }
        return true
    }

    public func provideAlternative<T>(type: T.Type) -> T? {
        if testMode && T.self == NetworkService.self {
            return MockNetworkService() as? T
        }
        return nil
    }
}
```

## 📊 메트릭 및 모니터링

### 성능 메트릭 수집
```swift
public class MetricsCollectionPlugin: PerformancePlugin {
    public let name = "MetricsCollectionPlugin"
    public let priority = 60

    private var metrics: [String: Double] = [:]
    private var timers: [TimerToken: Date] = [:]

    public func recordMetric(name: String, value: Double, tags: [String: String] = [:]) {
        metrics[name] = value
        #logDebug("📊 메트릭 기록: \(name) = \(value)")
    }

    public func startTimer(name: String) -> TimerToken {
        let token = TimerToken(name: name)
        timers[token] = Date()
        return token
    }

    public func endTimer(token: TimerToken) {
        guard let startTime = timers.removeValue(forKey: token) else { return }
        let duration = Date().timeIntervalSince(startTime)
        recordMetric(name: "\(token.name)_duration", value: duration * 1000)
    }

    public func getMetrics() -> [String: Double] {
        return metrics
    }
}

public struct TimerToken: Hashable {
    let name: String
    let id = UUID()
}
```

### 메모리 사용량 추적
```swift
public class MemoryTrackingPlugin: DIPlugin {
    public let name = "MemoryTrackingPlugin"
    public let priority = 40

    private var instanceCounts: [String: Int] = [:]

    public func didResolve<T>(type: T.Type, instance: T) {
        let typeName = String(describing: T.self)
        instanceCounts[typeName, default: 0] += 1

        #logDebug("🧠 메모리 추적: \(typeName) (\(instanceCounts[typeName]!)개 인스턴스)")
    }

    public func getInstanceCounts() -> [String: Int] {
        return instanceCounts
    }

    public func resetCounts() {
        instanceCounts.removeAll()
    }
}
```

## 🧪 테스트 환경 플러그인

### 테스트 전용 플러그인
```swift
public class TestEnvironmentPlugin: DIPlugin {
    public let name = "TestEnvironmentPlugin"
    public let priority = 100

    private var mockMappings: [String: Any] = [:]

    public func addMockMapping<T, Mock>(for type: T.Type, mock: Mock) {
        mockMappings[String(describing: T.self)] = mock
    }

    public func willResolve<T>(type: T.Type) {
        let typeName = String(describing: T.self)
        if let mock = mockMappings[typeName] as? T {
            #logInfo("🧪 테스트 모킹: \(typeName)")
        }
    }
}

// 사용 예시
let testPlugin = TestEnvironmentPlugin()
testPlugin.addMockMapping(for: NetworkService.self, mock: MockNetworkService())
testPlugin.addMockMapping(for: DatabaseService.self, mock: MockDatabaseService())
PluginManager.shared.register(testPlugin)
```

## 🔧 플러그인 체인 및 우선순위

### 우선순위 시스템
```swift
// 높은 우선순위 (먼저 실행)
PluginManager.shared.register(SecurityPlugin(), priority: 100)
PluginManager.shared.register(ValidationPlugin(), priority: 90)
PluginManager.shared.register(LoggingPlugin(), priority: 50)
PluginManager.shared.register(MetricsPlugin(), priority: 10)

// 실행 순서: Security → Validation → Logging → Metrics
```

### 조건부 플러그인 활성화
```swift
// 환경별 플러그인 설정
#if DEBUG
PluginManager.shared.register([
    DebugInformationPlugin(),
    PerformanceMonitoringPlugin(),
    MemoryTrackingPlugin()
])
#endif

#if TESTING
PluginManager.shared.register([
    TestEnvironmentPlugin(),
    MockingPlugin()
])
#endif

#if PRODUCTION
PluginManager.shared.register([
    ProductionLoggingPlugin(),
    ErrorReportingPlugin()
])
#endif
```

## 📚 실제 사용 사례

### 앱 시작 시 플러그인 설정
```swift
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // 플러그인 설정
        setupPlugins()

        // DI 컨테이너 부트스트랩
        Task {
            await DependencyContainer.bootstrap { container in
                // 의존성 등록...
            }
        }

        return true
    }

    private func setupPlugins() {
        #if DEBUG
        PluginManager.shared.register([
            ExampleLoggingPlugin(logLevel: .debug),
            PerformanceMonitoringPlugin(),
            DebugInformationPlugin()
        ])
        #else
        PluginManager.shared.register([
            ExampleLoggingPlugin(logLevel: .info),
            ErrorReportingPlugin()
        ])
        #endif
    }
}
```

### 단위 테스트에서 플러그인 사용
```swift
class DIContainerTests: XCTestCase {

    override func setUp() {
        super.setUp()

        // 테스트용 플러그인 설정
        let testPlugin = TestEnvironmentPlugin()
        testPlugin.addMockMapping(for: NetworkService.self, mock: MockNetworkService())
        PluginManager.shared.register(testPlugin)
    }

    override func tearDown() {
        PluginManager.shared.unregisterAll()
        super.tearDown()
    }

    func testDependencyResolution() {
        // 플러그인이 자동으로 모킹 처리
        let service: NetworkService = DI.resolve()
        XCTAssertTrue(service is MockNetworkService)
    }
}
```

## 💡 팁과 권장사항

1. **우선순위 설계**: 플러그인 간 실행 순서를 신중히 고려하세요
2. **성능 고려**: 무거운 작업은 백그라운드 큐에서 처리하세요
3. **메모리 관리**: 플러그인에서 강한 참조를 피하세요
4. **조건부 활성화**: 환경별로 적절한 플러그인만 활성화하세요
5. **테스트 격리**: 테스트에서 플러그인 상태를 깔끔히 정리하세요

## 🔗 관련 문서

- [CoreAPIs](CoreAPIs.md) - 핵심 API 가이드
- [DependencyGraphUsage](DependencyGraphUsage.md) - 의존성 그래프 사용법
- [PropertyWrappers](PropertyWrappers.md) - 프로퍼티 래퍼 가이드