# @SafeInject 프로퍼티 래퍼

`@SafeInject` 프로퍼티 래퍼는 컴파일 타임 안전성을 가진 보장된 의존성 주입을 제공합니다. 옵셔널을 반환하는 `@Inject`와 달리, `@SafeInject`는 대체 메커니즘을 제공하여 의존성이 항상 사용 가능하도록 보장합니다.

## 개요

`@SafeInject`는 의존성이 항상 해결되도록 보장하여 옵셔널 처리의 필요성을 제거합니다. 의존성이 등록되지 않았을 때 여러 가지 대체 전략을 제공하여 코드를 더 견고하고 작업하기 쉽게 만듭니다.

```swift
import WeaveDI

class UserService {
    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    @SafeInject(fallback: MockUserRepository())
    var repository: UserRepository

    func createUser(name: String) async {
        // 옵셔널 언래핑이 필요 없음!
        logger.info("사용자 생성: \\(name)")
        await repository.save(User(name: name))
        logger.info("사용자 생성 성공")
    }
}
```

## 기본 사용법

### 대체 옵션이 있는 간단한 SafeInject

```swift
class WeatherService {
    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    @SafeInject(fallback: MockNetworkClient())
    var networkClient: NetworkClient

    func fetchWeather() async {
        logger.info("날씨 데이터 가져오는 중...")
        // guard let이나 옵셔널 체이닝 필요 없음
        let data = await networkClient.fetchData(from: weatherURL)
        logger.info("날씨 데이터 수신됨")
    }
}
```

### 기본 팩토리와 함께

```swift
class DocumentService {
    @SafeInject { PDFGenerator() }
    var pdfGenerator: PDFGenerator

    @SafeInject { InMemoryCache() }
    var cache: CacheService

    func generateDocument() -> Document {
        // 의존성이 보장됨
        let pdf = pdfGenerator.generate()
        cache.store(pdf)
        return pdf
    }
}
```

## 튜토리얼의 실제 예제

### SafeInject가 있는 CountApp

우리 튜토리얼 CountApp을 기반으로, @SafeInject가 어떻게 신뢰성을 보장하는지 보여줍니다:

```swift
/// 보장된 의존성을 가진 카운터 ViewModel
@MainActor
class SafeCounterViewModel: ObservableObject {
    @Published var count = 0
    @Published var isLoading = false
    @Published var history: [CounterHistoryItem] = []

    // 대체 옵션을 가진 보장된 의존성
    @SafeInject(fallback: MockCounterRepository())
    var repository: CounterRepository

    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    init() {
        Task {
            await loadInitialData()
        }
    }

    func loadInitialData() async {
        isLoading = true

        // 옵셔널 언래핑이 필요 없음!
        count = await repository.getCurrentCount()
        history = await repository.getCountHistory()
        logger.info("📊 초기 데이터 로드 완료: count=\\(count), history=\\(history.count)개")

        isLoading = false
    }

    func increment() async {
        isLoading = true
        count += 1

        // 작동이 보장됨
        await repository.saveCount(count)
        history = await repository.getCountHistory()
        logger.info("⬆️ 카운트 증가: \\(count)")

        isLoading = false
    }

    func decrement() async {
        isLoading = true
        count -= 1

        await repository.saveCount(count)
        history = await repository.getCountHistory()
        logger.info("⬇️ 카운트 감소: \\(count)")

        isLoading = false
    }

    func reset() async {
        isLoading = true
        count = 0

        await repository.resetCount()
        history = await repository.getCountHistory()
        logger.info("🔄 카운트 리셋")

        isLoading = false
    }
}

/// 대체용 모의 구현
class MockCounterRepository: CounterRepository {
    private var currentCount = 0
    private var historyItems: [CounterHistoryItem] = []

    func getCurrentCount() async -> Int {
        return currentCount
    }

    func saveCount(_ count: Int) async {
        currentCount = count
        let item = CounterHistoryItem(
            count: count,
            timestamp: Date(),
            action: .increment
        )
        historyItems.append(item)
    }

    func getCountHistory() async -> [CounterHistoryItem] {
        return historyItems
    }

    func resetCount() async {
        currentCount = 0
        let resetItem = CounterHistoryItem(
            count: 0,
            timestamp: Date(),
            action: .reset
        )
        historyItems.append(resetItem)
    }
}
```

