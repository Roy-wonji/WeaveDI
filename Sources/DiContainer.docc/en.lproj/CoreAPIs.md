# Core APIs

Complete reference for DiContainer's core API components

## Overview

DiContainer provides three main API entry points, each designed for different use cases and complexity levels. This guide covers all core APIs and their intended usage patterns.

## API Hierarchy

### UnifiedDI (Recommended)
The most comprehensive API with all features available.

### DI (Simplified)
A streamlined API for basic dependency injection needs.

### DIAsync (Async-First)
Specialized API for async/await heavy applications.

## UnifiedDI API

### Registration Methods

#### Basic Registration

```swift
// Register a type with a factory closure
UnifiedDI.register(ServiceProtocol.self) { ServiceImpl() }

// Register with dependency injection
UnifiedDI.register(ComplexService.self) {
    ComplexService(
        dependency1: UnifiedDI.requireResolve(Dependency1.self),
        dependency2: UnifiedDI.resolve(Dependency2.self, default: DefaultDep2())
    )
}
```

#### Conditional Registration

```swift
// Register different implementations based on conditions
UnifiedDI.registerIf(
    APIService.self,
    condition: isProduction,
    factory: { ProductionAPIService() },
    fallback: { MockAPIService() }
)

// Multiple conditions
UnifiedDI.registerIf(
    LoggerService.self,
    condition: isDebugMode && verboseLogging,
    factory: { VerboseLogger() },
    fallback: { StandardLogger() }
)
```

#### Batch Registration

```swift
// Register multiple dependencies at once
UnifiedDI.registerMany {
    Registration(NetworkService.self) { URLSessionNetworkService() }
    Registration(CacheService.self) { NSCacheService() }
    Registration(Logger.self) { OSLogger() }

    // Conditional registration within batch
    Registration(AnalyticsService.self,
                condition: !isDebugMode,
                factory: { FirebaseAnalytics() },
                fallback: { NoOpAnalytics() })
}
```

#### KeyPath Registration

```swift
// Extend DependencyContainer for KeyPath support
extension DependencyContainer {
    var userService: UserService? { resolve(UserService.self) }
    var apiClient: APIClient? { resolve(APIClient.self) }
}

// Register and get instance immediately
let service = UnifiedDI.register(\.userService) { UserServiceImpl() }

// The service is now both registered and available as 'service'
```

### Resolution Methods

#### Basic Resolution

```swift
// Optional resolution
let service: ServiceProtocol? = UnifiedDI.resolve(ServiceProtocol.self)

// Required resolution (crashes if not found)
let required: ServiceProtocol = UnifiedDI.requireResolve(ServiceProtocol.self)

// Resolution with default value
let withDefault = UnifiedDI.resolve(ServiceProtocol.self, default: DefaultService())
```

#### Error Handling Resolution

```swift
// Throwing resolution
do {
    let service = try UnifiedDI.resolveThrows(ServiceProtocol.self)
    // Use service
} catch DIError.dependencyNotFound(let type) {
    print("Service not found: \(type)")
} catch {
    print("Resolution error: \(error)")
}
```

#### Performance Tracking Resolution

```swift
// Resolution with performance tracking
let service = UnifiedDI.resolveWithTracking(ServiceProtocol.self)

// Get performance metrics
let metrics = UnifiedDI.getPerformanceMetrics()
print("Average resolution time: \(metrics.averageResolutionTime)ms")
```

### Management Methods

#### Lifecycle Management

```swift
// Release specific type
UnifiedDI.release(ServiceProtocol.self)

// Release all dependencies
UnifiedDI.releaseAll()

// Check if type is registered
if UnifiedDI.isRegistered(ServiceProtocol.self) {
    // Type is available
}
```

#### Introspection

```swift
// Get list of registered types
let registeredTypes = UnifiedDI.getRegisteredTypes()

// Get dependency graph
let graph = UnifiedDI.getDependencyGraph()

// Validate dependency graph for circular dependencies
let validation = UnifiedDI.validateDependencyGraph()
```

## DI API (Simplified)

The simplified DI API focuses on the most common operations:

### Core Operations

```swift
// Registration
DI.register(Service.self) { ServiceImpl() }

// Resolution
let service = DI.resolve(Service.self)

// Required resolution
let required = DI.requireResolve(Service.self)

// KeyPath registration (returns instance)
let instance = DI.register(\.myService) { MyServiceImpl() }
```

### Conditional Registration

```swift
// Simple conditional registration
DI.registerIf(
    Service.self,
    condition: isProduction,
    factory: { ProductionService() },
    fallback: { MockService() }
)
```

## DIAsync API

For async-heavy applications, DIAsync provides async/await optimized operations:

### Async Registration

```swift
// Register async factory
await DIAsync.register(DatabaseService.self) {
    await DatabaseService.initialize()
}

// Batch async registration
await DIAsync.registerMany {
    DIAsyncRegistration(Service1.self) { await Service1.create() }
    DIAsyncRegistration(Service2.self) { Service2() }
}
```

### Async Resolution

```swift
// Async resolution
let service = await DIAsync.resolve(ServiceProtocol.self)

// Required async resolution
let required = await DIAsync.requireResolve(ServiceProtocol.self)

// Async resolution with default
let withDefault = await DIAsync.resolve(ServiceProtocol.self, default: DefaultService())
```

### Async KeyPath Operations

```swift
// Async KeyPath registration
let service = await DIAsync.register(\.databaseService) {
    await DatabaseService.initialize()
}

// Get or create (idempotent)
let service = await DIAsync.getOrCreate(\.expensiveService) {
    await ExpensiveService.create()
}
```

