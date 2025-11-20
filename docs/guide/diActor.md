# DIActor & @DIContainerActor

A safe and high-performance dependency injection system using Swift Concurrency. Solves concurrency issues through thread safety and the Actor model.

## Understanding Actor Hops

### What is an Actor Hop?

An **actor hop** is a fundamental concept in Swift's actor model that occurs when execution switches from one actor context to another. Understanding and optimizing actor hops is crucial for building high-performance applications with WeaveDI.

```swift
// Example demonstrating actor hop concept
@MainActor
class UIViewController {
    @Injected var userService: UserService?

    func updateUI() async {
        // 1. Currently on MainActor (UI thread)
        print("📱 On MainActor: \(Thread.isMainThread)")

        // 2. Actor hop occurs here - switching to DIActor context
        let service = await DIActor.shared.resolve(UserService.self)
        // ⚡ ACTOR HOP: MainActor → DIActor

        // 3. Now on DIActor context
        guard let userService = service else { return }

        // 4. Another actor hop - DIActor back to MainActor for UI update
        await MainActor.run {
            // ⚡ ACTOR HOP: DIActor → MainActor
            self.displayUsers(users)
        }
    }
}
```

### Actor Hop Performance Impact

Each actor hop involves:
- **Context Switching**: CPU switches execution context between actors
- **Memory Synchronization**: Ensures memory consistency across actor boundaries
- **Task Suspension**: Current task may be suspended and resumed later
- **Queue Coordination**: Actor message passing through internal queues

**Performance Characteristics:**
- **Typical Latency**: 50-200 microseconds per hop
- **Memory Overhead**: 16-64 bytes per suspended task
- **CPU Impact**: ~2-5% overhead for frequent hopping
- **Battery Impact**: Increased power consumption on mobile devices

### WeaveDI's Actor Hop Optimizations

WeaveDI implements several strategies to minimize actor hop overhead:

#### 1. Hot Path Caching
```swift
// First resolution requires actor hop
let service1 = await DIActor.shared.resolve(UserService.self)
// ⚡ ACTOR HOP: Current context → DIActor

// Subsequent resolutions are cached and optimized
let service2 = await DIActor.shared.resolve(UserService.self)
// ✨ OPTIMIZED: Cached resolution, minimal actor hop overhead
```

#### 2. Batch Resolution Optimization
```swift
// ❌ INEFFICIENT: Multiple actor hops
@DIActor
func inefficientSetup() async {
    let userService = await DIActor.shared.resolve(UserService.self)     // Hop 1
    let networkService = await DIActor.shared.resolve(NetworkService.self) // Hop 2
    let cacheService = await DIActor.shared.resolve(CacheService.self)   // Hop 3
}

// ✅ OPTIMIZED: Single actor context, multiple operations
@DIActor
func optimizedSetup() async {
    // All operations occur within DIActor context - no additional hops
    let userService = await DIActor.shared.resolve(UserService.self)
    let networkService = await DIActor.shared.resolve(NetworkService.self)
    let cacheService = await DIActor.shared.resolve(CacheService.self)
}
```

#### 3. Contextual Resolution Strategy
```swift
actor BusinessLogicActor {
    @Injected var userService: UserService?

    func processUserData() async {
        // Property wrapper injection minimizes actor hops
        // Service is resolved once and cached within actor instance
        guard let service = userService else { return }

        // All subsequent calls use cached instance - no actor hops
        let users = await service.fetchUsers()
        let processed = await service.processUsers(users)
        await service.saveProcessedUsers(processed)
    }
}
```

### Actor Hop Detection and Monitoring

WeaveDI provides comprehensive actor hop monitoring capabilities:

