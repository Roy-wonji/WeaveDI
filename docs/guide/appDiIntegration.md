# App DI Integration: AppWeaveDI.Container

A comprehensive guide to implementing **enterprise-level** Dependency Injection architecture in real applications using `AppWeaveDI.Container`.

## Overview

`AppWeaveDI.Container` is a top-level container class that **systematically manages** dependency injection throughout the application. It efficiently configures and manages each layer (Repository, UseCase, Service) through automated **Factory patterns** and supports **Clean Architecture**.

### Architecture Philosophy

#### 🏗️ Layered Architecture Support
- **Repository Layer**: Data access and external system integration
- **UseCase Layer**: Business logic and domain rule encapsulation
- **Service Layer**: Application services and UI support
- **Automatic Dependency Resolution**: Inter-layer dependencies are automatically injected

#### 🏭 Factory-Based Modularization
- **RepositoryModuleFactory**: Bulk management of Repository dependencies
- **UseCaseModuleFactory**: Automatic configuration of UseCase dependencies integrated with Repository
- **Extensibility**: Easy addition of new factories
- **Type Safety**: Compile-time dependency type verification

#### 🔄 Lifecycle Management
- **Lazy Initialization**: Modules are created only when actually needed
- **Memory Efficiency**: Unused dependencies are not created

## Architecture Diagram

```
┌─────────────────────────────────────┐
│           AppWeaveDI.Container            │
│                                     │
└─────────────────┬───────────────────┘
                  │
      ┌───────────┼───────────┐
      │           │           │
┌─────▼─────┐ ┌───▼────┐ ┌───▼────────┐
│Repository │ │UseCase │ │   Other    │
│ Factory   │ │Factory │ │ Factories  │
└───────────┘ └────────┘ └────────────┘
      │           │           │
      └───────────┼───────────┘
                  │
┌─────────────────▼───────────────────┐
│        WeaveDI.Container.live     │
│          (Global Registry)          │
└─────────────────────────────────────┘
```

## How It Works

### Step 1: Factory Preparation

`AppWeaveDI.Container` uses the `@Factory` property wrapper for automatic injection:

```swift
@Factory(\.repositoryFactory)
var repositoryFactory: RepositoryModuleFactory

@Factory(\.useCaseFactory)
var useCaseFactory: UseCaseModuleFactory

@Factory(\.scopeFactory)
var scopeFactory: ScopeModuleFactory
```

### Step 2: Module Registration

```swift
await AppWeaveDI.Container.shared.registerDependencies { container in
    // Register Repository modules
    container.register(UserRepositoryModule())

    // Register UseCase modules
    container.register(UserUseCaseModule())

    // Register Service modules
    container.register(UserServiceModule())
}
```

**Internal Process:**
1. Repository factory creates all Repository modules
2. UseCase factory creates UseCase modules connected with Repository
3. All modules are registered in parallel to `WeaveDI.Container.live`

### Step 3: Dependency Usage

```swift
// Use registered dependencies from anywhere
let userService = WeaveDI.Container.live.resolve(UserServiceProtocol.self)
let userUseCase = WeaveDI.Container.live.resolve(UserUseCaseProtocol.self)
```

## Compatibility and Environment Support

### Swift Version Compatibility
- **Swift 5.9+ & iOS 17.0+**: Actor-based optimization implementation
- **Swift 5.8 & iOS 16.0+**: Compatible mode with same functionality
- **Earlier Versions**: Fallback implementation maintaining core features

### Concurrency Support
- **Swift Concurrency**: Full support for `async/await` patterns
- **GCD Compatibility**: Compatible with existing `DispatchQueue`-based code
- **Thread Safety**: All operations are processed thread-safely

## Basic Usage

### Simple Application Setup

