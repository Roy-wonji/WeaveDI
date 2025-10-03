# @SafeInject Property Wrapper (Deprecated v3.2.0+)

::: danger Deprecated
`@SafeInject` is **deprecated as of v3.2.0**. Please migrate to `@Injected` for modern, TCA-style dependency injection with better type safety and KeyPath-based access.

**Migration Guide:**
```swift
// Old (Deprecated)
@SafeInject(fallback: ConsoleLogger()) var logger: LoggerProtocol

// New (Recommended)
@Injected(\.logger) var logger
// Define fallback in InjectedKey:
struct LoggerKey: InjectedKey {
    static var currentValue: LoggerProtocol = ConsoleLogger()
}
```

See the [@Injected documentation](./injected.md) for complete migration instructions.
:::

The `@SafeInject` property wrapper provided guaranteed dependency injection with compile-time safety and runtime resilience. **It is now superseded by @Injected.**

## Overview

`@SafeInject` fundamentally transforms dependency injection from an optional-based pattern to a guaranteed-resolution pattern. It eliminates the cognitive overhead and boilerplate code associated with optional handling by guaranteeing that a dependency will always be resolved. The wrapper implements multiple fallback strategies when a dependency is not registered in the container, making your code significantly more robust, maintainable, and easier to work with.

**Key Benefits**:
- **Guaranteed Resolution**: Dependencies are never nil, eliminating optional unwrapping
- **Fallback Strategies**: Multiple approaches for handling missing dependencies
- **Code Simplicity**: Cleaner, more readable code without optional handling
- **Runtime Safety**: Prevents crashes from missing dependencies
- **Testing Support**: Built-in fallbacks make testing easier and more reliable

**Performance Characteristics**:
- **Resolution Speed**: Identical to `@Injected` for registered dependencies
- **Fallback Overhead**: Minimal overhead when fallbacks are used
- **Memory Usage**: Small additional memory for storing fallback instances
- **Thread Safety**: Thread-safe resolution and fallback mechanisms

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

**Purpose**: Basic guaranteed dependency injection with explicit fallback instances for robust error handling.

**Pattern Benefits**:
- **Explicit Fallbacks**: Clear, compile-time definition of fallback behavior
- **Type Safety**: Fallback instances must conform to the same protocol
- **Immediate Availability**: Dependencies are available immediately without optional checks
- **Error Prevention**: Eliminates runtime errors from missing dependencies

**Use Cases**:
- Services that must always function, even without proper registration
- Development environments where not all services may be configured
- Graceful degradation scenarios
- Testing environments with partial dependency mocking

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

**Purpose**: Lazy fallback creation using closure-based factory patterns for memory-efficient fallback management.

**Factory Benefits**:
- **Lazy Creation**: Fallback instances created only when needed
- **Memory Efficiency**: Avoids creating unused fallback instances
- **Dynamic Creation**: Fallbacks can be created with runtime parameters
- **Flexible Configuration**: Different creation patterns based on conditions

**Performance Optimization**:
- **Deferred Instantiation**: Fallbacks created only when container resolution fails
- **Resource Management**: Efficient use of memory for fallback objects
- **Initialization Control**: Control over when and how fallbacks are created

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

**Purpose**: Provide a concrete, pre-instantiated fallback instance for immediate availability and predictable behavior.

**Strategy Benefits**:
- **Immediate Availability**: Fallback instance is ready for immediate use
- **Predictable Behavior**: Known fallback implementation with expected behavior
- **Simple Configuration**: Straightforward setup with minimal complexity
- **Testing Reliability**: Consistent fallback behavior across test runs

**Best Practices**:
- **Lightweight Instances**: Use minimal, efficient fallback implementations
- **Safe Operations**: Ensure fallback instances have no harmful side effects
- **Clear Semantics**: Choose fallbacks that clearly indicate their purpose (e.g., NoOpAnalytics)
- **Resource Management**: Consider memory and resource usage of fallback instances

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

**Purpose**: Use closure-based factory patterns to create fallback instances dynamically, providing flexibility and memory efficiency.

**Factory Pattern Benefits**:
- **Dynamic Creation**: Create fallbacks with runtime-specific parameters
- **Memory Efficiency**: Instances created only when container resolution fails
- **Flexible Configuration**: Different creation logic based on runtime conditions
- **Resource Optimization**: Avoid allocating resources for unused fallbacks

