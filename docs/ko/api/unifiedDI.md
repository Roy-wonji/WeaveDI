# UnifiedDI API 참조

UnifiedDI는 WeaveDI의 간소화된 의존성 주입 인터페이스로, 복잡한 컨테이너 관리 없이 깔끔하고 직관적인 API를 제공합니다. 일반적인 사용 사례에 최적화되어 있으며 시작하기 쉽게 설계되었습니다.

## 개요

UnifiedDI는 WeaveDI.Container의 강력함을 유지하면서 더 간단한 API를 제공합니다. 자동 타입 추론, 스마트 해결, 그리고 미니멀한 구성을 특징으로 합니다.

```swift
import WeaveDI

// 간단한 등록
UnifiedDI.register { FileLogger() as LoggerProtocol }
UnifiedDI.register { UserService() }

// 간단한 해결
let logger: LoggerProtocol = UnifiedDI.resolve()
let userService: UserService = UnifiedDI.resolve()
```

## 핵심 작업

### 의존성 등록

#### 타입 추론 등록

가장 간단한 등록 방법:

```swift
// 타입이 자동으로 추론됨
UnifiedDI.register { FileLogger() as LoggerProtocol }
UnifiedDI.register { UserService() }
UnifiedDI.register { DatabaseRepository() as Repository }
```

#### 명시적 타입 등록

명확성이 필요할 때:

```swift
UnifiedDI.register(LoggerProtocol.self) { FileLogger() }
UnifiedDI.register(UserService.self) { UserService() }
UnifiedDI.register(Repository.self) { DatabaseRepository() }
```

#### 이름이 있는 등록

같은 타입의 여러 구현:

```swift
UnifiedDI.register(name: "file") { FileLogger() as LoggerProtocol }
UnifiedDI.register(name: "console") { ConsoleLogger() as LoggerProtocol }
UnifiedDI.register(name: "network") { NetworkLogger() as LoggerProtocol }
```

### 의존성 해결

#### 타입 추론 해결

타입이 컨텍스트에서 추론됨:

```swift
let logger: LoggerProtocol = UnifiedDI.resolve()
let userService: UserService = UnifiedDI.resolve()

// 또는 변수 선언과 함께
var logger = UnifiedDI.resolve() as LoggerProtocol
```

#### 이름이 있는 해결

```swift
let fileLogger: LoggerProtocol = UnifiedDI.resolve(name: "file")
let consoleLogger: LoggerProtocol = UnifiedDI.resolve(name: "console")
```

#### 옵셔널 해결

실패할 수 있는 해결:

```swift
let optionalLogger: LoggerProtocol? = UnifiedDI.tryResolve()

if let logger = optionalLogger {
    logger.info("로거를 찾았습니다")
} else {
    print("로거를 찾을 수 없습니다")
}
```

## 튜토리얼의 실제 예제

### CountApp UnifiedDI 설정

우리 튜토리얼의 CountApp을 UnifiedDI로 간소화한 버전입니다:

```swift
/// UnifiedDI를 사용한 CountApp 설정
class CountAppUnifiedSetup {
    static func configure() {
        print("🚀 CountApp UnifiedDI 구성 시작...")

        // 1. 로깅 시스템
        UnifiedDI.register(name: "main") {
            FileLogger(
                filename: "counter_app.log",
                logLevel: .info
            ) as LoggerProtocol
        }

        UnifiedDI.register(name: "debug") {
            ConsoleLogger(logLevel: .debug) as LoggerProtocol
        }

        // 2. 데이터 계층
        UnifiedDI.register {
            UserDefaultsCounterRepository() as CounterRepository
        }

        // 3. 비즈니스 서비스 (의존성 자동 해결)
        UnifiedDI.register {
            let logger: LoggerProtocol = UnifiedDI.resolve(name: "main")
            let repository: CounterRepository = UnifiedDI.resolve()
            return CounterService(logger: logger, repository: repository)
        }

        // 4. 고급 기능들
        UnifiedDI.register {
            let repository: CounterRepository = UnifiedDI.resolve()
            let logger: LoggerProtocol = UnifiedDI.resolve(name: "main")
            return CounterHistoryService(repository: repository, logger: logger)
        }

        UnifiedDI.register {
            let logger: LoggerProtocol = UnifiedDI.resolve(name: "main")
            return NotificationService(logger: logger)
        }

        print("✅ CountApp UnifiedDI 구성 완료")
        printRegisteredServices()
    }

    private static func printRegisteredServices() {
        print("📋 등록된 서비스들:")
        print("  - LoggerProtocol (main)")
        print("  - LoggerProtocol (debug)")
        print("  - CounterRepository")
        print("  - CounterService")
        print("  - CounterHistoryService")
        print("  - NotificationService")
    }
}

/// UnifiedDI를 사용하는 간소화된 ViewModel
@MainActor
class UnifiedCounterViewModel: ObservableObject {
    @Published var count = 0
    @Published var isLoading = false
    @Published var history: [CounterHistoryItem] = []

    // UnifiedDI에서 직접 해결
    private let counterService: CounterService
    private let historyService: CounterHistoryService
    private let logger: LoggerProtocol

    init() {
        // 의존성 해결 (타입 추론)
        self.counterService = UnifiedDI.resolve()
        self.historyService = UnifiedDI.resolve()
        self.logger = UnifiedDI.resolve(name: "main")

        logger.info("📱 UnifiedCounterViewModel 초기화됨")

        Task {
            await loadInitialData()
        }
    }

    func increment() async {
        isLoading = true
        logger.debug("⬆️ 증가 작업 시작")

        count = await counterService.increment()
        history = await historyService.getRecentHistory()

        logger.info("📊 카운트 증가 완료: \(count)")
        isLoading = false
    }

    func decrement() async {
        isLoading = true
        logger.debug("⬇️ 감소 작업 시작")

        count = await counterService.decrement()
        history = await historyService.getRecentHistory()

        logger.info("📊 카운트 감소 완료: \(count)")
        isLoading = false
    }

    func reset() async {
        isLoading = true
        logger.debug("🔄 리셋 작업 시작")

        await counterService.reset()
        count = 0
        history = await historyService.getRecentHistory()

        logger.info("📊 카운트 리셋 완료")
        isLoading = false
    }

    private func loadInitialData() async {
        isLoading = true
        count = await counterService.getCurrentCount()
        history = await historyService.getRecentHistory()
        logger.info("📥 초기 데이터 로드 완료")
        isLoading = false
    }
}
```

### WeatherApp UnifiedDI 설정

