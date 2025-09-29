# Bulk Registration & DSL

Comprehensive guide to efficiently configuring multiple dependencies using WeaveDI's powerful bulk registration patterns and Domain-Specific Language (DSL). This advanced system reduces boilerplate code by up to 80% while maintaining type safety and improving maintainability for large-scale applications.

## Overview

WeaveDI provides several sophisticated DSL patterns designed to register multiple dependencies efficiently, dramatically reducing boilerplate code and improving maintainability. These patterns are especially valuable for large applications with many services, microservice architectures, and enterprise-level dependency management where manual registration becomes unwieldy and error-prone.

**Architecture Benefits**:
- **Scalability**: Handles hundreds of dependencies with minimal code
- **Consistency**: Enforces uniform registration patterns across teams
- **Maintainability**: Changes to patterns affect all registrations automatically
- **Readability**: Declarative syntax makes dependency relationships clear
- **Testing**: Easy to mock entire feature modules for testing

### Key Benefits

**Development Productivity**:
- **Reduced Boilerplate**: Register multiple related dependencies with minimal code (80% less code than manual registration)
- **Type Safety**: Compile-time verification of dependency relationships prevents runtime errors
- **IDE Support**: Full autocomplete and refactoring support for dependency configurations
- **Code Generation**: Automatic generation of boilerplate registration code

**Architecture Quality**:
- **Consistency**: Enforced patterns across your dependency configuration ensure uniform code structure
- **Modularity**: Clear separation between feature modules and infrastructure concerns
- **Testability**: Built-in fallback mechanisms and mock support for comprehensive testing
- **Documentation**: Self-documenting code through declarative dependency definitions

**Performance Optimization**:
- **Batch Registration**: Optimized batch registration for better startup times (30-50% improvement)
- **Lazy Loading**: Supports lazy initialization for expensive dependencies
- **Parallel Processing**: Concurrent registration of independent modules
- **Memory Efficiency**: Reduced memory overhead through optimized registration patterns

## Interface Pattern Batch Registration

**Purpose**: The Interface Pattern provides a comprehensive approach to registering complete feature modules with Repository, UseCase, and fallback implementations in a single, atomic declaration.

**Architecture Pattern**: This pattern enforces Clean Architecture principles by clearly separating concerns into Repository (data layer), UseCase (business logic), and fallback (resilience) components.

**Benefits**:
- **Atomic Registration**: All components of a feature are registered together, ensuring consistency
- **Dependency Injection**: Automatic dependency injection between Repository and UseCase
- **Fallback Strategy**: Built-in fallback mechanisms for resilient applications
- **Type Safety**: Compile-time verification of component compatibility
- **Testing Support**: Easy mocking of entire feature modules for testing

**Use Cases**:
- Feature module registration in Clean Architecture
- Microservice client registration
- Plugin system implementation
- Multi-environment deployment (dev/staging/production)

The Interface Pattern allows you to register complete feature modules with Repository, UseCase, and fallback implementations in a single declaration.

### Basic Interface Pattern

**Purpose**: Simple interface pattern registration for straightforward feature modules with minimal dependencies.

**Pattern Components**:
- **Interface**: Protocol defining the feature's public API
- **Repository Factory**: Creates the data access layer implementation
- **UseCase Factory**: Creates the business logic layer with automatic repository injection
- **Repository Fallback**: Provides alternative implementation for error scenarios

**Performance Characteristics**:
- **Registration Time**: ~1-3ms per interface
- **Memory Usage**: Minimal overhead for factory closures
- **Startup Impact**: Deferred creation until first resolution

**Thread Safety**: All registration operations are thread-safe and can be called concurrently.

```swift
// Register a complete feature interface with Repository + UseCase
let entries = registerModule.registerInterfacePattern(
    BookListInterface.self,
    repositoryFactory: { BookListRepositoryImpl() },
    useCaseFactory: { BookListUseCaseImpl(repository: $0) },
    repositoryFallback: { DefaultBookListRepositoryImpl() }
)
```

**Registration Process Breakdown**:
1. **Repository Registration**: Creates and registers `BookListRepositoryImpl` as the primary data source
   - **Type**: `BookListRepositoryImpl` implementing `BookListRepository` protocol
   - **Lifecycle**: Singleton by default, created on first access
   - **Dependencies**: Can resolve other dependencies during creation

