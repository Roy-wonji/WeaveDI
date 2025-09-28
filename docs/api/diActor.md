# DIActor API Reference

DIActor provides thread-safe dependency injection operations using Swift's actor model. It ensures that all DI container operations are performed safely in concurrent environments.

## Overview

DIActor wraps the DI container in an actor to provide thread-safe access to dependency registration and resolution. This is particularly useful in concurrent environments where multiple tasks might be accessing the DI container simultaneously.

```swift
import WeaveDI

// Thread-safe dependency registration
@DIActor
func setupDependencies() async {
    await DIActor.shared.register(UserService.self) {
        UserServiceImpl()
    }

    await DIActor.shared.register(Logger.self) {
        FileLogger()
    }
}

// Thread-safe dependency resolution
@DIActor
func getUserService() async -> UserService? {
    return await DIActor.shared.resolve(UserService.self)
}
```

## Core Operations

### Registration

#### `register(_:factory:)`

Registers a dependency with thread-safe operations:

```swift
@DIActor
func registerServices() async {
    // Thread-safe registration
    await DIActor.shared.register(NetworkService.self) {
        URLSessionNetworkService()
    }

    await DIActor.shared.register(CacheService.self) {
        CoreDataCacheService()
    }
}
```

#### Bulk Registration

```swift
@DIActor
func registerAllServices() async {
    let services: [(Any.Type, () -> Any)] = [
        (LoggerProtocol.self, { ConsoleLogger() }),
        (NetworkClient.self, { URLSessionNetworkClient() }),
        (DatabaseService.self, { CoreDataService() })
    ]

    for (serviceType, factory) in services {
        // Each registration is thread-safe
        await DIActor.shared.register(serviceType, factory: factory)
    }
}
```

### Resolution

#### `resolve(_:)`

Thread-safe dependency resolution:

```swift
@DIActor
func getConfiguredServices() async -> (UserService?, Logger?) {
    let userService = await DIActor.shared.resolve(UserService.self)
    let logger = await DIActor.shared.resolve(Logger.self)

    return (userService, logger)
}
```

### Concurrent Operations

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

## Real-World Examples from Tutorial

### CountApp with DIActor

```swift
/// Thread-safe counter service setup using DIActor
@DIActor
func setupCounterServices() async {
    print("🧵 Setting up counter services on background thread...")

    // Register counter repository with thread safety
    await DIActor.shared.register(CounterRepository.self) {
        UserDefaultsCounterRepository()
    }

    // Register logger
    await DIActor.shared.register(LoggerProtocol.self) {
        FileLogger(filename: "counter.log")
    }

    print("✅ Counter services registered safely")
}

/// Thread-safe counter operations
actor CounterActor {
    private var internalCount = 0

    @Inject var repository: CounterRepository?
    @Inject var logger: LoggerProtocol?

    func increment() async -> Int {
        internalCount += 1

        // Safe repository access
        await repository?.saveCount(internalCount)
        logger?.info("🔢 Count incremented to \(internalCount)")

        return internalCount
    }

    func getCurrentCount() async -> Int {
        // Ensure we have the latest from repository
        if let repoCount = await repository?.getCurrentCount() {
            internalCount = repoCount
        }
        return internalCount
    }
}

/// ViewModel using DIActor for safe initialization
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
        // Ensure services are available
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

### WeatherApp with DIActor

```swift
/// Weather service initialization with DIActor
@DIActor
func setupWeatherServices() async {
    print("🌤️ Setting up weather services...")

    // Network layer
    await DIActor.shared.register(HTTPClientProtocol.self) {
        URLSessionHTTPClient()
    }

    // Weather service with dependency resolution
    await DIActor.shared.register(WeatherServiceProtocol.self) {
        let httpClient = await DIActor.shared.resolve(HTTPClientProtocol.self)!
        return WeatherService(httpClient: httpClient)
    }

    // Cache service
    await DIActor.shared.register(CacheServiceProtocol.self) {
        CoreDataCacheService()
    }

    print("✅ Weather services registered")
}

