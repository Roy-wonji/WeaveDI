# DIActor API 참조

DIActor는 Swift의 액터 모델을 사용하여 스레드 안전한 의존성 주입 작업을 제공합니다. 동시성 환경에서 모든 DI 컨테이너 작업이 안전하게 수행되도록 보장합니다.

## 개요

DIActor는 DI 컨테이너를 Swift 액터로 감싸서 의존성 등록 및 해결 작업에 대한 보장된 스레드 안전한 접근을 제공합니다. 이 정교한 동시성 관리 시스템은 여러 작업, 비동기 작업 또는 병렬 프로세스가 DI 컨테이너에 동시에 접근할 수 있는 고도로 동시적인 환경에서 특히 유용합니다.

**주요 이점**:
- **액터 격리**: Swift 액터 모델이 메모리 안전성을 보장하고 데이터 경합을 방지
- **동시성 안전성**: 여러 작업이 동시에 의존성을 안전하게 등록하고 해결 가능
- **결정적 동작**: 의존성 작업에 대한 예측 가능한 실행 순서
- **성능 최적화**: 고처리량 동시성 시나리오에 최적화
- **교착상태 방지**: 액터 모델이 일반적인 동시성 함정을 방지

**성능 특성**:
- **등록 속도**: 액터 조정과 함께 등록당 ~0.1-1ms
- **해결 속도**: 등록된 의존성에 대한 거의 즉시 해결
- **동시성 오버헤드**: 액터 메시지 전달에 대한 최소한의 오버헤드
- **메모리 효율성**: 액터 격리를 통한 효율적인 메모리 사용
- **확장성**: 동시 작업 수에 따른 선형 성능 확장

## Actor Hop 이해하기

### Actor Hop이란 무엇인가요?

**Actor hop**은 Swift의 액터 모델에서 실행이 한 액터 컨텍스트에서 다른 액터 컨텍스트로 전환될 때 발생하는 핵심 개념입니다. Actor hop을 이해하고 최적화하는 것은 WeaveDI로 고성능 애플리케이션을 구축하는 데 중요합니다.

```swift
// Actor hop 개념을 보여주는 예제
@MainActor
class UIViewController {
    @Inject var userService: UserService?

    func updateUI() async {
        // 1. 현재 MainActor (UI 스레드)에 있음
        print("📱 MainActor에 있음: \(Thread.isMainThread)")

        // 2. 여기서 actor hop 발생 - DIActor 컨텍스트로 전환
        let service = await DIActor.shared.resolve(UserService.self)
        // ⚡ ACTOR HOP: MainActor → DIActor

        // 3. 이제 DIActor 컨텍스트에 있음
        guard let userService = service else { return }

        // 4. 또 다른 actor hop - DIActor에서 MainActor로 UI 업데이트를 위해 복귀
        await MainActor.run {
            // ⚡ ACTOR HOP: DIActor → MainActor
            self.displayUsers(users)
        }
    }
}
```

### Actor Hop 성능 영향

각 actor hop은 다음을 포함합니다:
- **컨텍스트 스위칭**: CPU가 액터 간 실행 컨텍스트를 전환
- **메모리 동기화**: 액터 경계 간 메모리 일관성 보장
- **작업 일시정지**: 현재 작업이 일시정지되고 나중에 재개될 수 있음
- **큐 조정**: 내부 큐를 통한 액터 메시지 전달

**성능 특성:**
- **일반적인 지연 시간**: hop당 50-200 마이크로초
- **메모리 오버헤드**: 일시정지된 작업당 16-64바이트
- **CPU 영향**: 빈번한 hopping 시 ~2-5% 오버헤드
- **배터리 영향**: 모바일 기기에서 전력 소모 증가

### WeaveDI의 Actor Hop 최적화

WeaveDI는 actor hop 오버헤드를 최소화하기 위한 여러 전략을 구현합니다:

#### 1. Hot Path 캐싱
```swift
// 첫 번째 해결은 actor hop이 필요함
let service1 = await DIActor.shared.resolve(UserService.self)
// ⚡ ACTOR HOP: 현재 컨텍스트 → DIActor

// 후속 해결은 캐시되고 최적화됨
let service2 = await DIActor.shared.resolve(UserService.self)
// ✨ 최적화됨: 캐시된 해결, 최소한의 actor hop 오버헤드
```

#### 2. 배치 해결 최적화
```swift
// ❌ 비효율적: 여러 actor hop
@DIActor
func inefficientSetup() async {
    let userService = await DIActor.shared.resolve(UserService.self)     // Hop 1
    let networkService = await DIActor.shared.resolve(NetworkService.self) // Hop 2
    let cacheService = await DIActor.shared.resolve(CacheService.self)   // Hop 3
}

// ✅ 최적화됨: 단일 액터 컨텍스트, 여러 작업
@DIActor
func optimizedSetup() async {
    // 모든 작업이 DIActor 컨텍스트 내에서 발생 - 추가 hop 없음
    let userService = await DIActor.shared.resolve(UserService.self)
    let networkService = await DIActor.shared.resolve(NetworkService.self)
    let cacheService = await DIActor.shared.resolve(CacheService.self)
}
```