## DependencyContainer Core

The underlying container that powers all APIs:

### Bootstrap System

```swift
// Synchronous bootstrap
await DependencyContainer.bootstrap { container in
    container.register(Service1.self) { Service1Impl() }
    container.register(Service2.self) { Service2Impl() }
}

// Async bootstrap for async dependencies
await DependencyContainer.bootstrapAsync { container in
    let database = await Database.initialize()
    container.register(Database.self, instance: database)
}
```

### Direct Container Operations

```swift
// Access live container
let container = DependencyContainer.live

// Register directly
container.register(Service.self) { ServiceImpl() }

// Register instance directly
let logger = Logger()
container.register(Logger.self, instance: logger)

// Resolve directly
let service = container.resolve(Service.self)
```

### Testing Support

```swift
// Reset container for testing
await DependencyContainer.resetForTesting()

// Create isolated test container
let testContainer = DependencyContainer.createIsolated()

// Use test container
testContainer.register(MockService.self) { MockServiceImpl() }
```

## Property Wrappers

### @Inject

```swift
class MyService {
    // Optional injection
    @Inject var optionalDep: OptionalService?

    // Required injection (non-optional type)
    @Inject var requiredDep: RequiredService

    // KeyPath injection
    @Inject(\.customService) var customDep: CustomService?
}
```

### @RequiredInject

```swift
class MyService {
    // Always required, clearer intent
    @RequiredInject var database: Database
    @RequiredInject var logger: Logger

    // KeyPath version
    @RequiredInject(\.apiClient) var apiClient: APIClient
}
```

### @Factory

```swift
class MyService {
    // Factory-based injection (creates new instance each time)
    @Factory var temporaryService: TemporaryService

    // With parameters
    @Factory var configuredService: ConfiguredService
}
```

## Error Handling

### DIError Types

```swift
enum DIError: Error {
    case dependencyNotFound(Any.Type)
    case circularDependency([Any.Type])
    case registrationConflict(Any.Type)
    case containerNotInitialized
}
```

### Error Handling Patterns

```swift
// Safe resolution with error handling
func safeResolve<T>(_ type: T.Type) -> T? {
    do {
        return try UnifiedDI.resolveThrows(type)
    } catch DIError.dependencyNotFound {
        print("Warning: \(type) not registered")
        return nil
    } catch {
        print("Unexpected error: \(error)")
        return nil
    }
}

// Graceful degradation
func getServiceWithFallback() -> ServiceProtocol {
    return UnifiedDI.resolve(ServiceProtocol.self) ?? DefaultService()
}
```

## Performance Considerations

### Optimization Tips

```swift
// 1. Use batch registration for related dependencies
UnifiedDI.registerMany {
    Registration(A.self) { AImpl() }
    Registration(B.self) { BImpl() }
    Registration(C.self) { CImpl() }
}

// 2. Prefer property wrappers for frequently accessed dependencies
class FrequentlyUsedService {
    @Inject var cache: CacheService? // Cached after first access
}

// 3. Use lazy initialization for expensive objects
UnifiedDI.register(ExpensiveService.self) {
    // Only created when first requested
    ExpensiveService()
}

// 4. Enable performance tracking in development
#if DEBUG
let metrics = UnifiedDI.getPerformanceMetrics()
print("DI Performance: \(metrics.summary)")
#endif
```

### Memory Management

```swift
// Avoid retain cycles with weak references
class ServiceA {
    @Inject weak var serviceB: ServiceB? // Weak to break cycles
}

// Release dependencies when no longer needed
UnifiedDI.release(TemporaryService.self)

// Periodic cleanup in long-running apps
Task {
    while true {
        try await Task.sleep(nanoseconds: 60_000_000_000) // 1 minute
        UnifiedDI.performMemoryCleanup()
    }
}
```

## Best Practices

### 1. Consistent API Usage

Choose one primary API and stick with it:

```swift
// ✅ Good: Consistent UnifiedDI usage
class AppDependencies {
    static func setup() {
        UnifiedDI.registerMany {
            Registration(A.self) { AImpl() }
            Registration(B.self) { BImpl() }
        }
    }
}

// ❌ Bad: Mixing APIs
class MixedDependencies {
    static func setup() {
        UnifiedDI.register(A.self) { AImpl() }
        DI.register(B.self) { BImpl() }        // Different API
    }
}
```

### 2. Clear Dependency Interfaces

```swift
// ✅ Good: Clear protocol-based dependencies
protocol UserService {
    func fetchUser(id: String) async throws -> User
}

class UserServiceImpl: UserService {
    @RequiredInject var apiClient: APIClient

    func fetchUser(id: String) async throws -> User {
        return try await apiClient.fetchUser(id: id)
    }
}

// Register interface, not implementation
UnifiedDI.register(UserService.self) { UserServiceImpl() }
```

### 3. Environment-Specific Configuration

```swift
enum DIEnvironment {
    static func configure() {
        #if DEBUG
        setupDevelopmentDependencies()
        #elseif STAGING
        setupStagingDependencies()
        #else
        setupProductionDependencies()
        #endif
    }

    private static func setupDevelopmentDependencies() {
        UnifiedDI.registerMany {
            Registration(APIService.self) { MockAPIService() }
            Registration(Logger.self) { VerboseLogger() }
        }
    }
}
```

This comprehensive API reference should help you effectively use DiContainer's powerful dependency injection capabilities in your Swift applications.