```swift
@main
struct MyApp {
    static func main() async {
        await AppWeaveDI.Container.shared.registerDependencies { container in
            // Repository modules
            container.register(UserRepositoryModule())
            container.register(OrderRepositoryModule())

            // UseCase modules
            container.register(UserUseCaseModule())
            container.register(OrderUseCaseModule())

            // Service modules
            container.register(UserServiceModule())
        }

        // Use registered dependencies
        let useCase: UserUseCaseProtocol = WeaveDI.Container.live.resolveOrDefault(
            UserUseCaseProtocol.self,
            default: UserUseCase(userRepo: UserRepository())
        )

        print("Loaded user profile: \(await useCase.loadUserProfile().displayName)")
    }
}
```

### Factory Pattern Extensions

#### Repository Factory Extension

```swift
extension RepositoryModuleFactory {
    public mutating func registerDefaultDefinitions() {
        let registerModuleCopy = registerModule
        repositoryDefinitions = [
            // User Repository
            registerModuleCopy.makeDependency(UserRepositoryProtocol.self) {
                UserRepositoryImpl(
                    networkService: WeaveDI.Container.live.resolve(NetworkService.self)!,
                    cacheService: WeaveDI.Container.live.resolve(CacheService.self)!
                )
            },

            // Auth Repository
            registerModuleCopy.makeDependency(AuthRepositoryProtocol.self) {
                AuthRepositoryImpl(
                    keychain: KeychainService(),
                    networkService: WeaveDI.Container.live.resolve(NetworkService.self)!
                )
            },

            // Order Repository
            registerModuleCopy.makeDependency(OrderRepositoryProtocol.self) {
                OrderRepositoryImpl(
                    database: WeaveDI.Container.live.resolve(DatabaseService.self)!
                )
            }
        ]
    }
}
```

#### UseCase Factory Extension

```swift
extension UseCaseModuleFactory {
    public var useCaseDefinitions: [() -> Module] {
        [
            // Auth UseCase with Repository dependency
            registerModule.makeUseCaseWithRepository(
                AuthUseCaseProtocol.self,
                repositoryProtocol: AuthRepositoryProtocol.self,
                repositoryFallback: DefaultAuthRepository()
            ) { repo in
                AuthUseCase(
                    repository: repo,
                    validator: AuthValidator(),
                    logger: WeaveDI.Container.live.resolve(LoggerProtocol.self)!
                )
            },

            // User UseCase with Repository dependency
            registerModule.makeUseCaseWithRepository(
                UserUseCaseProtocol.self,
                repositoryProtocol: UserRepositoryProtocol.self,
                repositoryFallback: DefaultUserRepository()
            ) { repo in
                UserUseCase(
                    repository: repo,
                    authUseCase: WeaveDI.Container.live.resolve(AuthUseCaseProtocol.self)!,
                    validator: UserValidator()
                )
            },

            // Order UseCase with multiple dependencies
            registerModule.makeUseCaseWithRepository(
                OrderUseCaseProtocol.self,
                repositoryProtocol: OrderRepositoryProtocol.self,
                repositoryFallback: DefaultOrderRepository()
            ) { repo in
                OrderUseCase(
                    repository: repo,
                    userUseCase: WeaveDI.Container.live.resolve(UserUseCaseProtocol.self)!,
                    paymentService: WeaveDI.Container.live.resolve(PaymentService.self)!
                )
            }
        ]
    }
}
```

## Advanced Usage Patterns

### SwiftUI App Integration

```swift
@main
struct TestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        registerDependencies()
    }

    var body: some Scene {
        WindowGroup {
            let store = Store(initialState: AppReducer.State()) {
                AppReducer()._printChanges()
            }
            AppView(store: store)
        }
    }

    private func registerDependencies() {
        Task {
            await AppWeaveDI.Container.shared.registerDependencies { container in
                // Repository layer setup
                var repoFactory = AppWeaveDI.Container.shared.repositoryFactory
                repoFactory.registerDefaultDefinitions()

                await repoFactory.makeAllModules().asyncForEach { module in
                    await container.register(module)
                }

                // UseCase layer setup
                let useCaseFactory = AppWeaveDI.Container.shared.useCaseFactory
                await useCaseFactory.makeAllModules().asyncForEach { module in
                    await container.register(module)
                }

                // Service layer setup
                await registerServiceModules(container)
            }
        }
    }

    private func registerServiceModules(_ container: Container) async {
        // Register application services
        await container.register(AnalyticsServiceModule())
        await container.register(NotificationServiceModule())
        await container.register(LocationServiceModule())
    }
}
```

