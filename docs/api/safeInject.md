# @SafeInject Property Wrapper

The `@SafeInject` property wrapper provides guaranteed dependency injection with compile-time safety. Unlike `@Inject` which returns optionals, `@SafeInject` ensures your dependencies are always available by providing fallback mechanisms.

## Overview

`@SafeInject` eliminates the need for optional handling by guaranteeing that a dependency will always be resolved. It provides several fallback strategies when a dependency is not registered, making your code more robust and easier to work with.

```swift
import WeaveDI

class UserService {
    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    @SafeInject(fallback: MockUserRepository())
    var repository: UserRepository

    func createUser(name: String) async {
        // No optional unwrapping needed!
        logger.info("Creating user: \(name)")
        await repository.save(User(name: name))
        logger.info("User created successfully")
    }
}
```

## Basic Usage

### Simple SafeInject with Fallback

```swift
class WeatherService {
    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    @SafeInject(fallback: MockNetworkClient())
    var networkClient: NetworkClient

    func fetchWeather() async {
        logger.info("Fetching weather data...")
        // No need for guard let or optional chaining
        let data = await networkClient.fetchData(from: weatherURL)
        logger.info("Weather data received")
    }
}
```

### With Default Factory

```swift
class DocumentService {
    @SafeInject { PDFGenerator() }
    var pdfGenerator: PDFGenerator

    @SafeInject { InMemoryCache() }
    var cache: CacheService

    func generateDocument() -> Document {
        // Guaranteed to have dependencies
        let pdf = pdfGenerator.generate()
        cache.store(pdf)
        return pdf
    }
}
```

## Real-World Examples from Tutorial

### CountApp with SafeInject

Based on our tutorial CountApp, here's how @SafeInject ensures reliability:

```swift
/// Counter ViewModel with guaranteed dependencies
@MainActor
class SafeCounterViewModel: ObservableObject {
    @Published var count = 0
    @Published var isLoading = false
    @Published var history: [CounterHistoryItem] = []

    // Guaranteed dependencies with fallbacks
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

        // No optional unwrapping needed!
        count = await repository.getCurrentCount()
        history = await repository.getCountHistory()
        logger.info("📊 초기 데이터 로드 완료: count=\(count), history=\(history.count)개")

        isLoading = false
    }

    func increment() async {
        isLoading = true
        count += 1

        // Guaranteed to work
        await repository.saveCount(count)
        history = await repository.getCountHistory()
        logger.info("⬆️ 카운트 증가: \(count)")

        isLoading = false
    }

    func decrement() async {
        isLoading = true
        count -= 1

        await repository.saveCount(count)
        history = await repository.getCountHistory()
        logger.info("⬇️ 카운트 감소: \(count)")

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

/// Mock implementation for fallback
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

### WeatherApp with SafeInject

```swift
/// Weather service with guaranteed dependencies
class SafeWeatherService: WeatherServiceProtocol {
    @SafeInject(fallback: MockHTTPClient())
    var httpClient: HTTPClientProtocol

    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    @SafeInject(fallback: InMemoryCacheService())
    var cacheService: CacheServiceProtocol

    func fetchCurrentWeather(for city: String) async throws -> Weather {
        logger.info("🌤️ \(city)의 날씨 요청 시작")

        do {
            // No optional unwrapping needed
            let url = buildWeatherURL(for: city)
            let data = try await httpClient.fetchData(from: url)
            let weather = try JSONDecoder().decode(Weather.self, from: data)

            // Cache the result
            try await cacheService.store(weather, forKey: "weather_\(city)")
            logger.info("✅ \(city) 날씨 데이터 수신 및 캐시 완료")

            return weather
        } catch {
            logger.error("❌ \(city) 날씨 요청 실패: \(error)")

            // Try to get cached data
            if let cachedWeather: Weather = try? await cacheService.retrieve(forKey: "weather_\(city)") {
                logger.info("📱 캐시된 \(city) 날씨 데이터 사용")
                return cachedWeather
            }

            throw error
        }
    }

