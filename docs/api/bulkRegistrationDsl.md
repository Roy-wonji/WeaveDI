# Bulk Registration & DSL

Comprehensive guide to efficiently configuring multiple dependencies using WeaveDI's powerful bulk registration patterns and Domain-Specific Language (DSL).

## Overview

WeaveDI provides several DSL patterns to register multiple dependencies efficiently, reducing boilerplate code and improving maintainability. These patterns are especially valuable for large applications with many services.

### Key Benefits

- **Reduced Boilerplate**: Register multiple related dependencies with minimal code
- **Type Safety**: Compile-time verification of dependency relationships
- **Consistency**: Enforced patterns across your dependency configuration
- **Performance**: Optimized batch registration for better startup times
- **Maintainability**: Clear, declarative dependency definitions

## Interface Pattern Batch Registration

The Interface Pattern allows you to register complete feature modules with Repository, UseCase, and fallback implementations in a single declaration.

### Basic Interface Pattern

```swift
// Register a complete feature interface with Repository + UseCase
let entries = registerModule.registerInterfacePattern(
    BookListInterface.self,
    repositoryFactory: { BookListRepositoryImpl() },
    useCaseFactory: { BookListUseCaseImpl(repository: $0) },
    repositoryFallback: { DefaultBookListRepositoryImpl() }
)
```

**What this does:**
1. **Repository Registration**: Creates and registers `BookListRepositoryImpl`
2. **UseCase Registration**: Creates `BookListUseCaseImpl` with automatic repository injection
3. **Fallback Handling**: Provides `DefaultBookListRepositoryImpl` if primary fails
4. **Returns**: Array of Module objects ready for container registration

### Advanced Interface Pattern

```swift
// More complex interface with dependencies
let userEntries = registerModule.registerInterfacePattern(
    UserInterface.self,
    repositoryFactory: {
        UserRepositoryImpl(
            networkService: DependencyContainer.live.resolve(NetworkService.self)!,
            cacheService: DependencyContainer.live.resolve(CacheService.self)!
        )
    },
    useCaseFactory: { repository in
        UserUseCaseImpl(
            repository: repository,
            authService: DependencyContainer.live.resolve(AuthService.self)!,
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
            logger: DependencyContainer.live.resolve(LoggerProtocol.self)!
        )
    },
    repositoryFallback: {
        OfflineNetworkRepository() // Works without network
    }
)
```

## Bulk DSL Syntax

The Bulk DSL provides a more expressive, domain-specific syntax for registering multiple interfaces.

### Basic Bulk DSL

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
                reachability: DependencyContainer.live.resolve(ReachabilityService.self)!
            )
        },
        fallback: { OfflineNetworkRepository() }
    )

    // User management with network dependency
    UserInterface.self => (
        repository: {
            UserRepositoryImpl(
                networkService: DependencyContainer.live.resolve(NetworkInterface.self)!,
                cacheService: DependencyContainer.live.resolve(CacheService.self)!
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
                database: DependencyContainer.live.resolve(DatabaseService.self)!,
                networkService: DependencyContainer.live.resolve(NetworkInterface.self)!
            )
        },
        useCase: { repository in
            OrderUseCaseImpl(
                repository: repository,
                userUseCase: DependencyContainer.live.resolve(UserInterface.self)!,
                paymentValidator: PaymentValidator()
            )
        },
        fallback: { LocalOrderRepository() }
    )
}
```

### Conditional Bulk Registration

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

Easy Scope provides a simplified DSL for registering multiple services within the same scope.

### Basic Easy Scope

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
            logger: DependencyContainer.live.resolve(LoggerProtocol.self)!
        )
    }

    register(DatabaseService.self) {
        SQLiteDatabaseService(
            path: Configuration.databasePath,
            logger: DependencyContainer.live.resolve(LoggerProtocol.self)!
        )
    }

    // Application layer with dependencies
    register(UserService.self) {
        UserServiceImpl(
            networkService: DependencyContainer.live.resolve(NetworkService.self)!,
            databaseService: DependencyContainer.live.resolve(DatabaseService.self)!,
            logger: DependencyContainer.live.resolve(LoggerProtocol.self)!
        )
    }

    register(OrderService.self) {
        OrderServiceImpl(
            userService: DependencyContainer.live.resolve(UserService.self)!,
            databaseService: DependencyContainer.live.resolve(DatabaseService.self)!,
            paymentService: DependencyContainer.live.resolve(PaymentService.self)!
        )
    }
}

// Register all modules
await modules.asyncForEach { module in
    await container.register(module)
}
```

### Scoped Registration with Lifecycle Management

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
        await AppDIContainer.shared.registerDependencies { container in
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
                        networkService: DependencyContainer.live.resolve(NetworkService.self)!
                    )
                },
                useCaseFactory: { repository in
                    PaymentUseCaseImpl(
                        repository: repository,
                        fraudDetection: DependencyContainer.live.resolve(FraudDetectionService.self)!,
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
        await AppDIContainer.shared.registerDependencies { container in
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
                        cache: DependencyContainer.live.resolve(CacheService.self)!
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

- [Module System](/guide/module-system) - Understanding WeaveDI's module architecture
- [App DI Integration](/guide/app-di-integration) - Enterprise-level dependency management
- [Property Wrappers](/guide/property-wrappers) - Using @Inject, @Factory, and @SafeInject
- [Core APIs](/api/core-apis) - Core WeaveDI API reference