#### 3. 컨텍스트 해결 전략
```swift
actor BusinessLogicActor {
    @Inject var userService: UserService?

    func processUserData() async {
        // 프로퍼티 래퍼 주입이 actor hop을 최소화
        // 서비스는 한 번 해결되고 액터 인스턴스 내에 캐시됨
        guard let service = userService else { return }

        // 모든 후속 호출은 캐시된 인스턴스 사용 - actor hop 없음
        let users = await service.fetchUsers()
        let processed = await service.processUsers(users)
        await service.saveProcessedUsers(processed)
    }
}
```

### Actor Hop 감지 및 모니터링

WeaveDI는 포괄적인 actor hop 모니터링 기능을 제공합니다:

```swift
// Actor hop 모니터링 활성화
@DIActor
func enableMonitoring() async {
    await DIActor.shared.enableActorHopMonitoring()

    // 작업 수행
    let service = await DIActor.shared.resolve(UserService.self)

    // Actor hop 통계 확인
    let stats = await DIActor.shared.getActorHopStats()
    print("🔍 Actor Hop 분석:")
    print("  총 hop 수: \(stats.totalHops)")
    print("  평균 지연 시간: \(stats.averageLatency)ms")
    print("  최대 지연 시간: \(stats.peakLatency)ms")
    print("  최적화 기회: \(stats.optimizationSuggestions)")
}

// 실시간 actor hop 로깅
@DIActor
func demonstrateHopLogging() async {
    // 상세 로깅 활성화
    await DIActor.shared.setActorHopLoggingLevel(.detailed)

    let service = await DIActor.shared.resolve(UserService.self)
    // 콘솔 출력:
    // 🎭 [ActorHop] MainActor → DIActor (85μs)
    // 🎭 [ActorHop] DIActor → MainActor (92μs)
    // ⚡ [최적화] hop을 줄이기 위해 작업을 배치하는 것을 고려하세요
}
```

### Actor Hop 최적화를 위한 모범 사례

#### 1. 액터 간 통신 최소화
```swift
// ❌ 피해야 할 패턴: 빈번한 액터 간 통신
@MainActor
class BadViewController {
    func loadData() async {
        for i in 1...10 {
            // 10개의 actor hop - 매우 비효율적!
            let user = await DIActor.shared.resolve(UserService.self)
            await updateUI(with: user)
        }
    }
}

// ✅ 좋은 패턴: 단일 액터 컨텍스트 내에서 작업 배치
@MainActor
class GoodViewController {
    func loadData() async {
        // 모든 서비스를 배치 해결하기 위한 단일 actor hop
        let services = await DIActor.shared.batchResolve([
            UserService.self,
            NetworkService.self,
            CacheService.self
        ])

        // MainActor 컨텍스트 내에서 모든 데이터 처리
        await processServices(services)
    }
}
```

#### 2. 액터별 패턴 사용
```swift
// ✅ 좋은 패턴: 액터를 고려한 서비스 설계
actor DataProcessingActor {
    private var cachedServices: [String: Any] = [:]

    func processWithOptimizedHops() async {
        // 액터 내에서 서비스를 한 번 해결하고 캐시
        if cachedServices.isEmpty {
            // 모든 서비스 해결을 위한 단일 actor hop
            await resolveDependencies()
        }

        // 모든 처리가 액터 내에서 발생 - 추가 hop 없음
        await performDataProcessing()
    }

    @DIActor
    private func resolveDependencies() async {
        let userService = await DIActor.shared.resolve(UserService.self)
        let networkService = await DIActor.shared.resolve(NetworkService.self)

        await MainActor.run {
            // 메인 액터 컨텍스트에서 서비스 캐시
            self.cachedServices["user"] = userService
            self.cachedServices["network"] = networkService
        }
    }
}
```

#### 3. 전략적 프로퍼티 래퍼 사용
```swift
// ✅ 최적: 프로퍼티 래퍼가 actor hop을 최소화
class OptimizedService {
    @Inject var userService: UserService?
    @Factory var logger: Logger  // 각 접근마다 새 인스턴스이지만 최적화됨
    @SafeInject var database: Database?

    func performOperations() async {
        // 프로퍼티 래퍼가 actor hop 최적화를 자동으로 처리
        // 서비스는 한 번 해결되고 인스턴스별로 캐시됨

        guard let user = userService,
              let db = database else { return }

        // 모든 후속 작업은 캐시된 인스턴스 사용
        let data = await user.fetchData()
        await db.save(data)

        // 팩토리 인스턴스는 생성 패턴에 최적화됨
        logger.info("작업 완료")
    }
}
```

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