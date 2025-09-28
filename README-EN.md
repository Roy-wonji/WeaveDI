# WeaveDI

![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/Roy-wonji/WeaveDI/blob/main/LICENSE)
![Platform](https://img.shields.io/badge/platforms-iOS%2015%2B%20%7C%20macOS%2014%2B%20%7C%20watchOS%208%2B%20%7C%20tvOS%2015%2B-lightgrey)

**A simple and powerful dependency injection framework for modern Swift Concurrency**

📖 **Documentation**: [한국어](README.md) | [English](README-EN.md) | [Official Docs](https://roy-wonji.github.io/WeaveDI/documentation/weavedi)

## 🎯 Key Features

- ⚡ **Swift Concurrency Native**: Perfect support for async/await and Actor
- 🔒 **Type Safety**: Compile-time type verification
- 📝 **Simple API**: Just remember 3 core Property Wrappers
- 🤖 **Auto Optimization**: Automated dependency graph, Actor hop detection, type safety verification
- 🚀 **Runtime Hot-Path Optimization**: 50-80% performance improvement with TypeID + lock-free reads
- 🧪 **Test Friendly**: Support for dependency mocking and isolation

## 🚀 Quick Start

### Installation

```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.1.0")
]
```

### Basic Usage

```swift
import WeaveDI

// 1. Register dependencies
let userService = UnifiedDI.register(UserServiceProtocol.self) {
    UserService()
}

// 2. Inject with Property Wrappers
class ViewController {
    @Inject var userService: UserServiceProtocol?     // Optional injection
    @Factory var generator: PDFGenerator              // Factory (new instance each time)
    @SafeInject var apiService: APIServiceProtocol?   // Safe injection
}

// 3. Safe injection (with error handling)
do {
    let service: UserService = try await UnifiedDI.resolveSafely(UserService.self)
} catch {
    print("Dependency resolution failed: \(error)")
}
```

## 🚀 Runtime Hot-Path Optimization (v3.1.0)

Micro-optimization features for high-performance applications.

### Enable Optimization

```swift
import WeaveDI

// Enable optimization mode (existing APIs work unchanged)
UnifiedRegistry.shared.enableOptimization()

// Existing code gets performance improvements without changes
let service = await UnifiedDI.resolve(UserService.self)
```

### Core Optimization Techniques

1. **TypeID + Index Access**: Dictionary → Array slot for O(1) access
2. **Lock-Free Reads**: Snapshot approach eliminates read contention
3. **Inline Optimization**: Reduced function call overhead
4. **Factory Chain Elimination**: Direct call paths remove intermediate steps
5. **Scope-Specific Storage**: Optimized separation of singleton/session/request scopes

### Expected Performance Improvements

| Scenario | Improvement | Description |
|----------|-------------|-------------|
| Single-threaded resolve | 50-80% faster | TypeID + direct access |
| Multi-threaded reads | 2-3x throughput | Lock-free snapshots |
| Complex dependencies | 20-40% faster | Chain flattening |

### Run Benchmarks

```bash
swift run -c release Benchmarks --count 100k --quick
```

For detailed information, see [PERFORMANCE-OPTIMIZATION.md](PERFORMANCE-OPTIMIZATION.md).

## 📚 Core APIs

### Registration API

```swift
// Basic registration (recommended)
let service = UnifiedDI.register(ServiceProtocol.self) {
    ServiceImpl()
}

// KeyPath registration
let repository = UnifiedDI.register(\.userRepository) {
    UserRepositoryImpl()
}

// Conditional registration
let service = UnifiedDI.Conditional.registerIf(
    ServiceProtocol.self,
    condition: isProduction,
    factory: { ProductionService() },
    fallback: { MockService() }
)

// Scope-based registration
let sessionService = UnifiedDI.registerScoped(
    SessionService.self,
    scope: .session
) {
    SessionServiceImpl()
}
```

### Property Wrappers

| Property Wrapper | Purpose | Example |
|---|---|---|
| `@Inject` | Basic injection (optional/required) | `@Inject var service: Service?` |
| `@Factory` | Factory pattern (new instance) | `@Factory var generator: Generator` |
| `@SafeInject` | Safe injection (throws) | `@SafeInject var api: API?` |

### Resolution API

```swift
// General resolution
let service = await UnifiedDI.resolve(UserService.self)

// Safe resolution (with error handling)
let service: UserService = try await UnifiedDI.resolveSafely(UserService.self)

// KeyPath resolution
let repository = await UnifiedDI.resolve(\.userRepository)

// Scoped resolution
let sessionService = await UnifiedDI.resolveScoped(SessionService.self, scope: .session)
```

## ⚡ Auto Performance Optimization

```swift
// Automatically optimized after multiple uses
for _ in 1...15 {
    let service = UnifiedDI.resolve(UserService.self)
}

// Optimized types are automatically logged
// ⚡ Auto optimized: UserService (15 uses)
```

## 🧪 Testing

```swift
// Test initialization
@MainActor
override func setUp() {
    UnifiedDI.releaseAll()

    // Register test dependencies
    _ = UnifiedDI.register(UserService.self) {
        MockUserService()
    }
}
```

## 📋 Auto-Collected Information

```swift
// 🔄 Auto-generated dependency graph
UnifiedDI.autoGraph

// ⚡ Auto-optimized types
UnifiedDI.optimizedTypes

// ⚠️ Circular dependencies
UnifiedDI.circularDependencies

// 📊 Usage statistics
UnifiedDI.stats
```

### Logging Control

```swift
UnifiedDI.setLogLevel(.registration)  // Registration only
UnifiedDI.setLogLevel(.optimization)  // Optimization only
UnifiedDI.setLogLevel(.errors)       // Errors/warnings only
UnifiedDI.setLogLevel(.off)          // Turn off logging
```

## 🔄 Migration from v2.x

```swift
// v2.x
let service = WeaveDI.Container.live.resolve(UserService.self)

// v3.x (recommended)
let service = await UnifiedDI.resolve(UserService.self)

// or still supported
let service = DIContainer.shared.resolve(UserService.self)
```

## 📖 Documentation

- [Official Documentation](https://roy-wonji.github.io/WeaveDI/documentation/weavedi)
- [Performance Optimization Guide](PERFORMANCE-OPTIMIZATION.md)
- [Migration Guide](MIGRATION.md)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

WeaveDI is released under the MIT license. See [LICENSE](LICENSE) for details.

---

*Built with ❤️ for the Swift community*
