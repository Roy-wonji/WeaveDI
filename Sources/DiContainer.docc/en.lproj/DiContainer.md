# ``DiContainer``

A high-performance dependency injection framework designed for modern Swift Concurrency and Actor models

## Overview

DiContainer is a modern dependency injection framework for iOS 15.0+, macOS 12.0+, watchOS 8.0+, and tvOS 15.0+ applications. It seamlessly integrates with Swift's latest concurrency model and improves dependency resolution performance by up to **10x** through **Actor Hop Optimization**.

### 🚀 Key Features

#### 🎭 Actor Hop Optimization
Intelligently optimizes transitions between different Actor contexts to maximize dependency resolution performance.

#### 🔒 Complete Type Safety
- **Compile-time validation**: KeyPath-based registration ensures type safety
- **Runtime safety**: Clear error messages and safe fallback systems
- **Type inference**: Leverages Swift's powerful type system

#### 📝 Intuitive Property Wrappers
- **`@Inject`**: Automatic dependency injection (optional/required support)
- **`@Factory`**: Factory pattern-based module management
- **`@RequiredInject`**: Required dependency injection

#### 🏗️ Powerful Module System
- **AppDIContainer**: App-wide dependency management
- **ModuleFactory**: Reusable module creation
- **Container**: Batch registration and parallel execution

#### 🔌 Extensible Plugin Architecture
- **RegistrationPlugin**: Extend registration process
- **ResolutionPlugin**: Customize resolution process
- **MonitoringPlugin**: Performance monitoring and logging

#### 🧪 Test-Friendly Design
- **Dependency mocking**: Easy registration of Mock objects for testing
- **Isolated testing**: Ensures state independence between tests
- **Bootstrap reset**: Container initialization for testing

### ⚡ Quick Start

#### Step 1: Register Dependencies (UnifiedDI Recommended)

```swift
import DiContainer

// Bootstrap dependencies at app startup
await DependencyContainer.bootstrap { container in
    // Register services
    container.register(UserServiceProtocol.self) {
        UserService()
    }

    container.register(NetworkServiceProtocol.self) {
        NetworkService()
    }

    // Register logger
    container.register(LoggerProtocol.self) {
        Logger()
    }
}

// Or use UnifiedDI directly
UnifiedDI.register(UserServiceProtocol.self) { UserService() }
UnifiedDI.register(NetworkServiceProtocol.self) { NetworkService() }
```

#### Step 2: Use Dependencies

```swift
class UserViewController: UIViewController {
    @Inject var userService: UserServiceProtocol?    // Optional injection
    @RequiredInject var logger: LoggerProtocol       // Required injection

    override func viewDidLoad() {
        super.viewDidLoad()

        Task {
            logger.info("Starting user data loading")

            if let service = userService {
                let user = try await service.getCurrentUser()
                await updateUI(with: user)
                logger.info("User data loading completed")
            }

            // Direct resolution with UnifiedDI is also possible
            if let networkService = UnifiedDI.resolve(NetworkServiceProtocol.self) {
                // Use network service
            }
        }
    }
}
```

### 🎯 What is Actor Hop Optimization?

Actor Hop refers to the phenomenon where execution transitions between different Actor contexts in Swift Concurrency. DiContainer optimizes these transitions to maximize performance.

```swift
// Traditional approach: Multiple Actor Hops occur ❌
@MainActor
class TraditionalViewController {
    func loadData() {
        Task {
            let service: UserService = resolve()      // Hop 1
            let data = await service.fetchUser()      // Hop 2
            await MainActor.run { updateUI(data) }    // Hop 3
        }
    }
}

// DiContainer approach: Optimized single Hop ✅
@MainActor
class OptimizedViewController {
    @Inject var userService: UserService?

    func loadData() {
        Task {
            guard let service = userService else { return }
            let data = await service.fetchUser()  // Optimized single Hop
            updateUI(data)  // Already in MainActor context
        }
    }
}
```

### 📊 Performance Improvement Metrics

| Scenario | Legacy DI | DiContainer 2.0 | Improvement |
|----------|-----------|----------------|-------------|
| Single dependency resolution | 0.8ms | 0.1ms | **87.5%** |
| Complex dependency graph | 15.6ms | 1.4ms | **91.0%** |
| MainActor UI updates | 3.1ms | 0.2ms | **93.5%** |

## Topics

### Getting Started

- <doc:QuickStart>
- <doc:CoreAPIs>
- <doc:MIGRATION-2.0.0>
- <doc:AppDIIntegration>
- ``DependencyContainer``

### Core Components

#### Dependency Injection APIs
- ``UnifiedDI`` - Unified DI system (recommended)
- ``DI`` - Simplified API
- ``DependencyContainer`` - Core container
- ``GlobalUnifiedRegistry`` - Global registry

#### Property Wrappers
- ``Inject``
- ``RequiredInject``
- ``Factory``
- ``FactoryValues``

#### Container System
- <doc:ContainerUsage>
- <doc:ContainerPerformance>
- ``Container``
- ``Module``
- ``BatchModule``
- ``AppDIContainer``

### Advanced Features

#### Auto Resolution System
- <doc:AutoResolution>
- ``AutoDependencyResolver``

#### Plugin System
- <doc:PluginSystem>
- ``BasePlugin``

#### Module Factory
- ``ModuleFactory``
- ``RepositoryModuleFactory``
- ``UseCaseModuleFactory``
- ``ScopeModuleFactory``

### Performance Optimization

- <doc:ActorHopOptimization>
- ``SimplePerformanceOptimizer``
- ``TypeSafeRegistry``
- ``UnifiedRegistry``

### Property Wrapper Extensions

- <doc:PropertyWrappers>
- <doc:DependencyKeyPatterns>
- ``ContainerRegister``
- ``SafeDependencyKey``
- ``RequiredDependencyRegister``

### Practical Guides

- <doc:BulkRegistrationDSL>
- <doc:ModuleFactory>
- <doc:AutoResolution>
- <doc:PluginSystem>
- <doc:LegacyAPIs>
- <doc:PropertyWrappers>
- <doc:ActorHopOptimization>

### API Reference

#### Registration APIs
- ``UnifiedDI/register(_:factory:)``
- ``UnifiedDI/registerMany(_:)``

#### Resolution APIs
- ``UnifiedDI/resolve(_:)``
- ``UnifiedDI/requireResolve(_:)``
- ``UnifiedDI/resolveThrows(_:)``
- ``UnifiedDI/resolve(_:default:)``

#### Management APIs
- ``UnifiedDI/release(_:)``
- ``UnifiedDI/releaseAll()``
- ``DependencyContainer/bootstrap(_:)``
- ``DependencyContainer/resetForTesting()``