### UIKit (AppDelegate) Integration

```swift
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Configure AppWeaveDI.Container for UIKit apps
        Task {
            await AppWeaveDI.Container.shared.registerDependencies { container in
                // Core infrastructure
                await setupCoreInfrastructure(container)

                // Feature modules
                await setupFeatureModules(container)

                // UI-specific services
                await setupUIServices(container)
            }
        }

        return true
    }

    private func setupCoreInfrastructure(_ container: Container) async {
        // Database setup
        let database = try! await Database.initialize()
        await container.register(DatabaseServiceModule(database: database))

        // Network setup
        await container.register(NetworkServiceModule())

        // Logging setup
        await container.register(LoggingServiceModule())
    }

    private func setupFeatureModules(_ container: Container) async {
        // Repository factory
        var repoFactory = AppWeaveDI.Container.shared.repositoryFactory
        repoFactory.registerDefaultDefinitions()

        let repoModules = await repoFactory.makeAllModules()
        for module in repoModules {
            await container.register(module)
        }

        // UseCase factory
        let useCaseFactory = AppWeaveDI.Container.shared.useCaseFactory
        let useCaseModules = await useCaseFactory.makeAllModules()
        for module in useCaseModules {
            await container.register(module)
        }
    }

    private func setupUIServices(_ container: Container) async {
        // UI-specific services
        await container.register(ViewControllerFactoryModule())
        await container.register(NavigationServiceModule())
        await container.register(AlertServiceModule())
    }
}
```

### ContainerRegister Usage

For type-safe dependency access, you can use the `ContainerRegister` pattern:

```swift
extension WeaveDI.Container {
    var authUseCase: AuthUseCaseProtocol? {
        ContainerRegister(\.authUseCase).wrappedValue
    }

    var userService: UserServiceProtocol? {
        ContainerRegister(\.userService).wrappedValue
    }

    var orderRepository: OrderRepositoryProtocol? {
        ContainerRegister(\.orderRepository).wrappedValue
    }
}

// Usage example
class AuthenticationViewModel: ObservableObject {
    @Published var isAuthenticated = false

    private let authUseCase: AuthUseCaseProtocol = ContainerRegister(\.authUseCase).wrappedValue

    func login(email: String, password: String) async {
        do {
            let result = try await authUseCase.login(email: email, password: password)
            await MainActor.run {
                self.isAuthenticated = result.isSuccess
            }
        } catch {
            // Handle authentication failure
            print("Login failed: \(error)")
        }
    }
}
```

### Complex Enterprise Architecture

```swift
class EnterpriseAppBootstrap {
    static func configure() async {
        await AppWeaveDI.Container.shared.registerDependencies { container in
            // Infrastructure layer
            await setupInfrastructure(container)

            // Data layer
            await setupDataLayer(container)

            // Domain layer
            await setupDomainLayer(container)

            // Application layer
            await setupApplicationLayer(container)

            // Presentation layer
            await setupPresentationLayer(container)
        }
    }

    private static func setupInfrastructure(_ container: Container) async {
        // Core infrastructure services
        await container.register(NetworkServiceModule())
        await container.register(DatabaseServiceModule())
        await container.register(CacheServiceModule())
        await container.register(SecurityServiceModule())
        await container.register(LoggingServiceModule())
    }

    private static func setupDataLayer(_ container: Container) async {
        // Repository factory setup
        var repoFactory = AppWeaveDI.Container.shared.repositoryFactory
        repoFactory.registerDefaultDefinitions()

        let modules = await repoFactory.makeAllModules()
        for module in modules {
            await container.register(module)
        }
    }

    private static func setupDomainLayer(_ container: Container) async {
        // UseCase factory setup
        let useCaseFactory = AppWeaveDI.Container.shared.useCaseFactory
        let modules = await useCaseFactory.makeAllModules()

        for module in modules {
            await container.register(module)
        }
    }

    private static func setupApplicationLayer(_ container: Container) async {
        // Application services
        await container.register(AuthenticationServiceModule())
        await container.register(UserManagementServiceModule())
        await container.register(OrderProcessingServiceModule())
        await container.register(PaymentServiceModule())
    }

    private static func setupPresentationLayer(_ container: Container) async {
        // ViewModels and Presenters
        await container.register(UserViewModelModule())
        await container.register(OrderViewModelModule())
        await container.register(PaymentViewModelModule())
    }
}
```