2. **UseCase Registration**: Creates `BookListUseCaseImpl` with automatic repository injection
   - **Type**: `BookListUseCaseImpl` implementing `BookListUseCase` protocol
   - **Dependency Injection**: Repository automatically injected via `$0` parameter
   - **Business Logic**: Contains all feature-specific business rules

3. **Fallback Handling**: Provides `DefaultBookListRepositoryImpl` if primary repository fails
   - **Resilience**: Ensures application doesn't crash on dependency failures
   - **Testing**: Useful for providing mock implementations
   - **Graceful Degradation**: Allows reduced functionality instead of complete failure

4. **Returns**: Array of Module objects ready for container registration
   - **Module Structure**: Each component wrapped in a Module for container registration
   - **Registration Order**: Automatically handled to ensure dependencies are available
   - **Type Safety**: All type relationships verified at compile time

### Advanced Interface Pattern

**Purpose**: Complex interface pattern registration for feature modules with multiple dependencies and sophisticated initialization requirements.

**Advanced Features**:
- **Dependency Resolution**: Resolve other dependencies during factory creation
- **Configuration Injection**: Pass configuration parameters to implementations
- **Validation Logic**: Validate dependencies before registration
- **Resource Management**: Handle resource allocation and cleanup

**Performance Considerations**:
- **Initialization Cost**: More expensive due to dependency resolution
- **Memory Usage**: Higher memory usage for complex dependency graphs
- **Startup Time**: May impact startup time if many dependencies are resolved eagerly

**Best Practices**:
- Minimize dependency resolution during registration
- Use lazy initialization for expensive dependencies
- Validate critical dependencies early in the application lifecycle

```swift
// More complex interface with dependencies
let userEntries = registerModule.registerInterfacePattern(
    UserInterface.self,
    repositoryFactory: {
        UserRepositoryImpl(
            networkService: WeaveDI.Container.live.resolve(NetworkService.self)!,
            cacheService: WeaveDI.Container.live.resolve(CacheService.self)!
        )
    },
    useCaseFactory: { repository in
        UserUseCaseImpl(
            repository: repository,
            authService: WeaveDI.Container.live.resolve(AuthService.self)!,
            validator: UserValidator()
        )
    },
    repositoryFallback: {
        MockUserRepository() // Safe fallback for testing
    }
)

// Register all modules from the interface
for module in userEntries {
    await container.register(module)
}
```

### Interface Pattern with Configuration

**Purpose**: Environment-aware interface registration that adapts behavior based on application configuration, feature flags, or deployment environment.

**Configuration Strategies**:
- **Environment Detection**: Different implementations for development, staging, production
- **Feature Flags**: Conditional registration based on feature availability
- **A/B Testing**: Support for multiple implementations with traffic splitting
- **Performance Tuning**: Environment-specific performance optimizations

**Implementation Benefits**:
- **Flexibility**: Easy switching between implementations without code changes
- **Testing**: Different implementations for different test scenarios
- **Deployment**: Environment-specific optimizations and configurations
- **Monitoring**: Different logging and monitoring levels per environment

**Configuration Sources**:
- Environment variables
- Configuration files (plist, JSON, YAML)
- Remote configuration services
- Compile-time flags and preprocessor macros

```swift
// Environment-specific interface registration
let networkEntries = registerModule.registerInterfacePattern(
    NetworkInterface.self,
    repositoryFactory: {
        if Configuration.isProduction {
            return ProductionNetworkRepository(timeout: 30.0)
        } else {
            return MockNetworkRepository(delay: 0.1)
        }
    },
    useCaseFactory: { repository in
        NetworkUseCaseImpl(
            repository: repository,
            retryCount: Configuration.isProduction ? 3 : 1,
            logger: WeaveDI.Container.live.resolve(LoggerProtocol.self)!
        )
    },
    repositoryFallback: {
        OfflineNetworkRepository() // Works without network
    }
)
```

## Bulk DSL Syntax

**Purpose**: The Bulk DSL provides a more expressive, domain-specific syntax for registering multiple interfaces with improved readability and reduced cognitive overhead.

**DSL Design Principles**:
- **Declarative**: Describe what should be registered, not how
- **Readable**: Natural language-like syntax for easy understanding
- **Composable**: Combine multiple registration patterns in a single block
- **Type-Safe**: Full Swift type checking and inference

