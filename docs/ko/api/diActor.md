# DIActor API 참조

DIActor는 Swift의 액터 모델을 사용하여 스레드 안전한 의존성 주입 작업을 제공합니다. 동시성 환경에서 모든 DI 컨테이너 작업이 안전하게 수행되도록 보장합니다.

## 개요

DIActor는 DI 컨테이너를 액터로 감싸서 의존성 등록 및 해결에 대한 스레드 안전한 접근을 제공합니다. 이는 여러 작업이 DI 컨테이너에 동시에 접근할 수 있는 동시성 환경에서 특히 유용합니다.

```swift
import WeaveDI

// 스레드 안전한 의존성 등록
@DIActor
func setupDependencies() async {
    await DIActor.shared.register(UserService.self) {
        UserServiceImpl()
    }

    await DIActor.shared.register(Logger.self) {
        FileLogger()
    }
}

// 스레드 안전한 의존성 해결
@DIActor
func getUserService() async -> UserService? {
    return await DIActor.shared.resolve(UserService.self)
}
```

## 핵심 작업

### 등록

#### `register(_:factory:)`

스레드 안전한 작업으로 의존성을 등록합니다:

```swift
@DIActor
func registerServices() async {
    // 스레드 안전한 등록
    await DIActor.shared.register(NetworkService.self) {
        URLSessionNetworkService()
    }

    await DIActor.shared.register(CacheService.self) {
        CoreDataCacheService()
    }
}
```

#### 대량 등록

```swift
@DIActor
func registerAllServices() async {
    let services: [(Any.Type, () -> Any)] = [
        (LoggerProtocol.self, { ConsoleLogger() }),
        (NetworkClient.self, { URLSessionNetworkClient() }),
        (DatabaseService.self, { CoreDataService() })
    ]

    for (serviceType, factory) in services {
        // 각 등록이 스레드 안전함
        await DIActor.shared.register(serviceType, factory: factory)
    }
}
```

### 해결

#### `resolve(_:)`

스레드 안전한 의존성 해결:

```swift
@DIActor
func getConfiguredServices() async -> (UserService?, Logger?) {
    let userService = await DIActor.shared.resolve(UserService.self)
    let logger = await DIActor.shared.resolve(Logger.self)

    return (userService, logger)
}
```

### 동시 작업

```swift
@DIActor
func setupServicesConcurrently() async {
    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            await DIActor.shared.register(ServiceA.self) { ServiceAImpl() }
        }

        group.addTask {
            await DIActor.shared.register(ServiceB.self) { ServiceBImpl() }
        }

        group.addTask {
            await DIActor.shared.register(ServiceC.self) { ServiceCImpl() }
        }
    }
}
```

## 튜토리얼의 실제 예제

### DIActor가 있는 CountApp

```swift
/// DIActor를 사용한 스레드 안전한 카운터 서비스 설정
@DIActor
func setupCounterServices() async {
    print("🧵 백그라운드 스레드에서 카운터 서비스 설정 중...")

    // 스레드 안전성을 가진 카운터 레포지토리 등록
    await DIActor.shared.register(CounterRepository.self) {
        UserDefaultsCounterRepository()
    }

    // 로거 등록
    await DIActor.shared.register(LoggerProtocol.self) {
        FileLogger(filename: "counter.log")
    }

    print("✅ 카운터 서비스가 안전하게 등록됨")
}

/// 스레드 안전한 카운터 작업
actor CounterActor {
    private var internalCount = 0

    @Inject var repository: CounterRepository?
    @Inject var logger: LoggerProtocol?

    func increment() async -> Int {
        internalCount += 1

        // 안전한 레포지토리 접근
        await repository?.saveCount(internalCount)
        logger?.info("🔢 카운트가 \\(internalCount)로 증가됨")

        return internalCount
    }

    func getCurrentCount() async -> Int {
        // 레포지토리에서 최신 데이터 확인
        if let repoCount = await repository?.getCurrentCount() {
            internalCount = repoCount
        }
        return internalCount
    }
}

/// 안전한 초기화를 위해 DIActor를 사용하는 ViewModel
@MainActor
class ThreadSafeCounterViewModel: ObservableObject {
    @Published var count = 0
    @Published var isLoading = false

    private let counterActor = CounterActor()

    init() {
        Task {
            await initializeServices()
            await loadInitialData()
        }
    }

    @DIActor
    private func initializeServices() async {
        // 서비스가 사용 가능한지 확인
        if await DIActor.shared.resolve(CounterRepository.self) == nil {
            await setupCounterServices()
        }
    }

    func increment() async {
        isLoading = true
        count = await counterActor.increment()
        isLoading = false
    }

    private func loadInitialData() async {
        isLoading = true
        count = await counterActor.getCurrentCount()
        isLoading = false
    }
}
```

