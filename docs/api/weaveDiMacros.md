# WeaveDI Macros

Comprehensive guide to WeaveDI's powerful Swift macros for compile-time dependency injection and graph validation.

## Overview

WeaveDI provides advanced Swift macros that enable compile-time dependency registration, graph validation, and automatic optimization. These macros leverage Swift's macro system to provide type-safe, compile-time verified dependency injection.

### Available Macros

| Macro | Purpose | Use Case |
|-------|---------|----------|
| `@AutoRegister` | Automatic dependency registration | Eliminate boilerplate registration code |
| `@DependencyGraph` | Compile-time graph validation | Detect circular dependencies early |

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

## See Also

- [Property Wrappers](/guide/propertyWrappers) - Dependency injection at point of use
- [Module System](/guide/moduleSystem) - Organizing large applications
- [Bootstrap Guide](/guide/bootstrap) - Application initialization patterns
- [Auto DI Optimizer](/guide/autoDiOptimizer) - Automatic performance optimization
