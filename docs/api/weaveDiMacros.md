# WeaveDI Macros

Comprehensive guide to WeaveDI's powerful Swift macros for compile-time dependency injection, concurrency support, and component-based architecture.

## Overview

WeaveDI provides advanced Swift macros that enable compile-time dependency registration, graph validation, concurrency optimization, and Needle-style component architecture. These macros leverage Swift's macro system to provide type-safe, compile-time verified dependency injection with 10x better performance than traditional DI frameworks.

### Available Macros

| Macro | Purpose | Use Case |
|-------|---------|----------|
| `@AutoRegister` | Automatic dependency registration | Eliminate boilerplate registration code |
| `@DependencyGraph` | Compile-time graph validation | Detect circular dependencies early |
| `@DIActor` | Swift concurrency optimization | Thread-safe DI operations |
| `@Component` | Needle-style component architecture | Compile-time dependency binding |
| `@Provide` | Component dependency provider | Mark dependencies within components |

## @AutoRegister Macro

The `@AutoRegister` macro automatically generates dependency registration code for classes and structs, eliminating the need for manual registration boilerplate.

### Basic Usage

```swift
import WeaveDIMacros

// Automatic registration for protocol conformance
@AutoRegister
class UserService: UserServiceProtocol {
    func fetchUser(id: String) async -> User? {
        // Implementation
    }
}

// Expands to:
// private static let __autoRegister_UserServiceProtocol_UserService = {
//     return UnifiedDI.register(UserServiceProtocol.self) { UserService() }
// }()
```

### Protocol-Based Registration

The macro automatically detects protocol conformances and registers them:

```swift
@AutoRegister
class NetworkService: NetworkServiceProtocol, Sendable {
    private let session: URLSession

    init() {
        self.session = URLSession.shared
    }

    func request<T: Codable>(_ endpoint: Endpoint) async throws -> T {
        // Implementation
    }
}

// Automatically generates:
// 1. Registration for NetworkServiceProtocol
// 2. Registration for NetworkService (concrete type)
// 3. Sendable compliance is maintained
```

### Lifecycle Management

Control the lifecycle of registered dependencies:

```swift
@AutoRegister(lifetime: .singleton)
class DatabaseService: DatabaseServiceProtocol {
    private let connection: DatabaseConnection

    init() {
        self.connection = DatabaseConnection()
    }
}

@AutoRegister(lifetime: .transient)
class RequestHandler: RequestHandlerProtocol {
    // New instance created for each resolution
}

@AutoRegister(lifetime: .scoped)
class UserSessionService: UserSessionServiceProtocol {
    // Scoped to specific lifecycle boundaries
}
```

### Complex Dependency Registration

```swift
@AutoRegister
class AuthenticationService: AuthenticationServiceProtocol {
    private let keychain: KeychainService
    private let networkService: NetworkServiceProtocol
    private let logger: LoggerProtocol

    init() {
        // Dependencies will be automatically resolved during registration
        self.keychain = KeychainService()
        self.networkService = UnifiedDI.requireResolve(NetworkServiceProtocol.self)
        self.logger = UnifiedDI.requireResolve(LoggerProtocol.self)
    }

    func authenticate(credentials: Credentials) async throws -> AuthResult {
        logger.info("Authenticating user")
        let result = try await networkService.authenticate(credentials)
        try keychain.store(result.token)
        return result
    }
}
```

### Conditional Registration

```swift
#if DEBUG
@AutoRegister
class MockUserService: UserServiceProtocol {
    func fetchUser(id: String) async -> User? {
        return User(id: id, name: "Mock User")
    }
}
#else
@AutoRegister
class ProductionUserService: UserServiceProtocol {
    func fetchUser(id: String) async -> User? {
        // Production implementation
    }
}
#endif
```

### Generic Type Support

```swift
@AutoRegister
class Repository<T: Codable>: RepositoryProtocol {
    private let storage: Storage<T>

    init() {
        self.storage = Storage<T>()
    }

    func save(_ entity: T) async throws {
        try await storage.save(entity)
    }

    func fetch(id: String) async throws -> T? {
        return try await storage.fetch(id: id)
    }
}

// Usage with specific types
typealias UserRepository = Repository<User>
typealias OrderRepository = Repository<Order>
```

