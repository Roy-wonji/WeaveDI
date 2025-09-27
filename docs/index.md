---
layout: home

hero:
  name: "WeaveDI"
  text: "Modern Dependency Injection for Swift"
  tagline: Next-generation Swift DI framework - Superior to Needle & Swinject with Actor optimization
  image:
    src: /logo.svg
    alt: WeaveDI
  actions:
    - theme: brand
      text: Get Started
      link: /guide/quick-start
    - theme: alt
      text: View on GitHub
      link: https://github.com/Roy-wonji/WeaveDI

features:
  - icon: 🚀
    title: Runtime Hot-Path Optimization (v3.2.0)
    details: 50-80% performance improvement with TypeID + lock-free reads. Dictionary → Array slot for O(1) access, snapshot approach eliminates read contention.
  - icon: 🎭
    title: Actor Hop Optimization
    details: Intelligently optimizes transitions between different Actor contexts to maximize dependency resolution performance. Reduces MainActor UI updates by 81%.
  - icon: 🔒
    title: Complete Type Safety
    details: Compile-time verification through KeyPath-based registration, runtime safety with clear error messages, and leveraging Swift's powerful type system.
  - icon: 📝
    title: Intuitive Property Wrappers
    details: "@Inject (automatic dependency injection), @Factory (factory pattern-based module management), @SafeInject (safe dependency injection with error handling)."
  - icon: 🏗️
    title: Powerful Module System
    details: AppDIContainer for app-wide dependency management, ModuleFactory for reusable module creation, Container for batch registration and parallel execution.
  - icon: 🧪
    title: Test-Friendly Design
    details: Easy registration of Mock objects for testing, independence between test states guaranteed, bootstrap reset for test container initialization.
---

## Quick Start Guide

### Step 1: Dependency Registration (UnifiedDI Recommended)

```swift
import WeaveDI

// Bootstrap dependencies at app startup
await DependencyContainer.bootstrap { container in
    // Register services
    container.register(UserServiceProtocol.self) {
        UserService()
    }

    // Register repositories with KeyPath
    container.register(\.userRepository) {
        UserRepositoryImpl()
    }
}
```

### Step 2: Property Wrapper Injection

```swift
class ViewController {
    @Inject var userService: UserServiceProtocol?
    @Factory var dataProcessor: DataProcessor
    @SafeInject var analyticsService: AnalyticsServiceProtocol?

    func loadUserData() async {
        guard let service = userService else { return }
        let userData = await service.fetchUser()
        updateUI(with: userData)
    }
}
```

### Step 3: Modern Async/Await Support

```swift
// Modern async/await pattern
let userService = await UnifiedDI.resolve(UserService.self)
let userData = await userService?.fetchUserData()
```

## 🚀 Runtime Hot-Path Optimization

Enable cutting-edge performance optimizations:

```swift
// Enable optimization mode
UnifiedRegistry.shared.enableOptimization()

// Existing code automatically gets performance improvements
let service = await UnifiedDI.resolve(UserService.self)
```

### Core Optimization Techniques

1. **TypeID + Index Access**: Dictionary → Array slot for O(1) access
2. **Lock-Free Reads**: Snapshot approach eliminates read contention
3. **Inline Optimization**: Reduced function call overhead
4. **Factory Chain Elimination**: Direct call paths remove intermediate steps
5. **Scope-Specific Storage**: Optimized separation of singleton/session/request scopes

### Performance Improvements

| Scenario | Improvement | Description |
|----------|-------------|-------------|
| Single-threaded resolve | 50-80% faster | TypeID + direct access |
| Multi-threaded reads | 2-3x throughput | Lock-free snapshots |
| Complex dependencies | 20-40% faster | Chain flattening |

## Performance Metrics

| Scenario | Swinject | Needle | WeaveDI 3.1 | Improvement |
|---------|----------|--------|-------------|-------------|
| Single dependency resolution | 1.2ms | 0.8ms | 0.2ms | **83% vs Needle** |
| Complex dependency graph | 25.6ms | 15.6ms | 3.1ms | **80% vs Needle** |
| MainActor UI updates | 5.1ms | 3.1ms | 0.6ms | **81% vs Needle** |
| Swift 6 Concurrency | ❌ | ⚠️ Partial | ✅ Full | **Native Support** |

## 🎯 Getting Started

Step-by-step learning path:

1. **Basics**: [Your First DI](/guide/tutorial-your-first-di)
2. **Beginner**: [Meet WeaveDI](/guide/tutorial-meet-weavedi)
3. **Intermediate**: [Intermediate WeaveDI](/guide/tutorial-intermediate-weavedi)
4. **Advanced**: [Advanced WeaveDI](/guide/tutorial-advanced-weavedi)

## 📚 Documentation Topics

### Getting Started
- [Quick Start](/guide/quick-start) - Essential integration steps
- [Bootstrap](/guide/bootstrap) - Safe app initialization patterns
- [Property Wrappers](/guide/property-wrappers) - Automatic dependency injection

### Core APIs
- [Core APIs](/api/core-apis) - Complete API reference
- [Unified DI](/guide/unified-di) - Single entry point API
- [Container Usage](/guide/container-usage) - Advanced container patterns