**Implementation Strategies**:
- **Parameter Injection**: Pass runtime parameters to factory closures
- **Environment Detection**: Create different fallbacks based on environment
- **Configuration Access**: Use configuration values during fallback creation
- **Dependency Chaining**: Create fallbacks that use other dependencies

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

**Purpose**: Leverage Swift protocol extensions to provide default implementations that serve as comprehensive fallback strategies.

**Protocol Extension Benefits**:
- **Default Behavior**: Protocols provide sensible default implementations
- **Code Reuse**: Shared default behavior across multiple implementations
- **Extensibility**: Easy to override specific methods while keeping defaults
- **Type Safety**: All conforming types automatically get default behavior

**Design Patterns**:
- **Safe Defaults**: Default implementations that are safe for production use
- **Graceful Degradation**: Defaults that provide reduced functionality rather than failure
- **Configuration Fallbacks**: Default values for configuration services
- **Mock-like Behavior**: Defaults that simulate real behavior for testing

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

**Comparison Analysis**: `@SafeInject` vs `@Injected` demonstrates the trade-offs between safety and flexibility in dependency injection patterns.

**@Injected Characteristics**:
- **Optional Dependencies**: Returns optional values that require unwrapping
- **Explicit Nil Handling**: Requires guard statements and optional chaining
- **Runtime Flexibility**: Can handle truly optional dependencies
- **Memory Efficiency**: No fallback instances stored in memory

**@SafeInject Characteristics**:
- **Guaranteed Dependencies**: Never returns nil, always provides working instances
- **Simplified Code**: No optional unwrapping or guard statements needed
- **Built-in Resilience**: Automatic fallback when dependencies are missing
- **Predictable Behavior**: Always have working dependencies, even if they're fallbacks

**Performance Impact**:
- **@Injected**: Slightly faster for registered dependencies (no fallback overhead)
- **@SafeInject**: Minimal overhead for fallback storage, identical speed for registered dependencies
- **Memory**: @SafeInject uses additional memory for fallback instances
- **Code Size**: @SafeInject reduces code size by eliminating optional handling

```swift
// With @Injected (optional handling required)
class UserServiceWithInject {
    @Injected var logger: LoggerProtocol?
    @Injected var repository: UserRepository?

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

**Purpose**: `@SafeInject` seamlessly integrates with WeaveDI's standard dependency registration system, providing fallback behavior only when needed.

**Resolution Priority**:
1. **Container Resolution**: First attempts to resolve from WeaveDI container
2. **Fallback Resolution**: Uses provided fallback if container resolution fails
3. **Type Safety**: Both container and fallback instances must conform to the same protocol

**Integration Benefits**:
- **Transparent Operation**: Works identically to `@Injected` when dependencies are registered
- **Fallback Safety**: Automatic fallback when dependencies are missing
- **Development Flexibility**: Easy switching between registered and fallback dependencies
- **Testing Support**: Simplified testing with reliable fallback behavior

SafeInject works with normal dependency registration:

```swift
await WeaveDI.Container.bootstrap { container in
    container.register(LoggerProtocol.self) { FileLogger() }
    container.register(UserRepository.self) { DatabaseUserRepository() }
}