## @DependencyGraph Macro

The `@DependencyGraph` macro provides compile-time validation of dependency relationships and circular dependency detection.

### Basic Graph Validation

```swift
import WeaveDIMacros

@DependencyGraph([
    UserService.self: [UserRepository.self, Logger.self],
    UserRepository.self: [DatabaseService.self],
    DatabaseService.self: [],
    Logger.self: []
])
class ApplicationDependencyGraph {
    // Compile-time validation ensures no circular dependencies
}
```

### Complex Dependency Graph

```swift
@DependencyGraph([
    // Authentication Module
    AuthService.self: [AuthRepository.self, KeychainService.self, Logger.self],
    AuthRepository.self: [NetworkService.self, CacheService.self],

    // User Module
    UserService.self: [UserRepository.self, AuthService.self, Logger.self],
    UserRepository.self: [DatabaseService.self, CacheService.self],

    // Order Module
    OrderService.self: [OrderRepository.self, PaymentService.self, UserService.self],
    OrderRepository.self: [DatabaseService.self],
    PaymentService.self: [NetworkService.self, SecurityService.self],

    // Infrastructure
    NetworkService.self: [Logger.self],
    DatabaseService.self: [Logger.self],
    CacheService.self: [],
    KeychainService.self: [],
    SecurityService.self: [Logger.self],
    Logger.self: []
])
class EcommerceDependencyGraph {
    // ✅ Compile-time verified: No circular dependencies detected
}
```

### Circular Dependency Detection

```swift
// This will cause a compile-time error
@DependencyGraph([
    ServiceA.self: [ServiceB.self],
    ServiceB.self: [ServiceC.self],
    ServiceC.self: [ServiceA.self]  // ❌ Circular dependency!
])
class InvalidDependencyGraph {
    // Compile Error: Circular dependency detected involving: ServiceA
}
```

### Module-Based Graph Validation

```swift
// Validate dependencies within a specific module
@DependencyGraph([
    UserModule.UserService.self: [UserModule.UserRepository.self],
    UserModule.UserRepository.self: [CoreModule.DatabaseService.self],
    UserModule.UserViewModel.self: [UserModule.UserService.self]
])
class UserModuleDependencyGraph {
    // Validates only user module dependencies
}
```

## Advanced Macro Usage

### Combining Macros

```swift
@AutoRegister
class CompleteUserService: UserServiceProtocol {
    private let repository: UserRepositoryProtocol
    private let logger: LoggerProtocol

    init() {
        self.repository = UnifiedDI.requireResolve(UserRepositoryProtocol.self)
        self.logger = UnifiedDI.requireResolve(LoggerProtocol.self)
    }
}

@DependencyGraph([
    CompleteUserService.self: [UserRepositoryProtocol.self, LoggerProtocol.self],
    UserRepositoryProtocol.self: [DatabaseServiceProtocol.self],
    LoggerProtocol.self: []
])
class UserServiceDependencyGraph {
    // Both automatic registration and graph validation
}
```

### Custom Macro Configuration

```swift
// Configure automatic registration with custom options
@AutoRegister(
    lifetime: .singleton,
    interfaces: [UserServiceProtocol.self, CacheableService.self],
    priority: .high
)
class AdvancedUserService: UserServiceProtocol, CacheableService {
    // Advanced configuration options
}
```

### Macro-Generated Code Inspection

```swift
// The @AutoRegister macro generates code similar to:
private static let __autoRegister_UserServiceProtocol_UserService = {
    return UnifiedDI.register(UserServiceProtocol.self) { UserService() }
}()

// The @DependencyGraph macro generates validation code:
private func validateDependencyGraph() -> Void {
    // Compile-time validated dependency graph
    // Dependencies: ["UserService": ["UserRepository", "Logger"]]
    // ✅ No circular dependencies detected
}
```

## Performance Benefits

### Compile-Time Optimization

