# Bootstrap API Reference

The Bootstrap API provides safe and efficient dependency container initialization patterns for WeaveDI applications.

## Overview

Bootstrap methods ensure that your dependency container is properly initialized before your application starts using dependencies. They provide atomic container replacement and support both synchronous and asynchronous initialization patterns.

```swift
import WeaveDI

// Basic bootstrap
await DIContainer.bootstrap { container in
    container.register(UserService.self) { UserServiceImpl() }
    container.register(DataManager.self) { CoreDataManager() }
}
```

## Core Bootstrap Methods

### `bootstrap(_:)`

Synchronous bootstrap for immediate dependency registration.

```swift
static func bootstrap(_ configure: @Sendable (DIContainer) -> Void) async
```

**Parameters:**
- `configure`: Closure that configures the container with dependencies

**Usage:**
```swift
await DIContainer.bootstrap { container in
    // Register core services
    container.register(Logger.self) { ConsoleLogger() }
    container.register(NetworkClient.self) { URLSessionNetworkClient() }

    // Register business services
    container.register(UserService.self) {
        let logger = container.resolve(Logger.self) ?? ConsoleLogger()
        let client = container.resolve(NetworkClient.self) ?? URLSessionNetworkClient()
        return UserServiceImpl(logger: logger, networkClient: client)
    }

    print("✅ All dependencies registered")
}
```

### `bootstrapAsync(_:)`

Asynchronous bootstrap for dependencies requiring async initialization.

```swift
@discardableResult
static func bootstrapAsync(_ configure: @Sendable (DIContainer) async throws -> Void) async -> Bool
```

**Parameters:**
- `configure`: Async closure that configures the container

**Returns:** `true` if bootstrap succeeded, `false` if it failed

**Usage:**
```swift
let success = await DIContainer.bootstrapAsync { container in
    // Async initialization of database
    let database = try await CoreDataStack.initialize()
    container.register(DatabaseProtocol.self, instance: database)

    // Network configuration with remote settings
    let networkConfig = try await RemoteConfigService.fetchNetworkConfig()
    container.register(NetworkClient.self) {
        URLSessionNetworkClient(config: networkConfig)
    }

    // Authentication service requiring network setup
    let authService = try await AuthService.initialize(
        networkClient: container.resolve(NetworkClient.self)!
    )
    container.register(AuthService.self, instance: authService)
}

if success {
    print("🚀 Async bootstrap completed successfully")
} else {
    print("❌ Bootstrap failed")
}
```

### `bootstrapMixed(sync:async:)`

Mixed bootstrap for combining immediate and async dependencies.

```swift
@MainActor
static func bootstrapMixed(
    sync: @Sendable (DIContainer) -> Void,
    async: @Sendable (DIContainer) async -> Void
) async
```

**Parameters:**
- `sync`: Immediate dependency registration
- `async`: Asynchronous dependency registration

**Usage:**
```swift
await DIContainer.bootstrapMixed(
    sync: { container in
        // Critical services that need to be available immediately
        container.register(Logger.self) { ConsoleLogger() }
        container.register(CrashReporter.self) { CrashReporterImpl() }
        container.register(ConfigManager.self) { ConfigManagerImpl() }
    },
    async: { container in
        // Services that can be initialized in background
        let database = await DatabaseManager.initialize()
        container.register(DatabaseManager.self, instance: database)

        let cacheManager = await CacheManager.setup()
        container.register(CacheManager.self, instance: cacheManager)
    }
)
```

## Conditional Bootstrap

### `bootstrapIfNeeded(_:)`

Bootstrap only if container is not already initialized.

```swift
@discardableResult
static func bootstrapIfNeeded(_ configure: @Sendable (DIContainer) -> Void) async -> Bool
```

**Usage:**
```swift
// Safe to call multiple times
let wasBootstrapped = await DIContainer.bootstrapIfNeeded { container in
    container.register(UserService.self) { UserServiceImpl() }
}

if wasBootstrapped {
    print("Container was bootstrapped")
} else {
    print("Container already initialized - bootstrap skipped")
}
```

### `bootstrapAsyncIfNeeded(_:)`

Async conditional bootstrap.

```swift
@discardableResult
static func bootstrapAsyncIfNeeded(_ configure: @Sendable (DIContainer) async throws -> Void) async -> Bool
```

## Background Bootstrap

### `bootstrapInTask(_:)`

Bootstrap in a detached high-priority task.

```swift
static func bootstrapInTask(_ configure: @Sendable @escaping (DIContainer) async throws -> Void)
```

**Usage:**
```swift
// Start bootstrap in background
DIContainer.bootstrapInTask { container in
    // Long-running initialization
    let heavyService = try await HeavyService.initialize()
    container.register(HeavyService.self, instance: heavyService)
}

// Continue with app initialization
// Bootstrap will complete in background
```

## Runtime Updates

### `update(_:)`

Update container with new dependencies at runtime.

