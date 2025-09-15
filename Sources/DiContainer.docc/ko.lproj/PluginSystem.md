# 플러그인 시스템

DiContainer의 강력한 플러그인 아키텍처를 사용하여 의존성 주입 과정을 커스터마이징하고 확장하는 방법

## 개요

DiContainer의 플러그인 시스템은 의존성 등록, 해결, 생명주기 관리 등의 모든 단계에서 커스텀 로직을 삽입할 수 있는 확장 가능한 아키텍처를 제공합니다. 로깅, 성능 모니터링, 검증, 자동 탐지 등 다양한 기능을 플러그인을 통해 구현할 수 있습니다.

## 플러그인 아키텍처

### 핵심 구성요소

```swift
// 1. 베이스 플러그인 - 모든 플러그인의 기본 클래스
open class BasePlugin: @unchecked Sendable {
    public let id: String
    public let priority: PluginPriority

    public init(id: String, priority: PluginPriority = .normal) {
        self.id = id
        self.priority = priority
    }

    // 플러그인 생명주기
    open func willLoad() async { }
    open func didLoad() async { }
    open func willUnload() async { }
    open func didUnload() async { }
}

// 2. 플러그인 타입별 프로토콜
public protocol RegistrationPlugin: Plugin {
    func beforeRegistration<T>(_ type: T.Type, factory: @escaping () -> T)
    func afterRegistration<T>(_ type: T.Type, instance: T)
}

public protocol ResolutionPlugin: Plugin {
    func beforeResolution<T>(_ type: T.Type) -> T?
    func afterResolution<T>(_ type: T.Type, instance: T) -> T
}

public protocol LifecyclePlugin: Plugin {
    func onContainerCreated(_ container: DependencyContainer)
    func onContainerDestroyed(_ container: DependencyContainer)
}
```

### 플러그인 우선순위

```swift
public enum PluginPriority: Int, Comparable {
    case highest = 1000
    case high = 750
    case normal = 500
    case low = 250
    case lowest = 100

    public static func < (lhs: PluginPriority, rhs: PluginPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
```

## 내장 플러그인

### 1. 로깅 플러그인

모든 DI 활동을 로그로 기록합니다.

```swift
public final class LoggingPlugin: BasePlugin, RegistrationPlugin, ResolutionPlugin, LifecyclePlugin {

    private let logLevel: LogLevel
    private let logger: Logger

    public init(logLevel: LogLevel = .info, logger: Logger = .default) {
        self.logLevel = logLevel
        self.logger = logger
        super.init(id: "com.dicontainer.logging", priority: .high)
    }

    // 등록 시 로깅
    public func beforeRegistration<T>(_ type: T.Type, factory: @escaping () -> T) {
        logger.log("📝 Registering \(String(describing: type))", level: logLevel)
    }

    public func afterRegistration<T>(_ type: T.Type, instance: T) {
        logger.log("✅ Registered \(String(describing: type))", level: logLevel)
    }

    // 해결 시 로깅
    public func beforeResolution<T>(_ type: T.Type) -> T? {
        logger.log("🔍 Resolving \(String(describing: type))", level: logLevel)
        return nil // 실제 해결은 컨테이너가 수행
    }

    public func afterResolution<T>(_ type: T.Type, instance: T) -> T {
        logger.log("✨ Resolved \(String(describing: type))", level: logLevel)
        return instance
    }

    // 생명주기 로깅
    public func onContainerCreated(_ container: DependencyContainer) {
        logger.log("🚀 DI Container created", level: .info)
    }
}

// 사용법
DI.addPlugin(LoggingPlugin(logLevel: .debug))
```

### 2. 성능 모니터링 플러그인

DI 성능 메트릭스를 추적합니다.

