# WeaveDI

![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/Roy-wonji/WeaveDI/blob/main/LICENSE)
![Platform](https://img.shields.io/badge/platforms-iOS%2015%2B%20%7C%20macOS%2014%2B%20%7C%20watchOS%208%2B%20%7C%20tvOS%2015%2B-lightgrey)

**A simple and powerful dependency injection framework for modern Swift Concurrency**

📖 **Documentation**: [한국어](README.md) | [English](README-EN.md) | [Official Docs](https://roy-wonji.github.io/WeaveDI/documentation/weavedi) | [Roadmap](docs/guide/roadmap.md)

## 🎯 Key Features

- ⚡ **Swift Concurrency Native**: Perfect support for async/await and Actor
- 🔒 **Type Safety**: Compile-time type verification
- 📝 **TCA-Style Dependency Injection**: `@Injected`/`@Dependency` with KeyPath and type-based access (v3.2.0)
- 🏗️ **Optional AppDI**: Use `WeaveDIAppDI` for module/factory registration only when needed
- 🤖 **Auto Optimization**: Automated dependency graph, Actor hop detection, type safety verification
- 🚀 **Runtime Hot-Path Optimization**: 50-80% performance improvement with TypeID + lock-free reads
- 🧪 **Test Friendly**: Support for dependency mocking and isolation

## 🚀 Quick Start

### Installation

```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.4.0")
]
```

### Basic Usage (v3.2.0)

```swift
import WeaveDI

// 1. App initialization - single entry point
await UnifiedDI.bootstrap { di in
    di.register(UserServiceProtocol.self) { UserService() }
    di.register(Networking.self) { NetworkClient() }
}

// 2. TCA-style @Injected/@Dependency usage (recommended)
class ViewModel {
    @Injected(\.userService) var userService
    @Dependency(\.networkClient) var networkClient

    func loadData() async {
        let data = await userService.fetchData()
    }
}

// 3. Define dependencies with InjectedKey
extension InjectedValues {
    var userService: UserServiceProtocol {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

struct UserServiceKey: InjectedKey {
    static var liveValue: UserServiceProtocol = UserService()
    static var testValue: UserServiceProtocol = UserService()
    static var previewValue: UserServiceProtocol = UserService()
}
```

### App Module Registration (Optional: WeaveDIAppDI)

```swift
import WeaveDI
import WeaveDIAppDI

await UnifiedDI.bootstrap { _ in
    await UnifiedDI.registerDi { register in
        [
            register.authRepositoryImplModule(),
            register.authUseCaseImplModule()
        ]
    }
}
```

### DiModuleFactory - Common DI Dependency Management (v3.3.4+)

WeaveDI v3.3.4 introduces `DiModuleFactory` for systematic management of common DI dependencies like Logger, Config, etc.

```swift
import WeaveDI
import WeaveDIAppDI

// DiModuleFactory usage
var diFactory = DiModuleFactory()

// Add common DI dependencies (actual API)
diFactory.addDependency(Logger.self) {
    ConsoleLogger()
}

diFactory.addDependency(APIConfig.self) {
    APIConfig(baseURL: "https://api.example.com")
}

// Use with ModuleFactoryManager
var factoryManager = ModuleFactoryManager()
factoryManager.diFactory = diFactory

// Other factories can also be configured together
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

// Register all modules to DI container
await factoryManager.registerAll(to: WeaveDI.Container.live)
```

**Key Features:**
- 📦 **Common Dependency Management**: Systematically manage dependencies used throughout the app like Logger, Config
- 🔄 **Automatic Registration**: Integrates with `ModuleFactoryManager` for automatic DI container registration
- 🎯 **Type Safety**: Compile-time type verification for safer DI

## 🆕 Latest Updates (v3.4.0)

### WeaveDI.builder Pattern Support 🏗️

New fluent API for more intuitive dependency registration:

```swift
// New builder pattern - automatic type inference!
WeaveDI.builder
    .register { UserServiceImpl() }    // Automatically registered as UserService
    .register { ConsoleLogger() }      // Automatically registered as Logger
    .register { NetworkClientImpl() }  // Automatically registered as NetworkClient
    .configure()

// Individual registration also supported
WeaveDI.register { UserServiceImpl() }  // Simple one-liner

// Environment-based registration
WeaveDI.registerForEnvironment { env in
    if env.isDebug {
        env.register { MockUserService() as UserService }
        env.register { DebugLogger() as Logger }
    } else {
        env.register { UserServiceImpl() as UserService }
        env.register { ProductionLogger() as Logger }
    }
}
```

### SwiftUI-Style @DependencyConfiguration ⚡

Declare dependencies declaratively like SwiftUI's ViewBuilder:

```swift
// SwiftUI-style declarative registration
@DependencyConfiguration
var appDependencies {
    UserServiceImpl()           // Automatically registered as UserService
    RepositoryImpl()            // Automatically registered as Repository

    // Conditional registration supported
    if ProcessInfo.processInfo.environment["DEBUG"] != nil {
        DebugLogger() as Logger
    } else {
        ProductionLogger() as Logger
    }
}

// Call once at app startup
appDependencies.configure()

// Environment-specific configuration also supported
let productionDeps = DependencyEnvironment.production {
    UserServiceImpl()
    ProductionLogger() as Logger
    RealNetworkClient() as NetworkClient
}

let developmentDeps = DependencyEnvironment.development {
    UserServiceImpl()
    ConsoleLogger() as Logger
    MockNetworkClient() as NetworkClient
}

#if DEBUG
developmentDeps.configure()
#else
productionDeps.configure()
#endif
```

### Module Structure Improvements 📦

WeaveDI is now more systematically organized with clear role separation:

- **WeaveDICore**: Core DI engine (`@Injected`, `UnifiedDI`, `DIContainer`)
- **WeaveDIAppDI**: App-level DI management (`ModuleFactoryManager`, `DiModuleFactory`)
- **WeaveDITCA**: TCA-dedicated integration (conflict resolution complete)
- **WeaveDIMacros**: Swift macro support (`@Component`, `@AutoRegister`)
- **WeaveDIOptimizations**: Performance optimization (AutoDI, graph optimization)
- **WeaveDIMonitoring**: Real-time monitoring (performance tracking, health checks)
- **WeaveDINeedleCompat**: Uber Needle compatibility
- **WeaveDICompat**: Legacy compatibility support
- **WeaveDITools**: CLI tools and utilities

### TCA Conflict Resolution 🔧

Type conflicts with The Composable Architecture are completely resolved:

```swift
// TCA and WeaveDI can now be used together safely
struct AppFeature: Reducer {
    @Dependency(\.userService) var userService: UserService  // TCA

    struct State {
        @Injected var logger: Logger  // WeaveDI - no conflicts!
    }
}
```

## 🎨 Swift Macro Support (v3.2.1+)

WeaveDI provides powerful Swift macros for compile-time optimization and Needle-style architecture.

### @Component - Needle-style Components (10x faster)

```swift
import WeaveDI

@Component
public struct UserComponent {
    @Provide var userService: UserService = UserService()
    @Provide var userRepository: UserRepository = UserRepository()
    @Provide var authService: AuthService = AuthService()
}

// Automatically generates at compile-time:
// UnifiedDI.register(UserService.self) { UserService() }
// UnifiedDI.register(UserRepository.self) { UserRepository() }
// UnifiedDI.register(AuthService.self) { AuthService() }
```

### @AutoRegister - Automatic Dependency Registration

```swift
@AutoRegister(lifetime: .singleton)
class DatabaseService: DatabaseServiceProtocol {
    // Automatically registered with UnifiedDI
}

@AutoRegister(lifetime: .transient)
class RequestHandler: RequestHandlerProtocol {
    // Creates new instance every time
}
```

### @DIActor - Swift Concurrency Optimization

```swift
@DIActor
public final class AutoMonitor {
    public static let shared = AutoMonitor()

    // All methods become automatically thread-safe
    public func onModuleRegistered<T>(_ type: T.Type) {
        // Actor-isolated safe operations
    }
}
```

### @DependencyGraph - Compile-time Validation

```swift
@DependencyGraph([
    UserService.self: [UserRepository.self, Logger.self],
    UserRepository.self: [DatabaseService.self],
    DatabaseService.self: [],
    Logger.self: []
])
class ApplicationDependencyGraph {
    // ✅ Validates circular dependencies at compile-time
}
```

### Performance Comparison (WeaveDI vs Other Frameworks)

| Framework | Registration | Resolution | Memory | Concurrency |
|-----------|-------------|------------|--------|-------------|
| Swinject | ~1.2ms | ~0.8ms | High | Manual locks |
| Needle | ~0.8ms | ~0.6ms | Medium | Limited |
| **WeaveDI** | **~0.2ms** | **~0.1ms** | **Low** | **Native async/await** |

For more detailed macro usage, see [WeaveDI Macros Guide](docs/api/weaveDiMacros.md).

## 🚀 Runtime Hot-Path Optimization (v3.2.0)

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
// Core recommended: register inside bootstrap
UnifiedDI.bootstrap { di in
    di.register(ServiceProtocol.self) { ServiceImpl() }
    di.register(UserRepositoryProtocol.self) { UserRepositoryImpl() }
}
```

### Property Wrappers

| Property Wrapper | Purpose | Example | Status |
|---|---|---|---|
| `@Injected` | TCA-style injection (recommended) | `@Injected(\.service) var service` | ✅ v3.2.0 |
| `@Dependency` | TCA-style injection (same storage) | `@Dependency(\.service) var service` | ✅ v3.2.0 |
| `@Factory` | Factory pattern (new instance) | `@Factory var generator: Generator` | ✅ Maintained |
| `@Inject` | Basic injection (legacy) | `@Inject var service: Service?` | ⚠️ Deprecated (v3.2.0+) |
| `@SafeInject` | Safe injection (legacy) | `@SafeInject var api: API?` | ⚠️ Deprecated (v3.2.0+) |

> 📖 **Migration Guide**: [@Injected Documentation](docs/api/injected.md) | [AppDI Simplification](docs/guide/appDiSimplification.md)

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
let service = UnifiedDI.resolve(UserService.self)
```

## 📖 Documentation

- [Official Documentation](https://roy-wonji.github.io/WeaveDI/documentation/weavedi)
- [Roadmap (v3.2.0)](docs/guide/roadmap.md) - Current version and future plans
- [@Injected Guide](docs/api/injected.md) - TCA-style dependency injection
- [TCA Integration](docs/guide/tcaIntegration.md) - Use WeaveDI within Composable Architecture
- [AppDI Simplification](docs/guide/appDiSimplification.md) - Automatic dependency registration
- [Performance Optimization Guide](PERFORMANCE-OPTIMIZATION.md)
- [Migration Guide](MIGRATION.md)
- [@Component Quick Start](docs/guide/tcaIntegration.md#component-quick-start) - Needle-style compile-time wiring

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

WeaveDI is released under the MIT license. See [LICENSE](LICENSE) for details.

---

*Built with ❤️ for the Swift community*