```swift
// Enable actor hop monitoring
@DIActor
func enableMonitoring() async {
    await DIActor.shared.enableActorHopMonitoring()

    // Perform operations
    let service = await DIActor.shared.resolve(UserService.self)

    // Check actor hop statistics
    let stats = await DIActor.shared.getActorHopStats()
    print("🔍 Actor Hop Analysis:")
    print("  Total hops: \(stats.totalHops)")
    print("  Average latency: \(stats.averageLatency)ms")
    print("  Peak latency: \(stats.peakLatency)ms")
    print("  Optimization opportunities: \(stats.optimizationSuggestions)")
}

// Real-time actor hop logging
@DIActor
func demonstrateHopLogging() async {
    // Enable detailed logging
    await DIActor.shared.setActorHopLoggingLevel(.detailed)

    let service = await DIActor.shared.resolve(UserService.self)
    // Console output:
    // 🎭 [ActorHop] MainActor → DIActor (85μs)
    // 🎭 [ActorHop] DIActor → MainActor (92μs)
    // ⚡ [Optimization] Consider batching operations to reduce hops
}
```

### Best Practices for Actor Hop Optimization

#### 1. Minimize Cross-Actor Communication
```swift
// ❌ AVOID: Frequent cross-actor communication
@MainActor
class BadViewController {
    func loadData() async {
        for i in 1...10 {
            // 10 actor hops - very inefficient!
            let user = await DIActor.shared.resolve(UserService.self)
            await updateUI(with: user)
        }
    }
}

// ✅ GOOD: Batch operations within single actor context
@MainActor
class GoodViewController {
    func loadData() async {
        // Single actor hop to batch resolve all services
        let services = await DIActor.shared.batchResolve([
            UserService.self,
            NetworkService.self,
            CacheService.self
        ])

        // Process all data within MainActor context
        await processServices(services)
    }
}
```

#### 2. Use Actor-Specific Patterns
```swift
// ✅ GOOD: Actor-aware service design
actor DataProcessingActor {
    private var cachedServices: [String: Any] = [:]

    func processWithOptimizedHops() async {
        // Resolve services once and cache within actor
        if cachedServices.isEmpty {
            // Single actor hop for all service resolution
            await resolveDependencies()
        }

        // All processing occurs within actor - no additional hops
        await performDataProcessing()
    }

    @DIActor
    private func resolveDependencies() async {
        let userService = await DIActor.shared.resolve(UserService.self)
        let networkService = await DIActor.shared.resolve(NetworkService.self)

        await MainActor.run {
            // Cache services in main actor context
            self.cachedServices["user"] = userService
            self.cachedServices["network"] = networkService
        }
    }
}
```

#### 3. Strategic Property Wrapper Usage
```swift
// ✅ OPTIMAL: Property wrappers minimize actor hops
class OptimizedService {
    @Injected var userService: UserService?
    @Factory var logger: Logger  // New instance each access, but optimized
    @SafeInject var database: Database?

    func performOperations() async {
        // Property wrappers handle actor hop optimization automatically
        // Services are resolved once and cached per instance

        guard let user = userService,
              let db = database else { return }

        // All subsequent operations use cached instances
        let data = await user.fetchData()
        await db.save(data)

        // Factory instances are optimized for creation patterns
        logger.info("Operations completed")
    }
}
```

## 🎯 What You'll Learn

- **@DIActor**: WeaveDI's global actor system
- **@DIContainerActor**: Container-level actor isolation
- **Thread Safety**: Safe dependency management across multiple threads
- **Performance**: High-performance caching and optimization techniques

## 📚 Swift Concurrency Basics

A quick primer for those new to Swift Concurrency:

- **Actor**: Swift's concurrency model for safely managing data
- **async/await**: Keywords that let you write asynchronous code like synchronous code
- **@MainActor**: Main thread actor for UI updates
- **Thread Safety**: Safe state when multiple threads access simultaneously

## @DIActor Global Actor

### Basic Usage (Beginner-Friendly)

`@DIActor` is a global actor that safely handles dependency injection:

