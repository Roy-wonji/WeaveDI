# Bootstrap API 참조

Bootstrap API는 WeaveDI 컨테이너를 초기화하고 의존성을 구성하는 핵심 메커니즘입니다. 애플리케이션 시작 시 모든 의존성을 등록하고 컨테이너를 준비 상태로 만듭니다.

## 개요

Bootstrap은 의존성 주입 컨테이너를 설정하는 중앙화된 방법을 제공합니다. 동기 및 비동기 등록 패턴을 모두 지원하며, 복잡한 의존성 그래프와 초기화 순서를 처리할 수 있습니다.

```swift
import WeaveDI

// 기본 bootstrap 설정
await WeaveDI.Container.bootstrap { container in
    container.register(LoggerProtocol.self) { FileLogger() }
    container.register(CounterRepository.self) { UserDefaultsCounterRepository() }
}

// 의존성을 사용할 준비 완료
let logger = WeaveDI.Container.resolve(LoggerProtocol.self)
```

## 핵심 Bootstrap 패턴

### 동기 Bootstrap

간단한 의존성의 경우 동기 방식으로 등록할 수 있습니다:

```swift
WeaveDI.Container.bootstrap { container in
    // 로거 등록
    container.register(LoggerProtocol.self) {
        FileLogger(filename: "app.log")
    }

    // 설정 서비스 등록
    container.register(ConfigurationService.self) {
        AppConfigurationService()
    }

    // 기본 서비스들 등록
    container.register(NetworkService.self) {
        URLSessionNetworkService()
    }
}
```

### 비동기 Bootstrap

데이터베이스나 네트워크 초기화가 필요한 경우 비동기 방식을 사용합니다:

```swift
await WeaveDI.Container.bootstrap { container in
    // 비동기 데이터베이스 초기화
    container.register(DatabaseService.self) {
        let db = CoreDataService()
        await db.initialize()
        return db
    }

    // 비동기 API 클라이언트 초기화
    container.register(APIClient.self) {
        let client = HTTPAPIClient()
        await client.authenticate()
        return client
    }
}
```

## 튜토리얼의 실제 예제

### CountApp Bootstrap 구성

우리 튜토리얼의 CountApp을 기반으로 한 포괄적인 bootstrap 설정입니다:

```swift
/// CountApp의 완전한 의존성 bootstrap 구성
class CountAppBootstrap {
    static func configure() async {
        print("🚀 CountApp 의존성 초기화 시작...")

        await WeaveDI.Container.bootstrap { container in
            // 1. 핵심 인프라 서비스
            container.register(LoggerProtocol.self) {
                FileLogger(
                    filename: "counter_app.log",
                    logLevel: .info
                )
            }

            // 2. 데이터 계층
            container.register(CounterRepository.self) {
                UserDefaultsCounterRepository()
            }

            // 3. 비즈니스 로직 계층
            container.register(CounterService.self) {
                let logger = container.resolve(LoggerProtocol.self)!
                let repository = container.resolve(CounterRepository.self)!
                return CounterService(logger: logger, repository: repository)
            }

            // 4. 고급 기능 - 히스토리 관리
            container.register(CounterHistoryService.self) {
                let repository = container.resolve(CounterRepository.self)!
                let logger = container.resolve(LoggerProtocol.self)!
                return CounterHistoryService(repository: repository, logger: logger)
            }

            // 5. 알림 서비스
            container.register(NotificationService.self) {
                let logger = container.resolve(LoggerProtocol.self)!
                return LocalNotificationService(logger: logger)
            }

            // 6. 데이터 내보내기 서비스
            container.register(DataExportService.self) {
                let historyService = container.resolve(CounterHistoryService.self)!
                let logger = container.resolve(LoggerProtocol.self)!
                return CSVDataExportService(historyService: historyService, logger: logger)
            }
        }

        print("✅ CountApp 의존성 초기화 완료")

        // 초기화 검증
        await validateBootstrap()
    }

    private static func validateBootstrap() async {
        let requiredServices = [
            (LoggerProtocol.self, "Logger"),
            (CounterRepository.self, "Repository"),
            (CounterService.self, "Counter Service"),
            (CounterHistoryService.self, "History Service"),
            (NotificationService.self, "Notification Service"),
            (DataExportService.self, "Export Service")
        ]

        print("🔍 의존성 검증 중...")

        for (serviceType, serviceName) in requiredServices {
            let isAvailable = WeaveDI.Container.canResolve(serviceType)
            let status = isAvailable ? "✅" : "❌"
            print("\(status) \(serviceName): \(isAvailable ? "사용 가능" : "누락")")
        }
    }
}

/// 향상된 CounterService 구현
class CounterService {
    private let logger: LoggerProtocol
    private let repository: CounterRepository

    init(logger: LoggerProtocol, repository: CounterRepository) {
        self.logger = logger
        self.repository = repository
        self.logger.info("📊 CounterService 초기화됨")
    }

    func getCurrentCount() async -> Int {
        let count = await repository.getCurrentCount()
        logger.debug("📖 현재 카운트 조회: \(count)")
        return count
    }

    func increment() async -> Int {
        let currentCount = await repository.getCurrentCount()
        let newCount = currentCount + 1
        await repository.saveCount(newCount)

        logger.info("⬆️ 카운트 증가: \(currentCount) → \(newCount)")
        return newCount
    }

    func decrement() async -> Int {
        let currentCount = await repository.getCurrentCount()
        let newCount = max(0, currentCount - 1) // 0 이하로 내려가지 않도록
        await repository.saveCount(newCount)

        logger.info("⬇️ 카운트 감소: \(currentCount) → \(newCount)")
        return newCount
    }

    func reset() async {
        await repository.resetCount()
        logger.info("🔄 카운트 리셋됨")
    }
}

/// CountApp 메인 시작점
@main
struct CountApp: App {
    init() {
        Task {
            await CountAppBootstrap.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            CounterView()
                .task {
                    // 의존성이 준비될 때까지 대기
                    await waitForDependencies()
                }
        }
    }

    private func waitForDependencies() async {
        while !WeaveDI.Container.isBootstrapped {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms 대기
        }
    }
}
```

### WeatherApp Bootstrap 구성