### DIActor가 있는 WeatherApp

```swift
/// DIActor를 사용한 날씨 서비스 초기화
@DIActor
func setupWeatherServices() async {
    print("🌤️ 날씨 서비스 설정 중...")

    // 네트워크 계층
    await DIActor.shared.register(HTTPClientProtocol.self) {
        URLSessionHTTPClient()
    }

    // 의존성 해결을 가진 날씨 서비스
    await DIActor.shared.register(WeatherServiceProtocol.self) {
        let httpClient = await DIActor.shared.resolve(HTTPClientProtocol.self)!
        return WeatherService(httpClient: httpClient)
    }

    // 캐시 서비스
    await DIActor.shared.register(CacheServiceProtocol.self) {
        CoreDataCacheService()
    }

    print("✅ 날씨 서비스 등록됨")
}

/// 스레드 안전한 날씨 데이터 액터
actor WeatherDataActor {
    private var cachedWeather: [String: Weather] = [:]
    private var lastUpdateTime: [String: Date] = [:]

    @Inject var weatherService: WeatherServiceProtocol?
    @Inject var cacheService: CacheServiceProtocol?
    @Inject var logger: LoggerProtocol?

    func getWeather(for city: String, forceRefresh: Bool = false) async throws -> Weather {
        let cacheKey = "weather_\\(city)"

        // 새로고침이 필요한지 확인
        if !forceRefresh,
           let cached = cachedWeather[city],
           let lastUpdate = lastUpdateTime[city],
           Date().timeIntervalSince(lastUpdate) < 300 { // 5분
            logger?.info("📱 \\(city)의 캐시된 날씨 사용")
            return cached
        }

        // 새로운 데이터 가져오기
        guard let service = weatherService else {
            throw WeatherError.serviceUnavailable
        }

        logger?.info("🌐 \\(city)의 새로운 날씨 가져오는 중")
        let weather = try await service.fetchCurrentWeather(for: city)

        // 캐시 업데이트
        cachedWeather[city] = weather
        lastUpdateTime[city] = Date()

        // 저장소에 지속
        try? await cacheService?.store(weather, forKey: cacheKey)

        logger?.info("✅ \\(city)의 날씨 업데이트됨")
        return weather
    }

    func clearCache() {
        cachedWeather.removeAll()
        lastUpdateTime.removeAll()
        logger?.info("🗑️ 날씨 캐시 지워짐")
    }
}
```

## 동시 초기화 패턴

### 병렬 서비스 설정

```swift
@DIActor
func setupServicesInParallel() async {
    print("⚡ 병렬 서비스 초기화 시작...")

    await withTaskGroup(of: Void.self) { group in
        // 핵심 서비스들
        group.addTask {
            await DIActor.shared.register(LoggerProtocol.self) {
                FileLogger()
            }
            print("📝 Logger 등록됨")
        }

        // 네트워크 서비스들
        group.addTask {
            await DIActor.shared.register(HTTPClientProtocol.self) {
                URLSessionHTTPClient()
            }
            print("🌐 HTTP Client 등록됨")
        }

        // 데이터베이스 서비스들
        group.addTask {
            await DIActor.shared.register(DatabaseService.self) {
                CoreDataService()
            }
            print("🗄️ Database 등록됨")
        }

        // 캐시 서비스들
        group.addTask {
            await DIActor.shared.register(CacheServiceProtocol.self) {
                InMemoryCacheService()
            }
            print("💾 Cache 등록됨")
        }
    }

    print("✅ 모든 서비스가 병렬로 등록됨")
}
```

