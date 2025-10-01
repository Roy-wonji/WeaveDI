# @Inject Property Wrapper (Deprecated v3.2.0+)

::: danger Deprecated
`@Inject` is **deprecated as of v3.2.0**. Please migrate to `@Injected` for modern, TCA-style dependency injection with better type safety and KeyPath-based access.

**Migration Guide:**
```swift
// Old (Deprecated)
@Inject var userService: UserServiceProtocol?

// New (Recommended)
@Injected(\.userService) var userService
```

See the [@Injected documentation](./injected.md) for complete migration instructions.
:::

The `@Inject` property wrapper was a core feature of WeaveDI that provided automatic dependency injection for properties in classes and structs. **It is now superseded by @Injected.**

## Overview

`@Inject` uses lazy evaluation to automatically resolve dependencies from the DI container when the property is first accessed. It provides optional resolution to make your code resilient to missing dependencies, preventing runtime crashes and enabling graceful degradation.

**Core Features**:
- **Lazy Resolution**: Dependencies are resolved only on first access for performance optimization
- **Optional Safety**: Returns `nil` if dependency is not registered, preventing crashes
- **Automatic Caching**: Once resolved, dependencies are reused for improved performance
- **Thread Safety**: Thread-safe implementation that can be safely accessed from any queue

**Performance Characteristics**:
- **First Access**: Small overhead for dependency resolution (~0.1-1ms)
- **Subsequent Access**: Near-zero overhead (direct property access)
- **Memory Usage**: Minimal memory overhead for tracking resolved dependencies
- **Thread Safety**: Safe access from all queues

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

**Purpose**: Basic dependency injection using the `@Inject` property wrapper for automatic dependency resolution.

**How it works**:
- **Lazy Resolution**: Dependencies are resolved only when first accessed
- **Optional Safety**: Returns `nil` if service is not registered, preventing crashes
- **Automatic Caching**: Reuses the same instance after first resolution
- **Thread Safety**: Thread-safe resolution across all queues

**Performance Characteristics**:
- **First Access**: Small overhead for dependency resolution (~0.1-1ms)
- **Subsequent Access**: Near-zero overhead (direct property access)
- **Memory Usage**: Minimal memory overhead for tracking resolved dependencies
- **Thread Safety**: Safe access from all queues

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

**Best Practice**: Always inject protocols rather than concrete types for better testability, flexibility, and adherence to dependency inversion principle.

**Benefits of Protocol Injection**:
- **Testability**: Easy to substitute mock implementations during testing
- **Flexibility**: Can swap implementations without changing client code
- **Loose Coupling**: Reduces dependencies between modules
- **Interface Segregation**: Clients depend only on interfaces they use

**Implementation Guidelines**:
- Define clear, focused protocols for your services
- Use protocol composition for complex behaviors
- Avoid exposing implementation details through protocols

Always inject protocols rather than concrete types for better testability:

```swift
// ✅ Good - Protocol injection
@Inject var networkClient: NetworkClientProtocol?

// ❌ Avoid - Concrete type injection
@Inject var networkClient: URLSessionNetworkClient?
```

## Real-World Examples

### CountApp with @Inject (from Tutorial)

**Purpose**: Real-world `@Inject` usage patterns and practical dependency injection applications based on actual CountApp tutorial code.

**Architecture Patterns**:
- **Repository Pattern**: Abstraction of data access layer
- **MVVM Pattern**: Model-View-ViewModel architecture implementation
- **Dependency Injection**: Loose coupling through dependency management
- **Logging Integration**: Unified logging across all layers

**Performance Optimizations**:
- **Lazy Initialization**: Services are initialized only when actually used
- **Singleton Pattern**: Repository and Logger managed as singletons
- **Memory Efficiency**: Prevents unnecessary instance creation

Based on actual tutorial code:

```swift
/// Counter Repository using @Inject for dependencies
class UserDefaultsCounterRepository: CounterRepository {
    /// Logger injected via WeaveDI
    @Inject var logger: LoggerProtocol?

    func getCurrentCount() async -> Int {
        let count = UserDefaults.standard.integer(forKey: "saved_count")
        logger?.info("📊 Current count loaded: \(count)")
        return count
    }

    func saveCount(_ count: Int) async {
        UserDefaults.standard.set(count, forKey: "saved_count")
        logger?.info("💾 Count saved: \(count)")
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

        logger?.info("⬆️ Count incremented: \(count)")
    }
}
```

### WeatherApp with @Inject

**Purpose**: Complex dependency injection patterns in WeatherApp with error handling, caching strategies, and real-world implementation cases.

**Architecture Features**:
- **Layered Architecture**: Service → Repository → Network layer structure
- **Error Handling**: Comprehensive error handling and recovery strategies
- **Caching Strategy**: Multi-level caching for performance improvement
- **Asynchronous Processing**: Modern async patterns using async/await

**Performance Considerations**:
- **Network Optimization**: Minimize unnecessary network calls
- **Cache Utilization**: Improve responsiveness by prioritizing cached data
- **Error Recovery**: Graceful recovery with cached data on network failure

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