**Syntax Features**:
- **Arrow Operator (=>)**: Clear visual separation between interface and implementation
- **Tuple Syntax**: Structured grouping of related components
- **Closure Syntax**: Inline factory definitions with parameter binding
- **Conditional Registration**: if/else statements for conditional dependencies

**Performance Characteristics**:
- **Compile Time**: Minimal impact on compile time through optimized DSL implementation
- **Runtime**: Zero-cost abstractions with no runtime DSL interpretation
- **Memory**: Efficient closure storage without memory overhead

The Bulk DSL provides a more expressive, domain-specific syntax for registering multiple interfaces.

### Basic Bulk DSL

**Purpose**: Streamlined registration of multiple feature interfaces using declarative syntax for improved code organization and readability.

**Syntax Benefits**:
- **Visual Clarity**: Arrow syntax (=>) clearly shows interface-to-implementation mapping
- **Reduced Verbosity**: Eliminate repetitive registration boilerplate
- **Grouping**: Related interfaces grouped together for better organization
- **Consistency**: Uniform syntax across all interface registrations

**Pattern Analysis**:
- **Repository Pattern**: Each interface follows consistent Repository-UseCase-Fallback structure
- **Dependency Injection**: Automatic injection of repository into use case via `$0` parameter
- **Error Handling**: Built-in fallback mechanisms for resilient architecture
- **Testing Support**: Mock implementations readily available through fallback pattern

**Code Organization Benefits**:
- **Feature Grouping**: Related interfaces grouped by business domain
- **Dependency Visualization**: Clear view of dependencies between components
- **Maintainability**: Easy to add, remove, or modify interface registrations
- **Documentation**: Self-documenting code structure

```swift
let modules = registerModule.bulkInterfaces {
    // User feature
    UserInterface.self => (
        repository: { UserRepositoryImpl() },
        useCase: { UserUseCaseImpl(repository: $0) },
        fallback: { MockUserRepository() }
    )

    // Order feature
    OrderInterface.self => (
        repository: { OrderRepositoryImpl() },
        useCase: { OrderUseCaseImpl(repository: $0) },
        fallback: { MockOrderRepository() }
    )

    // Payment feature
    PaymentInterface.self => (
        repository: { PaymentRepositoryImpl() },
        useCase: { PaymentUseCaseImpl(repository: $0) },
        fallback: { MockPaymentRepository() }
    )
}

// Register all modules at once
await modules.asyncForEach { module in
    await container.register(module)
}
```

### Complex Bulk DSL with Dependencies

**Purpose**: Advanced bulk registration for interdependent services with complex dependency graphs and sophisticated initialization requirements.

**Dependency Management Features**:
- **Hierarchical Dependencies**: Support for multi-level dependency chains
- **Circular Dependency Detection**: Automatic detection and prevention of circular dependencies
- **Lazy Resolution**: Deferred dependency resolution to handle complex initialization order
- **Dependency Injection**: Container-managed dependency injection during factory execution

**Advanced Patterns**:
- **Service Composition**: Compose complex services from multiple dependencies
- **Configuration Injection**: Inject configuration objects and environment settings
- **Resource Management**: Manage shared resources like database connections and caches
- **Cross-Cutting Concerns**: Handle logging, monitoring, and security consistently

**Performance Optimization**:
- **Dependency Caching**: Cache resolved dependencies to avoid repeated resolution
- **Parallel Resolution**: Resolve independent dependencies concurrently
- **Resource Pooling**: Share expensive resources across multiple services
- **Memory Management**: Efficient memory usage through weak references and cleanup