```swift
import WeaveDI

// 🔧 Step 1: Register dependencies (run once at app startup)
@DIActor
func setupDependencies() async {
    print("🚀 Starting dependency registration...")

    // Register UserService - handles user-related business logic
    let service = await DIActor.shared.register(UserService.self) {
        print("📦 Creating UserService instance")
        return UserServiceImpl()
    }

    // Register UserRepository - handles data storage/retrieval
    let repository = await DIActor.shared.register(UserRepository.self) {
        print("📦 Creating UserRepository instance")
        return UserRepositoryImpl()
    }

    print("✅ All dependencies registered successfully")
}

// 🎯 Step 2: Use dependencies (call whenever needed)
@DIActor
func useServices() async {
    print("🔍 Resolving dependencies...")

    // Get the registered UserService instance
    let userService = await DIActor.shared.resolve(UserService.self)

    if let service = userService {
        print("✅ UserService resolved successfully")
        let users = await service.fetchUsers()
        print("📊 Fetched \(users.count) users")
    } else {
        print("❌ UserService not found - did you register it?")
    }
}

// 🏃‍♂️ Step 3: How to use in a real app
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Set up dependencies when app starts
                    await setupDependencies()
                }
        }
    }
}
```

### Why Use @DIActor?

1. **Thread Safety**: Safe access from multiple threads simultaneously
2. **Performance**: Automatically optimized caching system
3. **Swift 6 Ready**: Supports the latest Swift Concurrency model
4. **Error Prevention**: Prevents concurrency errors at compile time

### Shared Actor Pattern

```swift
// Register shared (singleton) instances
@DIActor
func registerSharedServices() async {
    await DIActor.shared.registerSharedActor(DatabaseService.self) {
        DatabaseServiceImpl() // Created only once
    }

    await DIActor.shared.registerSharedActor(NetworkService.self) {
        NetworkServiceImpl() // Shared across the app
    }
}

// Access shared instances
@DIActor
func accessSharedServices() async {
    let database = await DIActor.shared.resolve(DatabaseService.self)
    let network = await DIActor.shared.resolve(NetworkService.self)
    // Both return the same shared instances
}
```

## Global API Bridge

For seamless integration:

```swift
// Using DIActorGlobalAPI for convenience
func setupApp() async {
    // Register
    await DIActorGlobalAPI.register(UserService.self) {
        UserServiceImpl()
    }

    // Resolve
    let service = await DIActorGlobalAPI.resolve(UserService.self)

    // Resolve with error handling
    let result = await DIActorGlobalAPI.resolveResult(UserService.self)
    switch result {
    case .success(let service):
        await service.performOperation()
    case .failure(let error):
        print("Resolution failed: \(error)")
    }
}
```

## Performance Features

### Hot Cache Optimization

```swift
// Frequently used types are automatically cached
for _ in 1...15 {
    let service = await DIActor.shared.resolve(UserService.self)
    // After 10+ uses, automatically moved to hot cache
}
```

### Automatic Cache Cleanup

```swift
// DIActor automatically performs cache cleanup every 100 resolutions
// and every 5 minutes to maintain memory efficiency
```

### Usage Statistics

```swift
@DIActor
func checkStatistics() async {
    let actor = DIActor.shared

    print("Registered types: \(actor.registeredCount)")
    print("Type names: \(actor.registeredTypeNames)")

    await actor.printRegistrationStatus()
    // 📊 [DIActor] Registration Status:
    //    Total registrations: 5
    //    [1] DatabaseService (registered: 2025-09-14...)
}
```

## Error Handling

### Result Pattern

```swift
@DIActor
func resolveWithResult() async {
    let result = await DIActor.shared.resolveResult(UserService.self)

    switch result {
    case .success(let service):
        await service.processData()
    case .failure(let error):
        switch error {
        case .dependencyNotFound(let type):
            print("Service \(type) not registered")
        default:
            print("Resolution error: \(error)")
        }
    }
}
```