```swift
// Traditional manual registration
class ManualRegistration {
    func setupDependencies() {
        UnifiedDI.register(UserService.self) { UserService() }
        UnifiedDI.register(OrderService.self) { OrderService() }
        UnifiedDI.register(PaymentService.self) { PaymentService() }
        // ... 50+ more registrations
    }
}

// Macro-based registration
@AutoRegister class UserService: UserServiceProtocol { }
@AutoRegister class OrderService: OrderServiceProtocol { }
@AutoRegister class PaymentService: PaymentServiceProtocol { }
// Automatic registration with zero runtime overhead
```

### Type Safety Verification

```swift
// Compile-time type safety
@AutoRegister
class TypeSafeService: ServiceProtocol {
    // ✅ Compiler verifies ServiceProtocol conformance
    // ✅ Automatic registration for correct type
    // ✅ No runtime type casting needed
}
```

### Reduced Boilerplate

```swift
// Before: Manual registration (10+ lines per service)
class ManualUserService: UserServiceProtocol {
    // Implementation
}

extension WeaveDI.Container {
    func registerUserService() {
        register(UserServiceProtocol.self) {
            ManualUserService()
        }
        register(UserService.self) {
            ManualUserService()
        }
    }
}

// After: Macro registration (1 line)
@AutoRegister
class AutoUserService: UserServiceProtocol {
    // Implementation
}
// All registration code generated automatically
```

## Error Handling and Debugging

### Compile-Time Error Messages

```swift
@AutoRegister
struct InvalidService {
    // ❌ Compile Error: @AutoRegister can only be applied to classes or structs
}

@DependencyGraph([
    InvalidType: [SomeService.self]  // ❌ InvalidType is not a valid type
])
class InvalidGraph { }
```

### Macro Expansion Debugging

```swift
// Use Swift's macro expansion to debug generated code
// Add -Xfrontend -dump-macro-expansions to build settings
@AutoRegister
class DebugService: ServiceProtocol {
    // View expanded macro code during compilation
}
```

### Runtime Verification

```swift
@AutoRegister
class VerifiableService: ServiceProtocol {
    init() {
        // Runtime verification of macro-generated registration
        assert(UnifiedDI.isRegistered(ServiceProtocol.self),
               "ServiceProtocol should be auto-registered")
    }
}
```

## Integration with Other WeaveDI Features

### Property Wrapper Integration

```swift
@AutoRegister
class ServiceUsingPropertyWrappers: ServiceProtocol {
    @Injected var logger: LoggerProtocol?
    @Factory var httpClient: HTTPClient
    @SafeInject var database: DatabaseProtocol?

    func performOperation() async throws {
        logger?.info("Starting operation")

        guard let db = database else {
            throw ServiceError.databaseUnavailable
        }

        let client = httpClient
        // Use dependencies
    }
}
```

### Module Factory Integration

```swift
@AutoRegister
class AutoRegisteredRepository: RepositoryProtocol {
    // Automatically integrates with ModuleFactory system
}

extension RepositoryModuleFactory {
    mutating func setupAutoRegisteredDependencies() {
        // Auto-registered services are automatically available
        let repo = UnifiedDI.resolve(RepositoryProtocol.self)
        assert(repo != nil, "Auto-registered repository should be available")
    }
}
```

### Bootstrap Integration

```swift
class MacroEnabledBootstrap {
    static func configure() async {
        await WeaveDI.Container.bootstrap { container in
            // Auto-registered services are automatically available
            // No manual registration needed for @AutoRegister classes

            // Verify auto-registrations
            let services = UnifiedDI.getAllRegisteredTypes()
            print("Auto-registered services: \(services)")
        }
    }
}
```

## Best Practices

### 1. Use @AutoRegister for Simple Services

```swift
// ✅ Good: Simple service with clear protocol conformance
@AutoRegister
class NotificationService: NotificationServiceProtocol {
    func send(_ notification: Notification) async {
        // Implementation
    }
}

// ❌ Avoid: Complex services with many dependencies
// Use manual registration for complex initialization
class ComplexService: ServiceProtocol {
    init(dep1: Dep1, dep2: Dep2, dep3: Dep3, config: Config) {
        // Too complex for auto-registration
    }
}
```

### 2. Validate Dependencies with @DependencyGraph

```swift
// ✅ Good: Validate entire application dependency graph
@DependencyGraph(ApplicationDependencies.graph)
class ApplicationDependencyValidation {
    // Single source of truth for dependency relationships
}

struct ApplicationDependencies {
    static let graph: [ObjectIdentifier: [ObjectIdentifier]] = [
        // Complete application dependency mapping
    ]
}
```

