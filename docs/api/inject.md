# @Inject Property Wrapper

The `@Inject` property wrapper provides automatic dependency injection for properties in your classes and structs. It's the most commonly used WeaveDI feature for clean dependency management.

## Overview

`@Inject` automatically resolves dependencies from the DI container when the property is first accessed. It provides optional resolution, making your code resilient to missing dependencies.

```swift
import WeaveDI

class WeatherViewModel: ObservableObject {
    @Inject var weatherService: WeatherService?
    @Inject var logger: LoggerProtocol?

    func loadWeather() {
        logger?.info("Loading weather data...")
        weatherService?.fetchCurrentWeather()
    }
}
```

## Basic Usage

### Simple Injection

```swift
class UserViewController: UIViewController {
    @Inject var userService: UserService?

    override func viewDidLoad() {
        super.viewDidLoad()
        userService?.loadUserData()
    }
}
```

### With Protocol Types

Always inject protocols rather than concrete types for better testability:

```swift
// ✅ Good - inject protocol
@Inject var networkClient: NetworkClientProtocol?

// ❌ Avoid - inject concrete type
@Inject var networkClient: URLSessionNetworkClient?
```

## Real-World Examples

### CountApp with @Inject (from Tutorial)

Based on our actual tutorial code:

```swift
/// Counter Repository using @Inject for dependencies
class UserDefaultsCounterRepository: CounterRepository {
    /// WeaveDI를 통해 Logger 주입
    @Inject var logger: LoggerProtocol?

    func getCurrentCount() async -> Int {
        let count = UserDefaults.standard.integer(forKey: "saved_count")
        logger?.info("📊 현재 카운트 로드: \(count)")
        return count
    }

    func saveCount(_ count: Int) async {
        UserDefaults.standard.set(count, forKey: "saved_count")
        logger?.info("💾 카운트 저장: \(count)")
    }
}

/// ViewModel with injected dependencies
@MainActor
class CounterViewModel: ObservableObject {
    @Published var count = 0
    @Published var isLoading = false

    /// Repository and Logger injected via @Inject
    @Inject var repository: CounterRepository?
    @Inject var logger: LoggerProtocol?

    func increment() async {
        guard let repo = repository else { return }

        isLoading = true
        count += 1
        await repo.saveCount(count)
        isLoading = false

        logger?.info("⬆️ 카운트 증가: \(count)")
    }
}
```

### WeatherApp with @Inject

```swift
/// Weather Service with injected HTTP client
class WeatherService: WeatherServiceProtocol {
    @Inject var httpClient: HTTPClientProtocol?
    @Inject var logger: LoggerProtocol?

    func fetchCurrentWeather(for city: String) async throws -> Weather {
        guard let client = httpClient else {
            throw WeatherError.httpClientNotAvailable
        }

        logger?.info("🌤️ Fetching weather for \(city)")
        let data = try await client.fetchData(from: weatherURL(for: city))
        return try JSONDecoder().decode(Weather.self, from: data)
    }
}

/// ViewModel with multiple injected services
@MainActor
class WeatherViewModel: ObservableObject {
    @Published var currentWeather: Weather?
    @Published var isLoading = false

    @Inject var weatherService: WeatherServiceProtocol?
    @Inject var cacheService: CacheServiceProtocol?
    @Inject var logger: LoggerProtocol?

    func loadWeather(for city: String) async {
        logger?.info("📍 Loading weather for \(city)")

        isLoading = true
        defer { isLoading = false }

        do {
            currentWeather = try await weatherService?.fetchCurrentWeather(for: city)
            await cacheWeather()
        } catch {
            logger?.error("❌ Weather loading failed: \(error)")
            await loadCachedWeather()
        }
    }
}
```

## SwiftUI Integration

### With StateObject

```swift
struct CounterView: View {
    @StateObject private var viewModel = CounterViewModel()

    var body: some View {
        VStack {
            Text("\(viewModel.count)")
                .font(.largeTitle)

            Button("Increment") {
                Task { await viewModel.increment() }
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }
}
```

### Direct Injection in Views

```swift
struct SettingsView: View {
    @Inject var settingsService: SettingsService?
    @Inject var logger: LoggerProtocol?

    var body: some View {
        List {
            Toggle("Notifications", isOn: .constant(true))
                .onChange(of: true) { enabled in
                    settingsService?.setNotifications(enabled)
                    logger?.info("🔔 Notifications: \(enabled)")
                }
        }
    }
}
```

## Thread Safety

`@Inject` is thread-safe and can be used across different queues:

```swift
class BackgroundService {
    @Inject var dataProcessor: DataProcessor?

    func processInBackground() {
        DispatchQueue.global(qos: .background).async {
            // Safe to access injected dependency from background queue
            self.dataProcessor?.processLargeDataset()
        }
    }
}
```

## Testing with @Inject

### Mock Injection for Tests

```swift
class UserServiceTests: XCTestCase {
    override func setUp() async throws {
        await DIContainer.resetForTesting()

        await DIContainer.bootstrap { container in
            // Register mocks for testing
            container.register(UserRepository.self) { MockUserRepository() }
            container.register(Logger.self) { MockLogger() }
        }
    }

    func testUserService() {
        let service = UserService()
        // @Inject properties will resolve to mock instances
        XCTAssertTrue(service.repository is MockUserRepository)
    }
}
```

## Error Handling

### Graceful Degradation

```swift
class AnalyticsManager {
    @Inject var analyticsService: AnalyticsService?

    func trackEvent(_ event: String) {
        // Gracefully handle missing dependency
        if let service = analyticsService {
            service.track(event)
        } else {
            print("⚠️ Analytics service not available, event not tracked: \(event)")
        }
    }
}
```

### Validation at Runtime

```swift
class CriticalService {
    @Inject var essentialDependency: EssentialService?

    func performCriticalOperation() {
        guard let dependency = essentialDependency else {
            fatalError("EssentialService must be registered before using CriticalService")
        }

        dependency.performOperation()
    }
}
```

## Performance Considerations

### Lazy Resolution

Dependencies are resolved lazily on first access:

```swift
class ExpensiveService {
    @Inject var heavyDependency: HeavyService? // Not resolved until accessed

    func lightweightOperation() {
        // heavyDependency is not resolved here
        print("Performing lightweight operation")
    }

    func heavyOperation() {
        // heavyDependency is resolved on first access
        heavyDependency?.performHeavyWork()
    }
}
```

### Caching

Once resolved, the dependency reference is cached:

```swift
class CachedService {
    @Inject var service: SomeService?

    func multipleAccesses() {
        service?.method1() // Resolves from container
        service?.method2() // Uses cached reference
        service?.method3() // Uses cached reference
    }
}
```

## Common Patterns

### Repository Pattern

```swift
class DataRepository {
    @Inject var networkClient: NetworkClient?
    @Inject var cacheManager: CacheManager?
    @Inject var logger: Logger?

    func fetchData() async -> Data? {
        // Try cache first
        if let cachedData = await cacheManager?.getCachedData() {
            logger?.info("📱 Using cached data")
            return cachedData
        }

        // Fetch from network
        do {
            let data = try await networkClient?.fetchData()
            await cacheManager?.cache(data)
            logger?.info("🌐 Fetched fresh data")
            return data
        } catch {
            logger?.error("❌ Network fetch failed: \(error)")
            return nil
        }
    }
}
```

### Service Layer

```swift
class UserService {
    @Inject var userRepository: UserRepository?
    @Inject var authService: AuthService?
    @Inject var logger: Logger?

    func getCurrentUser() async -> User? {
        guard let auth = authService,
              let repo = userRepository else {
            logger?.error("Required dependencies not available")
            return nil
        }

        guard let userId = auth.currentUserId else {
            logger?.info("No authenticated user")
            return nil
        }

        return await repo.getUser(id: userId)
    }
}
```

## Best Practices

### 1. Always Use Optionals

`@Inject` provides optional resolution to handle missing dependencies gracefully:

```swift
// ✅ Good
@Inject var service: MyService?

// ❌ Avoid
@Inject var service: MyService // Compiler error
```

### 2. Handle Nil Cases

Always handle the case where injection might fail:

```swift
func performAction() {
    guard let service = injectedService else {
        print("Service not available")
        return
    }
    service.performAction()
}
```

### 3. Inject Protocols, Not Implementations

```swift
// ✅ Good - testable and flexible
@Inject var logger: LoggerProtocol?

// ❌ Avoid - hard to test and mock
@Inject var logger: ConsoleLogger?
```

### 4. Document Dependencies

```swift
class WeatherService {
    /// HTTP client for making network requests
    @Inject var httpClient: HTTPClientProtocol?

    /// Logger for debugging and monitoring
    @Inject var logger: LoggerProtocol?

    /// Cache for offline weather data
    @Inject var cache: CacheServiceProtocol?
}
```

## See Also

- [@Factory Property Wrapper](./factory.md) - For factory-based injection
- [@SafeInject Property Wrapper](./safeInject.md) - For guaranteed injection
- [Property Wrappers Guide](../guide/propertyWrappers.md) - Comprehensive guide to all property wrappers