## Performance Optimization

### Automatic Optimization Configuration

`AppWeaveDI.Container` automatically configures performance optimizations:

```swift
public func registerDependencies(
    registerModules: @escaping @Sendable (Container) async -> Void
) async {
    // Enable runtime optimization and minimize logging for performance-sensitive builds
    UnifiedDI.configureOptimization(debounceMs: 100, threshold: 10, realTimeUpdate: true)
    UnifiedDI.setAutoOptimization(true)
    UnifiedDI.setLogLevel(.errors)

    // ... rest of registration logic
}
```

### Parallel Module Registration

For optimal performance, the container registers modules **in parallel**:

```swift
// All modules are registered concurrently
await container.register(module1)  // parallel
await container.register(module2)  // parallel
await container.register(module3)  // parallel
await container.build()            // wait for all to complete
```

### Memory Management

`AppWeaveDI.Container` implements efficient memory management:

```swift
// Lazy initialization - created only when needed
@Factory(\.repositoryFactory)
var repositoryFactory: RepositoryModuleFactory  // Created on first access

// Automatic cleanup of unused dependencies
private func cleanupUnusedDependencies() {
    // Internal optimization logic
}
```

## Testing Strategies

### Unit Testing with AppWeaveDI.Container

```swift
class AppWeaveDI.ContainerTests: XCTestCase {
    var container: AppWeaveDI.Container!

    override func setUp() async throws {
        try await super.setUp()
        container = AppWeaveDI.Container()
    }

    func testRepositoryFactoryRegistration() async {
        await container.registerDependencies { container in
            var repoFactory = self.container.repositoryFactory
            repoFactory.registerDefaultDefinitions()

            let modules = await repoFactory.makeAllModules()
            XCTAssertFalse(modules.isEmpty)

            for module in modules {
                await container.register(module)
            }
        }

        // Verify registration
        let userRepo = WeaveDI.Container.live.resolve(UserRepositoryProtocol.self)
        XCTAssertNotNil(userRepo)
    }

    func testUseCaseFactoryRegistration() async {
        await container.registerDependencies { container in
            // First configure Repository
            var repoFactory = self.container.repositoryFactory
            repoFactory.registerDefaultDefinitions()
            await repoFactory.makeAllModules().asyncForEach { module in
                await container.register(module)
            }

            // Then configure UseCase
            let useCaseFactory = self.container.useCaseFactory
            await useCaseFactory.makeAllModules().asyncForEach { module in
                await container.register(module)
            }
        }

        // Verify UseCase registration
        let authUseCase = WeaveDI.Container.live.resolve(AuthUseCaseProtocol.self)
        XCTAssertNotNil(authUseCase)
    }
}
```

### Integration Testing

