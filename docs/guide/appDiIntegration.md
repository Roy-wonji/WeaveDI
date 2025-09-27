# App DI Integration: AppDIContainer

Complete guide to using AppDIContainer for enterprise-level dependency injection architecture in real applications.

## Overview

`AppDIContainer` is the top-level container class that systematically manages dependency injection across your entire application. It supports Clean Architecture by efficiently organizing and managing each layer (Repository, UseCase, Service) through automated Factory patterns.

### Architecture Philosophy

#### 🏗️ Layered Architecture Support
- **Repository Layer**: Data access and external system integration
- **UseCase Layer**: Business logic and domain rule encapsulation
- **Service Layer**: Application services and UI support
- **Automatic Dependency Resolution**: Dependencies between layers are automatically injected

#### 🏭 Factory-Based Modularization
- **RepositoryModuleFactory**: Bulk management of Repository dependencies
- **UseCaseModuleFactory**: UseCase dependencies with automatic Repository integration
- **Extensibility**: Easy addition of new Factories
- **Type Safety**: Compile-time dependency type verification

#### 🔄 Lifecycle Management
- **Lazy Initialization**: Modules are created only when actually needed
- **Memory Efficiency**: Unused dependencies are not created

## Architecture Diagram

```
┌─────────────────────────────────────┐
│           AppDIContainer            │
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
│        DependencyContainer.live     │
│          (Global Registry)          │
└─────────────────────────────────────┘
```

## How It Works

### Step 1: Factory Preparation