    func fetchForecast(for city: String) async throws -> [WeatherForecast] {
        logger.info("📅 \(city)의 예보 요청 시작")

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

        // Cache forecasts
        try await cacheService.store(forecasts, forKey: "forecast_\(city)")
        logger.info("✅ \(city) 예보 데이터 수신 및 캐시 완료: \(forecasts.count)개")

        return forecasts
    }

    private func buildWeatherURL(for city: String) -> URL {
        // URL building logic
        return URL(string: "https://api.openweathermap.org/data/2.5/weather?q=\(city)&appid=test&units=metric")!
    }

    private func buildForecastURL(for city: String) -> URL {
        return URL(string: "https://api.openweathermap.org/data/2.5/forecast?q=\(city)&appid=test&units=metric")!
    }
}

/// Mock HTTP client for fallback
class MockHTTPClient: HTTPClientProtocol {
    func fetchData(from url: URL) async throws -> Data {
        // Return mock weather data
        let mockResponse = """
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
        """
        return mockResponse.data(using: .utf8)!
    }
}
```

## SafeInject Strategies

### 1. Fallback Instance

Provide a concrete fallback instance:

```swift
class AnalyticsService {
    @SafeInject(fallback: NoOpAnalytics())
    var analytics: AnalyticsProtocol

    func trackEvent(_ event: String) {
        // Always works, even if no analytics service is registered
        analytics.track(event)
    }
}

class NoOpAnalytics: AnalyticsProtocol {
    func track(_ event: String) {
        // Do nothing - safe fallback
    }
}
```

### 2. Factory Closure

Use a closure to create fallback instances:

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

### 3. Protocol with Default Implementation

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
    // Uses default implementation
}

class AppService {
    @SafeInject(fallback: DefaultConfiguration())
    var config: ConfigurationService

    func setupApp() {
        let apiKey = config.getValue(for: "api_key")
        // Always has a value
    }
}
```

## Compared to @Inject

### Code Comparison

```swift
// With @Inject (optional handling required)
class UserServiceWithInject {
    @Inject var logger: LoggerProtocol?
    @Inject var repository: UserRepository?

    func createUser(name: String) async {
        // Requires optional handling
        logger?.info("Creating user: \(name)")

        guard let repo = repository else {
            logger?.error("Repository not available")
            return
        }

        await repo.save(User(name: name))
        logger?.info("User created")
    }
}

// With @SafeInject (no optional handling)
class UserServiceWithSafeInject {
    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    @SafeInject(fallback: MockUserRepository())
    var repository: UserRepository

    func createUser(name: String) async {
        // Clean, straightforward code
        logger.info("Creating user: \(name)")
        await repository.save(User(name: name))
        logger.info("User created")
    }
}
```

## Registration and Resolution

### Normal Registration

SafeInject works with normal dependency registration:

```swift
await DIContainer.bootstrap { container in
    container.register(LoggerProtocol.self) { FileLogger() }
    container.register(UserRepository.self) { DatabaseUserRepository() }
}

// SafeInject will use registered dependencies when available
let service = UserServiceWithSafeInject() // Uses FileLogger and DatabaseUserRepository
```

### Fallback When Not Registered

```swift
// If no dependencies are registered
let service = UserServiceWithSafeInject() // Uses ConsoleLogger and MockUserRepository fallbacks
```

## Thread Safety

@SafeInject is thread-safe and works across different queues:

```swift
class ConcurrentService {
    @SafeInject(fallback: ThreadSafeLogger())
    var logger: LoggerProtocol

    func processConcurrently() async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    // Safe to use from any thread
                    self.logger.info("Processing item \(i)")
                }
            }
        }
    }
}
```

## Testing with @SafeInject

### Test Setup

