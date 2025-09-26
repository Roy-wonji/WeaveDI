# Needle-Style DI Usage

Guide on how to use dependency injection in a style similar to Uber's Needle framework in WeaveDI.

## Overview

WeaveDI provides all the core features of Needle while offering a better developer experience. This is a complete guide for developers who want to migrate from Needle to WeaveDI or use WeaveDI in Needle-style.

## 🏆 WeaveDI vs Needle Comparison

| Feature | Needle | WeaveDI | Result |
|---------|--------|---------|--------|
| **Compile-time Safety** | ✅ Code generation | ✅ Macro-based | **Equal** |
| **Runtime Performance** | ✅ Zero cost | ✅ Zero cost + Actor optimization | **WeaveDI Wins** |
| **Swift 6 Support** | ⚠️ Limited | ✅ Perfect native | **WeaveDI Wins** |
| **Code Generation Required** | ❌ Required | ✅ Optional | **WeaveDI Wins** |
| **Learning Curve** | ❌ Steep | ✅ Gradual | **WeaveDI Wins** |
| **Migration Ease** | ❌ All-or-nothing | ✅ Gradual | **WeaveDI Wins** |

## 🚀 Quick Start

### 1. Enable Needle-level Performance

```swift
import WeaveDI

@main
struct MyApp: App {
    init() {
        // Enable zero-cost performance same as Needle
        UnifiedDI.enableStaticOptimization()
        setupDependencies()
    }
}
```

**Build Settings (for maximum performance):**
```bash
# Xcode: Add to Build Settings → Other Swift Flags
-DUSE_STATIC_FACTORY

# Or SPM command
swift build -c release -Xswiftc -DUSE_STATIC_FACTORY
```

### 2. Compile-time Dependency Validation

```swift
// Needle's core advantage: compile-time safety
@DependencyGraph([
    UserService.self: [NetworkService.self, Logger.self],
    NetworkService.self: [Logger.self, DatabaseService.self],
    DatabaseService.self: [Logger.self]
])
extension WeaveDI {}

// ✅ OK: Dependency graph is correct
// ❌ Compile error if circular dependencies exist!
```

## 📋 Needle-Style Usage Patterns

### Pattern 1: Component-based Registration

**Needle approach:**
```swift
// Needle code
import NeedleFoundation

class AppComponent: Component<EmptyDependency> {
    var userService: UserServiceProtocol {
        return UserServiceImpl(networkService: networkService)
    }

    var networkService: NetworkServiceProtocol {
        return NetworkServiceImpl(logger: logger)
    }

    var logger: LoggerProtocol {
        return ConsoleLogger()
    }
}
```

**WeaveDI equivalent:**
```swift
// WeaveDI: Simpler and more powerful
import WeaveDI

extension UnifiedDI {
    // Component-style dependency setup
    static func setupAppComponent() {
        // Basic services
        _ = register(LoggerProtocol.self) { ConsoleLogger() }
        _ = register(NetworkServiceProtocol.self) {
            NetworkServiceImpl(logger: resolve(LoggerProtocol.self)!)
        }
        _ = register(UserServiceProtocol.self) {
            UserServiceImpl(networkService: resolve(NetworkServiceProtocol.self)!)
        }

        // Needle-style validation
        _ = validateNeedleStyle(
            component: AppComponent.self,
            dependencies: [LoggerProtocol.self, NetworkServiceProtocol.self, UserServiceProtocol.self]
        )
    }
}
```

### Pattern 2: Hierarchical Dependency Structure

**Needle-style hierarchical structure in WeaveDI:**
```swift
// 1. Root Component (app-wide common)
extension UnifiedDI {
    static func setupRootComponent() {
        _ = register(Logger.self) { OSLogger() }
        _ = register(NetworkClient.self) { URLSessionClient() }
        _ = register(DatabaseClient.self) { CoreDataClient() }
    }
}

// 2. Feature Component (per feature)
extension UnifiedDI {
    static func setupUserFeature() {
        _ = register(UserRepository.self) {
            UserRepositoryImpl(
                network: resolve(NetworkClient.self)!,
                database: resolve(DatabaseClient.self)!
            )
        }
        _ = register(UserService.self) {
            UserServiceImpl(repository: resolve(UserRepository.self)!)
        }
    }

    static func setupAuthFeature() {
        _ = register(AuthRepository.self) {
            AuthRepositoryImpl(network: resolve(NetworkClient.self)!)
        }
        _ = register(AuthService.self) {
            AuthServiceImpl(repository: resolve(AuthRepository.self)!)
        }
    }
}

// 3. Compile-time graph validation
@DependencyGraph([
    UserService.self: [UserRepository.self],
    UserRepository.self: [NetworkClient.self, DatabaseClient.self],
    AuthService.self: [AuthRepository.self],
    AuthRepository.self: [NetworkClient.self],
    NetworkClient.self: [Logger.self],
    DatabaseClient.self: [Logger.self]
])
extension WeaveDI {}
```