```swift
public final class PerformanceMonitoringPlugin: BasePlugin, ResolutionPlugin, MonitoringPlugin {

    private var resolutionTimes: [String: [TimeInterval]] = [:]
    private var resolutionCounts: [String: Int] = [:]
    private let queue = DispatchQueue(label: "performance-monitoring", attributes: .concurrent)

    public override init() {
        super.init(id: "com.dicontainer.performance", priority: .normal)
    }

    public func beforeResolution<T>(_ type: T.Type) -> T? {
        let typeName = String(describing: type)
        markResolutionStart(for: typeName)
        return nil
    }

    public func afterResolution<T>(_ type: T.Type, instance: T) -> T {
        let typeName = String(describing: type)
        markResolutionEnd(for: typeName)
        return instance
    }

    private func markResolutionStart(for typeName: String) {
        queue.async(flags: .barrier) {
            self.resolutionStartTimes[typeName] = CFAbsoluteTimeGetCurrent()
        }
    }

    private func markResolutionEnd(for typeName: String) {
        let endTime = CFAbsoluteTimeGetCurrent()

        queue.async(flags: .barrier) {
            guard let startTime = self.resolutionStartTimes[typeName] else { return }

            let duration = endTime - startTime
            self.resolutionTimes[typeName, default: []].append(duration)
            self.resolutionCounts[typeName, default: 0] += 1

            self.resolutionStartTimes.removeValue(forKey: typeName)
        }
    }

    // 성능 리포트 생성
    public func generateReport() -> PerformanceReport {
        return queue.sync {
            var metrics: [String: PerformanceMetric] = [:]

            for (typeName, times) in resolutionTimes {
                let avgTime = times.reduce(0, +) / Double(times.count)
                let maxTime = times.max() ?? 0
                let minTime = times.min() ?? 0
                let count = resolutionCounts[typeName] ?? 0

                metrics[typeName] = PerformanceMetric(
                    averageTime: avgTime,
                    maxTime: maxTime,
                    minTime: minTime,
                    totalResolutions: count
                )
            }

            return PerformanceReport(metrics: metrics)
        }
    }
}

// 사용법
let performancePlugin = PerformanceMonitoringPlugin()
DI.addPlugin(performancePlugin)

// 리포트 확인
let report = performancePlugin.generateReport()
print("평균 해결 시간: \(report.averageResolutionTime)ms")
```

### 3. 검증 플러그인

의존성 등록/해결을 검증합니다.

```swift
public final class DependencyValidationPlugin: BasePlugin, ValidationPlugin {

    private let rules: [ValidationRule]

    public init(rules: [ValidationRule]) {
        self.rules = rules
        super.init(id: "com.dicontainer.validation", priority: .highest)
    }

    public func validateRegistration<T>(_ type: T.Type, factory: @escaping () -> T) throws {
        for rule in rules {
            try rule.validateRegistration(type, factory: factory)
        }
    }

    public func validateResolution<T>(_ type: T.Type, instance: T?) throws {
        for rule in rules {
            try rule.validateResolution(type, instance: instance)
        }
    }
}

// 검증 규칙 예시
public struct DuplicateRegistrationRule: ValidationRule {
    public func validateRegistration<T>(_ type: T.Type, factory: @escaping () -> T) throws {
        // 중복 등록 방지 검증 로직
        if hasExistingRegistration(type) {
            throw ValidationError.duplicateRegistration(String(describing: type))
        }
    }
}

// 사용법
let validationPlugin = DependencyValidationPlugin(rules: [
    DuplicateRegistrationRule(),
    CircularDependencyRule(),
    ThreadSafetyRule()
])
DI.addPlugin(validationPlugin)
```

## 커스텀 플러그인 개발

### 기본 플러그인 생성

```swift
// 간단한 디버깅 플러그인
public final class DebugPlugin: BasePlugin, ResolutionPlugin {

    private var resolutionCount = 0

    public override init() {
        super.init(id: "com.myapp.debug", priority: .low)
    }

    public func afterResolution<T>(_ type: T.Type, instance: T) -> T {
        resolutionCount += 1

        #if DEBUG
        print("🐛 [Debug] Resolved \(String(describing: type)) (총 \(resolutionCount)회 해결)")

        // 메모리 사용량 체크
        if resolutionCount % 10 == 0 {
            let memoryUsage = getMemoryUsage()
            print("🐛 [Debug] 현재 메모리 사용량: \(memoryUsage)MB")
        }
        #endif

        return instance
    }

    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Int(info.resident_size) / 1024 / 1024
        }
        return 0
    }
}
```

### 고급 플러그인 - 자동 탐지

