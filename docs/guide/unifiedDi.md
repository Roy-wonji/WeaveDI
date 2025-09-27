# UnifiedDI vs DIContainer: Comprehensive Comparison

Complete guide to choosing between WeaveDI's two main APIs: the modern UnifiedDI approach and the advanced DIContainer system.

## Overview

WeaveDI provides two distinct APIs for dependency injection, each designed for different use cases and architectural requirements.

### Quick Decision Guide

| Use Case | Recommended API | Reason |
|----------|----------------|--------|
| **Simple applications** | `UnifiedDI` | Minimal learning curve, one-line registration |
| **Complex enterprise apps** | `DIContainer` | Advanced features, modular architecture |
| **Rapid prototyping** | `UnifiedDI` | Immediate registration and usage |
| **Production systems** | `DIContainer` | Bootstrap safety, async initialization |
| **Testing** | Both supported | UnifiedDI simpler, DIContainer more isolated |
| **Library development** | `DIContainer` | Better encapsulation and scoping |

## UnifiedDI: Modern Simple API

### Design Philosophy

UnifiedDI follows the principle of **"Simplicity First"** - removing complexity while maintaining power.

```swift
// ✅ UnifiedDI: Register and use immediately
let userService = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}
// userService is ready to use immediately

// ✅ Simple resolution
if let analytics = UnifiedDI.resolve(AnalyticsService.self) {
    analytics.track("user_action")
}

// ✅ Safe resolution with defaults
let logger = UnifiedDI.resolve(Logger.self, default: ConsoleLogger())
```

### Core Features

#### 1. Immediate Registration & Usage

```swift
// Register and get instance in one line
let repository = UnifiedDI.register(UserRepository.self) {
    UserRepositoryImpl(
        network: UnifiedDI.requireResolve(NetworkService.self),
        cache: UnifiedDI.resolve(CacheService.self, default: MemoryCache())
    )
}

// Use immediately
let users = await repository.fetchUsers()
```

#### 2. Type-Safe Resolution

```swift
// ✅ Safe optional resolution
let optionalService = UnifiedDI.resolve(OptionalService.self)

// ✅ Required resolution (crashes with clear error if missing)
let criticalService = UnifiedDI.requireResolve(DatabaseService.self)

// ✅ Resolution with fallback
let configService = UnifiedDI.resolve(ConfigService.self, default: DefaultConfig())
```

#### 3. KeyPath Support

```swift
// Register with KeyPath for additional type safety
let emailService = UnifiedDI.register(\.emailInterface) {
    EmailServiceImpl()
}

// Resolve with KeyPath
let notificationService = UnifiedDI.resolve(\.notificationInterface)
```

#### 4. Auto DI Optimizer Integration

UnifiedDI automatically benefits from WeaveDI's Auto DI Optimizer:

```swift
// ✅ Automatic performance optimization
print("Optimized types: \(UnifiedDI.optimizedTypes())")
print("Usage statistics: \(UnifiedDI.stats())")
print("Circular dependencies: \(UnifiedDI.circularDependencies())")

// ✅ Real-time monitoring
UnifiedDI.setLogLevel(.optimization)
print("Auto graph: \(UnifiedDI.autoGraph())")
```

#### 5. Conditional Registration

```swift
// Environment-specific registration
let apiService = UnifiedDI.Conditional.registerIf(
    APIService.self,
    condition: isProduction,
    factory: { ProductionAPIService() },
    fallback: { MockAPIService() }
)
```

### When to Choose UnifiedDI

**✅ Perfect for:**
- **Rapid development**: Get started immediately
- **Simple applications**: Straightforward dependency relationships
- **Learning DI patterns**: Minimal cognitive overhead
- **Prototyping**: Quick registration and testing
- **Small teams**: Less architectural coordination needed

**❌ Consider alternatives when:**
- Need complex initialization sequences
- Requiring parent-child container relationships
- Building large modular applications
- Need advanced bootstrap patterns

## DIContainer: Advanced Enterprise System

### Design Philosophy

DIContainer follows **"Power and Control"** - providing enterprise-grade features for complex applications.

```swift
// ✅ DIContainer: Bootstrap pattern for safe initialization
await DIContainer.bootstrap { container in
    // Core infrastructure first
    container.register(DatabaseService.self) { DatabaseImpl() }
    container.register(NetworkService.self) { NetworkServiceImpl() }

    // Business logic second
    container.register(UserRepository.self) {
        UserRepositoryImpl(
            database: container.resolve(DatabaseService.self)!,
            network: container.resolve(NetworkService.self)!
        )
    }
}
```

