# Module Factory - Advanced Dependency Organization

Comprehensive guide to WeaveDI's Module Factory system - the most powerful way to organize, manage, and scale dependencies in enterprise-level applications. This system enables systematic module creation, registration, and management for complex dependency graphs.

## Overview

The Module Factory pattern in WeaveDI transforms how you manage dependencies at scale. Instead of scattered registrations, you create organized, testable, and maintainable dependency modules that can be composed, configured, and managed systematically.

### Key Benefits

- **🏗️ Systematic Organization**: Group related dependencies into logical modules
- **🔧 Factory Patterns**: Leverage proven factory design patterns for dependency creation
- **🎯 Type Safety**: Compile-time verification of module dependencies
- **🧪 Testing Support**: Easy mock injection and test isolation
- **⚡ Performance**: Lazy loading and optimized module registration
- **📦 Modularization**: Perfect for large teams and complex applications

### Architecture Benefits

```
┌─────────────────────────────────────┐
│        Application Layer            │
│   ┌─────────────────────────────┐   │
│   │     ModuleFactoryManager    │   │
│   └─────────────────────────────┘   │
└─────────────────┬───────────────────┘
                  │
      ┌───────────┼───────────┐
      │           │           │
┌─────▼─────┐ ┌───▼────┐ ┌───▼────────┐
│Repository │ │UseCase │ │  Service   │
│  Factory  │ │Factory │ │  Factory   │
└───────────┘ └────────┘ └────────────┘
      │           │           │
      └───────────┼───────────┘
                  │
┌─────────────────▼───────────────────┐
│         WeaveDI Container           │
│        (Registered Modules)         │
└─────────────────────────────────────┘
```

## Core Components

### ModuleFactory Protocol

The foundation of the module system, based on the actual implementation:

```swift
public protocol ModuleFactory {
    var registerModule: RegisterModule { get }    // Module creation utility
    var definitions: [@Sendable () -> Module] { get set }  // Module definitions
    func makeAllModules() -> [Module]  // Create all modules at once
}
```

**Protocol Responsibilities:**
- **Module Definition Storage**: Maintains a list of module creation closures
- **Batch Creation**: Creates all modules in the factory simultaneously
- **Type Safety**: Ensures all modules are properly typed and sendable
- **Lazy Evaluation**: Modules are only created when `makeAllModules()` is called

### RegisterModule - The Module Creation Engine

The core utility that powers all module creation:

```swift
public struct RegisterModule: Sendable {
    // Basic module creation - for simple dependencies
    public func makeModule<T>(
        _ type: T.Type,
        factory: @Sendable @escaping () -> T
    ) -> Module where T: Sendable

    // Advanced UseCase-Repository pattern with automatic dependency injection
    public func makeUseCaseWithRepository<UseCase, Repo>(
        _ useCaseProtocol: UseCase.Type,      // The UseCase protocol to register
        repositoryProtocol: Repo.Type,        // Required repository dependency
        repositoryFallback: @Sendable @autoclosure @escaping () -> Repo,  // Fallback if repo not found
        factory: @Sendable @escaping (Repo) -> UseCase  // UseCase creation with injected repo
    ) -> @Sendable () -> Module where UseCase: Sendable

    // Dependency injection with multiple dependencies
    public func makeDependency<T>(
        _ type: T.Type,
        dependencies: [Any.Type] = [],
        factory: @Sendable @escaping () throws -> T
    ) -> Module where T: Sendable
}
```

**RegisterModule Features:**
- **🎯 Type Safety**: Compile-time type checking for all modules
- **🔄 Dependency Injection**: Automatic resolution of module dependencies
- **🛡️ Fallback Support**: Graceful handling of missing dependencies
- **⚡ Performance**: Optimized module creation and registration
- **🧵 Concurrency**: Full Swift 6 sendable compliance

## Basic Usage

### Simple Module Factory

Start with a basic factory for related dependencies:

```swift
struct RepositoryModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setup() {
        // User repository with database dependency
        definitions.append {
            registerModule.makeModule(UserRepository.self) {
                UserRepositoryImpl(
                    database: WeaveDI.Container.shared.resolve(DatabaseService.self)!,
                    logger: WeaveDI.Container.shared.resolve(Logger.self)
                )
            }
        }

        // Book repository with caching
        definitions.append {
            registerModule.makeModule(BookRepository.self) {
                CachedBookRepository(
                    baseRepository: BookRepositoryImpl(),
                    cache: WeaveDI.Container.shared.resolve(CacheService.self)!
                )
            }
        }

        // Order repository with complex dependencies
        definitions.append {
            registerModule.makeModule(OrderRepository.self) {
                OrderRepositoryImpl(
                    database: WeaveDI.Container.shared.resolve(DatabaseService.self)!,
                    paymentGateway: WeaveDI.Container.shared.resolve(PaymentGateway.self)!,
                    notificationService: WeaveDI.Container.shared.resolve(NotificationService.self)!
                )
            }
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}
```

### Enhanced Factory with Error Handling