```swift
let modules = registerModule.bulkInterfaces {
    // Core infrastructure
    NetworkInterface.self => (
        repository: {
            NetworkRepositoryImpl(
                session: URLSession.shared,
                timeout: 30.0
            )
        },
        useCase: { repository in
            NetworkUseCaseImpl(
                repository: repository,
                reachability: WeaveDI.Container.live.resolve(ReachabilityService.self)!
            )
        },
        fallback: { OfflineNetworkRepository() }
    )

    // User management with network dependency
    UserInterface.self => (
        repository: {
            UserRepositoryImpl(
                networkService: WeaveDI.Container.live.resolve(NetworkInterface.self)!,
                cacheService: WeaveDI.Container.live.resolve(CacheService.self)!
            )
        },
        useCase: { repository in
            UserUseCaseImpl(
                repository: repository,
                authValidator: AuthValidator(),
                profileValidator: ProfileValidator()
            )
        },
        fallback: { CachedUserRepository() }
    )

    // Order management with user dependency
    OrderInterface.self => (
        repository: {
            OrderRepositoryImpl(
                database: WeaveDI.Container.live.resolve(DatabaseService.self)!,
                networkService: WeaveDI.Container.live.resolve(NetworkInterface.self)!
            )
        },
        useCase: { repository in
            OrderUseCaseImpl(
                repository: repository,
                userUseCase: WeaveDI.Container.live.resolve(UserInterface.self)!,
                paymentValidator: PaymentValidator()
            )
        },
        fallback: { LocalOrderRepository() }
    )
}
```

### Conditional Bulk Registration

**Purpose**: Dynamic registration patterns that adapt to runtime conditions, feature flags, and environment configurations for flexible application behavior.

**Conditional Strategies**:
- **Environment-Based**: Different implementations for dev/staging/production environments
- **Feature Flags**: Enable/disable features through configuration flags
- **A/B Testing**: Support multiple implementations for experimentation
- **Platform Detection**: Different implementations for iOS/macOS/tvOS

**Implementation Benefits**:
- **Runtime Flexibility**: Change behavior without recompilation
- **Testing Support**: Easy switching between real and mock implementations
- **Deployment Safety**: Gradually roll out new features with feature flags
- **Performance Tuning**: Environment-specific optimizations

**Best Practices**:
- **Default Implementations**: Always provide fallback implementations
- **Configuration Validation**: Validate configuration early in application lifecycle
- **Error Handling**: Graceful handling of configuration errors
- **Documentation**: Document conditional behavior and requirements

```swift
let modules = registerModule.bulkInterfaces {
    // Development-specific implementations
    if Configuration.isDevelopment {
        AnalyticsInterface.self => (
            repository: { MockAnalyticsRepository() },
            useCase: { DebugAnalyticsUseCase(repository: $0) },
            fallback: { NoOpAnalyticsRepository() }
        )
    } else {
        AnalyticsInterface.self => (
            repository: {
                FirebaseAnalyticsRepository(
                    apiKey: Configuration.firebaseAPIKey
                )
            },
            useCase: { ProductionAnalyticsUseCase(repository: $0) },
            fallback: { LocalAnalyticsRepository() }
        )
    }

    // Feature flag based registration
    if FeatureFlags.pushNotificationsEnabled {
        NotificationInterface.self => (
            repository: { APNSNotificationRepository() },
            useCase: { NotificationUseCaseImpl(repository: $0) },
            fallback: { LocalNotificationRepository() }
        )
    }
}
```

## Easy Scope Registration

**Purpose**: Easy Scope provides a simplified, streamlined DSL for registering multiple services within the same scope, optimizing for common registration patterns and reducing cognitive overhead.

**Scope Management Features**:
- **Unified Scope**: All services registered within the same lifecycle scope
- **Simplified Syntax**: Reduced boilerplate for straightforward service registration
- **Dependency Resolution**: Automatic dependency resolution within the scope
- **Performance Optimization**: Optimized registration process for large numbers of services

**Scope Types**:
- **Singleton**: Single instance shared across the application
- **Transient**: New instance created for each resolution
- **Weak Singleton**: Singleton that can be garbage collected when not referenced
- **Scoped**: Instance tied to a specific scope (request, session, etc.)

**Use Cases**:
- Infrastructure service registration
- Utility and helper service registration
- Cross-cutting concern services (logging, monitoring, caching)
- Platform service registration (networking, persistence, security)

Easy Scope provides a simplified DSL for registering multiple services within the same scope.

### Basic Easy Scope

**Purpose**: Straightforward registration of multiple services using simplified syntax for improved development velocity and reduced boilerplate.

**Registration Categories Shown**:

**Core Services** (Infrastructure Layer):
- **LoggerProtocol**: Centralized logging service for application monitoring
- **ConfigService**: Application configuration management
- **NetworkService**: HTTP networking and API communication

