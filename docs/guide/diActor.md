# DIActor & @WeaveDI.ContainerActor

A safe and high-performance dependency injection system using Swift Concurrency. Solves concurrency issues through thread safety and the Actor model.

## 🎯 What You'll Learn

- **@DIActor**: WeaveDI's global actor system
- **@WeaveDI.ContainerActor**: Container-level actor isolation
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

## @WeaveDI.ContainerActor

For container-level actor isolation:

```swift
@WeaveDI.ContainerActor
public final class AppWeaveDI.Container {
    public static let shared: AppWeaveDI.Container = .init()

    public func setupDependencies() async {
        // All operations are actor-isolated
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
- [Concurrency Guide](/guide/concurrency) - Swift Concurrency patterns
- [UnifiedDI vs WeaveDI.Container](/guide/unifiedDi) - Choosing the right API