### Pattern 3: High-Performance Resolution (Needle-level)

```swift
class PerformanceCriticalViewModel {
    // General usage (convenience first)
    @Inject private var userService: UserService?

    // High-performance where needed (Needle-level zero cost)
    func performanceHotPath() {
        // Static resolution: complete runtime overhead elimination
        let fastUserService = UnifiedDI.staticResolve(UserService.self)

        // Optimization in loops
        for _ in 0..<10000 {
            // Use cached instance instead of resolving each time
            fastUserService?.performQuickOperation()
        }
    }
}
```

## 🔄 Needle Migration Guide

### Step-by-Step Migration

```swift
// 1. Check migration guide
func checkMigrationGuide() {
    print(UnifiedDI.migrateFromNeedle())
    // Prints detailed step-by-step guide

    print(UnifiedDI.needleMigrationBenefits())
    // Migration benefits analysis
}

// 2. Gradual migration (unlike Needle's all-or-nothing)
class HybridApproach {
    // Keep existing Needle code as is
    private let legacyService = NeedleContainer.resolve(LegacyService.self)

    // Use WeaveDI for new code only
    @Inject private var newService: NewService?

    func migrate() {
        // Can change one by one gradually
        let mixedResult = legacyService.work() + (newService?.work() ?? "")
    }
}
```

### Automatic Conversion Tools

```swift
// Automatic Needle Component validation
extension UnifiedDI {
    static func validateNeedleComponent() -> Bool {
        // Validate existing Needle-style dependencies
        let dependencies: [Any.Type] = [
            UserService.self,
            NetworkService.self,
            Logger.self
        ]

        return validateNeedleStyle(
            component: AppComponent.self,
            dependencies: dependencies
        )
    }
}
```

## 🎯 Real Project Application

### Large-scale App Structure Example

```swift
// AppDelegate.swift
class AppDelegate: UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Enable Needle-level performance
        UnifiedDI.enableStaticOptimization()

        // Hierarchical dependency setup
        setupCoreDependencies()
        setupFeatureDependencies()
        setupUIDependencies()

        // Dependency graph validation
        validateDependencyGraph()

        return true
    }

    private func setupCoreDependencies() {
        // Core Layer (similar to Needle's Root Component)
        _ = UnifiedDI.register(Logger.self) { OSLogger() }
        _ = UnifiedDI.register(NetworkClient.self) { URLSessionClient() }
        _ = UnifiedDI.register(DatabaseClient.self) { CoreDataClient() }
        _ = UnifiedDI.register(CacheClient.self) { NSCacheClient() }
    }

    private func setupFeatureDependencies() {
        // Business Layer (similar to Needle's Feature Component)
        _ = UnifiedDI.register(UserRepository.self) { UserRepositoryImpl() }
        _ = UnifiedDI.register(AuthRepository.self) { AuthRepositoryImpl() }
        _ = UnifiedDI.register(ProductRepository.self) { ProductRepositoryImpl() }

        _ = UnifiedDI.register(UserService.self) { UserServiceImpl() }
        _ = UnifiedDI.register(AuthService.self) { AuthServiceImpl() }
        _ = UnifiedDI.register(ProductService.self) { ProductServiceImpl() }
    }

    private func setupUIDependencies() {
        // Presentation Layer
        _ = UnifiedDI.register(UserViewModel.self) { UserViewModel() }
        _ = UnifiedDI.register(AuthViewModel.self) { AuthViewModel() }
        _ = UnifiedDI.register(ProductViewModel.self) { ProductViewModel() }
    }

    private func validateDependencyGraph() {
        // Needle-style validation
        _ = UnifiedDI.validateNeedleStyle(
            component: AppComponent.self,
            dependencies: [
                Logger.self, NetworkClient.self, DatabaseClient.self,
                UserService.self, AuthService.self, ProductService.self
            ]
        )

        print("✅ All Needle-style dependencies validated")
    }
}

// DependencyGraph.swift - Compile-time validation
@DependencyGraph([
    // UI Layer
    UserViewModel.self: [UserService.self],
    AuthViewModel.self: [AuthService.self],
    ProductViewModel.self: [ProductService.self],

    // Business Layer
    UserService.self: [UserRepository.self, Logger.self],
    AuthService.self: [AuthRepository.self, Logger.self],
    ProductService.self: [ProductRepository.self, CacheClient.self, Logger.self],

    // Data Layer
    UserRepository.self: [NetworkClient.self, DatabaseClient.self],
    AuthRepository.self: [NetworkClient.self],
    ProductRepository.self: [NetworkClient.self, DatabaseClient.self],

    // Core Layer
    NetworkClient.self: [Logger.self],
    DatabaseClient.self: [Logger.self],
    CacheClient.self: [Logger.self]
])
extension WeaveDI {}
```