**Purpose**: Integration of SwiftUI's StateObject with `@Inject` combining declarative UI and dependency injection for modern iOS app development patterns.

**Integration Benefits**:
- **Declarative Code**: Natural combination of SwiftUI's declarative paradigm with DI
- **Lifecycle Management**: StateObject automatically manages ViewModel lifecycle
- **Data Binding**: Automatic UI updates through @Published properties
- **Testability**: Easy unit testing of ViewModels

**Performance Characteristics**:
- **Lazy Loading**: ViewModel dependencies loaded when needed
- **Memory Efficiency**: SwiftUI efficiently manages ViewModel lifecycle
- **UI Responsiveness**: Dependency resolution doesn't block UI thread

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

**Purpose**: Direct dependency injection in SwiftUI Views for simple service access and rapid prototyping patterns.

**Benefits of Direct Injection**:
- **Simplicity**: Direct service access without ViewModels
- **Rapid Development**: Quick implementation for simple features
- **Flexibility**: Different service combinations per view
- **Testing**: Independent testing of individual view behaviors

**Usage Scenarios**:
- Simple views like settings screens
- Features that don't need state management
- Prototyping and rapid development
- Views performing one-time operations

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

**Thread Safety Guarantee**: `@Inject` provides comprehensive thread safety, ensuring safe dependency access in multi-threaded environments.

**Safety Mechanisms**:
- **Independent Instances**: Each property access creates isolated instances safely shared, not creating new isolated instances
- **Thread-Safe Resolution**: Container resolution is internally synchronized
- **Concurrent Access**: Multiple threads can safely access factory properties
- **Memory Barriers**: Automatic memory barrier handling for consistent visibility

**Concurrency Benefits**:
- **Parallel Processing**: Each thread gets independent instances
- **No Manual Synchronization**: No need for manual thread synchronization
- **Race Condition Prevention**: Instance isolation prevents race conditions
- **Scalable Concurrency**: Performance scales with number of threads

**Performance Characteristics**:
- **Resolution Overhead**: Minimal synchronized access overhead during resolution
- **Instance Creation**: No synchronization after instance creation
- **Memory Barriers**: Automatic memory barrier handling

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

**Testing Strategy**: `@Inject` provides powerful testing patterns through fresh mock instances and state isolation.

**Testing Benefits**:
- **Reliable Test Dependencies**: No test failures due to missing dependencies
- **Flexible Mock Strategies**: Easy switching between real and mock dependencies
- **Isolated Tests**: Each test has independent container state
- **Integration Testing**: Full system testing with partial mocks

**Test Configuration Patterns**:
- **Full Mock Environment**: Register all dependencies as mocks
- **Partial Mock Environment**: Mix of mock and real implementations
- **Integration Testing**: Mixed use of real and mock dependencies