```swift
/// UnifiedDI를 사용한 WeatherApp 구성
class WeatherAppUnifiedSetup {
    static func configure() {
        print("🌤️ WeatherApp UnifiedDI 구성 시작...")

        // 1. 로깅 시스템
        UnifiedDI.register(name: "main") {
            FileLogger(filename: "weather.log") as LoggerProtocol
        }

        UnifiedDI.register(name: "network") {
            FileLogger(filename: "network.log") as LoggerProtocol
        }

        // 2. 네트워크 계층
        UnifiedDI.register {
            let logger: LoggerProtocol = UnifiedDI.resolve(name: "network")
            return URLSessionHTTPClient(logger: logger) as HTTPClientProtocol
        }

        // 3. 캐시 계층
        UnifiedDI.register {
            CoreDataCacheService() as CacheServiceProtocol
        }

        // 4. 날씨 서비스 (복잡한 의존성 체인)
        UnifiedDI.register {
            let httpClient: HTTPClientProtocol = UnifiedDI.resolve()
            let cache: CacheServiceProtocol = UnifiedDI.resolve()
            let logger: LoggerProtocol = UnifiedDI.resolve(name: "main")

            return WeatherService(
                httpClient: httpClient,
                cache: cache,
                logger: logger
            ) as WeatherServiceProtocol
        }

        // 5. 위치 서비스
        UnifiedDI.register {
            let logger: LoggerProtocol = UnifiedDI.resolve(name: "main")
            return CoreLocationService(logger: logger) as LocationServiceProtocol
        }

        // 6. 고급 서비스들
        UnifiedDI.register {
            let weatherService: WeatherServiceProtocol = UnifiedDI.resolve()
            let logger: LoggerProtocol = UnifiedDI.resolve(name: "main")
            return WeatherAnalyticsService(
                weatherService: weatherService,
                logger: logger
            )
        }

        print("✅ WeatherApp UnifiedDI 구성 완료")
    }
}

/// UnifiedDI를 사용하는 WeatherViewModel
@MainActor
class UnifiedWeatherViewModel: ObservableObject {
    @Published var currentWeather: Weather?
    @Published var forecast: [WeatherForecast] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let weatherService: WeatherServiceProtocol
    private let locationService: LocationServiceProtocol
    private let analyticsService: WeatherAnalyticsService
    private let logger: LoggerProtocol

    init() {
        // UnifiedDI에서 의존성 해결
        self.weatherService = UnifiedDI.resolve()
        self.locationService = UnifiedDI.resolve()
        self.analyticsService = UnifiedDI.resolve()
        self.logger = UnifiedDI.resolve(name: "main")

        logger.info("🌤️ UnifiedWeatherViewModel 초기화됨")
    }

    func loadWeatherForCurrentLocation() async {
        isLoading = true
        errorMessage = nil

        do {
            let location = try await locationService.getCurrentLocation()
            await loadWeather(for: location.cityName)
        } catch {
            logger.error("위치 가져오기 실패: \(error)")
            errorMessage = "위치를 가져올 수 없습니다"
        }

        isLoading = false
    }

    func loadWeather(for city: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 현재 날씨와 예보를 병렬로 로드
            async let currentWeatherTask = weatherService.fetchCurrentWeather(for: city)
            async let forecastTask = weatherService.fetchForecast(for: city)

            currentWeather = try await currentWeatherTask
            forecast = try await forecastTask

            // 분석 데이터 전송
            await analyticsService.trackWeatherRequest(city: city)

            logger.info("🌈 \(city) 날씨 데이터 로드 완료")
        } catch {
            logger.error("날씨 로드 실패: \(error)")
            errorMessage = "날씨 데이터를 가져올 수 없습니다"
        }

        isLoading = false
    }
}
```

## 고급 UnifiedDI 패턴

### 조건부 등록

```swift
class ConditionalUnifiedSetup {
    static func configure(environment: AppEnvironment) {
        // 환경에 따른 로거 등록
        switch environment {
        case .development:
            UnifiedDI.register { ConsoleLogger() as LoggerProtocol }
        case .production:
            UnifiedDI.register { FileLogger() as LoggerProtocol }
        case .testing:
            UnifiedDI.register { TestLogger() as LoggerProtocol }
        }

        // 플랫폼별 서비스
        #if os(iOS)
        UnifiedDI.register { iOSNotificationService() as NotificationService }
        #elseif os(macOS)
        UnifiedDI.register { macOSNotificationService() as NotificationService }
        #endif

        // 기능 플래그 기반 등록
        if FeatureFlags.isAnalyticsEnabled {
            UnifiedDI.register { FirebaseAnalytics() as AnalyticsService }
        } else {
            UnifiedDI.register { NoOpAnalytics() as AnalyticsService }
        }
    }
}
```

### 지연 등록

```swift
class LazyUnifiedRegistration {
    static func registerCoreServices() {
        // 즉시 필요한 서비스
        UnifiedDI.register { ConsoleLogger() as LoggerProtocol }

        // 지연 등록 - 실제 사용될 때 생성
        UnifiedDI.registerLazy {
            // 무거운 ML 모델은 필요할 때만
            MLModelService()
        }

        UnifiedDI.registerLazy {
            // 데이터베이스 연결도 지연
            let logger: LoggerProtocol = UnifiedDI.resolve()
            return DatabaseService(logger: logger)
        }
    }
}
```