### 의존성이 있는 서비스 등록

```swift
@DIActor
func setupDependentServices() async {
    // 기본 서비스들을 먼저 등록
    await DIActor.shared.register(LoggerProtocol.self) {
        FileLogger()
    }

    await DIActor.shared.register(HTTPClientProtocol.self) {
        URLSessionHTTPClient()
    }

    // 그다음 의존 서비스들 등록
    await DIActor.shared.register(WeatherServiceProtocol.self) {
        let httpClient = await DIActor.shared.resolve(HTTPClientProtocol.self)!
        let logger = await DIActor.shared.resolve(LoggerProtocol.self)!
        return WeatherService(httpClient: httpClient, logger: logger)
    }

    await DIActor.shared.register(UserServiceProtocol.self) {
        let logger = await DIActor.shared.resolve(LoggerProtocol.self)!
        return UserService(logger: logger)
    }
}
```

## DIActor로 테스팅

### 테스트 설정

```swift
class DIActorTests: XCTestCase {

    override func setUp() async throws {
        // 테스트를 위해 DIActor 상태 리셋
        await DIActor.shared.reset()
    }

    func testConcurrentRegistration() async throws {
        // 동시 등록 안전성 테스트
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await DIActor.shared.register(TestService.self, name: "service_\\(i)") {
                        TestServiceImpl(id: i)
                    }
                }
            }
        }

        // 모든 서비스가 등록되었는지 확인
        for i in 0..<100 {
            let service = await DIActor.shared.resolve(TestService.self, name: "service_\\(i)")
            XCTAssertNotNil(service)
        }
    }

    func testConcurrentResolution() async throws {
        // 서비스 등록
        await DIActor.shared.register(TestService.self) {
            TestServiceImpl(id: 1)
        }

        // 동시 해결 테스트
        await withTaskGroup(of: TestService?.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    await DIActor.shared.resolve(TestService.self)
                }
            }

            var resolvedServices: [TestService?] = []
            for await service in group {
                resolvedServices.append(service)
            }

            // 모든 해결이 성공해야 함
            XCTAssertEqual(resolvedServices.count, 100)
            XCTAssertTrue(resolvedServices.allSatisfy { $0 != nil })
        }
    }
}
```

### 성능 테스팅

```swift
class DIActorPerformanceTests: XCTestCase {

    func testRegistrationPerformance() async throws {
        measure {
            Task {
                await DIActor.shared.reset()

                for i in 0..<1000 {
                    await DIActor.shared.register(TestService.self, name: "service_\\(i)") {
                        TestServiceImpl(id: i)
                    }
                }
            }
        }
    }

    func testResolutionPerformance() async throws {
        // 서비스들 설정
        for i in 0..<1000 {
            await DIActor.shared.register(TestService.self, name: "service_\\(i)") {
                TestServiceImpl(id: i)
            }
        }

        measure {
            Task {
                for i in 0..<1000 {
                    _ = await DIActor.shared.resolve(TestService.self, name: "service_\\(i)")
                }
            }
        }
    }
}
```

## SwiftUI와 통합

### 앱 초기화

```swift
@main
struct MyApp: App {
    init() {
        Task {
            await initializeAppServices()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // 서비스가 준비되었는지 확인
                    await ensureServicesReady()
                }
        }
    }

    @DIActor
    private func initializeAppServices() async {
        await setupCounterServices()
        await setupWeatherServices()
        print("🚀 앱 서비스 초기화됨")
    }

    private func ensureServicesReady() async {
        // 중요한 서비스들 대기
        while await DIActor.shared.resolve(LoggerProtocol.self) == nil {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
}
```

