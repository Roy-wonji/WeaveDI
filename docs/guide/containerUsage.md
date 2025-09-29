# Container Usage

WeaveDI's Container system provides efficient module-based dependency registration with optimized parallel processing. It collects modules and registers them in parallel to minimize Actor hops and improve performance in Swift 6 concurrent environments.

## Overview

The Container system is built on modular architecture where each `Module` represents a discrete unit of dependency registration work. This approach provides several advantages over traditional dependency injection patterns:

**Key Concepts**:
- **Module**: The minimum unit of registration work containing one or more related dependencies
- **Collection Phase**: Gather modules using `Container.register(_:)` without immediate registration
- **Parallel Building**: Register all collected modules simultaneously with `build()` for optimal performance
- **Actor Optimization**: Minimizes Actor hops in Swift's concurrent environment

**Performance Benefits**:
- **Parallel Processing**: Multiple modules are registered concurrently rather than sequentially
- **Actor Efficiency**: Reduces context switching between actors for better performance
- **Memory Optimization**: Efficient memory usage through batched registration
- **Startup Speed**: Faster application startup through optimized dependency resolution

## Basic Usage

The fundamental Container pattern involves creating modules, collecting them in a container, and building them in parallel.

**Purpose**: Create and register multiple related dependencies efficiently using the modular approach.

**How it works**:
- **Module Creation**: Each dependency is wrapped in a Module with its factory closure
- **Collection**: Modules are added to the container without immediate registration
- **Parallel Build**: All modules are registered simultaneously for optimal performance

```swift
// Create individual modules for each dependency
let repoModule = Module(RepositoryProtocol.self) {
    DefaultRepository()
}

let useCaseModule = Module(UseCaseProtocol.self) {
    DefaultUseCase(repo: DefaultRepository())
}

// Create container and collect modules
let container = Container()
container.register(repoModule)      // Collected, not yet registered
container.register(useCaseModule)   // Collected, not yet registered

// Build all modules in parallel - this is where actual registration happens
await container.build()
```

**What happens during `build()`**:
1. **Parallel Execution**: All collected modules are processed concurrently
2. **Dependency Resolution**: Factory closures are executed to create instances
3. **Registration**: Dependencies are registered in the global DI container
4. **Optimization**: Actor hops are minimized through batched operations

**Best Practices**:
- Group related dependencies into modules
- Use descriptive module names for better debugging
- Always call `build()` after collecting all modules
- Prefer this pattern for complex applications with many dependencies

## Usage with Factories

Module factories provide a scalable way to generate multiple related modules programmatically, perfect for large applications with complex dependency hierarchies.

**Purpose**: Generate and register large sets of related modules efficiently using factory patterns.

**Benefits of Factory Pattern**:
- **Scalability**: Handle hundreds of dependencies without manual registration
- **Organization**: Group related modules by domain or layer
- **Consistency**: Ensure consistent module creation patterns
- **Maintainability**: Centralize module creation logic

```swift
let container = Container()

// Create specialized factories for different domains
let repositoryFactory = RepositoryModuleFactory()
let useCaseFactory = UseCaseModuleFactory()

// Generate all repository modules and register them
await repositoryFactory.makeAllModules().asyncForEach { module in
    await container.register(module)
}

// Generate all use case modules and register them
await useCaseFactory.makeAllModules().asyncForEach { module in
    await container.register(module)
}

// Build all collected modules in parallel
await container.build()
```

**Example Factory Implementation**:

```swift
class RepositoryModuleFactory {
    func makeAllModules() async -> [Module] {
        return [
            Module(UserRepositoryProtocol.self) { UserRepositoryImpl() },
            Module(ProductRepositoryProtocol.self) { ProductRepositoryImpl() },
            Module(OrderRepositoryProtocol.self) { OrderRepositoryImpl() },
            // ... potentially hundreds more
        ]
    }
}

class UseCaseModuleFactory {
    func makeAllModules() async -> [Module] {
        return [
            Module(UserUseCaseProtocol.self) {
                UserUseCaseImpl(repository: UnifiedDI.resolve(UserRepositoryProtocol.self)!)
            },
            Module(ProductUseCaseProtocol.self) {
                ProductUseCaseImpl(repository: UnifiedDI.resolve(ProductRepositoryProtocol.self)!)
            },
            // ... more use cases with their dependencies
        ]
    }
}
```

**Advanced Factory Patterns**:

```swift
// Factory with conditional module creation
class PlatformSpecificFactory {
    func makeAllModules() async -> [Module] {
        var modules: [Module] = []

        // Core modules for all platforms
        modules.append(Module(LoggerProtocol.self) { ConsoleLogger() })

        // Platform-specific modules
        #if os(iOS)
        modules.append(Module(LocationServiceProtocol.self) { CoreLocationService() })
        #elseif os(macOS)
        modules.append(Module(LocationServiceProtocol.self) { MacOSLocationService() })
        #endif

        return modules
    }
}

// Factory with dynamic module generation
class DatabaseFactory {
    let configurations: [DatabaseConfig]

    func makeAllModules() async -> [Module] {
        return configurations.map { config in
            Module(DatabaseProtocol.self, identifier: config.name) {
                DatabaseImpl(config: config)
            }
        }
    }
}
```

