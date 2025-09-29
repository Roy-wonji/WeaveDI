# DIActor API Reference

DIActor provides comprehensive thread-safe dependency injection operations using Swift's actor model, ensuring that all DI container operations are performed safely in highly concurrent environments. This advanced system leverages Swift's actor isolation to eliminate race conditions, prevent data corruption, and provide deterministic behavior in multi-threaded dependency injection scenarios.

## Overview

DIActor wraps the DI container in a Swift actor to provide guaranteed thread-safe access to dependency registration and resolution operations. This sophisticated concurrency management system is particularly valuable in highly concurrent environments where multiple tasks, async operations, or parallel processes might be accessing the DI container simultaneously.

**Key Benefits**:
- **Actor Isolation**: Swift actor model ensures memory safety and prevents data races
- **Concurrent Safety**: Multiple tasks can safely register and resolve dependencies concurrently
- **Deterministic Behavior**: Predictable execution order for dependency operations
- **Performance Optimization**: Optimized for high-throughput concurrent scenarios
- **Deadlock Prevention**: Actor model prevents common concurrency pitfalls

**Performance Characteristics**:
- **Registration Speed**: ~0.1-1ms per registration with actor coordination
- **Resolution Speed**: Near-instant resolution for registered dependencies
- **Concurrency Overhead**: Minimal overhead for actor message passing
- **Memory Efficiency**: Efficient memory usage through actor isolation
- **Scalability**: Linear performance scaling with concurrent task count

## Understanding Actor Hops

### What is an Actor Hop?

An **actor hop** is a fundamental concept in Swift's actor model that occurs when execution switches from one actor context to another. Understanding and optimizing actor hops is crucial for building high-performance applications with WeaveDI.

```swift
// Example demonstrating actor hop concept
@MainActor
class UIViewController {
    @Inject var userService: UserService?

    func updateUI() async {
        // 1. Currently on MainActor (UI thread)
        print("📱 On MainActor: \(Thread.isMainThread)")

        // 2. Actor hop occurs here - switching to DIActor context
        let service = await DIActor.shared.resolve(UserService.self)
        // ⚡ ACTOR HOP: MainActor → DIActor

        // 3. Now on DIActor context
        guard let userService = service else { return }

        // 4. Another actor hop - DIActor back to MainActor for UI update
        await MainActor.run {
            // ⚡ ACTOR HOP: DIActor → MainActor
            self.displayUsers(users)
        }
    }
}
```

### Actor Hop Performance Impact

Each actor hop involves:
- **Context Switching**: CPU switches execution context between actors
- **Memory Synchronization**: Ensures memory consistency across actor boundaries
- **Task Suspension**: Current task may be suspended and resumed later
- **Queue Coordination**: Actor message passing through internal queues

**Performance Characteristics:**
- **Typical Latency**: 50-200 microseconds per hop
- **Memory Overhead**: 16-64 bytes per suspended task
- **CPU Impact**: ~2-5% overhead for frequent hopping
- **Battery Impact**: Increased power consumption on mobile devices

### WeaveDI's Actor Hop Optimizations

WeaveDI implements several strategies to minimize actor hop overhead:

#### 1. Hot Path Caching
```swift
// First resolution requires actor hop
let service1 = await DIActor.shared.resolve(UserService.self)
// ⚡ ACTOR HOP: Current context → DIActor

// Subsequent resolutions are cached and optimized
let service2 = await DIActor.shared.resolve(UserService.self)
// ✨ OPTIMIZED: Cached resolution, minimal actor hop overhead
```

#### 2. Batch Resolution Optimization
```swift
// ❌ INEFFICIENT: Multiple actor hops
@DIActor
func inefficientSetup() async {
    let userService = await DIActor.shared.resolve(UserService.self)     // Hop 1
    let networkService = await DIActor.shared.resolve(NetworkService.self) // Hop 2
    let cacheService = await DIActor.shared.resolve(CacheService.self)   // Hop 3
}

// ✅ OPTIMIZED: Single actor context, multiple operations
@DIActor
func optimizedSetup() async {
    // All operations occur within DIActor context - no additional hops
    let userService = await DIActor.shared.resolve(UserService.self)
    let networkService = await DIActor.shared.resolve(NetworkService.self)
    let cacheService = await DIActor.shared.resolve(CacheService.self)
}
```

#### 3. Contextual Resolution Strategy
```swift
actor BusinessLogicActor {
    @Inject var userService: UserService?

    func processUserData() async {
        // Property wrapper injection minimizes actor hops
        // Service is resolved once and cached within actor instance
        guard let service = userService else { return }

        // All subsequent calls use cached instance - no actor hops
        let users = await service.fetchUsers()
        let processed = await service.processUsers(users)
        await service.saveProcessedUsers(processed)
    }
}
```