### ViewModel 통합

```swift
@MainActor
class AppViewModel: ObservableObject {
    @Published var isReady = false

    init() {
        Task {
            await waitForServices()
            isReady = true
        }
    }

    @DIActor
    private func waitForServices() async {
        // 필수 서비스들 대기
        while await DIActor.shared.resolve(LoggerProtocol.self) == nil ||
              await DIActor.shared.resolve(WeatherServiceProtocol.self) == nil {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
}
```

## 모범 사례

### 1. 동시 초기화에 사용

```swift
// ✅ 좋음 - 동시 설정에 DIActor 사용
@DIActor
func setupServices() async {
    await withTaskGroup(of: Void.self) { group in
        group.addTask { await setupNetworkServices() }
        group.addTask { await setupDatabaseServices() }
        group.addTask { await setupCacheServices() }
    }
}
```

### 2. 액터 경계 교차 최소화

```swift
// ✅ 좋음 - 작업 일괄 처리
@DIActor
func setupRelatedServices() async {
    await DIActor.shared.register(ServiceA.self) { ServiceAImpl() }
    await DIActor.shared.register(ServiceB.self) { ServiceBImpl() }
    await DIActor.shared.register(ServiceC.self) { ServiceCImpl() }
}

// ❌ 피하기 - 여러 개의 별도 액터 호출
func setupServicesInefficiently() async {
    await DIActor.shared.register(ServiceA.self) { ServiceAImpl() }
    // ... 다른 액터가 아닌 코드
    await DIActor.shared.register(ServiceB.self) { ServiceBImpl() }
    // ... 더 많은 액터가 아닌 코드
}
```

### 3. 의존성 신중하게 처리

```swift
@DIActor
func setupWithDependencies() async {
    // 의존성을 먼저 등록
    await DIActor.shared.register(LoggerProtocol.self) { FileLogger() }

    // 그다음 의존 서비스들 등록
    await DIActor.shared.register(UserService.self) {
        let logger = await DIActor.shared.resolve(LoggerProtocol.self)!
        return UserService(logger: logger)
    }
}
```

## 일반적인 패턴

### 서비스 매니저 패턴

```swift
actor ServiceManager {
    private var isInitialized = false

    func initialize() async {
        guard !isInitialized else { return }

        await setupCoreServices()
        await setupBusinessServices()
        await setupUIServices()

        isInitialized = true
    }

    @DIActor
    private func setupCoreServices() async {
        await DIActor.shared.register(LoggerProtocol.self) { FileLogger() }
        await DIActor.shared.register(ConfigService.self) { AppConfigService() }
    }

    @DIActor
    private func setupBusinessServices() async {
        await DIActor.shared.register(UserService.self) { UserServiceImpl() }
        await DIActor.shared.register(WeatherService.self) { WeatherServiceImpl() }
    }

    @DIActor
    private func setupUIServices() async {
        await DIActor.shared.register(ThemeService.self) { AppThemeService() }
        await DIActor.shared.register(NavigationService.self) { NavigationServiceImpl() }
    }
}
```

### 우아한 초기화

```swift
@DIActor
func initializeWithFallbacks() async {
    do {
        // 주 서비스들 초기화 시도
        await setupPrimaryServices()
    } catch {
        print("⚠️ 주 서비스 실패, 대체 서비스 사용")
        await setupFallbackServices()
    }
}

@DIActor
private func setupPrimaryServices() async throws {
    await DIActor.shared.register(DatabaseService.self) {
        try CoreDataService()
    }
}

@DIActor
private func setupFallbackServices() async {
    await DIActor.shared.register(DatabaseService.self) {
        InMemoryDatabaseService()
    }
}
```

## 참고 자료

- [UnifiedDI API](./unifiedDI.md) - 간소화된 DI 인터페이스
- [Bootstrap API](./bootstrap.md) - 컨테이너 초기화
- [동시성 통합 가이드](../tutorial/concurrencyIntegration.md) - Swift 동시성 패턴