### Core Features

#### 1. Bootstrap System for Safe Initialization

```swift
// ✅ Synchronous bootstrap
await DIContainer.bootstrap { container in
    container.register(Logger.self) { ConsoleLogger() }
    container.register(ConfigService.self) { ConfigServiceImpl() }
}

// ✅ Asynchronous bootstrap for complex initialization
let success = await DIContainer.bootstrapAsync { container in
    // Initialize database connection
    let database = try await DatabaseConnection.establish()
    container.register(DatabaseService.self, instance: database)

    // Load remote configuration
    let config = try await RemoteConfig.load()
    container.register(ConfigService.self, instance: config)
}

// ✅ Mixed bootstrap (sync + async)
await DIContainer.bootstrapMixed(
    sync: { container in
        // Immediate dependencies
        container.register(Logger.self) { ConsoleLogger() }
    },
    async: { container in
        // Complex initialization
        let remoteService = try await RemoteService.initialize()
        container.register(RemoteService.self, instance: remoteService)
    }
)
```

#### 2. Parent-Child Container Architecture

```swift
// ✅ Create hierarchical containers
let appContainer = DIContainer()
appContainer.register(DatabaseService.self) { DatabaseImpl() }

// Child container inherits parent dependencies
let userModule = appContainer.createChild()
userModule.register(UserRepository.self) {
    // Can resolve DatabaseService from parent
    UserRepositoryImpl(database: userModule.resolve(DatabaseService.self)!)
}

let orderModule = appContainer.createChild()
orderModule.register(OrderRepository.self) {
    // Also inherits DatabaseService from parent
    OrderRepositoryImpl(database: orderModule.resolve(DatabaseService.self)!)
}
```

#### 3. Module System with Parallel Building

```swift
// ✅ Define modules for organized registration
struct UserModule: Module {
    func register() async {
        await DIContainer.shared.register(UserService.self) {
            UserServiceImpl()
        }
        await DIContainer.shared.register(UserRepository.self) {
            UserRepositoryImpl()
        }
    }
}

struct NetworkModule: Module {
    func register() async {
        await DIContainer.shared.register(NetworkService.self) {
            NetworkServiceImpl()
        }
        await DIContainer.shared.register(APIClient.self) {
            APIClientImpl()
        }
    }
}

// ✅ Parallel module building for performance
await DIContainer.bootstrap { container in
    container.addModule(UserModule())
    container.addModule(NetworkModule())
    container.addModule(AnalyticsModule())

    // All modules registered in parallel
    await container.buildModules()
}
```

#### 4. Factory Patterns with Lazy Resolution

```swift
// ✅ Factory registration (lazy evaluation)
let releaseHandler = DIContainer.shared.register(ExpensiveService.self, build: {
    // Only created when first resolved
    ExpensiveServiceImpl()
})

// ✅ Instance registration (immediate)
let logger = ConsoleLogger()
DIContainer.shared.register(Logger.self, instance: logger)

// ✅ Factory registration with immediate instance
let networkService = DIContainer.shared.register(NetworkService.self) {
    NetworkServiceImpl()
}
```

#### 5. Actor-Safe Operations

```swift
// ✅ Swift 6 actor-isolated operations
@DIContainerActor
func registerServices() async {
    let container = DIContainer.actorShared

    await container.actorRegister(UserService.self, instance: UserServiceImpl())

    let resolvedService = await DIContainer.resolveAsync(UserService.self)
}
```

#### 6. Performance Metrics and Monitoring

```swift
// ✅ Module build metrics
let metrics = await DIContainer.shared.buildModulesWithMetrics()
print("""
Performance Report:
- Modules built: \(metrics.moduleCount)
- Duration: \(metrics.duration)s
- Rate: \(metrics.modulesPerSecond) modules/sec
""")

// ✅ Container status monitoring
print("Container is bootstrapped: \(DIContainer.isBootstrapped)")
print("Module count: \(DIContainer.shared.moduleCount)")
print("Is empty: \(DIContainer.shared.isEmpty)")
```

### When to Choose DIContainer

