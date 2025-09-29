# Dependency Key Patterns

Organize DependencyKey patterns for safe dependency resolution with WeaveDI's actual implementation.

## Overview

WeaveDI's dependency system is built around KeyPath-based registration and type-safe resolution. This guide covers the actual API patterns available in the framework, based on the real source code implementation.

## Core API Patterns

### 1. UnifiedDI Registration Pattern

The primary API for dependency registration and resolution:

```swift
import WeaveDI

// Basic registration with immediate return
let userService = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}

// KeyPath-based registration
let repository = UnifiedDI.register(\.userRepository) {
    UserRepositoryImpl()
}

// Async registration
let asyncService = await UnifiedDI.registerAsync(AsyncService.self) {
    await AsyncServiceImpl()
}
```

### 2. Safe Resolution Patterns

```swift
// Safe resolution (returns optional)
let service = UnifiedDI.resolve(UserService.self)

// Required resolution (fatalError on failure)
let requiredService = UnifiedDI.requireResolve(UserService.self)

// Resolution with default fallback
let serviceWithDefault = UnifiedDI.resolve(UserService.self, default: DefaultUserService())

// Async resolution
let asyncResult = await UnifiedDI.resolveAsync(AsyncService.self)
```

## Advanced Patterns

### 3. WeaveDI.Container Bootstrap Pattern

The actual bootstrap API from the source code:

```swift
// Synchronous bootstrap
await WeaveDI.Container.bootstrap { container in
    _ = container.register(UserService.self) { UserServiceImpl() }
    _ = container.register(DataRepository.self) { DataRepositoryImpl() }
}

// Asynchronous bootstrap
let success = await WeaveDI.Container.bootstrapAsync { container in
    let config = await RemoteConfig.fetch()
    _ = container.register(Configuration.self) { config }
}

// Mixed bootstrap (sync + async)
await WeaveDI.Container.bootstrapMixed(
    sync: { container in
        _ = container.register(Logger.self) { LoggerImpl() }
    },
    async: { container in
        let database = await Database.initialize()
        _ = container.register(Database.self) { database }
    }
)

// Conditional bootstrap
let wasNeeded = await WeaveDI.Container.bootstrapIfNeeded { container in
    _ = container.register(DevService.self) { DevServiceImpl() }
}
```

### 4. Property Wrapper Patterns

Based on the actual PropertyWrapper implementations:

```swift
class ViewController {
    // Optional injection (safe)
    @Inject var userService: UserService?

    // Required injection (crashes if not registered)
    @Inject var logger: Logger

    // KeyPath-based injection
    @Inject(\.dataRepository) var repository: DataRepository?

    // Factory pattern (new instance each time)
    @Factory var temporaryCache: TemporaryCache

    // Safe injection with error handling
    @SafeInject var riskService: RiskService

    func handleSafeInjection() {
        switch riskService {
        case .success(let service):
            service.doWork()
        case .failure(let error):
            print("Injection failed: \(error)")
        }

        // Or with throwing
        do {
            let service = try riskService.getValue()
            service.doWork()
        } catch {
            print("Failed to get service: \(error)")
        }
    }
}
```

### 5. SimpleKeyPathRegistry Pattern

For more control over registration:

```swift
// Basic KeyPath registration
SimpleKeyPathRegistry.register(\.userService) {
    UserServiceImpl()
}

// Conditional registration
SimpleKeyPathRegistry.registerIf(\.debugService, condition: isDebugMode) {
    DebugServiceImpl()
}

// Environment-specific registration
#if DEBUG
SimpleKeyPathRegistry.registerIfDebug(\.mockService) {
    MockServiceImpl()
}
#else
SimpleKeyPathRegistry.registerIfRelease(\.productionService) {
    ProductionServiceImpl()
}
#endif
```

### 6. SafeDependencyRegister Helpers