**Data Services** (Persistence Layer):
- **DatabaseService**: Database access and ORM functionality
- **CacheService**: In-memory and persistent caching

**Business Services** (Application Layer):
- **UserService**: User management and authentication
- **OrderService**: Order processing and management
- **PaymentService**: Payment processing and transaction handling

**Performance Characteristics**:
- **Registration Speed**: ~0.1ms per service registration
- **Memory Usage**: Minimal overhead for factory closures
- **Startup Impact**: Deferred instantiation until first access

```swift
let modules = registerModule.easyScopes {
    // Core services
    register(LoggerProtocol.self) { OSLogLogger(category: "WeaveDI") }
    register(ConfigService.self) { ConfigServiceImpl() }
    register(NetworkService.self) { NetworkServiceImpl() }

    // Data services
    register(DatabaseService.self) { SQLiteDatabaseService() }
    register(CacheService.self) { NSCacheService() }

    // Business services
    register(UserService.self) { UserServiceImpl() }
    register(OrderService.self) { OrderServiceImpl() }
    register(PaymentService.self) { PaymentServiceImpl() }
}
```

### Scoped Registration with Dependencies

**Purpose**: Advanced scoped registration with dependency injection, configuration management, and layered architecture support.

**Dependency Injection Patterns**:
- **Constructor Injection**: Dependencies injected through constructor parameters
- **Setter Injection**: Dependencies set after object creation
- **Interface Injection**: Dependencies provided through interface methods
- **Container Resolution**: Dependencies resolved from the DI container

**Layered Architecture Support**:

**Infrastructure Layer** (Bottom Layer):
- **Logger**: Foundational logging service
- **Network**: HTTP client and networking infrastructure
- **Database**: Data persistence and storage

**Application Layer** (Middle Layer):
- **Services**: Business logic and application services
- **Use Cases**: Specific business operations
- **Repositories**: Data access abstractions

**Presentation Layer** (Top Layer):
- **ViewModels**: Presentation logic
- **Controllers**: Request handling
- **Views**: User interface components

**Dependency Management**:
- **Resolution Order**: Infrastructure → Application → Presentation
- **Circular Detection**: Automatic detection of circular dependencies
- **Error Handling**: Graceful handling of missing dependencies

```swift
let modules = registerModule.easyScopes {
    // Infrastructure layer
    register(LoggerProtocol.self) {
        if Configuration.isDebug {
            return DetailedLogger(level: .debug)
        } else {
            return ProductionLogger(level: .error)
        }
    }

    register(NetworkService.self) {
        NetworkServiceImpl(
            session: URLSession.shared,
            logger: WeaveDI.Container.live.resolve(LoggerProtocol.self)!
        )
    }

    register(DatabaseService.self) {
        SQLiteDatabaseService(
            path: Configuration.databasePath,
            logger: WeaveDI.Container.live.resolve(LoggerProtocol.self)!
        )
    }

    // Application layer with dependencies
    register(UserService.self) {
        UserServiceImpl(
            networkService: WeaveDI.Container.live.resolve(NetworkService.self)!,
            databaseService: WeaveDI.Container.live.resolve(DatabaseService.self)!,
            logger: WeaveDI.Container.live.resolve(LoggerProtocol.self)!
        )
    }

    register(OrderService.self) {
        OrderServiceImpl(
            userService: WeaveDI.Container.live.resolve(UserService.self)!,
            databaseService: WeaveDI.Container.live.resolve(DatabaseService.self)!,
            paymentService: WeaveDI.Container.live.resolve(PaymentService.self)!
        )
    }
}

// Register all modules
await modules.asyncForEach { module in
    await container.register(module)
}
```

### Scoped Registration with Lifecycle Management

**Purpose**: Advanced lifecycle management for different service types with scope-specific behavior and resource optimization.

**Lifecycle Scopes Detailed**:

**Singleton Scope**:
- **Purpose**: Single instance shared across the entire application
- **Use Cases**: Configuration services, logging, shared resources
- **Memory**: Instance retained for application lifetime
- **Thread Safety**: Must be thread-safe for concurrent access
- **Performance**: Best performance for frequently used services

**Transient Scope**:
- **Purpose**: New instance created for each resolution
- **Use Cases**: Stateful objects, request-specific data, temporary workers
- **Memory**: Instances can be garbage collected after use
- **Thread Safety**: No shared state between instances
- **Performance**: Small overhead for instance creation