**✅ Perfect for:**
- **Enterprise applications**: Complex initialization sequences
- **Modular architecture**: Parent-child container relationships
- **Performance-critical apps**: Parallel module building
- **Large teams**: Organized module-based registration
- **Production systems**: Bootstrap safety and error handling
- **Testing isolation**: Separate containers per test

**❌ May be overkill when:**
- Building simple applications
- Need immediate registration without setup
- Rapid prototyping
- Learning dependency injection concepts

## Performance Comparison

### Registration Performance

```swift
// UnifiedDI: Immediate registration
let start1 = CFAbsoluteTimeGetCurrent()
let service1 = UnifiedDI.register(TestService.self) { TestServiceImpl() }
let duration1 = CFAbsoluteTimeGetCurrent() - start1
// ~0.01ms per registration

// DIContainer: Deferred registration with bootstrap
let start2 = CFAbsoluteTimeGetCurrent()
await DIContainer.bootstrap { container in
    container.register(TestService.self) { TestServiceImpl() }
}
let duration2 = CFAbsoluteTimeGetCurrent() - start2
// ~0.1ms per bootstrap (more overhead, but safer)
```

### Resolution Performance

```swift
// Both APIs have similar resolution performance
let start = CFAbsoluteTimeGetCurrent()

// UnifiedDI resolution
let service1 = UnifiedDI.resolve(TestService.self)

// DIContainer resolution
let service2 = DIContainer.shared.resolve(TestService.self)

let duration = CFAbsoluteTimeGetCurrent() - start
// Both: ~0.001ms per resolution (negligible difference)
```

### Module Building Performance

```swift
// DIContainer: Parallel module building advantage
let modules = [UserModule(), NetworkModule(), AnalyticsModule(), PaymentModule()]

let start = CFAbsoluteTimeGetCurrent()
await DIContainer.bootstrap { container in
    for module in modules {
        container.addModule(module)
    }
    await container.buildModules() // Parallel execution
}
let parallelDuration = CFAbsoluteTimeGetCurrent() - start

// UnifiedDI: Sequential registration
let start2 = CFAbsoluteTimeGetCurrent()
modules.forEach { module in
    // Sequential registration (simulated)
    // module.registerInUnifiedDI()
}
let sequentialDuration = CFAbsoluteTimeGetCurrent() - start2

// DIContainer can be 3-5x faster for large module sets
```

## Auto DI Optimizer Integration

Both APIs benefit from WeaveDI's Auto DI Optimizer, but with different access patterns:

### UnifiedDI Integration

```swift
// ✅ Direct optimizer access
UnifiedDI.setLogLevel(.optimization)
print("Frequently used: \(UnifiedDI.stats())")
print("Optimization tips: \(UnifiedDI.getOptimizationTips())")

// ✅ Auto-optimization configuration
UnifiedDI.configureOptimization(
    debounceMs: 100,
    threshold: 10,
    realTimeUpdate: true
)

// ✅ Performance insights
let asyncStats = await UnifiedDI.asyncPerformanceStats
let actorHops = await UnifiedDI.actorHopStats
```

### DIContainer Integration

```swift
// ✅ Container-specific monitoring
let container = DIContainer.shared
print("Auto graph: \(container.getAutoGeneratedGraph())")
print("Optimized types: \(container.getOptimizedTypes())")
print("Circular dependencies: \(container.getDetectedCircularDependencies())")

// ✅ Container-level optimization control
container.setAutoOptimization(true)
container.resetAutoStats()
```

## Testing Strategies

### UnifiedDI Testing

```swift
class UserServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Simple cleanup
        UnifiedDI.releaseAll()
    }

    func testUserCreation() async {
        // ✅ Direct mock registration
        let mockRepo = UnifiedDI.register(UserRepository.self) {
            MockUserRepository()
        }

        let userService = UnifiedDI.register(UserService.self) {
            UserServiceImpl(repository: mockRepo)
        }

        let user = await userService.createUser(name: "Test")
        XCTAssertNotNil(user)
    }
}
```

### DIContainer Testing