// SafeInject will use registered dependencies when available
let service = UserServiceWithSafeInject() // Uses FileLogger and DatabaseUserRepository
```

### Fallback When Not Registered

**Purpose**: Demonstrate graceful degradation when dependencies are not registered in the container.

**Fallback Activation Scenarios**:
- **Missing Registration**: Dependency not registered in container
- **Container Reset**: Container cleared during testing or development
- **Partial Configuration**: Some dependencies registered, others missing
- **Environment Differences**: Different registrations across environments

**Fallback Behavior**:
- **Automatic Switching**: Seamless transition to fallback implementation
- **No Error Throwing**: No exceptions or crashes from missing dependencies
- **Consistent Interface**: Fallback provides same interface as registered dependency
- **Transparent Operation**: Calling code unaware of fallback vs registered dependency

```swift
// If no dependencies are registered
let service = UserServiceWithSafeInject() // Uses ConsoleLogger and MockUserRepository fallbacks
```

## Thread Safety

**Thread Safety Guarantees**: `@SafeInject` provides comprehensive thread safety through multiple layers of protection and concurrent access handling.

**Safety Mechanisms**:
- **Container Thread Safety**: Underlying WeaveDI container is thread-safe
- **Fallback Thread Safety**: Fallback resolution is protected against race conditions
- **Instance Thread Safety**: Fallback instances must be thread-safe (implementation responsibility)
- **Property Access Safety**: Property wrapper ensures thread-safe access to resolved dependencies

**Concurrency Considerations**:
- **Parallel Access**: Multiple threads can safely access `@SafeInject` properties
- **Resolution Caching**: Resolved dependencies are cached safely across threads
- **Fallback Creation**: Fallback factory closures executed safely in concurrent environments
- **Memory Barriers**: Automatic memory barrier handling for consistent visibility

**Performance in Concurrent Environments**:
- **Scalable Access**: Performance scales well with concurrent thread access
- **Minimal Contention**: Low lock contention for dependency resolution
- **Cache Efficiency**: Resolved dependencies cached for fast subsequent access

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

**Testing Strategy**: `@SafeInject` provides superior testing capabilities through guaranteed dependency availability and flexible fallback configuration.

**Testing Benefits**:
- **Reliable Test Dependencies**: Tests never fail due to missing dependencies
- **Flexible Mock Strategies**: Easy switching between real and mock dependencies
- **Fallback Testing**: Verify application behavior when services are unavailable
- **Integration Testing**: Test complete systems with partial mocking

**Test Configuration Patterns**:
- **Full Mock Environment**: Register all dependencies as mocks
- **Partial Mock Environment**: Register some mocks, rely on fallbacks for others
- **Fallback Testing**: Test with no registrations to verify fallback behavior
- **Mixed Environment**: Combine real and mock dependencies for integration testing

```swift
class SafeInjectServiceTests: XCTestCase {