```swift
/// WeatherApp의 복잡한 의존성 bootstrap
class WeatherAppBootstrap {
    static func configure() async {
        print("🌤️ WeatherApp 의존성 초기화 시작...")

        await WeaveDI.Container.bootstrap { container in
            // 1. 핵심 로깅 시스템
            container.register(LoggerProtocol.self, name: "main") {
                FileLogger(filename: "weather_app.log")
            }

            container.register(LoggerProtocol.self, name: "network") {
                FileLogger(filename: "network.log")
            }

            // 2. 네트워크 계층
            container.register(HTTPClientProtocol.self) {
                let logger = container.resolve(LoggerProtocol.self, name: "network")!
                return URLSessionHTTPClient(logger: logger)
            }

            // 3. 캐시 시스템
            container.register(CacheServiceProtocol.self) {
                let logger = container.resolve(LoggerProtocol.self, name: "main")!
                return CoreDataCacheService(logger: logger)
            }

            // 4. 날씨 서비스 (의존성 체인)
            container.register(WeatherServiceProtocol.self) {
                let httpClient = container.resolve(HTTPClientProtocol.self)!
                let cache = container.resolve(CacheServiceProtocol.self)!
                let logger = container.resolve(LoggerProtocol.self, name: "main")!
                return WeatherService(
                    httpClient: httpClient,
                    cache: cache,
                    logger: logger
                )
            }

            // 5. 위치 서비스
            container.register(LocationServiceProtocol.self) {
                let logger = container.resolve(LoggerProtocol.self, name: "main")!
                return CoreLocationService(logger: logger)
            }

            // 6. 날씨 데이터 분석 서비스
            container.register(WeatherAnalyticsService.self) {
                let weatherService = container.resolve(WeatherServiceProtocol.self)!
                let logger = container.resolve(LoggerProtocol.self, name: "main")!
                return WeatherAnalyticsService(
                    weatherService: weatherService,
                    logger: logger
                )
            }

            // 7. 알림 서비스
            container.register(WeatherNotificationService.self) {
                let logger = container.resolve(LoggerProtocol.self, name: "main")!
                return WeatherNotificationService(logger: logger)
            }
        }

        print("✅ WeatherApp 의존성 초기화 완료")
        await printDependencyGraph()
    }

    private static func printDependencyGraph() async {
        print("\n📊 WeatherApp 의존성 그래프:")
        print("┌─ LoggerProtocol (main) → FileLogger")
        print("├─ LoggerProtocol (network) → FileLogger")
        print("├─ HTTPClientProtocol → URLSessionHTTPClient")
        print("│   └── depends on: LoggerProtocol (network)")
        print("├─ CacheServiceProtocol → CoreDataCacheService")
        print("│   └── depends on: LoggerProtocol (main)")
        print("├─ WeatherServiceProtocol → WeatherService")
        print("│   ├── depends on: HTTPClientProtocol")
        print("│   ├── depends on: CacheServiceProtocol")
        print("│   └── depends on: LoggerProtocol (main)")
        print("├─ LocationServiceProtocol → CoreLocationService")
        print("│   └── depends on: LoggerProtocol (main)")
        print("├─ WeatherAnalyticsService")
        print("│   ├── depends on: WeatherServiceProtocol")
        print("│   └── depends on: LoggerProtocol (main)")
        print("└─ WeatherNotificationService")
        print("    └── depends on: LoggerProtocol (main)")
    }
}
```

## 고급 Bootstrap 패턴

### 환경별 구성

```swift
enum AppEnvironment {
    case development
    case staging
    case production
}

class EnvironmentBootstrap {
    static func configure(environment: AppEnvironment) async {
        await WeaveDI.Container.bootstrap { container in
            switch environment {
            case .development:
                setupDevelopmentServices(container)
            case .staging:
                setupStagingServices(container)
            case .production:
                setupProductionServices(container)
            }
        }
    }

    private static func setupDevelopmentServices(_ container: WeaveDI.Container) {
        // 개발 환경용 서비스
        container.register(LoggerProtocol.self) {
            ConsoleLogger(logLevel: .debug)
        }

        container.register(DatabaseService.self) {
            InMemoryDatabaseService() // 빠른 테스트용
        }

        container.register(APIClient.self) {
            MockAPIClient() // 모의 API
        }
    }

    private static func setupProductionServices(_ container: WeaveDI.Container) {
        // 프로덕션 환경용 서비스
        container.register(LoggerProtocol.self) {
            FileLogger(logLevel: .error) // 오류만 로깅
        }

        container.register(DatabaseService.self) {
            CoreDataService()
        }

        container.register(APIClient.self) {
            HTTPAPIClient()
        }
    }
}
```

### 모듈화된 Bootstrap

```swift
protocol BootstrapModule {
    func configure(_ container: WeaveDI.Container) async
}

class CoreModule: BootstrapModule {
    func configure(_ container: WeaveDI.Container) async {
        container.register(LoggerProtocol.self) { FileLogger() }
        container.register(ConfigService.self) { AppConfigService() }
    }
}

class NetworkModule: BootstrapModule {
    func configure(_ container: WeaveDI.Container) async {
        container.register(HTTPClient.self) {
            let config = container.resolve(ConfigService.self)!
            return URLSessionHTTPClient(config: config)
        }
    }
}

class ModularBootstrap {
    private let modules: [BootstrapModule]

    init(modules: [BootstrapModule]) {
        self.modules = modules
    }

    func configure() async {
        await WeaveDI.Container.bootstrap { container in
            for module in modules {
                await module.configure(container)
            }
        }
    }
}

// 사용법
let bootstrap = ModularBootstrap(modules: [
    CoreModule(),
    NetworkModule(),
    DatabaseModule(),
    UIModule()
])

await bootstrap.configure()
```