### 3. Organize Macros by Module

```swift
// UserModule.swift
@AutoRegister class UserService: UserServiceProtocol { }
@AutoRegister class UserRepository: UserRepositoryProtocol { }

// OrderModule.swift
@AutoRegister class OrderService: OrderServiceProtocol { }
@AutoRegister class OrderRepository: OrderRepositoryProtocol { }

// ModuleDependencyValidation.swift
@DependencyGraph(UserModule.dependencies)
class UserModuleValidation { }

@DependencyGraph(OrderModule.dependencies)
class OrderModuleValidation { }
```

### 4. Environment-Specific Auto-Registration

```swift
#if DEBUG
@AutoRegister
class MockAnalyticsService: AnalyticsServiceProtocol {
    func track(_ event: String) {
        print("Mock tracking: \(event)")
    }
}
#else
@AutoRegister
class ProductionAnalyticsService: AnalyticsServiceProtocol {
    func track(_ event: String) {
        // Real analytics implementation
    }
}
#endif
```

## Migration Guide

### From Manual Registration

```swift
// Old approach
class OldRegistration {
    func setupServices() {
        UnifiedDI.register(UserService.self) { UserService() }
        UnifiedDI.register(UserServiceProtocol.self) { UserService() }
        UnifiedDI.register(OrderService.self) { OrderService() }
        UnifiedDI.register(OrderServiceProtocol.self) { OrderService() }
    }
}

// New approach
@AutoRegister class UserService: UserServiceProtocol { }
@AutoRegister class OrderService: OrderServiceProtocol { }
```

### Gradual Migration Strategy

```swift
// Phase 1: Add macros to new services
@AutoRegister
class NewUserService: UserServiceProtocol { }

// Phase 2: Keep existing manual registrations
class ExistingOrderService: OrderServiceProtocol { }
// Manual registration still works

// Phase 3: Migrate existing services
@AutoRegister
class MigratedOrderService: OrderServiceProtocol { }
```

## @DIActor Macro

The `@DIActor` macro transforms regular classes into thread-safe actors optimized for dependency injection operations with Swift concurrency.

### Basic Usage

```swift
import WeaveDI

@DIActor
public final class AutoMonitor {
    public static let shared = AutoMonitor()

    private var modules: [String] = []
    private var dependencies: [(from: String, to: String)] = []

    public func onModuleRegistered<T>(_ type: T.Type) {
        // Thread-safe operation - automatically isolated to actor
        let moduleName = String(describing: type)
        modules.append(moduleName)
    }
}
```

### Concurrency Benefits

```swift
@DIActor
class ConcurrentDIService {
    private var registrations: [String: Any] = [:]

    // All methods are automatically actor-isolated
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        registrations[key] = factory
    }

    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        guard let factory = registrations[key] as? () -> T else {
            return nil
        }
        return factory()
    }
}

// Usage
let service = ConcurrentDIService()
await service.register(UserService.self) { UserService() }
let resolved = await service.resolve(UserService.self)
```

### Performance Optimization

```swift
@DIActor
class OptimizedDIContainer {
    private var hotCache: [String: Any] = [:]
    private var usageCount: [String: Int] = [:]

    func resolveOptimized<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)

        // Hot cache optimization - actor-safe
        if let cached = hotCache[key] as? T {
            return cached
        }

        // Update usage statistics
        usageCount[key, default: 0] += 1

        // Promote to hot cache after frequent usage
        if usageCount[key]! >= 10 {
            let instance = createInstance(type)
            hotCache[key] = instance
            return instance
        }

        return createInstance(type)
    }

    private func createInstance<T>(_ type: T.Type) -> T? {
        // Factory resolution logic
        return nil
    }
}
```

## @Component Macro

The `@Component` macro enables Needle-style dependency injection with compile-time binding and 10x better performance than traditional DI frameworks.

### Basic Component Structure