/// Thread-safe weather data actor
actor WeatherDataActor {
    private var cachedWeather: [String: Weather] = [:]
    private var lastUpdateTime: [String: Date] = [:]

    @Inject var weatherService: WeatherServiceProtocol?
    @Inject var cacheService: CacheServiceProtocol?
    @Inject var logger: LoggerProtocol?

    func getWeather(for city: String, forceRefresh: Bool = false) async throws -> Weather {
        let cacheKey = "weather_\(city)"

        // Check if we need to refresh
        if !forceRefresh,
           let cached = cachedWeather[city],
           let lastUpdate = lastUpdateTime[city],
           Date().timeIntervalSince(lastUpdate) < 300 { // 5 minutes
            logger?.info("📱 Using cached weather for \(city)")
            return cached
        }

        // Fetch fresh data
        guard let service = weatherService else {
            throw WeatherError.serviceUnavailable
        }

        logger?.info("🌐 Fetching fresh weather for \(city)")
        let weather = try await service.fetchCurrentWeather(for: city)

        // Update cache
        cachedWeather[city] = weather
        lastUpdateTime[city] = Date()

        // Persist to storage
        try? await cacheService?.store(weather, forKey: cacheKey)

        logger?.info("✅ Weather updated for \(city)")
        return weather
    }

    func clearCache() {
        cachedWeather.removeAll()
        lastUpdateTime.removeAll()
        logger?.info("🗑️ Weather cache cleared")
    }
}
```

## Concurrent Initialization Patterns

### Parallel Service Setup

```swift
@DIActor
func setupServicesInParallel() async {
    print("⚡ Starting parallel service initialization...")

    await withTaskGroup(of: Void.self) { group in
        // Core services
        group.addTask {
            await DIActor.shared.register(LoggerProtocol.self) {
                FileLogger()
            }
            print("📝 Logger registered")
        }

        // Network services
        group.addTask {
            await DIActor.shared.register(HTTPClientProtocol.self) {
                URLSessionHTTPClient()
            }
            print("🌐 HTTP Client registered")
        }

        // Database services
        group.addTask {
            await DIActor.shared.register(DatabaseService.self) {
                CoreDataService()
            }
            print("🗄️ Database registered")
        }

        // Cache services
        group.addTask {
            await DIActor.shared.register(CacheServiceProtocol.self) {
                InMemoryCacheService()
            }
            print("💾 Cache registered")
        }
    }

    print("✅ All services registered in parallel")
}
```

### Dependent Service Registration

```swift
@DIActor
func setupDependentServices() async {
    // Register base services first
    await DIActor.shared.register(LoggerProtocol.self) {
        FileLogger()
    }

    await DIActor.shared.register(HTTPClientProtocol.self) {
        URLSessionHTTPClient()
    }

    // Then register dependent services
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

## Testing with DIActor

### Test Setup

```swift
class DIActorTests: XCTestCase {

    override func setUp() async throws {
        // Reset DIActor state for testing
        await DIActor.shared.reset()
    }

    func testConcurrentRegistration() async throws {
        // Test concurrent registration safety
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await DIActor.shared.register(TestService.self, name: "service_\(i)") {
                        TestServiceImpl(id: i)
                    }
                }
            }
        }

        // Verify all services were registered
        for i in 0..<100 {
            let service = await DIActor.shared.resolve(TestService.self, name: "service_\(i)")
            XCTAssertNotNil(service)
        }
    }

    func testConcurrentResolution() async throws {
        // Register a service
        await DIActor.shared.register(TestService.self) {
            TestServiceImpl(id: 1)
        }

        // Test concurrent resolution
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

            // All resolutions should succeed
            XCTAssertEqual(resolvedServices.count, 100)
            XCTAssertTrue(resolvedServices.allSatisfy { $0 != nil })
        }
    }
}
```

### Performance Testing

```swift
class DIActorPerformanceTests: XCTestCase {

    func testRegistrationPerformance() async throws {
        measure {
            Task {
                await DIActor.shared.reset()

                for i in 0..<1000 {
                    await DIActor.shared.register(TestService.self, name: "service_\(i)") {
                        TestServiceImpl(id: i)
                    }
                }
            }
        }
    }

    func testResolutionPerformance() async throws {
        // Setup services
        for i in 0..<1000 {
            await DIActor.shared.register(TestService.self, name: "service_\(i)") {
                TestServiceImpl(id: i)
            }
        }

        measure {
            Task {
                for i in 0..<1000 {
                    _ = await DIActor.shared.resolve(TestService.self, name: "service_\(i)")
                }
            }
        }
    }
}
```

## Integration with SwiftUI

### App Initialization

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
                    // Ensure services are ready
                    await ensureServicesReady()
                }
        }
    }

    @DIActor
    private func initializeAppServices() async {
        await setupCounterServices()
        await setupWeatherServices()
        print("🚀 App services initialized")
    }

    private func ensureServicesReady() async {
        // Wait for critical services
        while await DIActor.shared.resolve(LoggerProtocol.self) == nil {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
}
```

### ViewModel Integration

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
        // Wait for essential services
        while await DIActor.shared.resolve(LoggerProtocol.self) == nil ||
              await DIActor.shared.resolve(WeatherServiceProtocol.self) == nil {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
}
```

## Best Practices

### 1. Use for Concurrent Initialization

```swift
// ✅ Good - use DIActor for concurrent setup
@DIActor
func setupServices() async {
    await withTaskGroup(of: Void.self) { group in
        group.addTask { await setupNetworkServices() }
        group.addTask { await setupDatabaseServices() }
        group.addTask { await setupCacheServices() }
    }
}
```

### 2. Minimize Actor Boundary Crossings

```swift
// ✅ Good - batch operations
@DIActor
func setupRelatedServices() async {
    await DIActor.shared.register(ServiceA.self) { ServiceAImpl() }
    await DIActor.shared.register(ServiceB.self) { ServiceBImpl() }
    await DIActor.shared.register(ServiceC.self) { ServiceCImpl() }
}

// ❌ Avoid - multiple separate actor calls
func setupServicesInefficiently() async {
    await DIActor.shared.register(ServiceA.self) { ServiceAImpl() }
    // ... other non-actor code
    await DIActor.shared.register(ServiceB.self) { ServiceBImpl() }
    // ... more non-actor code
}
```

### 3. Handle Dependencies Carefully

```swift
@DIActor
func setupWithDependencies() async {
    // Register dependencies first
    await DIActor.shared.register(LoggerProtocol.self) { FileLogger() }

    // Then register dependent services
    await DIActor.shared.register(UserService.self) {
        let logger = await DIActor.shared.resolve(LoggerProtocol.self)!
        return UserService(logger: logger)
    }
}
```

## Common Patterns

### Service Manager Pattern

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

### Graceful Initialization

```swift
@DIActor
func initializeWithFallbacks() async {
    do {
        // Try to initialize primary services
        await setupPrimaryServices()
    } catch {
        print("⚠️ Primary services failed, using fallbacks")
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

## See Also

- [UnifiedDI API](./unifiedDI.md) - Simplified DI interface
- [Bootstrap API](./bootstrap.md) - Container initialization
- [Concurrency Integration Guide](../tutorial/concurrencyIntegration.md) - Swift concurrency patterns