```swift
struct SafeRepositoryModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setup() {
        definitions.append {
            registerModule.makeModule(UserRepository.self) {
                do {
                    // Try to create with remote database
                    let remoteDB = try RemoteDatabaseService.connect()
                    return RemoteUserRepository(database: remoteDB)
                } catch {
                    // Fallback to local database
                    print("⚠️ Remote DB unavailable, using local: \(error)")
                    let localDB = LocalDatabaseService()
                    return LocalUserRepository(database: localDB)
                }
            }
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}
```

### Factory Registration and Usage

#### Basic Registration

```swift
// App initialization
func initializeRepositories() async {
    var repositoryFactory = RepositoryModuleFactory()
    repositoryFactory.setup()

    let modules = repositoryFactory.makeAllModules()

    await WeaveDI.Container.bootstrap { container in
        for module in modules {
            await container.register(module)
        }
    }

    print("✅ Registered \(modules.count) repository modules")
}
```

#### Advanced Registration with Validation

```swift
func initializeWithValidation() async throws {
    var repositoryFactory = RepositoryModuleFactory()
    repositoryFactory.setup()

    let modules = repositoryFactory.makeAllModules()

    // Validate modules before registration
    try validateModules(modules)

    await WeaveDI.Container.bootstrap { container in
        await withTaskGroup(of: Void.self) { group in
            for module in modules {
                group.addTask {
                    await container.register(module)
                    print("📦 Registered: \(module.description)")
                }
            }
        }
    }
}

func validateModules(_ modules: [Module]) throws {
    guard !modules.isEmpty else {
        throw ModuleError.noModulesFound
    }

    for module in modules {
        guard module.isValid else {
            throw ModuleError.invalidModule(module.description)
        }
    }
}
```

## Advanced Patterns

### 1. Multi-Module Factory System

A comprehensive system for managing different types of modules:

```swift
struct ApplicationModuleFactory {
    // Different factory types for different concerns
    var infrastructureFactory = InfrastructureModuleFactory()
    var repositoryFactory = RepositoryModuleFactory()
    var useCaseFactory = UseCaseModuleFactory()
    var serviceFactory = ServiceModuleFactory()
    var presentationFactory = PresentationModuleFactory()

    let environment: Environment
    let configuration: AppConfiguration

    init(environment: Environment, configuration: AppConfiguration) {
        self.environment = environment
        self.configuration = configuration
    }

    mutating func setupAll() async {
        // Setup in dependency order
        await setupInfrastructure()
        await setupRepositories()
        await setupUseCases()
        await setupServices()
        await setupPresentation()
    }

    private mutating func setupInfrastructure() async {
        infrastructureFactory.setup(for: environment, config: configuration)
    }

    private mutating func setupRepositories() async {
        // Repositories depend on infrastructure
        repositoryFactory.setup()
    }

    private mutating func setupUseCases() async {
        // UseCases depend on repositories
        useCaseFactory.setup()
    }

    private mutating func setupServices() async {
        // Services depend on use cases
        serviceFactory.setup()
    }

    private mutating func setupPresentation() async {
        // Presentation depends on services
        presentationFactory.setup()
    }

    func getAllModules() -> [Module] {
        var allModules: [Module] = []

        // Add modules in dependency order
        allModules.append(contentsOf: infrastructureFactory.makeAllModules())
        allModules.append(contentsOf: repositoryFactory.makeAllModules())
        allModules.append(contentsOf: useCaseFactory.makeAllModules())
        allModules.append(contentsOf: serviceFactory.makeAllModules())
        allModules.append(contentsOf: presentationFactory.makeAllModules())

        return allModules
    }

    func getModulesStatistics() -> ModuleStatistics {
        return ModuleStatistics(
            infrastructureCount: infrastructureFactory.makeAllModules().count,
            repositoryCount: repositoryFactory.makeAllModules().count,
            useCaseCount: useCaseFactory.makeAllModules().count,
            serviceCount: serviceFactory.makeAllModules().count,
            presentationCount: presentationFactory.makeAllModules().count
        )
    }
}

struct ModuleStatistics {
    let infrastructureCount: Int
    let repositoryCount: Int
    let useCaseCount: Int
    let serviceCount: Int
    let presentationCount: Int

    var totalCount: Int {
        infrastructureCount + repositoryCount + useCaseCount + serviceCount + presentationCount
    }
}
```

### 2. UseCase Factory with Repository Dependencies

Leveraging the built-in UseCase-Repository pattern for automatic dependency injection:

```swift
struct UseCaseModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setup() {
        // Authentication UseCase with Repository dependency
        definitions.append(
            registerModule.makeUseCaseWithRepository(
                LoginUseCase.self,
                repositoryProtocol: AuthRepository.self,
                repositoryFallback: DefaultAuthRepository(),
                factory: { repository in
                    LoginUseCaseImpl(
                        repository: repository,
                        validator: AuthValidator(),
                        logger: WeaveDI.Container.shared.resolve(Logger.self)
                    )
                }
            )
        )

        // User Management UseCase
        definitions.append(
            registerModule.makeUseCaseWithRepository(
                UserProfileUseCase.self,
                repositoryProtocol: UserRepository.self,
                repositoryFallback: DefaultUserRepository(),
                factory: { repository in
                    UserProfileUseCaseImpl(
                        repository: repository,
                        imageService: WeaveDI.Container.shared.resolve(ImageService.self)!,
                        analyticsService: WeaveDI.Container.shared.resolve(AnalyticsService.self)
                    )
                }
            )
        )

        // Order Management UseCase with multiple repositories
        definitions.append(
            registerModule.makeUseCaseWithRepository(
                OrderManagementUseCase.self,
                repositoryProtocol: OrderRepository.self,
                repositoryFallback: DefaultOrderRepository(),
                factory: { orderRepository in
                    OrderManagementUseCaseImpl(
                        orderRepository: orderRepository,
                        userRepository: WeaveDI.Container.shared.resolve(UserRepository.self)!,
                        paymentRepository: WeaveDI.Container.shared.resolve(PaymentRepository.self)!,
                        notificationService: WeaveDI.Container.shared.resolve(NotificationService.self)
                    )
                }
            )
        )

        // Search UseCase with caching
        definitions.append {
            registerModule.makeModule(SearchUseCase.self) {
                CachedSearchUseCaseImpl(
                    searchRepository: WeaveDI.Container.shared.resolve(SearchRepository.self)!,
                    cacheService: WeaveDI.Container.shared.resolve(CacheService.self)!,
                    analyticsService: WeaveDI.Container.shared.resolve(AnalyticsService.self)
                )
            }
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}
```

### 3. Specialized Factory Types

WeaveDI provides pre-built factory types for common patterns:

```swift
// Built-in specialized factories
public struct RepositoryModuleFactory: ModuleFactory, Sendable {
    // Optimized for data layer dependencies
    // - Database connections
    // - API clients
    // - Data mappers
    // - Caching layers
}

public struct UseCaseModuleFactory: ModuleFactory, Sendable {
    // Optimized for business logic
    // - Domain use cases
    // - Business rules
    // - Workflow orchestration
    // - Cross-cutting concerns
}

public struct ScopeModuleFactory: ModuleFactory, Sendable {
    // Optimized for scoped dependencies
    // - Request-scoped services
    // - Session-scoped data
    // - User-scoped preferences
    // - Temporary contexts
}
```

#### Custom Specialized Factories

```swift
// Infrastructure Factory
struct InfrastructureModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setup(for environment: Environment, config: AppConfiguration) {
        // Database setup
        definitions.append {
            registerModule.makeModule(DatabaseService.self) {
                switch environment {
                case .development:
                    return InMemoryDatabaseService()
                case .staging:
                    return SQLiteDatabaseService(path: config.stagingDBPath)
                case .production:
                    return PostgreSQLDatabaseService(config: config.productionDBConfig)
                }
            }
        }

        // Network setup
        definitions.append {
            registerModule.makeModule(NetworkService.self) {
                HTTPNetworkService(
                    baseURL: config.apiBaseURL,
                    timeout: config.networkTimeout,
                    interceptors: createInterceptors(for: environment)
                )
            }
        }

        // Logging setup
        definitions.append {
            registerModule.makeModule(Logger.self) {
                switch environment {
                case .development:
                    return ConsoleLogger(level: .debug)
                case .staging:
                    return FileLogger(level: .info, path: config.logPath)
                case .production:
                    return RemoteLogger(level: .error, endpoint: config.logEndpoint)
                }
            }
        }
    }

    private func createInterceptors(for environment: Environment) -> [NetworkInterceptor] {
        var interceptors: [NetworkInterceptor] = []

        // Add auth interceptor
        interceptors.append(AuthInterceptor())

        // Add logging in non-production
        if environment != .production {
            interceptors.append(LoggingInterceptor())
        }

        // Add retry interceptor
        interceptors.append(RetryInterceptor(maxRetries: 3))

        return interceptors
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}
```

### 4. ModuleFactoryManager - Enterprise-Level Management

Centralized, enterprise-grade management of all factories with monitoring and validation:

```swift
public struct ModuleFactoryManager: Sendable {
    public var repositoryFactory: RepositoryModuleFactory
    public var useCaseFactory: UseCaseModuleFactory
    public var scopeFactory: ScopeModuleFactory
    public var infrastructureFactory: InfrastructureModuleFactory
    public var presentationFactory: PresentationModuleFactory

    private let logger: Logger?
    private let environment: Environment
    private let configuration: AppConfiguration

    public init(
        environment: Environment,
        configuration: AppConfiguration,
        logger: Logger? = nil
    ) {
        self.environment = environment
        self.configuration = configuration
        self.logger = logger

        // Initialize factories with environment context
        self.repositoryFactory = RepositoryModuleFactory()
        self.useCaseFactory = UseCaseModuleFactory()
        self.scopeFactory = ScopeModuleFactory()
        self.infrastructureFactory = InfrastructureModuleFactory()
        self.presentationFactory = PresentationModuleFactory()
    }

    public mutating func setupAllFactories() async {
        logger?.info("🏭 Setting up module factories for \(environment)")

        // Setup in dependency order
        infrastructureFactory.setup(for: environment, config: configuration)
        repositoryFactory.setup()
        useCaseFactory.setup()
        scopeFactory.setup()
        presentationFactory.setup()

        logger?.info("✅ All factories configured")
    }

    public func registerAll() async throws {
        logger?.info("📦 Starting module registration process")

        // Get all modules
        let allModules = getAllModulesInOrder()

        logger?.info("📊 Found \(allModules.count) modules to register")

        // Validate modules before registration
        try validateModules(allModules)

        // Register modules in batches for better performance
        await registerModulesInBatches(allModules)

        logger?.info("🎉 Module registration completed successfully")
    }

    private func getAllModulesInOrder() -> [Module] {
        var allModules: [Module] = []

        // Register in dependency order
        allModules.append(contentsOf: infrastructureFactory.makeAllModules())
        allModules.append(contentsOf: repositoryFactory.makeAllModules())
        allModules.append(contentsOf: useCaseFactory.makeAllModules())
        allModules.append(contentsOf: scopeFactory.makeAllModules())
        allModules.append(contentsOf: presentationFactory.makeAllModules())

        return allModules
    }

    private func validateModules(_ modules: [Module]) throws {
        guard !modules.isEmpty else {
            throw ModuleFactoryError.noModulesFound
        }

        // Check for duplicate registrations
        var typeNames: Set<String> = []
        for module in modules {
            let typeName = String(describing: module.type)
            if typeNames.contains(typeName) {
                throw ModuleFactoryError.duplicateModule(typeName)
            }
            typeNames.insert(typeName)
        }

        logger?.info("✅ Module validation passed")
    }

    private func registerModulesInBatches(_ modules: [Module]) async {
        let batchSize = 10 // Register 10 modules at a time
        let batches = modules.chunked(into: batchSize)

        for (index, batch) in batches.enumerated() {
            logger?.info("📦 Registering batch \(index + 1)/\(batches.count)")

            await withTaskGroup(of: Void.self) { group in
                for module in batch {
                    group.addTask {
                        await WeaveDI.Container.shared.register(module)
                        self.logger?.debug("✅ Registered: \(module.description)")
                    }
                }
            }
        }
    }

    public func getRegistrationStatistics() -> RegistrationStatistics {
        return RegistrationStatistics(
            infrastructureModules: infrastructureFactory.makeAllModules().count,
            repositoryModules: repositoryFactory.makeAllModules().count,
            useCaseModules: useCaseFactory.makeAllModules().count,
            scopeModules: scopeFactory.makeAllModules().count,
            presentationModules: presentationFactory.makeAllModules().count
        )
    }
}

// Supporting types
enum ModuleFactoryError: LocalizedError {
    case noModulesFound
    case duplicateModule(String)
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .noModulesFound:
            return "No modules found in any factory"
        case .duplicateModule(let typeName):
            return "Duplicate module registration for type: \(typeName)"
        case .invalidConfiguration:
            return "Invalid factory configuration"
        }
    }
}

struct RegistrationStatistics {
    let infrastructureModules: Int
    let repositoryModules: Int
    let useCaseModules: Int
    let scopeModules: Int
    let presentationModules: Int

    var totalModules: Int {
        infrastructureModules + repositoryModules + useCaseModules + scopeModules + presentationModules
    }
}

// Usage
func setupApplication() async throws {
    var manager = ModuleFactoryManager(
        environment: .production,
        configuration: AppConfiguration.load(),
        logger: ConsoleLogger()
    )

    await manager.setupAllFactories()
    try await manager.registerAll()

    let stats = manager.getRegistrationStatistics()
    print("🎯 Registered \(stats.totalModules) modules across \(5) factories")
}
```

## Real-World Implementation

### Large Application Setup

#### SwiftUI Application with Comprehensive Module System

```swift
@main
struct EnterpriseWeaveDIApp: App {
    @State private var isInitialized = false
    @State private var initializationError: Error?

    init() {
        // Start initialization but don't block the main thread
        Task {
            await initializeApplication()
        }
    }

    var body: some Scene {
        WindowGroup {
            if isInitialized {
                ContentView()
            } else if let error = initializationError {
                ErrorView(error: error) {
                    Task {
                        await retryInitialization()
                    }
                }
            } else {
                LoadingView()
                    .task {
                        await initializeApplication()
                    }
            }
        }
    }

    @MainActor
    private func initializeApplication() async {
        do {
            let startTime = Date()
            print("🚀 Starting application initialization...")

            // Setup module factory manager
            var manager = ModuleFactoryManager(
                environment: AppEnvironment.current,
                configuration: try AppConfiguration.load(),
                logger: AppLogger.shared
            )

            // Setup all factories
            await manager.setupAllFactories()

            // Register all modules
            try await manager.registerAll()

            // Verify critical dependencies
            try await verifyCriticalDependencies()

            let initTime = Date().timeIntervalSince(startTime)
            print("✅ Application initialized in \(String(format: "%.2f", initTime))s")

            // Show statistics
            let stats = manager.getRegistrationStatistics()
            print("📊 Modules registered: \(stats.totalModules)")

            isInitialized = true

        } catch {
            print("❌ Application initialization failed: \(error)")
            initializationError = error
        }
    }

    private func retryInitialization() async {
        initializationError = nil
        await initializeApplication()
    }

    private func verifyCriticalDependencies() async throws {
        // Verify essential services are available
        let criticalServices: [Any.Type] = [
            DatabaseService.self,
            NetworkService.self,
            Logger.self,
            UserRepository.self,
            AuthenticationService.self
        ]

        for serviceType in criticalServices {
            let resolved = WeaveDI.Container.shared.resolve(serviceType)
            guard resolved != nil else {
                throw InitializationError.criticalServiceMissing(String(describing: serviceType))
            }
        }

        print("✅ All critical dependencies verified")
    }
}

enum InitializationError: LocalizedError {
    case criticalServiceMissing(String)
    case configurationLoadFailed
    case moduleRegistrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .criticalServiceMissing(let service):
            return "Critical service missing: \(service)"
        case .configurationLoadFailed:
            return "Failed to load application configuration"
        case .moduleRegistrationFailed(let details):
            return "Module registration failed: \(details)"
        }
    }
}
```