```swift
// Safe resolution with fallback
let service = SafeDependencyRegister.resolveWithFallback(\.userService) {
    DefaultUserService()
}

// Optional safe resolution
let optionalService = SafeDependencyRegister.safeResolve(\.optionalService)
```

## Module System Patterns

### 7. Module Registration

Based on the actual Module struct:

```swift
// Create and register a module
let userModule = Module(UserService.self) {
    UserServiceImpl()
}

await WeaveDI.Container.shared.register(userModule)

// Register with error handling
do {
    await userModule.registerThrowing()
} catch {
    print("Module registration failed: \(error)")
}
```

### 8. ModuleFactory Pattern

Using the real ModuleFactory protocol:

```swift
struct UserModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setup() {
        definitions.append {
            registerModule.makeModule(UserService.self) {
                UserServiceImpl()
            }
        }

        definitions.append {
            registerModule.makeUseCaseWithRepository(
                UserUseCase.self,
                repositoryProtocol: UserRepository.self,
                repositoryFallback: DefaultUserRepository(),
                factory: { repository in
                    UserUseCaseImpl(repository: repository)
                }
            )()
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}

// Usage
var factory = UserModuleFactory()
factory.setup()

let modules = factory.makeAllModules()
for module in modules {
    await module.register()
}
```

### 9. ModuleFactoryManager Pattern

```swift
let manager = ModuleFactoryManager(
    repositoryFactory: RepositoryModuleFactory(),
    useCaseFactory: UseCaseModuleFactory(),
    scopeFactory: ScopeModuleFactory()
)

await manager.registerAll()
```

## Scope Management Patterns

### 10. ScopeContext Usage

```swift
// Set current scope
ScopeContext.shared.setCurrent(.screen, id: "userProfile")

// Get current scope ID
let currentScreenID = ScopeContext.shared.currentID(for: .screen)

// Scope kinds available
let scopes: [ScopeKind] = [.singleton, .screen, .session, .request]
```

## Best Practices

### Type Safety

```swift
// ✅ Good: Use KeyPath for type safety
UnifiedDI.register(\.userService) { UserServiceImpl() }

// ✅ Good: Handle optional results
if let service = UnifiedDI.resolve(UserService.self) {
    service.performAction()
}

// ❌ Avoid: Force unwrapping
let service = UnifiedDI.resolve(UserService.self)! // Dangerous!
```

### Error Handling

```swift
// ✅ Good: Use SafeInject for error-prone dependencies
@SafeInject var networkService: NetworkService

func handleNetworkOperation() {
    do {
        let service = try networkService.getValue()
        await service.fetchData()
    } catch SafeInjectError.notRegistered {
        // Handle missing dependency
        showOfflineMode()
    } catch {
        // Handle other errors
        showError(error)
    }
}
```

### Performance Optimization

```swift
// Register expensive services as singletons
UnifiedDI.register(ExpensiveService.self) {
    ExpensiveServiceImpl() // Created once
}

// Use Factory for lightweight, stateless services
@Factory var dateFormatter: DateFormatter // New instance each time
```

### Testing Support

```swift
#if DEBUG
extension WeaveDI.Container {
    static func setupForTesting() async {
        await WeaveDI.Container.releaseAll() // Clear all dependencies

        await WeaveDI.Container.bootstrap { container in
            _ = container.register(UserService.self) { MockUserService() }
            _ = container.register(NetworkService.self) { MockNetworkService() }
        }
    }
}
#endif
```

## Migration from Other DI Frameworks

### From Swinject

```swift
// Before (Swinject)
container.register(UserServiceProtocol.self) { _ in
    UserServiceImpl()
}

// After (WeaveDI)
UnifiedDI.register(UserServiceProtocol.self) {
    UserServiceImpl()
}
```

### From Factory

```swift
// Before (Factory)
@Injected(\.userService) var userService: UserService

// After (WeaveDI)
@Inject(\.userService) var userService: UserService?
```

This comprehensive guide covers all the actual patterns available in WeaveDI based on the real source code implementation, ensuring accuracy and practical applicability.