The AppDIContainer uses the `@Factory` property wrapper for automatic injection:

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
await AppDIContainer.shared.registerDependencies { container in
    // Register Repository modules
    container.register(UserRepositoryModule())

    // Register UseCase modules
    container.register(UserUseCaseModule())

    // Register Service modules
    container.register(UserServiceModule())
}
```

**Internal Process:**
1. Repository Factory creates all Repository modules
2. UseCase Factory creates UseCase modules linked with Repositories
3. All modules are registered in parallel to `DependencyContainer.live`

### Step 3: Dependency Usage

```swift
// Use registered dependencies anywhere
let userService = DependencyContainer.live.resolve(UserServiceProtocol.self)
let userUseCase = DependencyContainer.live.resolve(UserUseCaseProtocol.self)
```

## Compatibility and Environment Support

### Swift Version Compatibility
- **Swift 5.9+ & iOS 17.0+**: Actor-based optimized implementation
- **Swift 5.8 & iOS 16.0+**: Compatibility mode with same functionality
- **Earlier Versions**: Fallback implementation maintaining core features

### Concurrency Support
- **Swift Concurrency**: Full async/await pattern support
- **GCD Compatibility**: Compatible with existing DispatchQueue code
- **Thread Safe**: All operations are processed thread-safely

## Basic Usage

### Simple Application Setup

```swift
@main
struct MyApp {
    static func main() async {
        await AppDIContainer.shared.registerDependencies { container in
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
        let useCase: UserUseCaseProtocol = DependencyContainer.live.resolveOrDefault(
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
                    networkService: DependencyContainer.live.resolve(NetworkService.self)!,
                    cacheService: DependencyContainer.live.resolve(CacheService.self)!
                )
            },

            // Auth Repository
            registerModuleCopy.makeDependency(AuthRepositoryProtocol.self) {
                AuthRepositoryImpl(
                    keychain: KeychainService(),
                    networkService: DependencyContainer.live.resolve(NetworkService.self)!
                )
            },

            // Order Repository
            registerModuleCopy.makeDependency(OrderRepositoryProtocol.self) {
                OrderRepositoryImpl(
                    database: DependencyContainer.live.resolve(DatabaseService.self)!
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
                    logger: DependencyContainer.live.resolve(LoggerProtocol.self)!
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
                    authUseCase: DependencyContainer.live.resolve(AuthUseCaseProtocol.self)!,
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
                    userUseCase: DependencyContainer.live.resolve(UserUseCaseProtocol.self)!,
                    paymentService: DependencyContainer.live.resolve(PaymentService.self)!
                )
            }
        ]
    }
}
```

## Advanced Usage Patterns

### SwiftUI Application Integration

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
            await AppDIContainer.shared.registerDependencies { container in
                // Repository layer setup
                var repoFactory = AppDIContainer.shared.repositoryFactory
                repoFactory.registerDefaultDefinitions()

                await repoFactory.makeAllModules().asyncForEach { module in
                    await container.register(module)
                }

                // UseCase layer setup
                let useCaseFactory = AppDIContainer.shared.useCaseFactory
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

        // Configure AppDIContainer for UIKit apps
        Task {
            await AppDIContainer.shared.registerDependencies { container in
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
        var repoFactory = AppDIContainer.shared.repositoryFactory
        repoFactory.registerDefaultDefinitions()

        let repoModules = await repoFactory.makeAllModules()
        for module in repoModules {
            await container.register(module)
        }

        // UseCase factory
        let useCaseFactory = AppDIContainer.shared.useCaseFactory
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

Using the `ContainerRegister` pattern for type-safe dependency access:

```swift
extension DependencyContainer {
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
            // Handle authentication error
            print("Login failed: \(error)")
        }
    }
}
```

### Complex Enterprise Architecture

```swift
class EnterpriseAppBootstrap {
    static func configure() async {
        await AppDIContainer.shared.registerDependencies { container in
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
        var repoFactory = AppDIContainer.shared.repositoryFactory
        repoFactory.registerDefaultDefinitions()

        let modules = await repoFactory.makeAllModules()
        for module in modules {
            await container.register(module)
        }
    }

    private static func setupDomainLayer(_ container: Container) async {
        // UseCase factory setup
        let useCaseFactory = AppDIContainer.shared.useCaseFactory
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

AppDIContainer automatically configures performance optimizations:

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

The container automatically registers modules in parallel for optimal performance:

```swift
// All modules are registered concurrently
await container.register(module1)  // Parallel
await container.register(module2)  // Parallel
await container.register(module3)  // Parallel
await container.build()            // Wait for all to complete
```

### Memory Management

AppDIContainer implements efficient memory management:

```swift
// Lazy initialization - only create when needed
@Factory(\.repositoryFactory)
var repositoryFactory: RepositoryModuleFactory  // Created on first access

// Automatic cleanup of unused dependencies
private func cleanupUnusedDependencies() {
    // Internal optimization logic
}
```

## Testing Strategies

### Unit Testing with AppDIContainer

```swift
class AppDIContainerTests: XCTestCase {
    var container: AppDIContainer!

    override func setUp() async throws {
        try await super.setUp()
        container = AppDIContainer()
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

        // Verify registrations
        let userRepo = DependencyContainer.live.resolve(UserRepositoryProtocol.self)
        XCTAssertNotNil(userRepo)
    }

    func testUseCaseFactoryRegistration() async {
        await container.registerDependencies { container in
            // Setup repositories first
            var repoFactory = self.container.repositoryFactory
            repoFactory.registerDefaultDefinitions()
            await repoFactory.makeAllModules().asyncForEach { module in
                await container.register(module)
            }

            // Setup use cases
            let useCaseFactory = self.container.useCaseFactory
            await useCaseFactory.makeAllModules().asyncForEach { module in
                await container.register(module)
            }
        }

        // Verify use case registration
        let authUseCase = DependencyContainer.live.resolve(AuthUseCaseProtocol.self)
        XCTAssertNotNil(authUseCase)
    }
}
```

### Integration Testing

```swift
class IntegrationTests: XCTestCase {
    override func setUp() async throws {
        // Reset container for each test
        DependencyContainer.live = DependencyContainer()

        await AppDIContainer.shared.registerDependencies { container in
            // Register test-specific dependencies
            await self.registerTestDependencies(container)
        }
    }

    private func registerTestDependencies(_ container: Container) async {
        // Mock repositories for integration tests
        await container.register(MockUserRepositoryModule())
        await container.register(MockAuthRepositoryModule())

        // Real use cases for integration testing
        let useCaseFactory = AppDIContainer.shared.useCaseFactory
        await useCaseFactory.makeAllModules().asyncForEach { module in
            await container.register(module)
        }
    }

    func testUserAuthenticationFlow() async throws {
        let authUseCase = DependencyContainer.live.resolve(AuthUseCaseProtocol.self)!
        let userUseCase = DependencyContainer.live.resolve(UserUseCaseProtocol.self)!

        // Test complete authentication flow
        let authResult = try await authUseCase.login(email: "test@example.com", password: "password")
        XCTAssertTrue(authResult.isSuccess)

        let userProfile = try await userUseCase.loadUserProfile()
        XCTAssertNotNil(userProfile)
    }
}
```

## Best Practices

### 1. Organize by Feature Modules

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

### 2. Environment-Specific Configuration

```swift
extension AppDIContainer {
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
        // Development-specific implementations
        await container.register(MockNetworkServiceModule())
        await container.register(InMemoryDatabaseModule())
        await container.register(DetailedLoggingModule())
    }

    private func registerProductionDependencies(_ container: Container) async {
        // Production implementations
        await container.register(ProductionNetworkServiceModule())
        await container.register(SQLiteDatabaseModule())
        await container.register(OptimizedLoggingModule())
    }
}
```

### 3. Gradual Migration Strategy

```swift
class LegacyAppMigration {
    static func migrateToAppDIContainer() async {
        await AppDIContainer.shared.registerDependencies { container in
            // Migrate existing dependencies gradually
            await migrateCoreServices(container)
            await migrateUserServices(container)
            await migrateOrderServices(container)
        }
    }

    private static func migrateCoreServices(_ container: Container) async {
        // Keep existing instances if needed
        if let existingLogger = LegacyServiceLocator.shared.logger {
            await container.register(ExistingLoggerModule(logger: existingLogger))
        } else {
            await container.register(NewLoggerModule())
        }
    }
}
```

## Discussion

- `AppDIContainer` serves as a single entry point for dependency management
- By registering modules at app initialization, you can create and query dependency objects quickly and reliably at runtime
- The internal `Container` optimizes performance by executing all registered modules **in parallel**
- Factory patterns systematically manage Repository, UseCase, and Scope layers
- Automatic optimization configuration ensures optimal performance out of the box

## See Also

- [Module System](/guide/module-system) - Organizing large applications with modules
- [Property Wrappers](/guide/property-wrappers) - Using @Factory and @Inject
- [Bootstrap Guide](/guide/bootstrap) - Application initialization patterns
- [UnifiedDI vs DIContainer](/guide/unified-di) - Choosing the right API