### 범위 지정 등록

```swift
class ScopedUnifiedRegistration {
    static func configureScopedServices() {
        // 싱글톤 (기본)
        UnifiedDI.register { AppConfigService() }

        // 일시적 (매번 새로운 인스턴스)
        UnifiedDI.registerTransient { TaskProcessor() }

        // 세션 범위
        UnifiedDI.registerScoped(.session) { UserSession() }

        // 요청 범위
        UnifiedDI.registerScoped(.request) { RequestContext() }
    }
}
```

## UnifiedDI와 Property Wrapper 통합

### 사용자 정의 Property Wrapper

```swift
@propertyWrapper
struct UnifiedInject<T> {
    private var value: T?

    var wrappedValue: T {
        if let value = value {
            return value
        }
        let resolved: T = UnifiedDI.resolve()
        self.value = resolved
        return resolved
    }

    init() {}

    init(name: String) {
        let resolved: T = UnifiedDI.resolve(name: name)
        self.value = resolved
    }
}

// 사용법
class ServiceWithUnifiedInject {
    @UnifiedInject var logger: LoggerProtocol
    @UnifiedInject var userService: UserService

    func performAction() {
        logger.info("액션 수행 중...")
        userService.doSomething()
    }
}
```

### 옵셔널 Wrapper

```swift
@propertyWrapper
struct UnifiedInjectOptional<T> {
    private var value: T??

    var wrappedValue: T? {
        if let value = value {
            return value
        }
        let resolved: T? = UnifiedDI.tryResolve()
        self.value = resolved
        return resolved
    }

    init() {}
}

class OptionalServiceUser {
    @UnifiedInjectOptional var optionalService: OptionalService?

    func doWork() {
        optionalService?.performOptionalTask()
    }
}
```

## 오류 처리 및 검증

### 등록 검증

```swift
class UnifiedDIValidator {
    static func validateRegistrations() throws {
        let requiredTypes: [Any.Type] = [
            LoggerProtocol.self,
            UserService.self,
            DatabaseService.self
        ]

        for type in requiredTypes {
            guard UnifiedDI.canResolve(type) else {
                throw UnifiedDIError.missingRegistration(type)
            }
        }
    }

    static func printRegistrationStatus() {
        let allTypes = UnifiedDI.getRegisteredTypes()
        print("📋 등록된 타입들 (\(allTypes.count)개):")
        for type in allTypes {
            print("  ✅ \(type)")
        }
    }
}

enum UnifiedDIError: Error {
    case missingRegistration(Any.Type)
    case circularDependency([Any.Type])
    case resolutionFailed(Any.Type, Error)
}
```

### 자동 와이어링

```swift
extension UnifiedDI {
    /// 타입의 생성자를 분석하여 자동으로 의존성 연결
    static func autoRegister<T>(_ type: T.Type) {
        register {
            // 리플렉션을 사용하여 생성자 분석
            let dependencies = analyzeDependencies(for: type)
            return createInstance(of: type, with: dependencies)
        }
    }

    private static func analyzeDependencies<T>(for type: T.Type) -> [Any] {
        // 실제 구현에서는 Mirror나 컴파일 타임 분석 사용
        return []
    }

    private static func createInstance<T>(of type: T.Type, with dependencies: [Any]) -> T {
        // 의존성을 사용하여 인스턴스 생성
        fatalError("구현 필요")
    }
}
```

## 성능 최적화

### 배치 등록