## 📊 Performance Monitoring

```swift
// Unlike Needle, provides real-time performance analysis
class PerformanceAnalyzer {
    func analyzeDIPerformance() {
        // WeaveDI vs Needle performance comparison
        print(UnifiedDI.performanceComparison())
        /*
        Output:
        🏆 WeaveDI vs Needle Performance:
        ✅ Compile-time safety: EQUAL
        ✅ Runtime performance: EQUAL (zero-cost)
        🚀 Developer experience: WeaveDI BETTER
        🎯 Swift 6 support: WeaveDI EXCLUSIVE
        */

        // Real-time performance statistics
        let stats = UnifiedDI.stats()
        print("📊 DI Usage Stats: \(stats)")

        // Actor hop optimization analysis (feature not in Needle)
        Task {
            let hopStats = await UnifiedDI.actorHopStats
            let optimizations = await UnifiedDI.actorOptimizations

            print("⚡ Actor Hop Stats: \(hopStats)")
            print("🤖 Optimization Suggestions: \(optimizations)")
        }
    }
}
```

## 🎨 Advanced Usage

### With Swift 6 Concurrency

```swift
// Needle has limited Swift 6 support, but WeaveDI has perfect support
actor DataManager {
    @Inject private var networkService: NetworkService?
    @Inject private var databaseService: DatabaseService?

    func syncData() async {
        // Safe DI usage within Actor
        let networkData = await networkService?.fetchData()
        await databaseService?.save(networkData)
    }
}

// Safe with MainActor too
@MainActor
class UIViewModel: ObservableObject {
    @Inject private var userService: UserService?

    func updateUI() {
        // Safe DI resolution in MainActor context
        userService?.updateUserData()
    }
}
```

### Module-based Dependency Management

```swift
// Module-based management for large projects
enum DIModule {
    case core
    case user
    case auth
    case product
}

extension UnifiedDI {
    static func setup(module: DIModule) {
        switch module {
        case .core:
            setupCoreModule()
        case .user:
            setupUserModule()
        case .auth:
            setupAuthModule()
        case .product:
            setupProductModule()
        }
    }

    private static func setupCoreModule() {
        // Core module dependencies
        _ = register(Logger.self) { OSLogger() }
        _ = register(NetworkClient.self) { URLSessionClient() }
    }

    // ... other modules
}
```

## 📝 Checklist

### ✅ Migrating from Needle to WeaveDI
- [ ] Add `import WeaveDI`
- [ ] Call `UnifiedDI.enableStaticOptimization()`
- [ ] Add `-DUSE_STATIC_FACTORY` to build flags (for maximum performance)
- [ ] Set up compile-time validation with `@DependencyGraph`
- [ ] Check compatibility with `validateNeedleStyle()`
- [ ] Gradually convert existing Components to WeaveDI style

### ✅ Using Needle-style WeaveDI in New Projects
- [ ] Design hierarchical dependency structure
- [ ] Component-style dependency registration
- [ ] Define compile-time dependency graph
- [ ] Apply `staticResolve()` to performance-critical parts
- [ ] Set up real-time performance monitoring

## 🚀 Conclusion

WeaveDI provides all core advantages of Needle while offering:

- **Easier Usage**: No code generation tools required
- **Better Performance**: Actor hop optimization + real-time analysis
- **Safer Migration**: Gradual conversion possible
- **More Modern**: Perfect Swift 6 support

**If you're using Needle, we strongly recommend migrating to WeaveDI!** 🏆

---

📖 **Documentation**: [한국어](../ko.lproj/NeedleStyleDI) | [English](NeedleStyleDI)