### Throwing API

```swift
@DIActor
func resolveWithThrows() async throws {
    let service = try await DIActor.shared.resolveThrows(UserService.self)
    await service.processData()
}
```

## @DIContainerActor

For container-level actor isolation:

```swift
@DIContainerActor
public final class AppDIContainer {
    public static let shared: AppDIContainer = .init()

    public func setupDependencies() async {
        // All operations are actor-isolated
        await registerDi()
        await registerRepositories()
        await registerUseCases()
        await registerServices()
    }

    private func registerRepositories() async {
        // Repository registration with actor safety
    }
}
```

## Migration from Synchronous DI

### Before (Synchronous)

```swift
// Old synchronous approach
class OldDI {
    func setup() {
        UnifiedDI.register(UserService.self) { UserServiceImpl() }
        let service = UnifiedDI.resolve(UserService.self)
    }
}
```

### After (Actor-based)

```swift
// New actor-based approach
@DIActor
class NewDI {
    func setup() async {
        await DIActor.shared.register(UserService.self) { UserServiceImpl() }
        let service = await DIActor.shared.resolve(UserService.self)
    }
}
```

### Migration Bridge (Transitional)

```swift
// Use DIActorBridge for gradual migration
@MainActor
class LegacySupport {
    func setupLegacyCode() {
        // Register synchronously (transitional)
        DIActorBridge.registerSync(UserService.self) {
            UserServiceImpl()
        }

        // Gradually migrate to async
        Task {
            await DIActorBridge.migrateToActor()
        }
    }
}
```

## Best Practices

### 1. Use Shared Actors for Singletons

```swift
// ✅ Good: Shared actor for singleton services
await DIActor.shared.registerSharedActor(DatabaseService.self) {
    DatabaseServiceImpl()
}

// ❌ Avoid: Manual singleton management
```

### 2. Leverage Actor Isolation

```swift
// ✅ Good: Function-level actor isolation
@DIActor
func configureServices() async {
    // All DI operations are automatically thread-safe
}

// ✅ Good: Class-level actor isolation
@DIActor
class ServiceConfigurator {
    func configure() async {
        // Entire class operations are actor-isolated
    }
}
```

### 3. Handle Errors Appropriately

```swift
// ✅ Good: Use Result for optional dependencies
let analyticsResult = await DIActor.shared.resolveResult(AnalyticsService.self)
let analytics = try? analyticsResult.get()

// ✅ Good: Use throws for required dependencies
let database = try await DIActor.shared.resolveThrows(DatabaseService.self)
```

## SwiftUI Integration

```swift
@main
struct MyApp: App {
    init() {
        Task {
            await setupDIActor()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    @DIActor
    private func setupDIActor() async {
        await DIActor.shared.register(UserService.self) {
            UserServiceImpl()
        }
    }
}

struct ContentView: View {
    @State private var userService: UserService?

    var body: some View {
        VStack {
            if let service = userService {
                Text("Service loaded")
            } else {
                Text("Loading...")
            }
        }
        .task {
            await loadService()
        }
    }

    @DIActor
    private func loadService() async {
        userService = await DIActor.shared.resolve(UserService.self)
    }
}
```

## Performance Monitoring

```swift
@DIActor
func monitorPerformance() async {
    let actor = DIActor.shared

    // Check registration count
    print("Registered services: \(actor.registeredCount)")

    // List all registered types
    for typeName in actor.registeredTypeNames {
        print("Registered: \(typeName)")
    }

    // Print detailed status
    await actor.printRegistrationStatus()
}
```

## See Also

- [Auto DI Optimizer](/guide/autoDiOptimizer) - Automatic performance optimization
- [Concurrency Guide](/tutorial/concurrencyIntegration) - Swift Concurrency patterns
- [UnifiedDI vs WeaveDI.Container](/guide/unifiedDi) - Choosing the right API