```swift
extension UnifiedDI {
    static func registerBatch(_ registrations: () -> Void) {
        // 배치 등록을 위한 최적화된 모드
        beginBatchRegistration()
        registrations()
        endBatchRegistration()
    }

    private static func beginBatchRegistration() {
        // 등록 중 검증 지연
    }

    private static func endBatchRegistration() {
        // 배치 완료 후 검증 실행
    }
}

// 사용법
UnifiedDI.registerBatch {
    UnifiedDI.register { ServiceA() }
    UnifiedDI.register { ServiceB() }
    UnifiedDI.register { ServiceC() }
    // ... 많은 등록들
}
```

### 미리 컴파일된 해결

```swift
extension UnifiedDI {
    /// 자주 사용되는 타입들을 미리 해결하여 캐시
    static func precompileResolutions() {
        let commonTypes: [Any.Type] = [
            LoggerProtocol.self,
            UserService.self,
            DatabaseService.self
        ]

        for type in commonTypes {
            _ = resolve(type) // 미리 해결하여 캐시
        }
    }
}
```

## 테스팅과 UnifiedDI

### 테스트 설정

```swift
class UnifiedDITestSetup {
    static func configureForTesting() {
        UnifiedDI.reset() // 기존 등록 클리어

        // 테스트용 모의 서비스들
        UnifiedDI.register { TestLogger() as LoggerProtocol }
        UnifiedDI.register { MockUserService() as UserService }
        UnifiedDI.register { InMemoryDatabase() as DatabaseService }
    }

    static func registerTestDoubles() {
        UnifiedDI.register(name: "test") { MockNetworkService() as NetworkService }
        UnifiedDI.register(name: "test") { MockAnalytics() as AnalyticsService }
    }
}

class UnifiedDITests: XCTestCase {
    override func setUp() {
        UnifiedDITestSetup.configureForTesting()
    }

    func testServiceResolution() {
        let logger: LoggerProtocol = UnifiedDI.resolve()
        XCTAssertTrue(logger is TestLogger)

        let userService: UserService = UnifiedDI.resolve()
        XCTAssertTrue(userService is MockUserService)
    }

    func testNamedResolution() {
        UnifiedDITestSetup.registerTestDoubles()

        let testNetwork: NetworkService = UnifiedDI.resolve(name: "test")
        XCTAssertTrue(testNetwork is MockNetworkService)
    }
}
```

## 모범 사례

### 1. 명확한 타입 등록

```swift
// ✅ 좋음 - 프로토콜로 명시적 등록
UnifiedDI.register { FileLogger() as LoggerProtocol }

// ❌ 피하기 - 구체 타입 등록 (나중에 변경하기 어려움)
UnifiedDI.register { FileLogger() }
```

### 2. 의존성 체인 관리

```swift
// ✅ 좋음 - 명확한 의존성 체인
UnifiedDI.register {
    let logger: LoggerProtocol = UnifiedDI.resolve()
    let db: DatabaseService = UnifiedDI.resolve()
    return UserService(logger: logger, database: db)
}
```

### 3. 환경별 구성

```swift
// ✅ 좋음 - 환경에 따른 다른 구현
#if DEBUG
UnifiedDI.register { DebugLogger() as LoggerProtocol }
#else
UnifiedDI.register { ProductionLogger() as LoggerProtocol }
#endif
```

### 4. 검증 및 문서화

```swift
class ServiceRegistration {
    /// 모든 필수 서비스를 등록합니다
    /// - Note: 이 메서드는 앱 시작 시 한 번만 호출되어야 합니다
    static func registerAllServices() {
        registerCoreServices()
        registerBusinessServices()
        registerUIServices()

        validateRegistrations()
    }

    private static func validateRegistrations() {
        assert(UnifiedDI.canResolve(LoggerProtocol.self), "Logger가 등록되지 않음")
        assert(UnifiedDI.canResolve(UserService.self), "UserService가 등록되지 않음")
    }
}
```

## 참고 자료

- [Bootstrap API](./bootstrap.md) - 컨테이너 초기화
- [DIActor API](./diActor.md) - 스레드 안전 작업
- [프로퍼티 래퍼 가이드](../guide/propertyWrappers.md) - @Inject, @Factory, @SafeInject