```swift
class SafeInjectServiceTests: XCTestCase {

    func testWithRegisteredDependencies() async throws {
        // Register test dependencies
        await DIContainer.bootstrap { container in
            container.register(LoggerProtocol.self) { TestLogger() }
            container.register(UserRepository.self) { TestUserRepository() }
        }

        let service = UserServiceWithSafeInject()

        // Uses registered test dependencies
        await service.createUser(name: "Test User")

        // Verify behavior with real dependencies
    }

    func testWithoutRegisteredDependencies() async throws {
        // Reset container (no dependencies registered)
        await DIContainer.resetForTesting()

        let service = UserServiceWithSafeInject()

        // Uses fallback dependencies
        await service.createUser(name: "Test User")

        // Verify fallback behavior works correctly
    }
}
```

### Mocking Fallbacks

```swift
class TestableService {
    @SafeInject(fallback: MockService())
    var service: ServiceProtocol

    // For testing, you can override the fallback
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

        // Test with custom mock
    }
}
```

## Performance Considerations

### Memory Usage

SafeInject keeps a reference to the fallback instance:

```swift
class EfficientService {
    // ✅ Good - lightweight fallback
    @SafeInject(fallback: NoOpLogger())
    var logger: LoggerProtocol

    // ⚠️ Consider - heavy fallback instance
    @SafeInject(fallback: FullDatabaseService())
    var database: DatabaseService
}
```

### Lazy Fallback Creation

```swift
class LazyFallbackService {
    @SafeInject {
        // Fallback created only when needed
        ExpensiveFallbackService()
    }
    var expensiveService: ExpensiveService
}
```

## Best Practices

### 1. Choose Appropriate Fallbacks

```swift
// ✅ Good - safe, no-op fallback
@SafeInject(fallback: NoOpAnalytics())
var analytics: AnalyticsProtocol

// ✅ Good - minimal fallback
@SafeInject(fallback: ConsoleLogger())
var logger: LoggerProtocol

// ⚠️ Consider carefully - fallback with side effects
@SafeInject(fallback: ProductionEmailService())
var emailService: EmailService // Might send real emails!
```

### 2. Document Fallback Behavior

```swift
class PaymentService {
    /// Analytics service with no-op fallback (safe for production)
    @SafeInject(fallback: NoOpAnalytics())
    var analytics: AnalyticsProtocol

    /// Logger with console fallback (logs to console if no file logger)
    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol
}
```

### 3. Test Both Paths

```swift
func testServiceWithRegisteredDependencies() {
    // Test with real dependencies
}

func testServiceWithFallbackDependencies() {
    // Test with fallback dependencies
}
```

### 4. Use for Critical Dependencies

```swift
class CriticalService {
    // ✅ Use SafeInject for dependencies that must always work
    @SafeInject(fallback: EmergencyHandler())
    var emergencyHandler: EmergencyHandler

    // ✅ Use @Inject for optional dependencies
    @Inject var optionalFeature: OptionalFeature?
}
```

## Common Patterns

### Service Layer with SafeInject

```swift
class UserManagementService {
    @SafeInject(fallback: ConsoleLogger())
    var logger: LoggerProtocol

    @SafeInject(fallback: InMemoryUserRepository())
    var userRepository: UserRepository

    @SafeInject(fallback: NoOpEmailService())
    var emailService: EmailService

    func registerUser(_ userData: UserData) async throws {
        logger.info("Registering new user: \(userData.email)")

        let user = User(from: userData)
        try await userRepository.save(user)

        await emailService.sendWelcomeEmail(to: user)

        logger.info("User registration completed: \(user.id)")
    }
}
```

### Configuration Service Pattern

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

        // Always has configuration values
    }
}
```

## See Also

- [@Inject Property Wrapper](./inject.md) - For optional dependency injection
- [@Factory Property Wrapper](./factory.md) - For factory-based injection
- [Property Wrappers Guide](../guide/propertyWrappers.md) - Comprehensive guide to all property wrappers