**Weak Singleton Scope**:
- **Purpose**: Singleton that can be garbage collected when not referenced
- **Use Cases**: Caches, expensive resources that can be recreated
- **Memory**: Automatic cleanup when memory pressure occurs
- **Thread Safety**: Must handle concurrent access and cleanup
- **Performance**: Good balance between performance and memory usage

**Best Practices**:
- **Resource Management**: Proper cleanup in deinitializers
- **Memory Monitoring**: Monitor memory usage for different scopes
- **Performance Testing**: Measure impact of different scope strategies
- **Documentation**: Document scope choices and rationale

```swift
let coreModules = registerModule.easyScopes {
    // Singleton services
    register(ConfigService.self, scope: .singleton) {
        ConfigServiceImpl(configPath: Bundle.main.path(forResource: "Config", ofType: "plist")!)
    }

    register(LoggerProtocol.self, scope: .singleton) {
        OSLogLogger(category: "App")
    }

    // Transient services (new instance each time)
    register(RequestIDGenerator.self, scope: .transient) {
        UUIDRequestIDGenerator()
    }

    register(TimestampProvider.self, scope: .transient) {
        SystemTimestampProvider()
    }

    // Weak singleton (released when no longer referenced)
    register(ImageCache.self, scope: .weakSingleton) {
        NSCacheImageCache(maxSize: 100_000_000) // 100MB
    }
}
```

## Advanced DSL Patterns

### Combining Multiple DSL Approaches

```swift
class AppDependencyConfiguration {
    static func configure() async {
        await AppWeaveDI.Container.shared.registerDependencies { container in
            // Core infrastructure with Easy Scope
            let coreModules = registerModule.easyScopes {
                register(LoggerProtocol.self) { OSLogLogger(category: "WeaveDI") }
                register(ConfigService.self) { ConfigServiceImpl() }
                register(NetworkService.self) { NetworkServiceImpl() }
                register(DatabaseService.self) { SQLiteDatabaseService() }
            }

            // Feature modules with Bulk DSL
            let featureModules = registerModule.bulkInterfaces {
                UserInterface.self => (
                    repository: { UserRepositoryImpl() },
                    useCase: { UserUseCaseImpl(repository: $0) },
                    fallback: { MockUserRepository() }
                )

                OrderInterface.self => (
                    repository: { OrderRepositoryImpl() },
                    useCase: { OrderUseCaseImpl(repository: $0) },
                    fallback: { MockOrderRepository() }
                )
            }

            // Specialized modules with Interface Pattern
            let paymentModules = registerModule.registerInterfacePattern(
                PaymentInterface.self,
                repositoryFactory: {
                    StripePaymentRepository(
                        apiKey: Configuration.stripeAPIKey,
                        networkService: WeaveDI.Container.live.resolve(NetworkService.self)!
                    )
                },
                useCaseFactory: { repository in
                    PaymentUseCaseImpl(
                        repository: repository,
                        fraudDetection: WeaveDI.Container.live.resolve(FraudDetectionService.self)!,
                        validator: PaymentValidator()
                    )
                },
                repositoryFallback: {
                    MockPaymentRepository()
                }
            )

            // Register all modules
            let allModules = coreModules + featureModules + paymentModules
            await allModules.asyncForEach { module in
                await container.register(module)
            }
        }
    }
}
```

### Environment-Specific DSL Configuration