### SafeInject가 있는 WeatherApp

```swift
/// 보장된 의존성을 가진 날씨 서비스
class SafeWeatherService: WeatherServiceProtocol {
    @SafeInject(fallback: MockHTTPClient())
    var httpClient: HTTPClientProtocol

    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    @SafeInject(fallback: InMemoryCacheService())
    var cacheService: CacheServiceProtocol

    func fetchCurrentWeather(for city: String) async throws -> Weather {
        logger.info("🌤️ \\(city)의 날씨 요청 시작")

        do {
            // 옵셔널 언래핑 필요 없음
            let url = buildWeatherURL(for: city)
            let data = try await httpClient.fetchData(from: url)
            let weather = try JSONDecoder().decode(Weather.self, from: data)

            // 결과 캐시
            try await cacheService.store(weather, forKey: "weather_\\(city)")
            logger.info("✅ \\(city) 날씨 데이터 수신 및 캐시 완료")

            return weather
        } catch {
            logger.error("❌ \\(city) 날씨 요청 실패: \\(error)")

            // 캐시된 데이터 시도
            if let cachedWeather: Weather = try? await cacheService.retrieve(forKey: "weather_\\(city)") {
                logger.info("📱 캐시된 \\(city) 날씨 데이터 사용")
                return cachedWeather
            }

            throw error
        }
    }

    func fetchForecast(for city: String) async throws -> [WeatherForecast] {
        logger.info("📅 \\(city)의 예보 요청 시작")

        let url = buildForecastURL(for: city)
        let data = try await httpClient.fetchData(from: url)
        let forecastResponse = try JSONDecoder().decode(ForecastResponse.self, from: data)

        let forecasts = forecastResponse.list.map { item in
            WeatherForecast(
                date: Date(timeIntervalSince1970: TimeInterval(item.dt)),
                maxTemperature: item.main.tempMax,
                minTemperature: item.main.tempMin,
                description: item.weather.first?.description ?? "Unknown",
                iconName: item.weather.first?.icon ?? "unknown"
            )
        }

        // 예보 캐시
        try await cacheService.store(forecasts, forKey: "forecast_\\(city)")
        logger.info("✅ \\(city) 예보 데이터 수신 및 캐시 완료: \\(forecasts.count)개")

        return forecasts
    }

    private func buildWeatherURL(for city: String) -> URL {
        // URL 빌드 로직
        return URL(string: "https://api.openweathermap.org/data/2.5/weather?q=\\(city)&appid=test&units=metric")!
    }

    private func buildForecastURL(for city: String) -> URL {
        return URL(string: "https://api.openweathermap.org/data/2.5/forecast?q=\\(city)&appid=test&units=metric")!
    }
}

/// 대체용 모의 HTTP 클라이언트
class MockHTTPClient: HTTPClientProtocol {
    func fetchData(from url: URL) async throws -> Data {
        // 모의 날씨 데이터 반환
        let mockResponse = \"\"\"
        {
            "name": "Mock City",
            "main": {
                "temp": 20.0,
                "humidity": 50
            },
            "weather": [
                {
                    "description": "Mock Weather",
                    "icon": "01d"
                }
            ]
        }
        \"\"\"
        return mockResponse.data(using: .utf8)!
    }
}
```

## SafeInject 전략

### 1. 대체 인스턴스

구체적인 대체 인스턴스 제공:

```swift
class AnalyticsService {
    @SafeInject(fallback: NoOpAnalytics())
    var analytics: AnalyticsProtocol

    func trackEvent(_ event: String) {
        // 분석 서비스가 등록되지 않았어도 항상 작동
        analytics.track(event)
    }
}

class NoOpAnalytics: AnalyticsProtocol {
    func track(_ event: String) {
        // 아무것도 하지 않음 - 안전한 대체
    }
}
```

### 2. 팩토리 클로저

클로저를 사용하여 대체 인스턴스 생성:

```swift
class ImageService {
    @SafeInject { DefaultImageProcessor() }
    var imageProcessor: ImageProcessor

    @SafeInject { FileSystemImageCache() }
    var imageCache: ImageCache

    func processImage(_ image: UIImage) -> UIImage {
        let processed = imageProcessor.process(image)
        imageCache.store(processed)
        return processed
    }
}
```

### 3. 기본 구현이 있는 프로토콜

```swift
protocol ConfigurationService {
    func getValue(for key: String) -> String
}

extension ConfigurationService {
    func getValue(for key: String) -> String {
        return "default_value"
    }
}

class DefaultConfiguration: ConfigurationService {
    // 기본 구현 사용
}

class AppService {
    @SafeInject(fallback: DefaultConfiguration())
    var config: ConfigurationService

    func setupApp() {
        let apiKey = config.getValue(for: "api_key")
        // 항상 값을 가짐
    }
}
```

## @Inject와 비교

### 코드 비교

```swift
// @Inject 사용 (옵셔널 처리 필요)
class UserServiceWithInject {
    @Inject var logger: LoggerProtocol?
    @Inject var repository: UserRepository?

    func createUser(name: String) async {
        // 옵셔널 처리 필요
        logger?.info("사용자 생성: \\(name)")

        guard let repo = repository else {
            logger?.error("Repository 사용 불가")
            return
        }

        await repo.save(User(name: name))
        logger?.info("사용자 생성됨")
    }
}

// @SafeInject 사용 (옵셔널 처리 없음)
class UserServiceWithSafeInject {
    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    @SafeInject(fallback: MockUserRepository())
    var repository: UserRepository

    func createUser(name: String) async {
        // 깔끔하고 직관적인 코드
        logger.info("사용자 생성: \\(name)")
        await repository.save(User(name: name))
        logger.info("사용자 생성됨")
    }
}
```

## 등록 및 해결

### 일반 등록

SafeInject는 일반 의존성 등록과 함께 작동합니다:

```swift
await WeaveDI.Container.bootstrap { container in
    container.register(LoggerProtocol.self) { FileLogger() }
    container.register(UserRepository.self) { DatabaseUserRepository() }
}

// SafeInject는 사용 가능할 때 등록된 의존성을 사용
let service = UserServiceWithSafeInject() // FileLogger와 DatabaseUserRepository 사용
```

### 등록되지 않았을 때 대체

```swift
// 의존성이 등록되지 않은 경우
let service = UserServiceWithSafeInject() // ConsoleLogger와 MockUserRepository 대체 사용
```

## 스레드 안전성

@SafeInject는 스레드 안전하며 다른 큐에서 작동합니다:

```swift
class ConcurrentService {
    @SafeInject(fallback: ThreadSafeLogger())
    var logger: LoggerProtocol

    func processConcurrently() async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    // 모든 스레드에서 안전하게 사용
                    self.logger.info("항목 \\(i) 처리 중")
                }
            }
        }
    }
}
```

## @SafeInject로 테스팅

### 테스트 설정

```swift
class SafeInjectServiceTests: XCTestCase {

    func testWithRegisteredDependencies() async throws {
        // 테스트 의존성 등록
        await WeaveDI.Container.bootstrap { container in
            container.register(LoggerProtocol.self) { TestLogger() }
            container.register(UserRepository.self) { TestUserRepository() }
        }

        let service = UserServiceWithSafeInject()

        // 등록된 테스트 의존성 사용
        await service.createUser(name: "Test User")

        // 실제 의존성으로 동작 확인
    }

    func testWithoutRegisteredDependencies() async throws {
        // 컨테이너 리셋 (의존성 등록 없음)
        await WeaveDI.Container.resetForTesting()

        let service = UserServiceWithSafeInject()

        // 대체 의존성 사용
        await service.createUser(name: "Test User")

        // 대체 동작이 올바르게 작동하는지 확인
    }
}
```

### 대체 모킹

```swift
class TestableService {
    @SafeInject(fallback: MockService())
    var service: ServiceProtocol

    // 테스트를 위해 대체를 재정의할 수 있음
    init(fallbackService: ServiceProtocol? = nil) {
        if let fallback = fallbackService {
            self._service = SafeInject(fallback: fallback)
        }
    }
}

class ServiceTests: XCTestCase {
    func testWithCustomFallback() {
        let mockService = SpecialMockService()
        let testableService = TestableService(fallbackService: mockService)

        // 사용자 정의 모의로 테스트
    }
}
```