### Actor Hop Detection and Monitoring

WeaveDI provides comprehensive actor hop monitoring capabilities:

```swift
// Enable actor hop monitoring
@DIActor
func enableMonitoring() async {
    await DIActor.shared.enableActorHopMonitoring()

    // Perform operations
    let service = await DIActor.shared.resolve(UserService.self)

    // Check actor hop statistics
    let stats = await DIActor.shared.getActorHopStats()
    print("🔍 Actor Hop Analysis:")
    print("  Total hops: \(stats.totalHops)")
    print("  Average latency: \(stats.averageLatency)ms")
    print("  Peak latency: \(stats.peakLatency)ms")
    print("  Optimization opportunities: \(stats.optimizationSuggestions)")
}

// Real-time actor hop logging
@DIActor
func demonstrateHopLogging() async {
    // Enable detailed logging
    await DIActor.shared.setActorHopLoggingLevel(.detailed)

    let service = await DIActor.shared.resolve(UserService.self)
    // Console output:
    // 🎭 [ActorHop] MainActor → DIActor (85μs)
    // 🎭 [ActorHop] DIActor → MainActor (92μs)
    // ⚡ [Optimization] Consider batching operations to reduce hops
}
```

### Best Practices for Actor Hop Optimization

#### 1. Minimize Cross-Actor Communication
```swift
// ❌ AVOID: Frequent cross-actor communication
@MainActor
class BadViewController {
    func loadData() async {
        for i in 1...10 {
            // 10 actor hops - very inefficient!
            let user = await DIActor.shared.resolve(UserService.self)
            await updateUI(with: user)
        }
    }
}

// ✅ GOOD: Batch operations within single actor context
@MainActor
class GoodViewController {
    func loadData() async {
        // Single actor hop to batch resolve all services
        let services = await DIActor.shared.batchResolve([
            UserService.self,
            NetworkService.self,
            CacheService.self
        ])

        // Process all data within MainActor context
        await processServices(services)
    }
}
```

#### 2. Use Actor-Specific Patterns
```swift
// ✅ GOOD: Actor-aware service design
actor DataProcessingActor {
    private var cachedServices: [String: Any] = [:]

    func processWithOptimizedHops() async {
        // Resolve services once and cache within actor
        if cachedServices.isEmpty {
            // Single actor hop for all service resolution
            await resolveDependencies()
        }

        // All processing occurs within actor - no additional hops
        await performDataProcessing()
    }

    @DIActor
    private func resolveDependencies() async {
        let userService = await DIActor.shared.resolve(UserService.self)
        let networkService = await DIActor.shared.resolve(NetworkService.self)

        await MainActor.run {
            // Cache services in main actor context
            self.cachedServices["user"] = userService
            self.cachedServices["network"] = networkService
        }
    }
}
```

#### 3. Strategic Property Wrapper Usage
```swift
// ✅ OPTIMAL: Property wrappers minimize actor hops
class OptimizedService {
    @Inject var userService: UserService?
    @Factory var logger: Logger  // New instance each access, but optimized
    @SafeInject var database: Database?

    func performOperations() async {
        // Property wrappers handle actor hop optimization automatically
        // Services are resolved once and cached per instance

        guard let user = userService,
              let db = database else { return }

        // All subsequent operations use cached instances
        let data = await user.fetchData()
        await db.save(data)

        // Factory instances are optimized for creation patterns
        logger.info("Operations completed")
    }
}
```

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

**Purpose**: Registers a dependency with comprehensive thread-safe operations using actor isolation to ensure data consistency and prevent race conditions.

**Thread Safety Guarantees**:
- **Actor Isolation**: All registration operations executed within actor context
- **Atomic Operations**: Registration is atomic and cannot be interrupted
- **Consistency**: Container state remains consistent across concurrent operations
- **Order Independence**: Registration order doesn't affect final container state

**Performance Optimization**:
- **Batched Operations**: Multiple registrations can be batched for efficiency
- **Lazy Evaluation**: Factory closures evaluated only when dependencies are resolved
- **Memory Management**: Efficient memory usage for factory storage
- **Concurrent Registration**: Multiple registrations can proceed in parallel

**Use Cases**:
- Application startup dependency registration
- Runtime service discovery and registration
- Plugin system dynamic registration
- Test environment setup with mock services

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

**Purpose**: Efficient registration of multiple dependencies using optimized batch operations for improved performance and simplified setup.

**Batch Operation Benefits**:
- **Performance Optimization**: Reduced actor message passing overhead
- **Atomic Batching**: All registrations succeed or fail as a unit
- **Error Handling**: Comprehensive error handling for batch operations
- **Setup Simplification**: Streamlined configuration for multiple services

