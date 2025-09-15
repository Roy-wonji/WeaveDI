# ``DiContainer``

A modern, high-performance dependency injection framework designed for Swift Concurrency and Actor models.

## Overview

DiContainer is a modern dependency injection framework for iOS 15.0+, macOS 12.0+, watchOS 8.0+, and tvOS 15.0+ applications. It integrates perfectly with Swift's latest concurrency model and improves dependency resolution performance by up to **10x** through **Actor Hop Optimization**.

### 🚀 Key Features

- **Actor Hop Optimization**: Intelligently optimizes context switching between different Actors
- **Complete Type Safety**: Compile-time and runtime type verification
- **Intuitive Property Wrappers**: `@Inject`, `@Factory`, `@RequiredInject`
- **Powerful Module System**: Scalable and reusable module architecture
- **Extensible Plugin Architecture**: Customizable registration and resolution processes
- **Test-Friendly Design**: Easy mocking and isolated testing

## Quick Start

```swift
import DiContainer

// Bootstrap dependencies at app startup
await DependencyContainer.bootstrap { container in
    container.register(UserServiceProtocol.self) {
        UserService()
    }
}

// Use dependency injection
class UserViewController: UIViewController {
    @Inject var userService: UserServiceProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Service is automatically injected
    }
}
```

## Documentation Languages

- **한국어 (Korean)**: Complete documentation available in [ko.lproj](ko.lproj/)
- **English**: Documentation in progress

## Topics

### Getting Started

- <doc:ko.lproj/QuickStart>
- <doc:ko.lproj/CoreAPIs>
- <doc:ko.lproj/MIGRATION-2.0.0>

### Core Components

#### Dependency Injection API
- ``UnifiedDI`` - Unified DI System (Recommended)
- ``DI`` - Simplified API
- ``DependencyContainer`` - Core Container

#### Property Wrappers
- ``Inject``
- ``RequiredInject``
- ``Factory``
- ``FactoryValues``

#### Container System
- ``Container``
- ``Module``
- ``BatchModule``
- ``AppDIContainer``

### Advanced Features

#### Auto Resolution System
- <doc:ko.lproj/AutoResolution>
- ``AutoDependencyResolver``

#### Plugin System
- <doc:ko.lproj/PluginSystem>
- ``BasePlugin``

#### Module Factory
- ``ModuleFactory``
- ``RepositoryModuleFactory``
- ``UseCaseModuleFactory``

### Performance Optimization

- <doc:ko.lproj/ActorHop>
- ``SimplePerformanceOptimizer``
- ``TypeSafeRegistry``
- ``UnifiedRegistry``

### Property Wrapper Extensions

- <doc:ko.lproj/PropertyWrappers>
- ``ContainerRegister``
- ``SafeDependencyKey``

### Practical Guides

- <doc:ko.lproj/PracticalGuide>
- <doc:ko.lproj/BootstrapSystem>
- <doc:ko.lproj/ModuleSystem>
- <doc:ko.lproj/UnifiedDI>

### API Reference

#### Registration API
- ``UnifiedDI/register(_:factory:)``
- ``UnifiedDI/register(_:instance:)``

#### Resolution API
- ``UnifiedDI/resolve(_:)``
- ``UnifiedDI/requireResolve(_:)``
- ``UnifiedDI/resolveThrows(_:)``

#### Management API
- ``UnifiedDI/release(_:)``
- ``UnifiedDI/releaseAll()``
- ``DependencyContainer/bootstrap(_:)``