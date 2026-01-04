# WeaveDI Builder Pattern Guide

Complete guide for the new Builder pattern officially introduced in WeaveDI v3.4.0. This pattern enables dependency registration through a more intuitive and fluent API.

## Overview

The WeaveDI.builder pattern is a new approach that allows you to register multiple dependencies at once through method chaining. It enables writing more readable and maintainable code compared to the traditional individual registration method.

### Key Advantages

- 🔗 **Method Chaining**: Register multiple dependencies fluentily in one go
- 📖 **Improved Readability**: Declarative and intuitive code style
- 🎯 **Type Safety**: Compile-time type verification
- 🔄 **Consistency**: Handle all dependency registration with a consistent pattern

## Basic Usage

### Simple Registration (Automatic Type Inference)

```swift
import WeaveDI

// Basic builder pattern - types are automatically inferred
WeaveDI.builder
    .register { UserServiceImpl() }    // Automatically registered as UserService
    .register { ConsoleLogger() }      // Automatically registered as Logger
    .register { NetworkClientImpl() }  // Automatically registered as NetworkClient
    .configure()
```

### Individual Registration

```swift
// Simple one-liner registration
WeaveDI.register { UserServiceImpl() }
WeaveDI.register { ConsoleLogger() }
WeaveDI.register { NetworkClientImpl() }

// Explicit registration as protocol types
WeaveDI.register { UserRepository() as UserRepositoryProtocol }
WeaveDI.register { AuthService() as AuthServiceProtocol }
```

## Comparison with Traditional Approach

### Traditional Approach

```swift
// Traditional individual registration method
UnifiedDI.register(UserService.self) { UserServiceImpl() }
UnifiedDI.register(Logger.self) { ConsoleLogger() }
UnifiedDI.register(NetworkClient.self) { NetworkClientImpl() }
UnifiedDI.register(CacheService.self) { CacheServiceImpl() }
```

### Builder Pattern (New Approach)

```swift
// New builder pattern - automatic type inference
WeaveDI.builder
    .register { UserServiceImpl() }    // Automatically registered as UserService
    .register { ConsoleLogger() }      // Automatically registered as Logger
    .register { NetworkClientImpl() }  // Automatically registered as NetworkClient
    .register { CacheServiceImpl() }   // Automatically registered as CacheService
    .configure()
```

## Advanced Usage

### Conditional Registration

```swift
WeaveDI.builder
    .register { UserServiceImpl() }
    .register {
        #if DEBUG
        return DebugLogger() as Logger
        #else
        return ProductionLogger() as Logger
        #endif
    }
    .register {
        if FeatureFlags.analyticsEnabled {
            return FirebaseAnalyticsService() as AnalyticsService
        } else {
            return NoOpAnalyticsService() as AnalyticsService
        }
    }
    .configure()

// Or use environment-based registration API
WeaveDI.registerForEnvironment { env in
    env.register { UserServiceImpl() }

    if env.isDebug {
        env.register { DebugLogger() as Logger }
        env.register { MockAnalyticsService() as AnalyticsService }
    } else {
        env.register { ProductionLogger() as Logger }
        env.register { FirebaseAnalyticsService() as AnalyticsService }
    }
}
```

### Dependency Chains

```swift
var factory = DiModuleFactory()

// Set up dependency chains
factory.addDependency(NetworkClient.self) {
    let config = WeaveDI.Container.live.resolve(NetworkConfig.self)!
    let logger = WeaveDI.Container.live.resolve(Logger.self)!
    return NetworkClient(config: config, logger: logger)
}

factory.addDependency(APIService.self) {
    let client = WeaveDI.Container.live.resolve(NetworkClient.self)!
    return APIService(client: client)
}
```

### Scope Specification

```swift
WeaveDI.builder
    .register { UserServiceImpl() }.scoped(.singleton)
    .register { RequestHandlerImpl() }.scoped(.transient)
    .register { SessionManagerImpl() }.scoped(.session)
    .configure()
```

## Environment-Based Configuration

### Development Environment

```swift
#if DEBUG
WeaveDI.builder
    .register { DebugLogger(level: .verbose) as Logger }
    .register { MockNetworkClient() as NetworkClient }
    .register { MockUserService() as UserService }
    .configure()
#endif
```

### Production Environment

```swift
#if !DEBUG
WeaveDI.builder
    .register { ProductionLogger(level: .warning) as Logger }
    .register { NetworkClientImpl() as NetworkClient }
    .register { FirebaseAnalyticsService() as AnalyticsService }
    .configure()
#endif
```

### Environment Factory Pattern

```swift
enum BuilderEnvironment {
    case development
    case staging
    case production

    func configure() {
        switch self {
        case .development:
            WeaveDI.builder
                .register { DebugLogger() as Logger }
                .register { MockAPIClient() as APIClient }
                .configure()

        case .staging:
            WeaveDI.builder
                .register { StagingLogger() as Logger }
                .register { StagingAPIClient() as APIClient }
                .configure()

        case .production:
            WeaveDI.builder
                .register { ProductionLogger() as Logger }
                .register { ProductionAPIClient() as APIClient }
                .configure()
        }
    }
}

// Usage
BuilderEnvironment.current.configure()
```

## Modularized Registration

### Feature-Based Builders