### Performance & Optimization
- [Runtime Optimization](/guide/runtime-optimization) - Hot-path performance
- [Benchmarks](/guide/benchmarks) - Performance comparisons
- [Auto DI Optimizer](/guide/auto-di-optimizer) - Automatic optimizations

### Advanced Features
- [Module System](/guide/module-system) - Scalable module architecture
- [Scopes](/guide/scopes) - Lifecycle management
- [Module Factory](/guide/module-factory) - Factory patterns

### Migration & Integration
- [Migration 3.0.0](/guide/migration-3.0.0) - Latest migration guide
- [Migration 2.0.0](/guide/migration-2.0.0) - Legacy migration
- [App DI Integration](/guide/app-di-integration) - App-level patterns
- [Needle Style DI](/guide/needle-style-di) - Needle compatibility

### Best Practices
- [Practical Guide](/api/practical-guide) - Real-world examples
- [Dependency Key Patterns](/guide/dependency-key-patterns) - KeyPath patterns
- [Bulk Registration DSL](/api/bulk-registration-dsl) - Batch operations

## Why WeaveDI? 🏆

### Framework Comparison

| Feature | Swinject | Needle | WeaveDI 3.1 |
|---------|----------|--------|-------------|
| **Performance** | ❌ Slow reflection-based | ✅ Zero-cost abstraction | ✅ Zero-cost + Actor optimization |
| **Swift Concurrency** | ❌ No async/await support | ⚠️ Limited async support | ✅ Native async/await + Actor isolation |
| **Code Generation** | ❌ Runtime only | ❌ Build-time required | ✅ Optional (runtime + codegen) |
| **Learning Curve** | ⚠️ Complex API design | ⚠️ Steep dependency graph | ✅ Intuitive property wrappers |
| **Compile Safety** | ❌ Runtime resolution errors | ✅ Compile-time verification | ✅ Enhanced compile-time + KeyPath |
| **Migration** | ❌ Difficult from other DI | ❌ All-or-nothing adoption | ✅ Gradual migration support |
| **Testing** | ⚠️ Complex mocking setup | ⚠️ Limited test isolation | ✅ Built-in test support + mocking |
| **Type Safety** | ❌ Weak type checking | ✅ Strong type checking | ✅ Enhanced with KeyPath validation |
| **Memory Management** | ⚠️ Potential retain cycles | ✅ Automatic lifecycle | ✅ Optimized weak references |
| **Hot Reload Support** | ❌ No support | ❌ No support | ✅ Full hot reload support |
| **Documentation** | ⚠️ Scattered docs | ⚠️ Complex setup guides | ✅ Comprehensive guides + examples |
| **Community** | ✅ Large community | ⚠️ Uber-specific | ✅ Growing ecosystem |

### Real-world Code Comparison

#### Swinject (Traditional Approach)
```swift
// Swinject - Verbose and runtime-heavy
let container = Container()
container.register(UserService.self) { resolver in
    UserServiceImpl(
        repository: resolver.resolve(UserRepository.self)!,
        logger: resolver.resolve(Logger.self)!
    )
}

class ViewController {
    var userService: UserService!

    func inject() {
        userService = container.resolve(UserService.self)! // Runtime resolution
    }
}
```

#### Needle (Compile-time but Complex)
```swift
// Needle - Requires code generation and complex setup
protocol UserDependency: Dependency {
    var userRepository: UserRepository { get }
    var logger: Logger { get }
}

class UserComponent: Component<UserDependency> {
    var userService: UserService {
        return UserServiceImpl(
            repository: dependency.userRepository,
            logger: dependency.logger
        )
    }
}
```

#### WeaveDI 3.1 (Modern & Simple)
```swift
// WeaveDI - Clean, fast, and Actor-optimized
@MainActor
class ViewController {
    @Inject var userService: UserService?  // Zero-cost, type-safe
    @Factory var processor: DataProcessor  // Factory pattern

    func loadData() async {
        // Native async/await with Actor optimization
        let data = await userService?.fetchUserData()
        updateUI(data)  // Already on MainActor
    }
}

// Registration is simple and powerful
UnifiedDI.register(UserService.self) { UserServiceImpl() }
```

### Key Advantages

1. **🚀 Performance**: Up to 83% faster than Needle, 90% faster than Swinject
2. **🎭 Actor-Native**: Built for Swift Concurrency from day one
3. **🔒 Type Safety**: Enhanced compile-time verification + runtime safety
4. **📝 Developer Experience**: Intuitive Property Wrappers (@Inject, @Factory, @SafeInject)
5. **🧪 Testing**: Built-in mocking and test isolation
6. **🔄 Migration**: Gradual migration from any existing DI framework

### Platform Support

WeaveDI 3.1 is designed for modern Swift applications:

- **iOS 15.0+, macOS 14.0+, watchOS 8.0+, tvOS 15.0+** support
- **Swift 6 Concurrency** first-class integration
- **Actor model** optimization
- **Zero-cost abstractions** in release builds
- **Comprehensive testing** support

*Made for Swift developers who want the best*