```swift
// 자동으로 특정 패키지의 타입을 탐지하고 등록하는 플러그인
public final class AutoDiscoveryPlugin: BasePlugin, RegistrationPlugin {

    private let packagePrefixes: [String]
    private let discoveryQueue = DispatchQueue(label: "auto-discovery", qos: .background)

    public init(packagePrefixes: [String]) {
        self.packagePrefixes = packagePrefixes
        super.init(id: "com.dicontainer.autodiscovery", priority: .high)
    }

    public override func didLoad() async {
        await discoverAndRegisterTypes()
    }

    private func discoverAndRegisterTypes() async {
        return await withTaskGroup(of: Void.self) { group in
            for prefix in packagePrefixes {
                group.addTask {
                    await self.discoverTypes(withPrefix: prefix)
                }
            }
        }
    }

    private func discoverTypes(withPrefix prefix: String) async {
        // 런타임 타입 탐지 (실제 구현은 더 복잡함)
        let discoveredTypes = await scanTypesWithPrefix(prefix)

        for type in discoveredTypes {
            if conformsToAutoRegistrable(type) {
                await registerDiscoveredType(type)
            }
        }
    }

    public func beforeRegistration<T>(_ type: T.Type, factory: @escaping () -> T) {
        let typeName = String(describing: type)
        print("🔍 [AutoDiscovery] Auto-registering \(typeName)")
    }
}

// 자동 등록 가능한 타입을 위한 프로토콜
public protocol AutoRegistrable {
    static func createInstance() -> Self
}

// 사용법
DI.addPlugin(AutoDiscoveryPlugin(packagePrefixes: [
    "com.myapp.services",
    "com.myapp.repositories"
]))
```

### 설정 기반 플러그인

```swift
// 설정 파일을 기반으로 의존성을 관리하는 플러그인
public final class ConfigurationPlugin: BasePlugin, RegistrationPlugin, LifecyclePlugin {

    private let configurationPath: String
    private var configuration: DIConfiguration?

    public init(configurationPath: String) {
        self.configurationPath = configurationPath
        super.init(id: "com.dicontainer.configuration", priority: .highest)
    }

    public override func willLoad() async {
        do {
            configuration = try await loadConfiguration()
            await registerConfiguredDependencies()
        } catch {
            print("❌ [Configuration] 설정 로드 실패: \(error)")
        }
    }

    private func loadConfiguration() async throws -> DIConfiguration {
        let data = try Data(contentsOf: URL(fileURLWithPath: configurationPath))
        return try JSONDecoder().decode(DIConfiguration.self, from: data)
    }

    private func registerConfiguredDependencies() async {
        guard let config = configuration else { return }

        for dependency in config.dependencies {
            await registerDependency(dependency)
        }
    }

    private func registerDependency(_ dependency: DIConfiguration.Dependency) async {
        // 설정 기반 등록 로직
        switch dependency.scope {
        case .instance:
            // 인스턴스로 등록
            break
        case .transient:
            // 매번 새로운 인스턴스로 등록
            break
        case .scoped:
            // 스코프 기반으로 등록
            break
        }
    }
}

// 설정 모델
struct DIConfiguration: Codable {
    let dependencies: [Dependency]

    struct Dependency: Codable {
        let type: String
        let implementation: String
        let scope: Scope

        enum Scope: String, Codable {
            case instance
            case transient
            case scoped
        }
    }
}
```

## 플러그인 관리

### 플러그인 등록 및 제거

```swift
// 플러그인 추가
let loggingPlugin = LoggingPlugin(logLevel: .debug)
DI.addPlugin(loggingPlugin)

// 여러 플러그인 동시 추가
DI.addPlugins([
    LoggingPlugin(),
    PerformanceMonitoringPlugin(),
    ValidationPlugin()
])

// 플러그인 제거
DI.removePlugin(withId: "com.dicontainer.logging")

// 모든 플러그인 제거
DI.removeAllPlugins()

// 플러그인 조회
let activePlugins = DI.getActivePlugins()
print("활성 플러그인: \(activePlugins.map { $0.id })")
```

### 플러그인 생명주기 관리

```swift
// 플러그인 시스템 초기화
await DI.initializePluginSystem()

// 플러그인 순서대로 로드
await DI.loadPlugins()

// 플러그인 시스템 종료
await DI.shutdownPluginSystem()
```

## 플러그인 조합 패턴

### 1. 개발/프로덕션 환경별 플러그인