```swift
extension WeaveDI {
    static func configureNetworking() {
        builder
            .register { NetworkConfig.default as NetworkConfig }
            .register { NetworkClientImpl() as NetworkClient }
            .register { APIServiceImpl() as APIService }
            .configure()
    }

    static func configureAuth() {
        builder
            .register { AuthConfig.load() as AuthConfig }
            .register { AuthServiceImpl() as AuthService }
            .register { TokenManagerImpl() as TokenManager }
            .configure()
    }

    static func configureCore() {
        builder
            .register { AppLogger.shared as Logger }
            .register { UserDefaults.standard }
            .configure()
    }
}

// In app initialization
WeaveDI.configureCore()
WeaveDI.configureNetworking()
WeaveDI.configureAuth()
```

### Module Composition

```swift
struct AppDependencyBuilder {
    static func configureAll() {
        // Core dependencies
        WeaveDI.builder
            .register { AppConfig.load() as AppConfig }
            .register { AppLogger.shared as Logger }
            .configure()

        // Networking dependencies
        WeaveDI.builder
            .register { NetworkClientImpl() as NetworkClient }
            .register { APIServiceImpl() as APIService }
            .configure()

        // Business logic dependencies
        WeaveDI.builder
            .register { UserRepositoryImpl() as UserRepository }
            .register { AuthUseCaseImpl() as AuthUseCase }
            .configure()
    }
}
```

## Usage in Testing

### Test Builders

```swift
#if DEBUG
extension WeaveDI {
    static func configureMocks() {
        builder
            .register { MockUserService() as UserService }
            .register { MockNetworkClient() as NetworkClient }
            .register { MockLogger() as Logger }
            .configure()
    }

    static func configureTestData() {
        builder
            .register { TestDataManagerImpl() as TestDataManager }
            .register { MockServerImpl() as MockServer }
            .configure()
    }
}

// In test cases
class SomeTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        WeaveDI.configureMocks()
        WeaveDI.configureTestData()
    }
}
#endif
```

### Partial Mock Registration

```swift
// Replace only some with mocks
WeaveDI.builder
    .register { MockUserService() as UserService }  // Mock
    .register { AppLogger.shared as Logger }        // Real
    .register { MockNetworkClient() as NetworkClient }  // Mock
    .configure()
```

## Performance Considerations

### Batch Registration

The builder pattern internally performs batch registration for performance optimization:

```swift
// Internally optimized batch registration
WeaveDI.builder
    .register { Service1Impl() }
    .register { Service2Impl() }
    .register { Service3Impl() }
    .configure()  // All registered at once here
```

### Lazy Registration

```swift
// Execute builder only when needed
lazy var dependencyBuilder = WeaveDI.builder
    .register { ExpensiveServiceImpl() as ExpensiveService }

// Register at the actual needed moment
func setupDependencies() {
    dependencyBuilder.configure()
}
```

## Error Handling

### Registration Failure Handling

```swift
do {
    try WeaveDI.builder
        .register {
            try RiskyServiceImpl()
        }
        .register { SafeServiceImpl() }
        .configure()
} catch {
    print("Dependency registration failed: \(error)")
    // Fallback configuration
    WeaveDI.builder
        .register { FallbackService() as RiskyService }
        .configure()
}
```

### Validation

```swift
WeaveDI.builder
    .register { UserServiceImpl() }
    .register { ConsoleLogger() }
    .validate()  // Validate before registration
    .configure()
```

## Migration Guide

### From Traditional Code to Builder Pattern

**Before:**
```swift
UnifiedDI.register(UserService.self) { UserServiceImpl() }
UnifiedDI.register(Logger.self) { ConsoleLogger() }
UnifiedDI.register(NetworkClient.self) { NetworkClientImpl() }
```

**After:**
```swift
WeaveDI.builder
    .register { UserServiceImpl() }
    .register { ConsoleLogger() }
    .register { NetworkClientImpl() }
    .configure()
```

### Gradual Migration

You can use existing code and new builder pattern together:

```swift
// Keep existing registration
UnifiedDI.register(LegacyService.self) { LegacyServiceImpl() }

// Add new builder pattern
WeaveDI.builder
    .register { NewServiceImpl() }
    .register { ModernServiceImpl() }
    .configure()
```

## Best Practices

### 1. Dependency Grouping

Register related dependencies together:

```swift
// Good: Group related dependencies
WeaveDI.builder
    .register { UserRepositoryImpl() }
    .register { UserServiceImpl() }
    .register { UserValidatorImpl() }
    .configure()
```

### 2. Clear Dependency Order

Register in order considering relationships between dependencies:

```swift
WeaveDI.builder
    .register { DatabaseConfig.load() as DatabaseConfig }    // 1. Configuration
    .register { DatabaseImpl() as Database }                 // 2. Infrastructure
    .register { UserRepositoryImpl() as UserRepository }     // 3. Data layer
    .register { UserServiceImpl() as UserService }           // 4. Business logic
    .configure()
```

### 3. Environment Separation

```swift
// Good: Clear separation by environment
#if DEBUG
WeaveDI.builder
    .register { DebugLogger() as Logger }
    .configure()
#else
WeaveDI.builder
    .register { ProductionLogger() as Logger }
    .configure()
#endif
```

Through the WeaveDI Builder pattern, you can write cleaner and more maintainable dependency registration code. It's perfectly compatible with existing APIs, allowing for gradual migration.