```swift
class IntegrationTests: XCTestCase {
    override func setUp() async throws {
        // Initialize container for each test
          WeaveDI.Container.live = WeaveDI.Container()

        await AppWeaveDI.Container.shared.registerDependencies { container in
            // Register test-specific dependencies
            await self.registerTestDependencies(container)
        }
    }

    private func registerTestDependencies(_ container: Container) async {
        // Mock repositories for integration testing
        await container.register(MockUserRepositoryModule())
        await container.register(MockAuthRepositoryModule())

        // Use actual UseCase for integration testing
        let useCaseFactory = AppWeaveDI.Container.shared.useCaseFactory
        await useCaseFactory.makeAllModules().asyncForEach { module in
            await container.register(module)
        }
    }

    func testUserAuthenticationFlow() async throws {
        let authUseCase = WeaveDI.Container.live.resolve(AuthUseCaseProtocol.self)!
        let userUseCase = WeaveDI.Container.live.resolve(UserUseCaseProtocol.self)!

        // Test complete authentication flow
        let authResult = try await authUseCase.login(email: "test@example.com", password: "password")
        XCTAssertTrue(authResult.isSuccess)

        let userProfile = try await userUseCase.loadUserProfile()
        XCTAssertNotNil(userProfile)
    }
}
```

## Best Practices

### 1) Organize by Feature Modules

```swift
// Feature-based module organization
struct UserFeatureModule {
    static func register(_ container: Container) async {
        // User-related repositories
        await container.register(UserRepositoryModule())
        await container.register(UserPreferencesRepositoryModule())

        // User-related use cases
        await container.register(UserUseCaseModule())
        await container.register(UserPreferencesUseCaseModule())

        // User-related services
        await container.register(UserServiceModule())
    }
}

struct OrderFeatureModule {
    static func register(_ container: Container) async {
        await container.register(OrderRepositoryModule())
        await container.register(OrderUseCaseModule())
        await container.register(OrderServiceModule())
    }
}
```

### 2) Environment-Specific Configuration

```swift
extension AppWeaveDI.Container {
    func registerDependenciesForEnvironment(_ environment: AppEnvironment) async {
        await registerDependencies { container in
            switch environment {
            case .development:
                await self.registerDevelopmentDependencies(container)
            case .staging:
                await self.registerStagingDependencies(container)
            case .production:
                await self.registerProductionDependencies(container)
            }
        }
    }

    private func registerDevelopmentDependencies(_ container: Container) async {
        // Development environment specific implementations
        await container.register(MockNetworkServiceModule())
        await container.register(InMemoryDatabaseModule())
        await container.register(DetailedLoggingModule())
    }

    private func registerProductionDependencies(_ container: Container) async {
        // Production environment implementations
        await container.register(ProductionNetworkServiceModule())
        await container.register(SQLiteDatabaseModule())
        await container.register(OptimizedLoggingModule())
    }
}
```

### 3) Gradual Migration Strategy

```swift
class LegacyAppMigration {
    static func migrateToAppWeaveDI.Container() async {
        await AppWeaveDI.Container.shared.registerDependencies { container in
            // Gradually migrate existing dependencies
            await migrateCoreServices(container)
            await migrateUserServices(container)
            await migrateOrderServices(container)
        }
    }

    private static func migrateCoreServices(_ container: Container) async {
        // Reuse existing instances when necessary
        if let existingLogger = LegacyServiceLocator.shared.logger {
            await container.register(ExistingLoggerModule(logger: existingLogger))
        } else {
            await container.register(NewLoggerModule())
        }
    }
}
```

## Discussion

- `AppWeaveDI.Container` serves as a **single entry point** for dependency management.
- By registering modules during app initialization, you can create and retrieve dependency objects **quickly and reliably** at runtime.
- The internal `Container` runs all registered modules **in parallel** to optimize performance.
- Factory patterns **systematically manage** Repository, UseCase, and Scope layers.
- Automatic optimization configuration provides **optimal performance with default settings**.

## See Also

- [Module System](./moduleSystem.md) — Organizing large apps with modules
- [Property Wrappers](./propertyWrappers.md) — Using `@Factory` and `@Inject`
- [Bootstrap Guide](./bootstrap.md) — Application initialization patterns
- [UnifiedDI vs WeaveDI.Container](./unifiedDi.md) — Guide to choosing which API to use