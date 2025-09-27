# ``WeaveDI``

📖 **Documentation**: [한국어](../ko.lproj/WeaveDI) | [English](WeaveDI) | [Official Site](https://roy-wonji.github.io/WeaveDI/documentation/weavedi)

A high-performance dependency injection framework designed for modern Swift Concurrency and Actor models

## Overview

WeaveDI 3.1.0 is a next-generation dependency injection framework for iOS 15.0+, macOS 14.0+, watchOS 8.0+, tvOS 15.0+ applications. It seamlessly integrates with Swift's latest concurrency model and improves dependency resolution performance by up to **80%** through **Runtime Hot-Path Optimization**.

### 🚀 Key Features

#### 🚀 Runtime Hot-Path Optimization (v3.1.0)
50-80% performance improvement with TypeID + lock-free reads. See <doc:RuntimeOptimization> for details.

#### 🎭 Actor Hop Optimization
Intelligently optimizes transitions between different Actor contexts to maximize dependency resolution performance.

#### 🔒 Complete Type Safety
- **Compile-time verification**: Type safety guaranteed through KeyPath-based registration
- **Runtime safety**: Clear error messages and safe fallback systems
- **Type inference**: Leveraging Swift's powerful type system

#### 📝 Intuitive Property Wrappers
- **`@Inject`**: Automatic dependency injection (optional/required support)
- **`@Factory`**: Factory pattern-based module management
- **`@SafeInject`**: Safe dependency injection with error handling

#### 🏗️ Powerful Module System
- **AppDIContainer**: App-wide dependency management
- **ModuleFactory**: Reusable module creation
- **Container**: Batch registration and parallel execution

#### 🧪 Test-Friendly Design
- **Dependency mocking**: Easy registration of Mock objects for testing
- **Isolated tests**: Independence between test states guaranteed
- **Bootstrap reset**: Test container initialization

### ⚡ Quick Start

#### Step 1: Dependency Registration (UnifiedDI Recommended)

```swift
import WeaveDI

// Bootstrap dependencies at app startup
await DependencyContainer.bootstrap { container in
    // Register services
    container.register(UserServiceProtocol.self) {
        UserService()
    }

    // Register repositories
    container.register(\.userRepository) {
        UserRepositoryImpl()
    }
}
```

#### Step 2: Property Wrapper Injection

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

#### Step 3: Modern Async/Await Support

```swift
// Modern async/await pattern
let userService = await UnifiedDI.resolve(UserService.self)
let userData = await userService?.fetchUserData()
```

### 🚀 Runtime Hot-Path Optimization

Enable cutting-edge performance optimizations:

```swift
// Enable optimization mode
UnifiedRegistry.shared.enableOptimization()

// Existing code automatically gets performance improvements
let service = await UnifiedDI.resolve(UserService.self)
```

#### Core Optimization Techniques

1. **TypeID + Index Access**: Dictionary → Array slot for O(1) access
2. **Lock-Free Reads**: Snapshot approach eliminates read contention
3. **Inline Optimization**: Reduced function call overhead
4. **Factory Chain Elimination**: Direct call paths remove intermediate steps
5. **Scope-Specific Storage**: Optimized separation of singleton/session/request scopes

#### Performance Improvements

| Scenario | Improvement | Description |
|----------|-------------|-------------|
| Single-threaded resolve | 50-80% faster | TypeID + direct access |
| Multi-threaded reads | 2-3x throughput | Lock-free snapshots |
| Complex dependencies | 20-40% faster | Chain flattening |

### 📊 Performance Metrics

| Scenario | Legacy DI | WeaveDI 3.2 | Improvement |
|---------|-----------|-------------|-------------|
| Single dependency resolution | 0.8ms | 0.2ms | **75%** |
| Complex dependency graph | 15.6ms | 3.1ms | **80%** |
| MainActor UI updates | 3.1ms | 0.6ms | **81%** |

### 🎯 Getting Started

Step-by-step learning path:

1. **Basics**: <doc:Tutorial-YourFirstDI>
2. **Beginner**: <doc:Tutorial-MeetWeaveDI>
3. **Intermediate**: <doc:Tutorial-IntermediateWeaveDI>
4. **Advanced**: <doc:Tutorial-AdvancedWeaveDI>

## Topics

### Getting Started

- <doc:QuickStart>
- <doc:Tutorial-YourFirstDI>
- <doc:Tutorial-MeetWeaveDI>

### Core APIs

- <doc:CoreAPIs>
- <doc:PropertyWrappers>
- <doc:UnifiedDI>

### Performance & Optimization

- <doc:RuntimeOptimization>
- <doc:Benchmarks>
- <doc:AutoDIOptimizer>

### Advanced Features

- <doc:ModuleSystem>
- <doc:Scopes>
- <doc:ContainerUsage>

### Migration & Integration

- <doc:MIGRATION-3.0.0>
- <doc:AppDIIntegration>
- <doc:NeedleStyleDI>

### Best Practices

- <doc:PracticalGuide>
- <doc:DependencyKeyPatterns>
- <doc:Bootstrap>

---

*Built with ❤️ for the Swift community*