```swift
class UserServiceTests: XCTestCase {
    override func setUp() async throws {
        await WeaveDI.Container.resetForTesting()

        await WeaveDI.Container.bootstrap { container in
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

**Purpose**: Resilient error handling patterns that allow applications to continue functioning even when dependencies are unavailable.

**Benefits of Graceful Degradation**:
- **Application Stability**: Prevents crashes due to missing dependencies
- **User Experience**: Application remains usable even with some missing features
- **Development Flexibility**: Development can continue without all services implemented
- **Progressive Deployment**: Enables gradual feature deployment and rollback

**Pattern Implementation**:
- **Optional Chaining**: Use optional chaining for safe method calls
- **Default Values**: Provide default behavior when services are unavailable
- **Logging**: Appropriate logging for missing services
- **User Feedback**: User notifications about feature limitations

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

### Runtime Validation

**Purpose**: Validate critical dependency availability at runtime to ensure core application functionality works correctly.

**Validation Strategies**:
- **Early Validation**: Validate critical dependencies at app startup
- **Fail Fast**: Immediately fail when critical dependencies are missing
- **Clear Error Messages**: Provide clear descriptions of missing dependencies
- **Developer Guidance**: Guide developers on how to resolve missing dependencies

**Validation Levels**:
- **Critical**: Dependencies essential for core application functionality
- **Optional**: Optional dependencies for enhanced features
- **Development**: Dependencies for development and debugging

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

**Performance Optimization Strategy**: Dependencies are resolved lazily only on first access, optimizing application startup time and reducing memory usage.

**Benefits of Lazy Resolution**:
- **Fast App Startup**: Unused dependencies are not initialized
- **Memory Efficiency**: Memory allocation only when needed
- **Conditional Usage**: Efficient management of services used only under specific conditions
- **Progressive Loading**: Gradual feature loading based on user interaction

**Performance Characteristics**:
- **Initialization Cost**: Defer heavy dependency initialization cost to actual usage time
- **Memory Usage**: Prevent memory waste from unused services
- **CPU Efficiency**: Improve CPU efficiency by preventing unnecessary initialization work

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

**Caching Strategy**: Once resolved, dependency references are automatically cached, providing excellent performance on subsequent accesses.

**Caching Benefits**:
- **Performance Improvement**: Near-zero overhead access after first resolution
- **Consistency**: Maintain consistent state with same instance references
- **Memory Efficiency**: Prevent duplicate instance creation
- **Predictability**: Predictable performance characteristics

**Caching Mechanisms**:
- **Automatic Caching**: Automatically store references on first resolution
- **Thread Safety**: Safe cache access in multi-threaded environments
- **Memory Management**: Prevent memory leaks with proper memory management
- **Lifecycle**: Cache management tied to property wrapper lifecycle

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

**Purpose**: Application of `@Inject` in the Repository pattern to abstract the data access layer and separate business logic from data sources.

**Benefits of Repository Pattern**:
- **Layer Separation**: Clear separation of data access logic and business logic
- **Testability**: Easy unit testing through mock repositories
- **Flexibility**: Easy switching between different data sources
- **Caching Strategy**: Unified caching and performance optimization

**Implementation Features**:
- **Multiple Data Sources**: Combination of network, cache, and local database
- **Error Handling**: Comprehensive error handling and recovery strategies
- **Performance Optimization**: Performance optimization through cache-first access
- **Logging Integration**: Unified logging for all data access

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

**Purpose**: Service layer patterns that encapsulate business logic and coordinate between multiple repositories and services.

**Service Layer Features**:
- **Business Logic Encapsulation**: Centralized management of complex business rules
- **Transaction Management**: Transaction coordination across multiple repositories
- **Dependency Coordination**: Dependency management between multiple sub-services
- **Error Handling**: Business-level error handling and recovery

**Architecture Benefits**:
- **Separation of Concerns**: Each service focuses on specific business domains
- **Reusability**: Reuse same service logic across multiple UI layers
- **Testability**: Independent testing of business logic
- **Scalability**: Flexible response to changing business requirements

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

**Guideline**: `@Inject` provides optional resolution to handle missing dependencies gracefully, so always use optional types.

**Benefits of Using Optionals**:
- **Crash Prevention**: Prevents runtime crashes due to missing dependencies
- **Development Flexibility**: Development can continue without all dependencies implemented
- **Testing Ease**: Flexible test environment configuration through partial mocks
- **Progressive Development**: Gradual development and deployment by feature

**Compile-Time Safety**:
- **Type Safety**: Safety through Swift's optional type system
- **Explicit Handling**: Explicit nil handling through optional binding
- **Code Readability**: Clear expression of optional nature of dependencies in code

`@Inject` provides optional resolution to handle missing dependencies gracefully:

```swift
// ✅ Good
@Inject var service: MyService?

// ❌ Avoid
@Inject var service: MyService // Compiler error
```

### 2. Handle Nil Cases

**Strategy**: Properly handle all cases where dependency injection might fail to ensure application stability and user experience.

**Nil Handling Patterns**:
- **Guard Statements**: Clear error handling through early returns
- **Optional Binding**: Safe value extraction through if-let
- **Nil Coalescing Operator**: Graceful degradation through default values
- **Optional Chaining**: Safe method call chains

**Error Handling Strategies**:
- **Logging**: Appropriate logging for missing dependencies
- **User Feedback**: User notifications about feature limitations
- **Alternative Behavior**: Alternative logic when dependencies are unavailable
- **Developer Tools**: Debugging information in development environments

Always handle cases where injection might fail:

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

**Design Principle**: Inject protocols rather than concrete implementations to adhere to the Dependency Inversion Principle and increase code flexibility.

**Benefits of Protocol Injection**:
- **Testability**: Easy and reliable unit testing through mock implementations
- **Flexibility**: Can replace implementations at runtime
- **Extensibility**: Minimal changes to existing code when adding new implementations
- **Modularity**: Reduced coupling between modules through interfaces

**Design Guidelines**:
- **Single Responsibility**: Each protocol has one clear responsibility
- **Interface Segregation**: Clients depend only on interfaces they use
- **Minimal Interfaces**: Define only necessary methods in protocols
- **Meaningful Names**: Use names that clearly express the protocol's role

```swift
// ✅ Good - testable and flexible
@Inject var logger: LoggerProtocol?

// ❌ Avoid - hard to test and mock
@Inject var logger: ConsoleLogger?
```

### 4. Document Dependencies

**Documentation Strategy**: Clearly document the purpose and role of each dependency to improve code readability and maintainability.

**Documentation Elements**:
- **Dependency Purpose**: Explain why the dependency is needed
- **Usage Patterns**: Describe how the dependency is used
- **Lifecycle**: Dependency lifecycle and management approach
- **Substitutability**: Specify whether the dependency is optional or required

**Documentation Benefits**:
- **Team Collaboration**: Team members can easily understand and modify code
- **Maintenance**: Easy impact assessment when changing dependencies
- **Onboarding**: Quick codebase understanding for new team members
- **Architecture Understanding**: Grasp overall system dependency structure

**Documentation Tools**:
- **Inline Comments**: Direct explanations within code
- **DocC**: Utilize Swift's official documentation tool
- **README**: Project-level dependency descriptions
- **Architecture Diagrams**: Visual representation of dependency relationships

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