```swift
class EnvironmentPluginManager {
    static func configurePlugins() {
        #if DEBUG
        DI.addPlugins([
            LoggingPlugin(logLevel: .debug),
            PerformanceMonitoringPlugin(),
            DebugPlugin(),
            ValidationPlugin(rules: [CircularDependencyRule()])
        ])
        #elseif RELEASE
        DI.addPlugins([
            LoggingPlugin(logLevel: .error),
            CrashReportingPlugin(),
            ProductionMonitoringPlugin()
        ])
        #endif
    }
}
```

### 2. 기능별 플러그인 세트

```swift
// 보안 관련 플러그인 세트
struct SecurityPluginSet {
    static var plugins: [Plugin] {
        return [
            AccessControlPlugin(),
            AuditLoggingPlugin(),
            SecurityValidationPlugin()
        ]
    }
}

// 성능 관련 플러그인 세트
struct PerformancePluginSet {
    static var plugins: [Plugin] {
        return [
            PerformanceMonitoringPlugin(),
            CachingPlugin(),
            ProfilerPlugin()
        ]
    }
}

// 사용
DI.addPlugins(SecurityPluginSet.plugins)
DI.addPlugins(PerformancePluginSet.plugins)
```

## 플러그인 테스팅

### 플러그인 단위 테스트

```swift
class LoggingPluginTests: XCTestCase {

    var plugin: LoggingPlugin!
    var mockLogger: MockLogger!

    override func setUp() {
        mockLogger = MockLogger()
        plugin = LoggingPlugin(logger: mockLogger)
    }

    func testRegistrationLogging() {
        // Given
        let expectation = XCTestExpectation(description: "로깅 호출됨")

        mockLogger.onLog = { message, level in
            XCTAssertTrue(message.contains("UserService"))
            expectation.fulfill()
        }

        // When
        plugin.beforeRegistration(UserService.self) { UserService() }

        // Then
        wait(for: [expectation], timeout: 1.0)
    }
}
```

### 통합 테스트

```swift
class PluginIntegrationTests: XCTestCase {

    func testMultiplePluginsWork() async {
        // Given
        let loggingPlugin = LoggingPlugin()
        let performancePlugin = PerformanceMonitoringPlugin()

        DI.addPlugins([loggingPlugin, performancePlugin])

        // When
        DI.register(UserService.self) { UserService() }
        let service: UserService = DI.resolve()

        // Then
        let report = performancePlugin.generateReport()
        XCTAssertTrue(report.metrics.contains("UserService"))
    }
}
```

## 모범 사례

### 1. 플러그인 설계 원칙

```swift
// ✅ 좋은 예: 단일 책임 원칙
class LoggingOnlyPlugin: BasePlugin, ResolutionPlugin {
    // 로깅만 담당
}

class PerformanceOnlyPlugin: BasePlugin, ResolutionPlugin {
    // 성능 모니터링만 담당
}

// ❌ 나쁜 예: 여러 책임
class EverythingPlugin: BasePlugin, ResolutionPlugin {
    // 로깅도 하고, 성능도 측정하고, 검증도 하고...
}
```

### 2. 성능 고려사항

```swift
class OptimizedPlugin: BasePlugin, ResolutionPlugin {
    private let isEnabled: Bool = UserDefaults.standard.bool(forKey: "plugin.enabled")

    public func afterResolution<T>(_ type: T.Type, instance: T) -> T {
        // 성능을 위한 빠른 조건 검사
        guard isEnabled else { return instance }

        // 실제 플러그인 로직
        performPluginLogic(for: type, instance: instance)
        return instance
    }

    private func performPluginLogic<T>(for type: T.Type, instance: T) {
        // 비용이 큰 작업은 백그라운드에서
        Task.detached(priority: .background) {
            // 무거운 로직
        }
    }
}
```

### 3. 오류 처리

```swift
class RobustPlugin: BasePlugin, ResolutionPlugin {
    public func afterResolution<T>(_ type: T.Type, instance: T) -> T {
        do {
            // 플러그인 로직 실행
            return try processInstance(instance)
        } catch {
            // 플러그인 오류가 DI 과정을 방해하지 않도록
            print("⚠️ Plugin error: \(error)")
            return instance // 원본 인스턴스 반환
        }
    }
}
```

DiContainer의 플러그인 시스템을 통해 의존성 주입 과정을 완전히 커스터마이징하고, 애플리케이션의 요구사항에 맞는 강력한 DI 솔루션을 구축할 수 있습니다.