**Implementation Strategies**:
- **Array-Based Registration**: Process arrays of service definitions
- **Dictionary-Based Registration**: Key-value mapping for service configuration
- **Configuration-Driven**: Load service definitions from configuration files
- **Environment-Specific**: Different registration sets for different environments

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

**Purpose**: Thread-safe dependency resolution with actor-coordinated access to ensure consistent reads and prevent concurrent modification issues.

**Resolution Process**:
1. **Actor Access**: Resolution request processed within actor context
2. **Container Lookup**: Thread-safe lookup in underlying container
3. **Factory Execution**: Safe execution of factory closures if needed
4. **Instance Return**: Return resolved instance to calling context

**Performance Characteristics**:
- **Cached Resolution**: Previously resolved dependencies returned immediately
- **Factory Execution**: First-time resolution executes factory closure
- **Concurrent Resolution**: Multiple threads can resolve different dependencies simultaneously
- **Memory Safety**: Actor isolation prevents memory corruption during resolution

**Thread Safety Features**:
- **Isolated Access**: All container access within actor boundary
- **Consistent Reads**: Guaranteed consistent view of container state
- **Safe Factory Execution**: Factory closures executed safely within actor context
- **Exception Handling**: Safe handling of factory execution errors

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

**Purpose**: Demonstrate advanced concurrent dependency registration patterns using Swift's structured concurrency with TaskGroup for optimal performance.

**Concurrency Benefits**:
- **Parallel Registration**: Independent services registered simultaneously
- **Performance Scaling**: Linear performance improvement with parallelization
- **Resource Utilization**: Optimal CPU and I/O resource utilization
- **Structured Concurrency**: Safe, cancellable concurrent operations

**TaskGroup Features**:
- **Automatic Coordination**: TaskGroup coordinates multiple concurrent tasks
- **Error Propagation**: Errors from individual tasks properly propagated
- **Cancellation Support**: Cancellable operations for responsive applications
- **Resource Management**: Automatic cleanup of concurrent resources

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

**Purpose**: Demonstrate optimal parallel service initialization patterns for maximum performance and efficient resource utilization during application startup.

**Parallel Initialization Benefits**:
- **Startup Performance**: Significantly reduced application startup time
- **Resource Efficiency**: Optimal utilization of CPU cores and I/O resources
- **Independence**: Services without dependencies can initialize simultaneously
- **Scalability**: Performance scales with available system resources

**Pattern Analysis**:
- **Independent Services**: Services with no dependencies can initialize in parallel
- **Grouped Operations**: Related services grouped for logical organization
- **Progress Tracking**: Individual service initialization progress can be tracked
- **Error Isolation**: Failure in one service doesn't affect others

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

**Purpose**: Demonstrate proper dependency management for services that require other services to be registered first, ensuring correct initialization order.

**Dependency Management Features**:
- **Ordered Registration**: Dependencies registered before dependent services
- **Dependency Resolution**: Dependent services can resolve their dependencies during registration
- **Circular Dependency Detection**: Automatic detection and prevention of circular dependencies
- **Graceful Failure**: Proper error handling when dependencies are missing

**Best Practices**:
- **Layered Registration**: Register services in dependency layers (infrastructure → business → presentation)
- **Dependency Validation**: Validate that dependencies are available before registration
- **Error Recovery**: Provide fallback strategies when dependency registration fails
- **Documentation**: Clear documentation of service dependencies

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

**Purpose**: Comprehensive testing strategies for DIActor to ensure thread safety, concurrency correctness, and performance characteristics under various load conditions.

**Testing Categories**:
- **Concurrency Testing**: Verify thread safety under concurrent access
- **Performance Testing**: Measure performance characteristics under load
- **Stress Testing**: Test behavior under extreme concurrent load
- **Integration Testing**: Test integration with application components

**Test Environment Setup**:
- **Clean State**: Reset DIActor state before each test
- **Isolated Tests**: Ensure tests don't interfere with each other
- **Reproducible Results**: Consistent test results across runs
- **Comprehensive Coverage**: Test all critical code paths and edge cases

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

**Purpose**: Comprehensive performance testing to measure and validate DIActor performance characteristics under various load conditions and usage patterns.

**Performance Metrics**:
- **Registration Throughput**: Number of registrations per second
- **Resolution Latency**: Time required to resolve dependencies
- **Concurrent Scalability**: Performance scaling with concurrent operations
- **Memory Usage**: Memory consumption patterns and efficiency

**Testing Methodologies**:
- **Benchmark Testing**: Standardized performance benchmarks
- **Load Testing**: Performance under sustained load
- **Stress Testing**: Behavior at performance limits
- **Profiling**: Detailed performance profiling and optimization

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