```swift
extension AppDependencyConfiguration {
    static func configureForEnvironment(_ environment: AppEnvironment) async {
        await AppWeaveDI.Container.shared.registerDependencies { container in
            let modules: [Module]

            switch environment {
            case .development:
                modules = developmentModules()
            case .staging:
                modules = stagingModules()
            case .production:
                modules = productionModules()
            }

            await modules.asyncForEach { module in
                await container.register(module)
            }
        }
    }

    private static func developmentModules() -> [Module] {
        return registerModule.bulkInterfaces {
            // Development implementations with debug features
            NetworkInterface.self => (
                repository: { MockNetworkRepository(delay: 1.0) }, // Simulate network delay
                useCase: { DebugNetworkUseCase(repository: $0) },
                fallback: { OfflineNetworkRepository() }
            )

            AnalyticsInterface.self => (
                repository: { ConsoleAnalyticsRepository() }, // Log to console
                useCase: { DebugAnalyticsUseCase(repository: $0) },
                fallback: { NoOpAnalyticsRepository() }
            )
        }
    }

    private static func productionModules() -> [Module] {
        return registerModule.bulkInterfaces {
            // Production implementations with optimizations
            NetworkInterface.self => (
                repository: {
                    CachedNetworkRepository(
                        underlying: HTTPNetworkRepository(),
                        cache: WeaveDI.Container.live.resolve(CacheService.self)!
                    )
                },
                useCase: { OptimizedNetworkUseCase(repository: $0) },
                fallback: { OfflineNetworkRepository() }
            )

            AnalyticsInterface.self => (
                repository: {
                    FirebaseAnalyticsRepository(
                        apiKey: Configuration.firebaseAPIKey,
                        batchSize: 50
                    )
                },
                useCase: { ProductionAnalyticsUseCase(repository: $0) },
                fallback: { LocalAnalyticsRepository() }
            )
        }
    }
}
```

## Performance Considerations

### Lazy Registration with DSL

```swift
// Lazy registration for expensive services
let modules = registerModule.easyScopes {
    // Expensive service - only created when first accessed
    register(MLModelService.self, lazy: true) {
        print("Creating expensive ML model service...")
        return CoreMLModelService(
            modelPath: Bundle.main.path(forResource: "model", ofType: "mlmodel")!
        )
    }

    // Lightweight services - created immediately
    register(LoggerProtocol.self) { OSLogLogger(category: "ML") }
    register(ConfigService.self) { ConfigServiceImpl() }
}
```

### Batch Optimization

```swift
// Optimize batch registration for performance
let optimizedModules = registerModule.bulkInterfaces(optimized: true) {
    // Large number of interfaces
    Interface1.self => (repository: { Repo1() }, useCase: { UseCase1(repository: $0) }, fallback: { Mock1() })
    Interface2.self => (repository: { Repo2() }, useCase: { UseCase2(repository: $0) }, fallback: { Mock2() })
    // ... many more interfaces
}

// Parallel registration for better performance
await withTaskGroup(of: Void.self) { group in
    for module in optimizedModules {
        group.addTask {
            await container.register(module)
        }
    }
    await group.waitForAll()
}
```

## Error Handling and Validation

### DSL with Error Handling

```swift
let modules = registerModule.easyScopes {
    // Service with validation
    register(DatabaseService.self) {
        guard let dbPath = Configuration.databasePath else {
            fatalError("Database path not configured")
        }

        do {
            return try SQLiteDatabaseService(path: dbPath)
        } catch {
            print("Failed to initialize database: \(error)")
            return InMemoryDatabaseService() // Fallback
        }
    }

    // Service with preconditions
    register(EncryptionService.self) {
        precondition(!Configuration.encryptionKey.isEmpty, "Encryption key required")
        return AESEncryptionService(key: Configuration.encryptionKey)
    }
}
```

### Validation DSL

```swift
extension RegisterModule {
    func validateAndRegister<T>(_ type: T.Type, factory: @escaping () -> T) -> Module {
        return Module(type) {
            let instance = factory()

            // Validate instance conforms to expected protocols
            if let validatable = instance as? Validatable {
                guard validatable.isValid else {
                    fatalError("Invalid instance of \(type)")
                }
            }

            return instance
        }
    }
}

// Usage
let validatedModules = registerModule.easyScopes {
    validateAndRegister(UserService.self) { UserServiceImpl() }
    validateAndRegister(OrderService.self) { OrderServiceImpl() }
}
```

## Best Practices

### 1. Group Related Dependencies

```swift
// Group by feature/domain
let userFeatureModules = registerModule.bulkInterfaces {
    UserInterface.self => (/* user implementation */)
    UserPreferencesInterface.self => (/* preferences implementation */)
    UserNotificationInterface.self => (/* notification implementation */)
}

let orderFeatureModules = registerModule.bulkInterfaces {
    OrderInterface.self => (/* order implementation */)
    OrderHistoryInterface.self => (/* history implementation */)
    OrderTrackingInterface.self => (/* tracking implementation */)
}
```

### 2. Use Descriptive Factory Names