### 조건부 등록

```swift
class ConditionalBootstrap {
    static func configure() async {
        await WeaveDI.Container.bootstrap { container in
            // 기본 서비스들
            container.register(LoggerProtocol.self) { FileLogger() }

            // 플랫폼별 조건부 등록
            #if os(iOS)
            container.register(PlatformService.self) { iOSPlatformService() }
            #elseif os(macOS)
            container.register(PlatformService.self) { macOSPlatformService() }
            #endif

            // 기능 플래그 기반 조건부 등록
            if FeatureFlags.isAnalyticsEnabled {
                container.register(AnalyticsService.self) { FirebaseAnalytics() }
            } else {
                container.register(AnalyticsService.self) { NoOpAnalytics() }
            }

            // 디버그 빌드에서만 등록
            #if DEBUG
            container.register(DebugService.self) { DebugServiceImpl() }
            #endif
        }
    }
}
```

## 오류 처리 및 검증

### Bootstrap 검증

```swift
class BootstrapValidator {
    static func validate() async throws {
        // 필수 의존성 확인
        let requiredDependencies: [Any.Type] = [
            LoggerProtocol.self,
            ConfigService.self,
            NetworkService.self
        ]

        for dependency in requiredDependencies {
            guard WeaveDI.Container.canResolve(dependency) else {
                throw BootstrapError.missingRequiredDependency(dependency)
            }
        }

        // 순환 의존성 검사
        let cycles = WeaveDI.Container.detectCycles()
        if !cycles.isEmpty {
            throw BootstrapError.circularDependency(cycles)
        }
    }
}

enum BootstrapError: Error {
    case missingRequiredDependency(Any.Type)
    case circularDependency([DependencyCycle])
    case initializationFailed(String)
}
```

### 우아한 실패 처리

```swift
class GracefulBootstrap {
    static func configure() async {
        do {
            await WeaveDI.Container.bootstrap { container in
                try await setupPrimaryServices(container)
            }
        } catch {
            print("⚠️ 주 서비스 초기화 실패, 대체 서비스 사용: \(error)")
            await setupFallbackServices()
        }

        try? await BootstrapValidator.validate()
    }

    private static func setupPrimaryServices(_ container: WeaveDI.Container) async throws {
        // 데이터베이스 연결 등 실패할 수 있는 서비스들
        container.register(DatabaseService.self) {
            let db = CoreDataService()
            try await db.connect()
            return db
        }
    }

    private static func setupFallbackServices() async {
        await WeaveDI.Container.bootstrap { container in
            // 인메모리 대체 서비스들
            container.register(DatabaseService.self) {
                InMemoryDatabaseService()
            }
        }
    }
}
```

## 성능 최적화

### 지연 초기화

```swift
class LazyBootstrap {
    static func configure() async {
        await WeaveDI.Container.bootstrap { container in
            // 즉시 필요한 서비스들
            container.register(LoggerProtocol.self) { FileLogger() }
            container.register(ConfigService.self) { AppConfigService() }

            // 지연 초기화가 필요한 무거운 서비스들
            container.register(DatabaseService.self) {
                // 실제 사용될 때까지 초기화 지연
                LazyDatabaseService()
            }

            container.register(MLModelService.self) {
                // 머신러닝 모델은 매우 무거우므로 지연 로딩
                LazyMLModelService()
            }
        }
    }
}

class LazyDatabaseService: DatabaseService {
    private var actualService: DatabaseService?

    func getData() async -> Data {
        if actualService == nil {
            actualService = CoreDataService()
            await actualService?.initialize()
        }
        return await actualService?.getData() ?? Data()
    }
}
```