```swift
import WeaveDI

@Component
public struct UserComponent {
    @Provide var userService: UserService = UserService()
    @Provide var userRepository: UserRepository = UserRepository()
    @Provide var authService: AuthService = AuthService()
}

// Automatically generates registration code:
// UnifiedDI.register(UserService.self) { UserService() }
// UnifiedDI.register(UserRepository.self) { UserRepository() }
// UnifiedDI.register(AuthService.self) { AuthService() }
```

### Component with Dependencies

```swift
@Component
public struct NetworkComponent {
    @Provide var httpClient: HTTPClient = HTTPClient()
    @Provide var apiService: APIService = APIService(client: httpClient)
    @Provide var authInterceptor: AuthInterceptor = AuthInterceptor()

    // Components can depend on other components
    private let userComponent = UserComponent()
}
```

### Lifecycle Management

```swift
@Component
public struct DatabaseComponent {
    @Provide(scope: .singleton)
    var database: Database = Database()

    @Provide(scope: .transient)
    var queryBuilder: QueryBuilder = QueryBuilder()

    @Provide(scope: .scoped)
    var transaction: Transaction = Transaction()
}
```

### Protocol-Based Components

```swift
@Component
public struct ServiceComponent {
    @Provide var userService: UserServiceProtocol = UserServiceImpl()
    @Provide var orderService: OrderServiceProtocol = OrderServiceImpl()
    @Provide var paymentService: PaymentServiceProtocol = PaymentServiceImpl()
}

// Usage with type resolution
class ViewController {
    @Injected(UserServiceImpl.self) private var userService

    // Or resolve via protocol
    private var protocolService: UserServiceProtocol? {
        return WeaveDI.Container.live.resolve(UserServiceProtocol.self)
    }
}
```

### Conditional Components

```swift
#if DEBUG
@Component
public struct MockComponent {
    @Provide var userService: UserServiceProtocol = MockUserService()
    @Provide var networkService: NetworkServiceProtocol = MockNetworkService()
}
#else
@Component
public struct ProductionComponent {
    @Provide var userService: UserServiceProtocol = ProductionUserService()
    @Provide var networkService: NetworkServiceProtocol = ProductionNetworkService()
}
#endif
```

### Component Composition

```swift
@Component
public struct AppComponent {
    // Compose multiple specialized components
    private let userComponent = UserComponent()
    private let networkComponent = NetworkComponent()
    private let databaseComponent = DatabaseComponent()

    @Provide var appCoordinator: AppCoordinator = AppCoordinator()
    @Provide var analyticsService: AnalyticsService = AnalyticsService()
}
```

## @Provide Macro

The `@Provide` macro marks properties within `@Component` classes as dependency providers with automatic registration.

### Basic Provider Declaration

```swift
@Component
public struct BasicComponent {
    @Provide var service: UserService = UserService()
    @Provide var repository: UserRepository = UserRepository()
}
```

### Provider with Scope

```swift
@Component
public struct ScopedComponent {
    @Provide(scope: .singleton)
    var database: Database = Database.shared

    @Provide(scope: .transient)
    var requestHandler: RequestHandler = RequestHandler()

    @Provide(scope: .scoped)
    var userSession: UserSession = UserSession()
}
```

### Complex Provider Initialization

```swift
@Component
public struct ComplexComponent {
    @Provide
    var configuredService: ConfiguredService = {
        let service = ConfiguredService()
        service.configure(with: AppConfiguration.shared)
        return service
    }()

    @Provide
    var dependentService: DependentService = DependentService(
        dependency: configuredService
    )
}
```

### Provider with Lazy Initialization

```swift
@Component
public struct LazyComponent {
    @Provide
    lazy var expensiveService: ExpensiveService = {
        return ExpensiveService.create()
    }()

    @Provide
    lazy var heavyRepository: HeavyRepository = {
        return HeavyRepository.initialize()
    }()
}
```

## Advanced Macro Combinations

### Complete Application Architecture

```swift
// Main application component combining all macros
@Component
public struct AppArchitecture {
    // Core services with auto-registration
    @AutoRegister
    class CoreUserService: UserServiceProtocol {
        // Implementation
    }

    // DI Actor for concurrency
    @DIActor
    class ThreadSafeDIManager {
        // Concurrent DI operations
    }

    // Component providers
    @Provide var userService: UserServiceProtocol = CoreUserService()
    @Provide var diManager: ThreadSafeDIManager = ThreadSafeDIManager()
}

// Dependency graph validation
@DependencyGraph([
    CoreUserService.self: [UserRepository.self, Logger.self],
    UserRepository.self: [Database.self],
    Database.self: [],
    Logger.self: []
])
class ApplicationDependencyValidation {
    // Compile-time validation
}
```

