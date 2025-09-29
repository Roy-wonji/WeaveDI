# Module Factory

WeaveDI's Module Factory system provides a powerful way to organize and manage dependencies in large-scale applications through systematic module creation and registration.

## Overview

The Module Factory pattern in WeaveDI allows you to group related dependencies logically and register them systematically in the container. This ensures clean, maintainable DI architecture even in large projects.

## Core Components

### ModuleFactory Protocol

Based on the actual implementation in the source code:

```swift
public protocol ModuleFactory {
    var registerModule: RegisterModule { get }
    var definitions: [@Sendable () -> Module] { get set }
    func makeAllModules() -> [Module]
}
```

### RegisterModule

The core module creation utility:

```swift
public struct RegisterModule: Sendable {
    // Basic module creation
    public func makeModule<T>(_ type: T.Type, factory: @Sendable @escaping () -> T) -> Module where T: Sendable

    // UseCase-Repository pattern
    public func makeUseCaseWithRepository<UseCase, Repo>(
        _ useCaseProtocol: UseCase.Type,
        repositoryProtocol: Repo.Type,
        repositoryFallback: @Sendable @autoclosure @escaping () -> Repo,
        factory: @Sendable @escaping (Repo) -> UseCase
    ) -> @Sendable () -> Module where UseCase: Sendable
}
```

## Basic Usage

### Simple Module Factory

```swift
struct RepositoryModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setup() {
        definitions.append {
            registerModule.makeModule(UserRepository.self) {
                UserRepositoryImpl()
            }
        }

        definitions.append {
            registerModule.makeModule(BookRepository.self) {
                BookRepositoryImpl()
            }
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}
```

### Factory Registration and Usage

```swift
// App initialization
var repositoryFactory = RepositoryModuleFactory()
repositoryFactory.setup()

let modules = repositoryFactory.makeAllModules()
for module in modules {
    await module.register()
}
```

## Advanced Patterns

### 1. Multi-Module Factory System

Creating and managing multiple types of modules:

```swift
struct ApplicationModuleFactory {
    var repositoryFactory = RepositoryModuleFactory()
    var useCaseFactory = UseCaseModuleFactory()
    var serviceFactory = ServiceModuleFactory()

    mutating func setupAll() {
        repositoryFactory.setup()
        useCaseFactory.setup()
        serviceFactory.setup()
    }

    func getAllModules() -> [Module] {
        var allModules: [Module] = []
        allModules.append(contentsOf: repositoryFactory.makeAllModules())
        allModules.append(contentsOf: useCaseFactory.makeAllModules())
        allModules.append(contentsOf: serviceFactory.makeAllModules())
        return allModules
    }
}
```

### 2. UseCase Factory with Repository Dependencies

Using the built-in UseCase-Repository pattern:

```swift
struct UseCaseModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setup() {
        // UseCase with Repository dependency
        definitions.append(
            registerModule.makeUseCaseWithRepository(
                LoginUseCase.self,
                repositoryProtocol: AuthRepository.self,
                repositoryFallback: DefaultAuthRepository(),
                factory: { repository in
                    LoginUseCaseImpl(repository: repository)
                }
            )
        )

        definitions.append(
            registerModule.makeUseCaseWithRepository(
                UserProfileUseCase.self,
                repositoryProtocol: UserRepository.self,
                repositoryFallback: DefaultUserRepository(),
                factory: { repository in
                    UserProfileUseCaseImpl(repository: repository)
                }
            )
        )
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}
```

### 3. Specialized Factory Types

WeaveDI provides pre-built factory types:

```swift
// Built-in specialized factories
public struct RepositoryModuleFactory: ModuleFactory, Sendable
public struct UseCaseModuleFactory: ModuleFactory, Sendable
public struct ScopeModuleFactory: ModuleFactory, Sendable
```

### 4. ModuleFactoryManager

Centralized management of all factories:

```swift
public struct ModuleFactoryManager: Sendable {
    public var repositoryFactory: RepositoryModuleFactory
    public var useCaseFactory: UseCaseModuleFactory
    public var scopeFactory: ScopeModuleFactory

    public func registerAll() async {
        // Registers all modules from all factories
        let allModules = repositoryFactory.makeAllModules() +
                        useCaseFactory.makeAllModules() +
                        scopeFactory.makeAllModules()

        for module in allModules {
            await module.register()
        }
    }
}

// Usage
let manager = ModuleFactoryManager(
    repositoryFactory: RepositoryModuleFactory(),
    useCaseFactory: UseCaseModuleFactory(),
    scopeFactory: ScopeModuleFactory()
)

await manager.registerAll()
```