## Conditional Registration

Conditional registration allows you to dynamically choose which modules to register based on runtime conditions, build configurations, or feature flags.

**Purpose**: Register different sets of dependencies based on environment, configuration, or runtime conditions.

**Common Use Cases**:
- **Debug vs Release**: Different implementations for development and production
- **Feature Flags**: Enable/disable features based on remote configuration
- **Environment-Specific**: Different services for different deployment environments
- **A/B Testing**: Different implementations for testing purposes

```swift
let container = Container()

// Environment-based conditional registration
#if DEBUG
container.register(debugModule)        // Mock services for development
container.register(loggingModule)      // Verbose logging for debugging
#else
container.register(prodModule)         // Production implementations
container.register(analyticsModule)    // Analytics only in production
#endif

await container.build()
```

**Advanced Conditional Examples**:

```swift
let container = Container()

// Feature flag based registration
if FeatureFlags.isNewPaymentSystemEnabled {
    container.register(Module(PaymentServiceProtocol.self) {
        NewPaymentService()
    })
} else {
    container.register(Module(PaymentServiceProtocol.self) {
        LegacyPaymentService()
    })
}

// Environment-specific registration
switch AppEnvironment.current {
case .development:
    container.register(Module(APIClientProtocol.self) {
        MockAPIClient()
    })

case .staging:
    container.register(Module(APIClientProtocol.self) {
        StagingAPIClient()
    })

case .production:
    container.register(Module(APIClientProtocol.self) {
        ProductionAPIClient()
    })
}

// Device-specific registration
if UIDevice.current.userInterfaceIdiom == .pad {
    container.register(Module(LayoutServiceProtocol.self) {
        iPadLayoutService()
    })
} else {
    container.register(Module(LayoutServiceProtocol.self) {
        iPhoneLayoutService()
    })
}

await container.build()
```

## Performance Optimization

Container usage provides several optimization opportunities that can significantly improve application startup time and memory usage.

**Optimization Strategies**:

### 1. Batch Registration
```swift
// ✅ Efficient: Batch all modules and build once
let container = Container()
container.register(moduleA)
container.register(moduleB)
container.register(moduleC)
await container.build() // Single parallel operation

// ❌ Inefficient: Individual registration
await WeaveDI.Container.bootstrap { container in
    container.register(TypeA.self) { /* ... */ }
    container.register(TypeB.self) { /* ... */ }
    // Each registration is separate
}
```

### 2. Lazy Module Creation
```swift
// Create modules only when needed
class LazyModuleFactory {
    private var _modules: [Module]?

    func makeAllModules() async -> [Module] {
        if _modules == nil {
            _modules = await createExpensiveModules()
        }
        return _modules!
    }

    private func createExpensiveModules() async -> [Module] {
        // Expensive module creation logic
        return [/* modules */]
    }
}
```

### 3. Memory Management
```swift
let container = Container()

// Register modules
await factory.makeAllModules().asyncForEach { module in
    await container.register(module)
}

// Build and then clear container to free memory
await container.build()
container.clear() // Free collected modules from memory
```

## Error Handling

Proper error handling in container usage ensures robust application startup and clear debugging information.

```swift
func setupDependencies() async throws {
    let container = Container()

    do {
        // Collect modules with potential failures
        let repositoryModules = try await RepositoryFactory().makeAllModules()
        let useCaseModules = try await UseCaseFactory().makeAllModules()

        // Register all modules
        repositoryModules.forEach { container.register($0) }
        useCaseModules.forEach { container.register($0) }

        // Build with error handling
        try await container.build()

        print("✅ All dependencies registered successfully")

    } catch let error as ModuleCreationError {
        print("❌ Module creation failed: \(error.localizedDescription)")
        throw error

    } catch let error as DependencyResolutionError {
        print("❌ Dependency resolution failed: \(error.localizedDescription)")
        throw error

    } catch {
        print("❌ Unexpected error during container setup: \(error)")
        throw error
    }
}
```

## Best Practices

### 1. Module Organization
```swift
// ✅ Group related modules by domain
let userModules = UserModuleFactory().makeAllModules()
let paymentModules = PaymentModuleFactory().makeAllModules()
let analyticsModules = AnalyticsModuleFactory().makeAllModules()

// ✅ Clear module naming
let coreModule = Module(LoggerProtocol.self, name: "CoreLogger") { ConsoleLogger() }
let networkModule = Module(HTTPClientProtocol.self, name: "NetworkClient") { URLSessionClient() }
```

### 2. Dependency Order
```swift
let container = Container()

// Register in logical dependency order (infrastructure first)
container.register(loggerModule)      // No dependencies
container.register(networkModule)     // Might need logger
container.register(repositoryModule)  // Needs network
container.register(useCaseModule)     // Needs repository

await container.build()
```

### 3. Resource Management
```swift
func setupApplication() async {
    let container = Container()

    // Setup
    await populateContainer(container)
    await container.build()

    // Cleanup
    container.clear() // Free memory after build
}
```

## See Also

- [Module System](./moduleSystem.md) - Detailed module creation and management
- [Module Factory](./moduleFactory.md) - Advanced factory patterns
- [Bootstrap Guide](./bootstrap.md) - Alternative registration approaches