    func testWithRegisteredDependencies() async throws {
        // Register test dependencies
        await WeaveDI.Container.bootstrap { container in
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
        await WeaveDI.Container.resetForTesting()

        let service = UserServiceWithSafeInject()

        // Uses fallback dependencies
        await service.createUser(name: "Test User")

        // Verify fallback behavior works correctly
    }
}
```

### Mocking Fallbacks

**Purpose**: Advanced testing patterns that allow custom fallback configuration for specific test scenarios.

**Custom Fallback Benefits**:
- **Test-Specific Mocks**: Provide specialized mocks for specific test scenarios
- **Behavior Verification**: Verify interactions with custom test doubles
- **State Control**: Control initial state and behavior of fallback dependencies
- **Isolation Testing**: Test components in complete isolation with controlled fallbacks

**Advanced Testing Patterns**:
- **Constructor Injection**: Override fallbacks through constructor parameters
- **Property Injection**: Modify fallbacks after instance creation
- **Protocol Mocking**: Use protocol-based mocks for maximum flexibility
- **State Verification**: Verify state changes in custom fallback instances

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

**Memory Management Strategy**: `@SafeInject` implements efficient memory management while maintaining guaranteed dependency availability.

**Memory Characteristics**:
- **Fallback Storage**: Maintains reference to fallback instance for immediate availability
- **Resolution Caching**: Caches resolved dependencies to avoid repeated container lookups
- **Lifecycle Management**: Fallback instances follow normal Swift memory management rules
- **Resource Optimization**: Lazy factory closures avoid creating unnecessary instances

**Memory Optimization Guidelines**:
- **Lightweight Fallbacks**: Choose minimal implementations for fallback instances
- **Resource Sharing**: Share resources between fallback instances when appropriate
- **Lazy Creation**: Use factory closures for expensive fallback instances
- **Memory Monitoring**: Monitor memory usage patterns in production environments

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

**Purpose**: Optimize memory usage and initialization performance through deferred fallback creation.

**Lazy Creation Benefits**:
- **Memory Efficiency**: Fallback instances created only when container resolution fails
- **Initialization Performance**: Avoid expensive fallback creation during property wrapper initialization
- **Resource Conservation**: Don't allocate resources for unused fallbacks
- **Dynamic Configuration**: Create fallbacks with runtime-specific parameters

**Implementation Strategies**:
- **Closure-Based Factories**: Use closures to defer instance creation
- **Conditional Creation**: Create different fallbacks based on runtime conditions
- **Resource Management**: Manage expensive resources efficiently in fallback instances
- **Performance Monitoring**: Track fallback creation patterns and performance impact

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

**Strategy**: Select fallback implementations that provide safe, predictable behavior without harmful side effects.

**Fallback Selection Criteria**:
- **Safety First**: Fallbacks should never cause data loss or security issues
- **Minimal Side Effects**: Avoid fallbacks that perform destructive operations
- **Clear Intent**: Use fallbacks that clearly indicate their purpose (e.g., NoOp, Mock, Console)
- **Resource Efficiency**: Choose lightweight implementations that don't consume excessive resources

**Fallback Categories**:
- **No-Op Implementations**: Safe fallbacks that perform no operations
- **Console/Debug Implementations**: Fallbacks that log to console for debugging
- **In-Memory Implementations**: Temporary fallbacks that work without external dependencies
- **Mock Implementations**: Test-friendly fallbacks that simulate real behavior

**Risk Assessment**:
- **Production Safety**: Ensure fallbacks are safe for production environments
- **Data Integrity**: Verify fallbacks don't compromise data consistency
- **Security Implications**: Assess security impact of fallback implementations
- **Performance Impact**: Monitor performance characteristics of fallback implementations

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

**Documentation Strategy**: Clearly document fallback behavior to help team members understand the implications of missing dependencies.

**Documentation Elements**:
- **Fallback Purpose**: Explain why specific fallbacks were chosen
- **Behavior Description**: Document what the fallback implementation does
- **Safety Guarantees**: Describe the safety characteristics of fallbacks
- **Performance Impact**: Note any performance implications of fallback usage

**Documentation Best Practices**:
- **Inline Comments**: Add clear comments explaining fallback choices
- **README Documentation**: Document fallback strategies in project documentation
- **Code Examples**: Provide examples of expected fallback behavior
- **Migration Notes**: Document any changes to fallback behavior over time

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

**Testing Strategy**: Comprehensive testing should verify both normal dependency resolution and fallback behavior.

**Dual Path Testing Benefits**:
- **Complete Coverage**: Ensure both success and fallback scenarios work correctly
- **Behavior Verification**: Verify that fallbacks provide expected functionality
- **Regression Prevention**: Catch issues in either resolution path
- **Integration Confidence**: Build confidence in system reliability

**Testing Approaches**:
- **Registered Dependency Tests**: Test with all dependencies properly registered
- **Fallback Dependency Tests**: Test with missing or unregistered dependencies
- **Mixed Scenario Tests**: Test with some dependencies registered, others missing
- **Performance Tests**: Verify performance characteristics of both paths

**Test Organization**:
- **Separate Test Cases**: Create distinct tests for each scenario
- **Parametrized Tests**: Use test parameters to cover multiple scenarios
- **Integration Suites**: Include both paths in integration test suites
- **Continuous Testing**: Ensure both paths are tested in CI/CD pipelines

```swift
func testServiceWithRegisteredDependencies() {
    // Test with real dependencies
}

func testServiceWithFallbackDependencies() {
    // Test with fallback dependencies
}
```

### 4. Use for Critical Dependencies

**Usage Strategy**: Apply `@SafeInject` strategically to dependencies that are critical for application functionality.

**Critical Dependency Identification**:
- **Core Functionality**: Dependencies required for basic application operation
- **Error Handling**: Services needed for proper error handling and recovery
- **Security Services**: Dependencies critical for application security
- **Data Integrity**: Services required for maintaining data consistency

**Decision Framework**:
- **Must Always Work**: Use `@SafeInject` for dependencies that cannot be optional
- **Can Be Optional**: Use `@Injected` for features that can be disabled gracefully
- **Enhanced Features**: Use `@Injected` for dependencies that provide enhanced but non-essential functionality
- **Development Tools**: Use appropriate wrapper based on development vs production needs

**Architecture Considerations**:
- **Service Layers**: Different injection strategies for different architectural layers
- **Feature Flags**: Consider feature availability when choosing injection strategies
- **Environment Differences**: Different strategies for different deployment environments
- **Migration Paths**: Plan for transitioning between injection strategies as requirements evolve

```swift
class CriticalService {
    // ✅ Use SafeInject for dependencies that must always work
    @SafeInject(fallback: EmergencyHandler())
    var emergencyHandler: EmergencyHandler

    // ✅ Use @Injected for optional dependencies
    @Injected var optionalFeature: OptionalFeature?
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

- [@Injected Property Wrapper](./inject.md) - For optional dependency injection
- [@Factory Property Wrapper](./factory.md) - For factory-based injection
- [Property Wrappers Guide](../guide/propertyWrappers.md) - Comprehensive guide to all property wrappers