#### UIKit Application with Factory System

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var moduleManager: ModuleFactoryManager?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Setup window
        window = UIWindow(windowScene: windowScene)

        // Show loading screen
        window?.rootViewController = LoadingViewController()
        window?.makeKeyAndVisible()

        // Initialize asynchronously
        Task {
            await initializeModuleSystem()
        }
    }

    private func initializeModuleSystem() async {
        do {
            print("🏭 Initializing module factory system...")

            // Create and setup module manager
            var manager = ModuleFactoryManager(
                environment: AppEnvironment.current,
                configuration: try AppConfiguration.load(),
                logger: AppLogger.shared
            )
            self.moduleManager = manager

            // Setup factories
            await manager.setupAllFactories()

            // Register all modules
            try await manager.registerAll()

            // Transition to main app
            await transitionToMainApp()

        } catch {
            await showInitializationError(error)
        }
    }

    @MainActor
    private func transitionToMainApp() {
        // Create main coordinator with injected dependencies
        let mainCoordinator = MainCoordinator()
        let mainViewController = mainCoordinator.start()

        // Smooth transition
        UIView.transition(with: window!, duration: 0.3, options: .transitionCrossDissolve) {
            self.window?.rootViewController = mainViewController
        }

        print("🎉 Successfully transitioned to main application")
    }

    @MainActor
    private func showInitializationError(_ error: Error) {
        let errorViewController = ErrorViewController(error: error) { [weak self] in
            Task {
                await self?.initializeModuleSystem()
            }
        }

        window?.rootViewController = errorViewController
    }
}
```

### Environment-Specific Factories

Comprehensive environment-aware factory system:

```swift
struct EnvironmentModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []
    let environment: Environment
    let configuration: AppConfiguration

    init(environment: Environment, configuration: AppConfiguration) {
        self.environment = environment
        self.configuration = configuration
    }

    mutating func setup() {
        switch environment {
        case .development:
            setupDevelopmentModules()
        case .staging:
            setupStagingModules()
        case .production:
            setupProductionModules()
        case .testing:
            setupTestingModules()
        }
    }

    private mutating func setupDevelopmentModules() {
        print("🛠️ Setting up development modules")

        // Mock API with detailed logging
        definitions.append {
            registerModule.makeModule(APIClient.self) {
                MockAPIClient(
                    baseURL: "https://dev-api.example.com",
                    enableNetworkLogs: true,
                    simulateLatency: true,
                    failureRate: 0.1 // 10% failure rate for testing
                )
            }
        }

        // Verbose logging for debugging
        definitions.append {
            registerModule.makeModule(Logger.self) {
                CompositeLogger([
                    ConsoleLogger(level: .debug),
                    FileLogger(level: .info, path: configuration.devLogPath),
                    OSLogger(subsystem: "com.app.dev", category: "general")
                ])
            }
        }

        // In-memory database for fast development
        definitions.append {
            registerModule.makeModule(DatabaseService.self) {
                InMemoryDatabaseService(preloadTestData: true)
            }
        }

        // Mock analytics that logs to console
        definitions.append {
            registerModule.makeModule(AnalyticsService.self) {
                ConsoleAnalyticsService(verbose: true)
            }
        }

        // Debug image loader with caching disabled
        definitions.append {
            registerModule.makeModule(ImageLoader.self) {
                DebugImageLoader(cacheEnabled: false)
            }
        }
    }

    private mutating func setupStagingModules() {
        print("🎭 Setting up staging modules")

        // Real API with staging endpoints
        definitions.append {
            registerModule.makeModule(APIClient.self) {
                HTTPAPIClient(
                    baseURL: "https://staging-api.example.com",
                    timeout: 30,
                    retryPolicy: RetryPolicy(maxRetries: 3),
                    certificatePinner: nil, // Less strict in staging
                    interceptors: [
                        AuthInterceptor(),
                        LoggingInterceptor(level: .info),
                        MetricsInterceptor()
                    ]
                )
            }
        }

        // Structured logging with remote reporting
        definitions.append {
            registerModule.makeModule(Logger.self) {
                CompositeLogger([
                    ConsoleLogger(level: .info),
                    RemoteLogger(
                        endpoint: "https://logs-staging.example.com",
                        level: .warning
                    )
                ])
            }
        }

        // Real database with staging data
        definitions.append {
            registerModule.makeModule(DatabaseService.self) {
                PostgreSQLDatabaseService(
                    connectionString: configuration.stagingDBConnectionString,
                    poolSize: 5,
                    enableMigrations: true
                )
            }
        }

        // Test analytics service
        definitions.append {
            registerModule.makeModule(AnalyticsService.self) {
                TestAnalyticsService(
                    endpoint: "https://analytics-staging.example.com",
                    flushInterval: 10 // seconds
                )
            }
        }
    }

    private mutating func setupProductionModules() {
        print("🚀 Setting up production modules")

        // Production API with all security measures
        definitions.append {
            registerModule.makeModule(APIClient.self) {
                SecureHTTPAPIClient(
                    baseURL: "https://api.example.com",
                    timeout: 15,
                    retryPolicy: RetryPolicy(maxRetries: 2),
                    certificatePinner: SSLCertificatePinner(
                        certificates: configuration.trustedCertificates
                    ),
                    interceptors: [
                        AuthInterceptor(),
                        RateLimitInterceptor(),
                        SecurityHeadersInterceptor(),
                        MetricsInterceptor()
                    ]
                )
            }
        }

        // Production logging - errors only
        definitions.append {
            registerModule.makeModule(Logger.self) {
                ProductionLogger(
                    remoteEndpoint: "https://logs.example.com",
                    level: .error,
                    encryptionKey: configuration.logEncryptionKey
                )
            }
        }

        // Production database with connection pooling
        definitions.append {
            registerModule.makeModule(DatabaseService.self) {
                ProductionDatabaseService(
                    primaryConnectionString: configuration.primaryDBConnectionString,
                    readReplicaConnectionString: configuration.readReplicaConnectionString,
                    poolSize: 20,
                    enableConnectionPooling: true,
                    enableReadWriteSplit: true
                )
            }
        }

        // Full analytics with privacy compliance
        definitions.append {
            registerModule.makeModule(AnalyticsService.self) {
                PrivacyCompliantAnalyticsService(
                    providers: [
                        FirebaseAnalyticsProvider(),
                        MixpanelAnalyticsProvider(),
                        CustomAnalyticsProvider(endpoint: configuration.analyticsEndpoint)
                    ],
                    privacySettings: configuration.privacySettings
                )
            }
        }

        // Performance-optimized image loader
        definitions.append {
            registerModule.makeModule(ImageLoader.self) {
                OptimizedImageLoader(
                    cacheSize: 100_000_000, // 100MB
                    compressionQuality: 0.8,
                    enableWebP: true
                )
            }
        }
    }

    private mutating func setupTestingModules() {
        print("🧪 Setting up testing modules")

        // Deterministic mock services for testing
        definitions.append {
            registerModule.makeModule(APIClient.self) {
                DeterministicMockAPIClient()
            }
        }

        definitions.append {
            registerModule.makeModule(Logger.self) {
                SilentLogger() // No output during tests
            }
        }

        definitions.append {
            registerModule.makeModule(DatabaseService.self) {
                InMemoryDatabaseService(preloadTestData: false)
            }
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}

// Supporting configuration
struct AppConfiguration {
    let devLogPath: String
    let stagingDBConnectionString: String
    let primaryDBConnectionString: String
    let readReplicaConnectionString: String
    let trustedCertificates: [Certificate]
    let logEncryptionKey: String
    let analyticsEndpoint: String
    let privacySettings: PrivacySettings

    static func load() throws -> AppConfiguration {
        // Load from bundle, environment variables, or remote config
        // Implementation depends on your app's configuration strategy
        fatalError("Implement configuration loading")
    }
}
```

### Async Module Factory

Advanced async module factory for complex initialization scenarios:

```swift
struct AsyncModuleFactory {
    private let logger: Logger?
    private let configuration: AppConfiguration
    private let timeout: TimeInterval

    init(configuration: AppConfiguration, logger: Logger? = nil, timeout: TimeInterval = 30) {
        self.configuration = configuration
        self.logger = logger
        self.timeout = timeout
    }

    func makeConfigurationModule() async throws -> Module {
        logger?.info("🔧 Loading remote configuration...")

        do {
            // Fetch remote configuration with timeout
            let remoteConfig = try await withTimeout(timeout) {
                try await RemoteConfigService.fetchConfiguration(
                    endpoint: configuration.configEndpoint,
                    apiKey: configuration.configAPIKey
                )
            }

            logger?.info("✅ Remote configuration loaded successfully")

            return Module(RemoteConfiguration.self) {
                remoteConfig
            }
        } catch {
            logger?.warning("⚠️ Failed to load remote config, using defaults: \(error)")

            // Fallback to local configuration
            return Module(RemoteConfiguration.self) {
                RemoteConfiguration.defaultConfiguration()
            }
        }
    }

    func makeDatabaseModule() async throws -> Module {
        logger?.info("🗄️ Initializing database connection...")

        do {
            // Initialize database with retry logic
            let database = try await withRetry(maxAttempts: 3, delay: 1.0) {
                try await DatabaseManager.initialize(
                    connectionString: configuration.primaryDBConnectionString,
                    poolSize: 10,
                    enableSSL: true
                )
            }

            // Verify database health
            try await database.healthCheck()

            logger?.info("✅ Database initialized and healthy")

            return Module(DatabaseService.self) {
                database
            }
        } catch {
            logger?.error("❌ Database initialization failed: \(error)")
            throw AsyncModuleError.databaseInitializationFailed(error)
        }
    }

    func makeAuthenticationModule() async throws -> Module {
        logger?.info("🔐 Setting up authentication service...")

        // Load authentication configuration
        let authConfig = try await AuthConfiguration.load()

        // Initialize auth providers
        let providers = try await initializeAuthProviders(authConfig)

        logger?.info("✅ Authentication service configured with \(providers.count) providers")

        return Module(AuthenticationService.self) {
            MultiProviderAuthenticationService(
                providers: providers,
                defaultProvider: authConfig.defaultProvider
            )
        }
    }

    func makeAnalyticsModule() async throws -> Module {
        logger?.info("📊 Initializing analytics service...")

        // Get user consent for analytics
        let consentStatus = await AnalyticsConsentManager.getConsentStatus()

        guard consentStatus.analyticsAllowed else {
            logger?.info("📊 Analytics disabled due to user consent")
            return Module(AnalyticsService.self) {
                NoOpAnalyticsService()
            }
        }

        // Initialize analytics with consent
        let analyticsService = try await AnalyticsService.initialize(
            configuration: configuration.analyticsConfig,
            consentSettings: consentStatus
        )

        logger?.info("✅ Analytics service initialized")

        return Module(AnalyticsService.self) {
            analyticsService
        }
    }

    private func initializeAuthProviders(_ config: AuthConfiguration) async throws -> [AuthProvider] {
        var providers: [AuthProvider] = []

        // Initialize OAuth providers concurrently
        await withTaskGroup(of: AuthProvider?.self) { group in
            for providerConfig in config.providers {
                group.addTask {
                    do {
                        return try await AuthProviderFactory.create(providerConfig)
                    } catch {
                        self.logger?.error("Failed to initialize auth provider \(providerConfig.type): \(error)")
                        return nil
                    }
                }
            }

            for await provider in group {
                if let provider = provider {
                    providers.append(provider)
                }
            }
        }

        guard !providers.isEmpty else {
            throw AsyncModuleError.noAuthProvidersAvailable
        }

        return providers
    }

    // Batch async module creation
    func makeAllAsyncModules() async throws -> [Module] {
        logger?.info("⚡ Creating all async modules concurrently...")

        return try await withThrowingTaskGroup(of: Module.self) { group in
            // Add all async module creation tasks
            group.addTask { try await self.makeConfigurationModule() }
            group.addTask { try await self.makeDatabaseModule() }
            group.addTask { try await self.makeAuthenticationModule() }
            group.addTask { try await self.makeAnalyticsModule() }

            var modules: [Module] = []
            for try await module in group {
                modules.append(module)
            }
            return modules
        }
    }
}

// Error types
enum AsyncModuleError: LocalizedError {
    case databaseInitializationFailed(Error)
    case configurationLoadFailed(Error)
    case noAuthProvidersAvailable
    case timeoutExceeded

    var errorDescription: String? {
        switch self {
        case .databaseInitializationFailed(let error):
            return "Database initialization failed: \(error.localizedDescription)"
        case .configurationLoadFailed(let error):
            return "Configuration load failed: \(error.localizedDescription)"
        case .noAuthProvidersAvailable:
            return "No authentication providers could be initialized"
        case .timeoutExceeded:
            return "Async module initialization timed out"
        }
    }
}

// Utility functions
func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw AsyncModuleError.timeoutExceeded
        }

        guard let result = try await group.next() else {
            throw AsyncModuleError.timeoutExceeded
        }

        group.cancelAll()
        return result
    }
}

