---
title: DIActor
lang: en-US
---

# DIActor

Actor-based implementation for thread-safe DI operations

## Features
- **Actor Isolation**: Full Swift Concurrency compliance
- **Type Safety**: Compile-time type safety
- **Memory Safety**: Automatic memory management
- **Performance**: Optimized concurrent access

## Basic Usage

```swift
import WeaveDI

// Async/await pattern
let diActor = DIActor.shared
await diActor.register(ServiceProtocol.self) { ServiceImpl() }
let service = await diActor.resolve(ServiceProtocol.self)
```

## Core API

```swift
@globalActor
public actor DIActor {
    public static let shared = DIActor()

    // MARK: - Registration

    /// Register a type with a factory closure
    public func register<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) -> @Sendable () async -> Void

    /// Register a Sendable instance directly
    public func register<T>(_ type: T.Type, instance: T) where T: Sendable

    /// Register a shared actor instance (recommended)
    public func registerSharedActor<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) -> @Sendable () async -> Void where T: Sendable

    // MARK: - Resolution

    /// Resolve a type (returns optional)
    public func resolve<T>(_ type: T.Type) -> T?

    /// Resolve with Result pattern
    public func resolveResult<T>(_ type: T.Type) -> Result<T, DIError>

    /// Resolve with throwing
    public func resolveThrows<T>(_ type: T.Type) throws -> T

    // MARK: - Release

    /// Release a specific type
    public func release<T>(_ type: T.Type)

    /// Release all registrations
    public func releaseAll()

    // MARK: - Inspection

    /// Get count of registered types
    public func registeredCount() -> Int

    /// Get all registered type names
    public func allRegisteredTypes() -> [String]

    /// Print detailed registration status
    public func printStatus()
}
```

## Registration Patterns

### Basic Factory Registration

```swift
// Register with factory closure
await DIActor.shared.register(UserService.self) {
    UserServiceImpl()
}

// Resolve when needed
if let service = await DIActor.shared.resolve(UserService.self) {
    await service.fetchUsers()
}
```

### Instance Registration

```swift
// Register a Sendable instance directly
let config = AppConfig(apiKey: "key123", timeout: 30)
await DIActor.shared.register(AppConfig.self, instance: config)

// Resolve the same instance
let resolvedConfig = await DIActor.shared.resolve(AppConfig.self)
print(resolvedConfig?.apiKey) // "key123"
```

### Shared Actor Registration (Recommended)

```swift
// Register as shared actor (singleton-like but thread-safe)
let releaseHandler = await DIActor.shared.registerSharedActor(DatabaseService.self) {
    DatabaseService()
}

// All resolutions return the same instance (created once)
let db1 = await DIActor.shared.resolve(DatabaseService.self)
let db2 = await DIActor.shared.resolve(DatabaseService.self)
// db1 and db2 are the same instance

// Release when done
await releaseHandler()
```

## Resolution Patterns

### Optional Resolution

```swift
// Returns optional
if let service = await DIActor.shared.resolve(UserService.self) {
    await service.performAction()
} else {
    print("Service not registered")
}
```

### Result Pattern

```swift
// Returns Result<T, DIError>
let result = await DIActor.shared.resolveResult(UserService.self)
switch result {
case .success(let service):
    await service.performAction()
case .failure(let error):
    print("Resolution failed: \(error)")
}
```

### Throwing Pattern

```swift
// Throws DIError
do {
    let service = try await DIActor.shared.resolveThrows(UserService.self)
    await service.performAction()
} catch {
    print("Resolution failed: \(error)")
}
```

## Performance Features

### Hot Path Cache

DIActor automatically caches frequently used types (10+ resolutions) for faster access:

```swift
// First resolution: normal speed
let service1 = await DIActor.shared.resolve(UserService.self)

// After 10+ resolutions: cached, much faster
for _ in 1...20 {
    let service = await DIActor.shared.resolve(UserService.self)
    // Cached access after 10th resolution
}
```

### Usage Tracking

```swift
// DIActor tracks usage count for all types
await DIActor.shared.printStatus()
// Output includes usage counts:
// UserService: 23 resolutions
// DatabaseService: 15 resolutions
```

## Global API

For convenience, WeaveDI provides a global API that uses DIActor internally:

```swift
public enum DIActorGlobalAPI {
    /// Register a dependency using DIActor
    public static func register<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) async -> @Sendable () async -> Void

    /// Resolve a dependency using DIActor
    public static func resolve<T>(_ type: T.Type) async -> T?

    /// Resolve with Result pattern
    public static func resolveResult<T>(_ type: T.Type) async -> Result<T, DIError>

    /// Resolve with throwing
    public static func resolveThrows<T>(_ type: T.Type) async throws -> T

    /// Release a specific type
    public static func release<T>(_ type: T.Type) async

    /// Release all registrations
    public static func releaseAll() async
}
```

### Using Global API

```swift
import WeaveDI

// Register via global API
await DIActorGlobalAPI.register(UserService.self) {
    UserServiceImpl()
}

// Resolve via global API
let service = await DIActorGlobalAPI.resolve(UserService.self)
```

## Migration Bridge

For migrating existing DispatchQueue-based code to Actor-based:

```swift
public enum DIActorBridge {
    /// Bridge existing DI API to Actor-based
    public static func register<T>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) async

    /// Sync wrapper for compatibility (transitional)
    /// - Warning: Use only on main thread
    public static func registerSync<T>(
        _ type: T.Type,
        factory: @escaping () -> T
    )

    /// Sync wrapper for compatibility (transitional)
    /// - Warning: Use only on main thread
    public static func resolveSync<T>(_ type: T.Type) -> T?
}
```

### Migration Example

```swift
// OLD (DispatchQueue-based):
DI.register(Service.self) { ServiceImpl() }
let service = DI.resolve(Service.self)

// NEW (Actor-based):
await DIActorBridge.register(Service.self) { ServiceImpl() }
let service = await DIActorBridge.resolve(Service.self)
```

## Memory Management

### Automatic Cleanup

DIActor performs automatic cleanup of hot cache periodically:

```swift
// Cleanup happens automatically based on memory pressure
// No manual intervention needed
```

### Manual Release

```swift
// Release specific type
await DIActor.shared.release(UserService.self)

// Release all types
await DIActor.shared.releaseAll()

// Using release handler
let releaseHandler = await DIActor.shared.register(Service.self) {
    ServiceImpl()
}

// Later, when you want to release
await releaseHandler()
```

## Scoped Instances

DIActor supports scoped instances for managing lifecycles:

```swift
// Scoped instances are stored per scope identifier
// Useful for feature-level or screen-level lifecycles

// Implementation handled internally by DIActor
// Access via WeaveDI.Container.resolve() with scope parameter
```

## Inspection & Debugging

### Print Registration Status

```swift
await DIActor.shared.printStatus()
// Output:
// 📊 [DIActor] Registration Status:
// • UserService (registered at 2025-10-01 10:30:00, resolved 15 times)
// • DatabaseService (registered at 2025-10-01 10:30:01, resolved 8 times, shared)
// • NetworkService (registered at 2025-10-01 10:30:02, resolved 3 times)
```

### Count Registered Types

```swift
let count = await DIActor.shared.registeredCount()
print("Total registered types: \(count)")
```

### List All Types

```swift
let types = await DIActor.shared.allRegisteredTypes()
print("Registered types:")
for typeName in types {
    print("  - \(typeName)")
}
```

## Best Practices

1. **Prefer Shared Actor for Singletons**: Use `registerSharedActor()` instead of managing singletons manually
2. **Use Async/Await**: Always use `await` for DIActor operations
3. **Store Release Handlers**: Keep release handlers if you need to unregister later
4. **Choose Right Resolution Pattern**: Use optional for optional dependencies, throwing for required ones
5. **Avoid Sync Wrappers in Production**: Only use `DIActorBridge.Sync` methods during migration
6. **Monitor Usage**: Use `printStatus()` during development to understand usage patterns

## Integration with WeaveDI.Container

DIActor is used internally by WeaveDI.Container for thread-safe operations:

```swift
// WeaveDI.Container uses DIActor under the hood
await WeaveDI.Container.bootstrap { container in
    // This uses DIActor internally
    container.register(UserService.self) {
        UserServiceImpl()
    }
}

// Direct DIActor access for advanced use cases
let service = await DIActor.shared.resolve(UserService.self)
```

## See Also

- [WeaveDI.Container](./coreApis.md) - High-level container API
- [AutoDIOptimizer](./autoDiOptimizer.md) - Automatic optimization system
- [Performance Monitoring](./performanceMonitoring.md) - Performance tracking tools