## Real-World Implementation

### Large Application Setup

```swift
@main
struct WeaveDIApp: App {
    init() {
        Task {
            await setupDependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupDependencies() async {
        var applicationFactory = ApplicationModuleFactory()
        applicationFactory.setupAll()

        let allModules = applicationFactory.getAllModules()

        await WeaveDI.Container.bootstrap { container in
            for module in allModules {
                await container.register(module)
            }
        }
    }
}
```

### Environment-Specific Factories

```swift
struct EnvironmentModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []
    let environment: Environment

    mutating func setup() {
        switch environment {
        case .development:
            setupDevelopmentModules()
        case .staging:
            setupStagingModules()
        case .production:
            setupProductionModules()
        }
    }

    private mutating func setupDevelopmentModules() {
        definitions.append {
            registerModule.makeModule(APIClient.self) {
                MockAPIClient(baseURL: "https://dev-api.example.com")
            }
        }

        definitions.append {
            registerModule.makeModule(Logger.self) {
                VerboseLogger()
            }
        }
    }

    private mutating func setupProductionModules() {
        definitions.append {
            registerModule.makeModule(APIClient.self) {
                ProductionAPIClient(
                    baseURL: "https://api.example.com",
                    certificatePinner: SSLCertificatePinner()
                )
            }
        }

        definitions.append {
            registerModule.makeModule(Logger.self) {
                ProductionLogger()
            }
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}
```

### Async Module Factory

For dependencies requiring async initialization:

```swift
struct AsyncModuleFactory {
    func makeConfigurationModule() async -> Module {
        // Fetch remote configuration
        let remoteConfig = await RemoteConfigService.fetchConfiguration()

        return Module(Configuration.self) {
            remoteConfig
        }
    }

    func makeDatabaseModule() async -> Module {
        // Initialize database connection
        let database = await DatabaseManager.initialize()

        return Module(Database.self) {
            database
        }
    }
}

// Usage
let asyncFactory = AsyncModuleFactory()

await WeaveDI.Container.bootstrap { container in
    // Register sync modules first
    var syncFactory = ApplicationModuleFactory()
    syncFactory.setupAll()

    for module in syncFactory.getAllModules() {
        await container.register(module)
    }

    // Then register async modules
    let configModule = await asyncFactory.makeConfigurationModule()
    let dbModule = await asyncFactory.makeDatabaseModule()

    await container.register(configModule)
    await container.register(dbModule)
}
```

## Best Practices

### 1. Ordered Module Registration

```swift
struct OrderedModuleRegistration {
    static func registerInOrder() async {
        await WeaveDI.Container.bootstrap { container in
            // 1. Infrastructure layer
            let infraModules = InfrastructureModuleFactory().makeAllModules()
            for module in infraModules {
                await container.register(module)
            }

            // 2. Data layer
            let dataModules = DataModuleFactory().makeAllModules()
            for module in dataModules {
                await container.register(module)
            }

            // 3. Domain layer
            let domainModules = DomainModuleFactory().makeAllModules()
            for module in domainModules {
                await container.register(module)
            }

            // 4. Presentation layer
            let presentationModules = PresentationModuleFactory().makeAllModules()
            for module in presentationModules {
                await container.register(module)
            }
        }
    }
}
```

### 2. Testing Support

```swift
#if DEBUG
struct TestModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setupMocks() {
        definitions.append {
            registerModule.makeModule(UserRepository.self) {
                MockUserRepository()
            }
        }

        definitions.append {
            registerModule.makeModule(NetworkService.self) {
                MockNetworkService()
            }
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}
#endif
```

### 3. Error Handling

```swift
struct SafeModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setup() {
        definitions.append {
            registerModule.makeModule(RiskyService.self) {
                do {
                    return try RiskyServiceImpl()
                } catch {
                    print("Failed to create RiskyService: \(error)")
                    return FallbackService()
                }
            }
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}
```

## Performance Considerations

### Lazy Module Creation

```swift
struct LazyModuleFactory {
    private lazy var expensiveModule = Module(ExpensiveService.self) {
        ExpensiveServiceImpl() // Only created when first accessed
    }

    func getExpensiveModule() -> Module {
        expensiveModule
    }
}
```

The Module Factory system in WeaveDI provides a robust foundation for managing complex dependency graphs while maintaining clean, testable, and maintainable code architecture.