```swift
class UserServiceTests: XCTestCase {
    var testContainer: DIContainer!

    override func setUp() async throws {
        try await super.setUp()

        // ✅ Isolated test container
        testContainer = DIContainer()

        // ✅ Test-specific bootstrap
        await DIContainer.bootstrap { container in
            container.register(UserRepository.self) { MockUserRepository() }
            container.register(UserService.self) {
                UserServiceImpl(repository: container.resolve(UserRepository.self)!)
            }
        }
    }

    override func tearDown() async throws {
        // ✅ Container cleanup
        await DIContainer.resetForTesting()
        try await super.tearDown()
    }

    func testUserCreation() async {
        let userService = testContainer.resolve(UserService.self)
        let user = await userService?.createUser(name: "Test")
        XCTAssertNotNil(user)
    }
}
```

## Migration Strategies

### From UnifiedDI to DIContainer

```swift
// Before: UnifiedDI simple registration
let userService = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}

// After: DIContainer with bootstrap
await DIContainer.bootstrap { container in
    container.register(UserService.self) {
        UserServiceImpl()
    }
}
```

### From DIContainer to UnifiedDI

```swift
// Before: DIContainer bootstrap
await DIContainer.bootstrap { container in
    container.register(Logger.self) { ConsoleLogger() }
    container.register(NetworkService.self) { NetworkServiceImpl() }
}

// After: UnifiedDI immediate registration
let logger = UnifiedDI.register(Logger.self) { ConsoleLogger() }
let networkService = UnifiedDI.register(NetworkService.self) { NetworkServiceImpl() }
```

## Best Practices

### UnifiedDI Best Practices

```swift
// ✅ Use immediate registration for core services
let logger = UnifiedDI.register(Logger.self) { ConsoleLogger() }

// ✅ Leverage default values for optional dependencies
let analytics = UnifiedDI.resolve(AnalyticsService.self, default: NoOpAnalytics())

// ✅ Use requireResolve for critical dependencies
let database = UnifiedDI.requireResolve(DatabaseService.self)

// ✅ Monitor performance automatically
if UnifiedDI.logLevel == .optimization {
    print("Tips: \(UnifiedDI.getOptimizationTips())")
}
```

### DIContainer Best Practices

```swift
// ✅ Always use bootstrap for initialization
await DIContainer.bootstrap { container in
    // Register dependencies in dependency order
    container.register(Logger.self) { ConsoleLogger() }
    container.register(ConfigService.self) {
        ConfigServiceImpl(logger: container.resolve(Logger.self)!)
    }
}

// ✅ Use modules for organization
struct CoreModule: Module {
    func register() async {
        let container = DIContainer.shared
        await container.register(Logger.self) { ConsoleLogger() }
        await container.register(ConfigService.self) { ConfigServiceImpl() }
    }
}

// ✅ Check bootstrap status
DIContainer.ensureBootstrapped()
let service = DIContainer.shared.resolve(MyService.self)

// ✅ Use child containers for isolation
let testContainer = DIContainer.shared.createChild()
testContainer.register(TestService.self) { MockTestService() }
```

## Compatibility and Interoperability

Both APIs can be used together in the same application:

```swift
// ✅ Mix both APIs
await DIContainer.bootstrap { container in
    // Bootstrap core services with DIContainer
    container.register(DatabaseService.self) { DatabaseImpl() }
}

// Register additional services with UnifiedDI
let analyticsService = UnifiedDI.register(AnalyticsService.self) {
    AnalyticsServiceImpl(
        database: DIContainer.shared.resolve(DatabaseService.self)!
    )
}

// Both resolve from the same underlying container
let database1 = UnifiedDI.resolve(DatabaseService.self)
let database2 = DIContainer.shared.resolve(DatabaseService.self)
// database1 and database2 are the same instance
```

## Conclusion

### Choose UnifiedDI when:
- Building simple to medium applications
- Need immediate registration and usage
- Rapid prototyping or learning DI patterns
- Minimal setup overhead is important
- Auto-optimization insights are valuable

### Choose DIContainer when:
- Building enterprise or complex applications
- Need advanced bootstrap patterns
- Require parent-child container relationships
- Building modular architectures
- Performance monitoring is critical
- Testing isolation is important

Both APIs provide excellent performance and are fully compatible with Swift 6 concurrency. The choice depends on your application's complexity and architectural requirements.

## See Also

- [Property Wrappers](/guide/property-wrappers) - Injectable property patterns
- [Bootstrap Guide](/guide/bootstrap) - Advanced initialization patterns
- [Module System](/guide/module-system) - Organizing large applications
- [Auto DI Optimizer](/guide/auto-di-optimizer) - Automatic performance optimization