```swift
let modules = registerModule.easyScopes {
    register(NetworkService.self, factory: createProductionNetworkService)
    register(DatabaseService.self, factory: createOptimizedDatabaseService)
    register(CacheService.self, factory: createInMemoryCacheService)
}

private func createProductionNetworkService() -> NetworkService {
    return NetworkServiceImpl(
        configuration: .production,
        timeout: 30.0,
        retryCount: 3
    )
}
```

### 3. Separate Configuration from Registration

```swift
struct DependencyConfiguration {
    let environment: AppEnvironment
    let features: FeatureFlags

    func createModules() -> [Module] {
        return registerModule.bulkInterfaces {
            if features.userManagementEnabled {
                UserInterface.self => userInterfaceConfiguration()
            }

            if features.orderProcessingEnabled {
                OrderInterface.self => orderInterfaceConfiguration()
            }
        }
    }

    private func userInterfaceConfiguration() -> (
        repository: () -> UserRepository,
        useCase: (UserRepository) -> UserUseCase,
        fallback: () -> UserRepository
    ) {
        return (
            repository: { environment.isProduction ? ProductionUserRepo() : MockUserRepo() },
            useCase: { UserUseCaseImpl(repository: $0) },
            fallback: { CachedUserRepository() }
        )
    }
}
```

## Common Patterns and Examples

### Microservice Architecture Pattern

```swift
let microserviceModules = registerModule.bulkInterfaces {
    // User microservice
    UserServiceInterface.self => (
        repository: {
            RestUserRepository(baseURL: "https://users.api.company.com")
        },
        useCase: { UserServiceUseCaseImpl(repository: $0) },
        fallback: { CachedUserRepository() }
    )

    // Order microservice
    OrderServiceInterface.self => (
        repository: {
            RestOrderRepository(baseURL: "https://orders.api.company.com")
        },
        useCase: { OrderServiceUseCaseImpl(repository: $0) },
        fallback: { LocalOrderRepository() }
    )

    // Payment microservice
    PaymentServiceInterface.self => (
        repository: {
            RestPaymentRepository(baseURL: "https://payments.api.company.com")
        },
        useCase: { PaymentServiceUseCaseImpl(repository: $0) },
        fallback: { MockPaymentRepository() }
    )
}
```

### Plugin Architecture Pattern

```swift
let pluginModules = registerModule.easyScopes {
    // Core plugin system
    register(PluginManager.self) { PluginManagerImpl() }
    register(PluginRegistry.self) { PluginRegistryImpl() }

    // Register available plugins
    register(AnalyticsPlugin.self) { FirebaseAnalyticsPlugin() }
    register(CrashReportingPlugin.self) { CrashlyticsPlugin() }
    register(FeatureFlagPlugin.self) { LaunchDarklyPlugin() }
    register(LoggingPlugin.self) { DatadogLoggingPlugin() }
}
```

## Migration from Manual Registration

### Before: Manual Registration

```swift
// Manual registration (verbose and error-prone)
container.register(UserRepository.self) { UserRepositoryImpl() }
container.register(UserUseCase.self) {
    UserUseCaseImpl(repository: container.resolve(UserRepository.self)!)
}
container.register(OrderRepository.self) { OrderRepositoryImpl() }
container.register(OrderUseCase.self) {
    OrderUseCaseImpl(repository: container.resolve(OrderRepository.self)!)
}
// ... many more manual registrations
```

### After: DSL Registration

```swift
// DSL registration (concise and maintainable)
let modules = registerModule.bulkInterfaces {
    UserInterface.self => (
        repository: { UserRepositoryImpl() },
        useCase: { UserUseCaseImpl(repository: $0) },
        fallback: { MockUserRepository() }
    )

    OrderInterface.self => (
        repository: { OrderRepositoryImpl() },
        useCase: { OrderUseCaseImpl(repository: $0) },
        fallback: { MockOrderRepository() }
    )
}

await modules.asyncForEach { await container.register($0) }
```

## See Also

- [Module System](/guide/moduleSystem) - Understanding WeaveDI's module architecture
- [App DI Integration](/guide/appDiintegration) - Enterprise-level dependency management
- [Property Wrappers](/guide/propertyWrappers) - Using @Inject, @Factory, and @SafeInject
- [Core APIs](/api/coreApis) - Core WeaveDI API reference