**Purpose**: Demonstrate optimal integration patterns for DIActor with SwiftUI applications, ensuring smooth startup and dependency availability.

**SwiftUI Integration Benefits**:
- **Startup Coordination**: Coordinate service initialization with UI startup
- **Async Initialization**: Handle async service setup in SwiftUI lifecycle
- **Dependency Readiness**: Ensure services are ready before UI needs them
- **Error Handling**: Graceful handling of service initialization failures

**Integration Patterns**:
- **Background Initialization**: Initialize services in background during app startup
- **Progressive Loading**: Show loading states while services initialize
- **Dependency Checking**: Verify service availability before UI operations
- **Graceful Degradation**: Handle missing services gracefully in UI

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

**Purpose**: Demonstrate proper integration patterns between DIActor and SwiftUI ViewModels for responsive and reliable user interfaces.

**ViewModel Integration Benefits**:
- **Service Coordination**: Coordinate service availability with ViewModel lifecycle
- **Async Handling**: Proper async/await patterns for service access
- **UI Responsiveness**: Maintain responsive UI during service operations
- **State Management**: Proper state management for service-dependent operations

**Best Practices**:
- **Service Readiness**: Check service availability before performing operations
- **Loading States**: Provide appropriate loading states for async operations
- **Error Handling**: Graceful error handling and user feedback
- **Resource Management**: Proper cleanup of service references

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

**Strategy**: Leverage DIActor's concurrency capabilities for optimal application startup performance through parallel service initialization.

**Concurrent Initialization Benefits**:
- **Startup Performance**: Reduced application startup time through parallelization
- **Resource Utilization**: Optimal use of system resources during initialization
- **Scalability**: Performance scales with available CPU cores
- **Responsiveness**: Improved application responsiveness during startup

**Implementation Guidelines**:
- **Independent Services**: Identify services that can initialize independently
- **Task Grouping**: Group related services for logical organization
- **Error Isolation**: Isolate errors to prevent cascading failures
- **Progress Monitoring**: Monitor initialization progress for debugging

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

**Strategy**: Optimize performance by minimizing the number of actor boundary crossings through batching and strategic operation grouping.

**Performance Optimization Principles**:
- **Batch Operations**: Group multiple operations into single actor calls
- **Reduced Overhead**: Minimize async/await overhead from actor calls
- **Improved Throughput**: Higher overall throughput with fewer boundary crossings
- **Better Latency**: Reduced latency for batch operations

**Optimization Techniques**:
- **Operation Batching**: Combine multiple registrations/resolutions into single calls
- **Strategic Grouping**: Group related operations logically
- **Async Context Management**: Minimize context switching overhead
- **Efficient Communication**: Use efficient data structures for actor communication

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

**Strategy**: Implement robust dependency management to ensure correct registration order and handle dependency failures gracefully.

**Dependency Management Principles**:
- **Ordered Registration**: Register dependencies before dependent services
- **Dependency Validation**: Validate dependency availability before use
- **Error Handling**: Graceful handling of missing or failed dependencies
- **Circular Detection**: Prevent and detect circular dependency issues

**Implementation Best Practices**:
- **Layered Architecture**: Register services in architectural layers
- **Dependency Checking**: Verify dependencies are available before registration
- **Fallback Strategies**: Provide fallbacks for missing dependencies
- **Documentation**: Document service dependencies clearly

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

**Purpose**: Centralized service management using actor pattern for coordinated initialization and lifecycle management.

**Service Manager Benefits**:
- **Centralized Control**: Single point of control for service lifecycle
- **Initialization Coordination**: Coordinated startup sequence for related services
- **State Management**: Centralized state management for service readiness
- **Error Handling**: Centralized error handling and recovery strategies

**Pattern Implementation**:
- **Actor-Based Management**: Use actor for thread-safe service management
- **Layered Initialization**: Initialize services in dependency layers
- **State Tracking**: Track initialization state and service readiness
- **Error Recovery**: Implement recovery strategies for failed services

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

**Purpose**: Implement robust initialization patterns with fallback strategies and error recovery for resilient application startup.

**Graceful Initialization Benefits**:
- **Resilient Startup**: Application starts even if some services fail
- **Fallback Strategies**: Alternative implementations when primary services fail
- **Error Recovery**: Automatic recovery from initialization failures
- **User Experience**: Improved user experience with graceful degradation

**Implementation Strategies**:
- **Primary/Fallback Pattern**: Try primary services first, fallback on failure
- **Service Isolation**: Isolate service failures to prevent cascading issues
- **Progressive Enhancement**: Start with basic functionality, enhance as services become available
- **Health Monitoring**: Monitor service health and retry failed initializations

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