func withRetry<T>(maxAttempts: Int, delay: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    var lastError: Error?

    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            if attempt < maxAttempts {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    throw lastError ?? AsyncModuleError.timeoutExceeded
}

// Usage in application
func setupAsyncModules() async throws {
    let asyncFactory = AsyncModuleFactory(
        configuration: AppConfiguration.load(),
        logger: AppLogger.shared
    )

    await WeaveDI.Container.bootstrap { container in
        // Register sync modules first
        var syncFactory = ApplicationModuleFactory()
        await syncFactory.setupAll()

        for module in syncFactory.getAllModules() {
            await container.register(module)
        }

        // Then register async modules
        do {
            let asyncModules = try await asyncFactory.makeAllAsyncModules()
            for module in asyncModules {
                await container.register(module)
            }
        } catch {
            print("⚠️ Some async modules failed to initialize: \(error)")
            // Handle partial initialization or fallback strategies
        }
    }
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

## DiModuleFactory - Common DI Dependency Management (v3.3.4+)

The `DiModuleFactory` introduced in v3.3.4 is a specialized module factory for systematically managing common DI dependencies such as Logger, Config, Cache, etc., used throughout the app.

### Key Features

- 📦 **Common Dependency Management**: Centralized management of dependencies shared across the app
- 🔄 **Builder Pattern**: Intuitive API for adding dependencies
- ⚙️ **Automatic Integration**: Seamless integration with ModuleFactoryManager
- 🎯 **Type Safety**: Compile-time type verification

### Basic Usage

```swift
import WeaveDI
import WeaveDIAppDI

// Create DiModuleFactory instance
var diFactory = DiModuleFactory()

// Add common DI dependencies (builder pattern)
diFactory.addDependency(Logger.self) {
    ConsoleLogger()
}

diFactory.addDependency(APIConfig.self) {
    APIConfig(baseURL: "https://api.example.com")
}

diFactory.addDependency(CacheService.self) {
    MemoryCacheService()
}

// Generate dependency modules
let modules = diFactory.makeAllModules()
```

### Integration with ModuleFactoryManager

`DiModuleFactory` integrates perfectly with `ModuleFactoryManager` for use alongside other factories.

```swift
// Configure ModuleFactoryManager
var factoryManager = ModuleFactoryManager()

// Configure DiModuleFactory
factoryManager.diFactory.addDependency(Logger.self) {
    #if DEBUG
    ConsoleLogger()
    #else
    ProductionLogger()
    #endif
}

factoryManager.diFactory.addDependency(NetworkConfig.self) {
    NetworkConfig(
        timeout: 30.0,
        retryCount: 3,
        baseURL: "https://api.example.com"
    )
}

// Configure Repository and UseCase factories together
factoryManager.repositoryFactory.addRepository(UserRepository.self) {
    UserRepositoryImpl()
}

factoryManager.useCaseFactory.addUseCase(
    AuthUseCase.self,
    repositoryType: UserRepository.self,
    repositoryFallback: { UserRepositoryImpl() }
) { repo in
    AuthUseCaseImpl(repository: repo)
}

// Register all modules at once
await factoryManager.registerAll(to: WeaveDI.Container.live)
```

### Environment-Specific Dependencies

Flexible patterns for setting different dependencies based on environment:

```swift
struct EnvironmentDiFactory {
    static func create(for environment: AppEnvironment) -> DiModuleFactory {
        var factory = DiModuleFactory()

        // Common dependencies
        factory.addDependency(AppConfig.self) {
            AppConfig.load()
        }

        // Environment-specific Logger
        switch environment {
        case .development:
            factory.addDependency(Logger.self) {
                ConsoleLogger(level: .debug)
            }
        case .staging:
            factory.addDependency(Logger.self) {
                FileLogger(level: .info)
            }
        case .production:
            factory.addDependency(Logger.self) {
                ProductionLogger(level: .warning)
            }
        }

        // Environment-specific Analytics
        factory.addDependency(AnalyticsService.self) {
            switch environment {
            case .development:
                return MockAnalyticsService()
            case .staging, .production:
                return FirebaseAnalyticsService()
            }
        }

        return factory
    }
}

// Usage
let environment = AppEnvironment.current
var factoryManager = ModuleFactoryManager()
factoryManager.diFactory = EnvironmentDiFactory.create(for: environment)
```

### Automatic Setup at App Startup

`AppDIManager` automatically supports `DiModuleFactory` from v3.3.4:

```swift
// In AppDelegate or App.swift
@main
struct MyApp: App {
    init() {
        setupDependencies()
    }

    private func setupDependencies() {
        // DiModuleFactory is automatically registered
        // ModuleFactoryManager is also automatically configured

        // Additional configuration if needed
        let factoryManager = WeaveDI.Container.live.resolve(ModuleFactoryManager.self)

        factoryManager?.diFactory.addDependency(CustomService.self) {
            CustomServiceImpl()
        }
    }
}
```

### Advanced Patterns

#### Conditional Dependency Registration

```swift
var factory = DiModuleFactory()

// Conditional registration based on feature flags
if FeatureFlags.isAnalyticsEnabled {
    factory.addDependency(AnalyticsService.self) {
        FirebaseAnalyticsService()
    }
} else {
    factory.addDependency(AnalyticsService.self) {
        NoOpAnalyticsService()
    }
}

// Platform-specific dependencies
#if os(iOS)
factory.addDependency(BiometricService.self) {
    iOSBiometricService()
}
#elseif os(macOS)
factory.addDependency(BiometricService.self) {
    MacBiometricService()
}
#endif
```

#### Dependency Chains

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

### Testing Support

Easy replacement with mock objects in test environments:

```swift
#if DEBUG
struct TestDiFactory {
    static func createMockFactory() -> DiModuleFactory {
        var factory = DiModuleFactory()

        factory.addDependency(Logger.self) {
            MockLogger()
        }

        factory.addDependency(NetworkClient.self) {
            MockNetworkClient()
        }

        factory.addDependency(AnalyticsService.self) {
            MockAnalyticsService()
        }

        return factory
    }
}

// Usage in tests
class SomeTestCase: XCTestCase {
    override func setUp() {
        super.setUp()

        var factoryManager = ModuleFactoryManager()
        factoryManager.diFactory = TestDiFactory.createMockFactory()

        await factoryManager.registerAll(to: WeaveDI.Container.live)
    }
}
#endif
```

### Best Practices

1. **Dependency Grouping**: Configure related dependencies together
2. **Environment Separation**: Use different implementations for development/staging/production environments
3. **Late Binding**: Register dependencies after configuration loading
4. **Type Safety**: Prevent incorrect type registration at compile time
5. **Test Isolation**: Manage test-specific dependencies separately

Through `DiModuleFactory`, you can systematically and type-safely manage your app's common dependencies while writing intuitive and readable code through the builder pattern.