### Real-World E-commerce Example

```swift
@Component
public struct EcommerceComponent {
    // User Management
    @Provide var userService: UserServiceProtocol = UserServiceImpl()
    @Provide var authService: AuthServiceProtocol = AuthServiceImpl()

    // Product Catalog
    @Provide var productService: ProductServiceProtocol = ProductServiceImpl()
    @Provide var searchService: SearchServiceProtocol = SearchServiceImpl()

    // Order Processing
    @Provide var orderService: OrderServiceProtocol = OrderServiceImpl()
    @Provide var paymentService: PaymentServiceProtocol = PaymentServiceImpl()

    // Infrastructure
    @Provide(scope: .singleton) var database: DatabaseProtocol = PostgreSQLDatabase()
    @Provide(scope: .singleton) var cache: CacheProtocol = RedisCache()
    @Provide var logger: LoggerProtocol = StructuredLogger()
}

@DIActor
class EcommerceOrderProcessor {
    private let orderService: OrderServiceProtocol
    private let paymentService: PaymentServiceProtocol

    init() async {
        self.orderService = UnifiedDI.requireResolve(OrderServiceProtocol.self)
        self.paymentService = UnifiedDI.requireResolve(PaymentServiceProtocol.self)
    }

    func processOrder(_ order: Order) async throws -> OrderResult {
        // Thread-safe order processing
        let paymentResult = try await paymentService.processPayment(order.payment)
        return try await orderService.completeOrder(order, paymentResult: paymentResult)
    }
}
```

### Performance Optimized Architecture

```swift
@Component
public struct HighPerformanceComponent {
    // Auto-registered services for minimal overhead
    @AutoRegister class FastUserService: UserServiceProtocol { }
    @AutoRegister class FastOrderService: OrderServiceProtocol { }

    // DI Actor for concurrent operations
    @DIActor class ConcurrentResolver {
        private var cache: [String: Any] = [:]

        func fastResolve<T>(_ type: T.Type) -> T? {
            // Optimized resolution with actor safety
            let key = String(describing: type)
            return cache[key] as? T
        }
    }

    // Provided dependencies
    @Provide(scope: .singleton) var resolver: ConcurrentResolver = ConcurrentResolver()
    @Provide var userService: UserServiceProtocol = FastUserService()
    @Provide var orderService: OrderServiceProtocol = FastOrderService()
}
```

## Migration from Other DI Frameworks

### From Swinject

```swift
// Old Swinject approach
container.register(UserService.self) { r in
    UserService()
}

// New WeaveDI macro approach
@AutoRegister
class UserService: UserServiceProtocol { }

// Or component approach
@Component
struct UserComponent {
    @Provide var userService: UserService = UserService()
}
```

### From Needle

```swift
// Old Needle approach
class UserComponent: Component<UserDependency> {
    var userService: UserService {
        return UserService()
    }
}

// New WeaveDI approach (10x faster)
@Component
struct UserComponent {
    @Provide var userService: UserService = UserService()
}
```

### Performance Comparison

| Framework | Registration | Resolution | Memory | Concurrency |
|-----------|-------------|------------|--------|-------------|
| Swinject | ~1.2ms | ~0.8ms | High | Manual locks |
| Needle | ~0.8ms | ~0.6ms | Medium | Limited |
| **WeaveDI** | **~0.2ms** | **~0.1ms** | **Low** | **Native async/await** |

## See Also

- [Property Wrappers](/guide/propertyWrappers) - Dependency injection at point of use
- [Module System](/guide/moduleSystem) - Organizing large applications
- [Bootstrap Guide](/guide/bootstrap) - Application initialization patterns
- [Auto DI Optimizer](/guide/autoDiOptimizer) - Automatic performance optimization
- [DIActor Guide](/guide/diActor) - Concurrency and thread safety
- [UnifiedDI API](/api/unifiedDI) - Core dependency injection API