### 병렬 초기화

```swift
class ParallelBootstrap {
    static func configure() async {
        await WeaveDI.Container.bootstrap { container in
            // 독립적인 서비스들을 병렬로 초기화
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    container.register(LoggerProtocol.self) { FileLogger() }
                }

                group.addTask {
                    container.register(ConfigService.self) { AppConfigService() }
                }

                group.addTask {
                    container.register(CacheService.self) { RedisCacheService() }
                }
            }

            // 의존성이 있는 서비스들은 순차적으로
            container.register(DatabaseService.self) {
                let config = container.resolve(ConfigService.self)!
                return CoreDataService(config: config)
            }
        }
    }
}
```

## 테스팅과 Bootstrap

### 테스트용 Bootstrap

```swift
class TestBootstrap {
    static func configure() async {
        await WeaveDI.Container.bootstrap { container in
            // 테스트용 모의 서비스들
            container.register(LoggerProtocol.self) { TestLogger() }
            container.register(DatabaseService.self) { MockDatabaseService() }
            container.register(NetworkService.self) { MockNetworkService() }

            // 실제 비즈니스 로직은 유지
            container.register(CounterService.self) {
                let logger = container.resolve(LoggerProtocol.self)!
                let repository = MockCounterRepository()
                return CounterService(logger: logger, repository: repository)
            }
        }
    }
}

class BootstrapTests: XCTestCase {
    override func setUp() async throws {
        await WeaveDI.Container.resetForTesting()
        await TestBootstrap.configure()
    }

    func testBootstrapConfiguration() async throws {
        // Bootstrap이 올바르게 구성되었는지 확인
        XCTAssertTrue(WeaveDI.Container.isBootstrapped)

        // 필수 의존성들이 등록되었는지 확인
        XCTAssertNotNil(WeaveDI.Container.resolve(LoggerProtocol.self))
        XCTAssertNotNil(WeaveDI.Container.resolve(DatabaseService.self))
        XCTAssertNotNil(WeaveDI.Container.resolve(CounterService.self))
    }
}
```

## 모범 사례

### 1. 계층적 등록

```swift
// ✅ 좋음 - 하위 레벨부터 상위 레벨 순으로
await WeaveDI.Container.bootstrap { container in
    // 1. 인프라 계층
    container.register(LoggerProtocol.self) { FileLogger() }
    container.register(ConfigService.self) { AppConfigService() }

    // 2. 데이터 계층
    container.register(DatabaseService.self) { CoreDataService() }
    container.register(NetworkService.self) { URLSessionNetworkService() }

    // 3. 비즈니스 계층
    container.register(UserService.self) {
        let db = container.resolve(DatabaseService.self)!
        let logger = container.resolve(LoggerProtocol.self)!
        return UserService(database: db, logger: logger)
    }
}
```

### 2. 명확한 의존성 표현

```swift
// ✅ 좋음 - 의존성이 명확함
container.register(WeatherService.self) {
    let httpClient = container.resolve(HTTPClientProtocol.self)!
    let cache = container.resolve(CacheServiceProtocol.self)!
    let logger = container.resolve(LoggerProtocol.self)!

    return WeatherService(
        httpClient: httpClient,
        cache: cache,
        logger: logger
    )
}
```

### 3. 오류 처리

```swift
// ✅ 좋음 - 오류 상황 고려
container.register(DatabaseService.self) {
    do {
        let service = CoreDataService()
        await service.initialize()
        return service
    } catch {
        print("⚠️ 데이터베이스 초기화 실패, 인메모리 서비스 사용")
        return InMemoryDatabaseService()
    }
}
```

## 참고 자료

- [UnifiedDI API](./unifiedDI.md) - 간소화된 DI 인터페이스
- [DIActor API](./diActor.md) - 스레드 안전 의존성 연산
- [성능 모니터링 API](./performanceMonitoring.md) - Bootstrap 성능 모니터링