```swift
static func update(_ configure: @Sendable (DIContainer) -> Void) async
```

**Usage:**
```swift
// Add feature flag dependent services
await DIContainer.update { container in
    if FeatureFlags.newUserExperience {
        container.register(NewUserService.self) { NewUserServiceImpl() }
    }
}
```

### `updateAsync(_:)`

Async runtime updates.

```swift
static func updateAsync(_ configure: @Sendable (DIContainer) async -> Void) async
```

**Usage:**
```swift
await DIContainer.updateAsync { container in
    // Fetch updated configuration
    let config = await ConfigService.fetchLatestConfig()

    // Update service with new config
    container.register(ConfigurableService.self) {
        ConfigurableServiceImpl(config: config)
    }
}
```

## Real-World Examples

### iOS App Bootstrap

```swift
@main
struct MyApp: App {
    init() {
        Task {
            await setupDependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Ensure bootstrap is complete before UI loads
                    DIContainer.ensureBootstrapped()
                }
        }
    }

    private func setupDependencies() async {
        await DIContainer.bootstrapMixed(
            sync: { container in
                // Core services needed immediately
                container.register(Logger.self) {
                    OSLogLogger(category: "MyApp")
                }

                container.register(AnalyticsService.self) {
                    FirebaseAnalytics()
                }

                container.register(CrashReporter.self) {
                    CrashlyticsReporter()
                }
            },
            async: { container in
                // Database initialization
                let database = await CoreDataStack.shared.initialize()
                container.register(Database.self, instance: database)

                // Network services
                let apiClient = await APIClient.initialize()
                container.register(APIClient.self, instance: apiClient)

                // Business services
                container.register(UserManager.self) {
                    UserManagerImpl(
                        database: container.resolve(Database.self)!,
                        apiClient: container.resolve(APIClient.self)!
                    )
                }
            }
        )

        print("🚀 App dependencies bootstrapped successfully")
    }
}
```

### Test Bootstrap

```swift
class UserServiceTests: XCTestCase {
    override func setUp() async throws {
        await DIContainer.resetForTesting()

        await DIContainer.bootstrap { container in
            // Mock dependencies for testing
            container.register(Logger.self) { MockLogger() }
            container.register(APIClient.self) { MockAPIClient() }
            container.register(Database.self) { InMemoryDatabase() }

            // Service under test
            container.register(UserService.self) {
                UserServiceImpl(
                    database: container.resolve(Database.self)!,
                    apiClient: container.resolve(APIClient.self)!
                )
            }
        }
    }

    func testUserCreation() async {
        let userService = DIContainer.shared.resolve(UserService.self)!
        let user = await userService.createUser(name: "Test User")
        XCTAssertEqual(user.name, "Test User")
    }
}
```

### Feature Module Bootstrap

```swift
struct FeatureModule {
    static func bootstrap() async {
        await DIContainer.update { container in
            // Feature-specific services
            container.register(FeatureService.self) {
                FeatureServiceImpl()
            }

            container.register(FeatureRepository.self) {
                let database = container.resolve(Database.self)!
                return FeatureRepositoryImpl(database: database)
            }

            container.register(FeatureViewModel.self) {
                FeatureViewModel(
                    service: container.resolve(FeatureService.self)!,
                    repository: container.resolve(FeatureRepository.self)!
                )
            }
        }
    }
}
```

## Error Handling

Bootstrap methods include comprehensive error handling:

```swift
// With error handling
let success = await DIContainer.bootstrapAsync { container in
    do {
        let service = try await RiskyService.initialize()
        container.register(RiskyService.self, instance: service)
    } catch {
        print("Failed to initialize RiskyService: \(error)")
        // Register fallback
        container.register(RiskyService.self) { MockRiskyService() }
    }
}
```

## Best Practices

### 1. Bootstrap Early
Always bootstrap before any dependency resolution:

```swift
// ✅ Good
await DIContainer.bootstrap { /* configure */ }
let service = DIContainer.shared.resolve(Service.self)

// ❌ Bad
let service = DIContainer.shared.resolve(Service.self) // May be nil
await DIContainer.bootstrap { /* configure */ }
```

### 2. Use Conditional Bootstrap for Libraries
Libraries should use conditional bootstrap to avoid conflicts:

```swift
public static func initialize() async {
    await DIContainer.bootstrapIfNeeded { container in
        container.register(LibraryService.self) { LibraryServiceImpl() }
    }
}
```

### 3. Handle Bootstrap Failures
Always check bootstrap results in production:

```swift
let success = await DIContainer.bootstrapAsync { container in
    try await setupCriticalServices(container)
}

guard success else {
    fatalError("Failed to initialize critical services")
}
```

## See Also

- [DIContainer API](./coreApis.md) - Core container functionality
- [UnifiedDI](./unifiedDI.md) - Simplified dependency injection
- [Property Wrappers Guide](../guide/propertyWrappers.md) - Automatic injection patterns