## 성능 고려사항

### 메모리 사용량

SafeInject는 대체 인스턴스에 대한 참조를 유지합니다:

```swift
class EfficientService {
    // ✅ 좋음 - 가벼운 대체
    @SafeInject(fallback: NoOpLogger())
    var logger: LoggerProtocol

    // ⚠️ 고려 - 무거운 대체 인스턴스
    @SafeInject(fallback: FullDatabaseService())
    var database: DatabaseService
}
```

### 지연 대체 생성

```swift
class LazyFallbackService {
    @SafeInject {
        // 필요할 때만 대체 생성
        ExpensiveFallbackService()
    }
    var expensiveService: ExpensiveService
}
```

## 모범 사례

### 1. 적절한 대체 선택

```swift
// ✅ 좋음 - 안전한 무작동 대체
@SafeInject(fallback: NoOpAnalytics())
var analytics: AnalyticsProtocol

// ✅ 좋음 - 최소한의 대체
@SafeInject(fallback: ConsoleLogger())
var logger: LoggerProtocol

// ⚠️ 신중히 고려 - 부작용이 있는 대체
@SafeInject(fallback: ProductionEmailService())
var emailService: EmailService // 실제 이메일을 보낼 수 있음!
```

### 2. 대체 동작 문서화

```swift
class PaymentService {
    /// 무작동 대체가 있는 분석 서비스 (프로덕션에서 안전)
    @SafeInject(fallback: NoOpAnalytics())
    var analytics: AnalyticsProtocol

    /// 콘솔 대체가 있는 로거 (파일 로거가 없으면 콘솔에 로그)
    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol
}
```

### 3. 두 경로 모두 테스트

```swift
func testServiceWithRegisteredDependencies() {
    // 실제 의존성으로 테스트
}

func testServiceWithFallbackDependencies() {
    // 대체 의존성으로 테스트
}
```

### 4. 중요한 의존성에 사용

```swift
class CriticalService {
    // ✅ 항상 작동해야 하는 의존성에 SafeInject 사용
    @SafeInject(fallback: EmergencyHandler())
    var emergencyHandler: EmergencyHandler

    // ✅ 옵셔널 의존성에 @Inject 사용
    @Inject var optionalFeature: OptionalFeature?
}
```

## 일반적인 패턴

### SafeInject가 있는 서비스 계층

```swift
class UserManagementService {
    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    @SafeInject(fallback: InMemoryUserRepository())
    var userRepository: UserRepository

    @SafeInject(fallback: NoOpEmailService())
    var emailService: EmailService

    func registerUser(_ userData: UserData) async throws {
        logger.info("새 사용자 등록: \\(userData.email)")

        let user = User(from: userData)
        try await userRepository.save(user)

        await emailService.sendWelcomeEmail(to: user)

        logger.info("사용자 등록 완료: \\(user.id)")
    }
}
```

### 구성 서비스 패턴

```swift
protocol AppConfiguration {
    func apiBaseURL() -> URL
    func apiKey() -> String
    func isDebugMode() -> Bool
}

class DefaultAppConfiguration: AppConfiguration {
    func apiBaseURL() -> URL {
        URL(string: "https://api.example.com")!
    }

    func apiKey() -> String {
        "default_api_key"
    }

    func isDebugMode() -> Bool {
        true
    }
}

class NetworkService {
    @SafeInject(fallback: DefaultAppConfiguration())
    var config: AppConfiguration

    func makeAPICall() async {
        let baseURL = config.apiBaseURL()
        let apiKey = config.apiKey()

        // 항상 구성 값을 가짐
    }
}
```

## 참고 자료

- [@Inject 프로퍼티 래퍼](./inject.md) - 옵셔널 의존성 주입용
- [@Factory 프로퍼티 래퍼](./factory.md) - 팩토리 기반 주입용
- [프로퍼티 래퍼 가이드](../guide/propertyWrappers.md) - 모든 프로퍼티 래퍼의 종합 가이드