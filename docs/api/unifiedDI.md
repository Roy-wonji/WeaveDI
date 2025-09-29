# UnifiedDI API Reference

The `UnifiedDI` class provides a simplified, static interface for dependency injection in WeaveDI. It acts as a convenient wrapper around the underlying `WeaveDI.Container` system.

## Overview

`UnifiedDI` is designed for developers who want a simple, straightforward API without dealing with container management directly. It provides static methods for registration and resolution.

```swift
import WeaveDI

// Simple registration
UnifiedDI.register(UserService.self) { UserServiceImpl() }

// Simple resolution
let userService = UnifiedDI.resolve(UserService.self)
```

## Core Methods

### Registration

#### `register(_:factory:)`

**Purpose**: Registers a dependency with immediate factory execution, creating the instance during registration and storing it for future resolution. This is ideal for eager initialization of critical services.

**When to use**:
- **Critical Services**: Services that must be available immediately
- **Expensive Initialization**: Services with costly setup that should happen once
- **Validation**: When you want to verify service creation during app startup
- **Singleton Pattern**: For services that should exist as single instances

**Performance Characteristics**:
- **Memory**: Instance is created immediately and held in memory
- **Startup Time**: May increase app startup time but improves later resolution speed
- **Thread Safety**: Registration is thread-safe but factory execution happens once

**Memory Management**:
- Instance is retained by the container until app termination
- Consider weak references for large objects if appropriate
- Automatic cleanup when container is reset

```swift
@discardableResult
static func register<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) -> T where T: Sendable
```

**Parameters:**
- `type: T.Type` - The protocol or class type to register. Must conform to `Sendable` for thread safety.
- `factory: @escaping @Sendable () -> T` - A closure that creates the instance. Executed immediately during registration.

**Returns:**
- `T` - The created instance, allowing immediate use after registration.

**Example:**
```swift
let userService = UnifiedDI.register(UserService.self) {
    print("Creating UserService...")
    return UserServiceImpl()
}
// userService is immediately available
```

#### `register(_:build:)`

Registers a dependency with lazy factory execution.

```swift
@discardableResult
static func register<T>(_ type: T.Type, build factory: @escaping @Sendable () -> T) -> @Sendable () -> Void where T: Sendable
```

**Parameters:**
- `type`: The protocol or class type to register
- `factory`: A closure that creates the instance (executed on resolve)

**Returns:** A release handler function

**Example:**
```swift
let releaseHandler = UnifiedDI.register(ExpensiveService.self, build: {
    print("Creating expensive service...")
    return ExpensiveServiceImpl()
})

// Service is created only when first resolved
let service = UnifiedDI.resolve(ExpensiveService.self)
```

### Resolution

#### `resolve(_:)`

Resolves a dependency from the container.

```swift
static func resolve<T>(_ type: T.Type) -> T?
```

**Parameters:**
- `type`: The type to resolve

**Returns:** The resolved instance or `nil` if not registered

**Example:**
```swift
if let userService = UnifiedDI.resolve(UserService.self) {
    let user = userService.getCurrentUser()
} else {
    print("UserService not registered")
}
```

#### `resolveOrDefault(_:default:)`

Resolves a dependency or returns a default value.

```swift
static func resolveOrDefault<T>(_ type: T.Type, default defaultValue: @autoclosure () -> T) -> T
```

**Parameters:**
- `type`: The type to resolve
- `defaultValue`: Default value if resolution fails

**Returns:** The resolved instance or default value

**Example:**
```swift
let userService = UnifiedDI.resolveOrDefault(
    UserService.self,
    default: MockUserService()
)
```

## Advanced Usage

### Dependency Chains

UnifiedDI automatically handles dependency injection when dependencies are resolved within factory closures:

```swift
// Register dependencies in order
UnifiedDI.register(NetworkClient.self) {
    URLSessionNetworkClient()
}

UnifiedDI.register(UserRepository.self) {
    let networkClient = UnifiedDI.resolve(NetworkClient.self) ?? URLSessionNetworkClient()
    return UserRepositoryImpl(networkClient: networkClient)
}

UnifiedDI.register(UserService.self) {
    let repository = UnifiedDI.resolve(UserRepository.self) ?? MockUserRepository()
    return UserServiceImpl(repository: repository)
}
```

### Thread Safety

All UnifiedDI operations are thread-safe and can be called from any queue:

```swift
// Safe to call from background queue
DispatchQueue.global().async {
    let service = UnifiedDI.resolve(BackgroundService.self)
    service?.performBackgroundWork()
}
```

### Performance Optimization

UnifiedDI automatically tracks usage patterns and applies optimizations:

```swift
// Frequently used services are automatically optimized
for _ in 0..<100 {
    let service = UnifiedDI.resolve(FrequentlyUsedService.self)
    // WeaveDI automatically optimizes this lookup
}
```

## Integration with Property Wrappers

UnifiedDI works seamlessly with WeaveDI property wrappers:

```swift
class ViewController: UIViewController {
    @Inject var userService: UserService?

    override func viewDidLoad() {
        super.viewDidLoad()

        // The @Inject wrapper uses UnifiedDI.resolve internally
        userService?.loadUserData()
    }
}
```

## Best Practices

### 1. Register Early
Register all dependencies during app startup:

```swift
@main
struct MyApp: App {
    init() {
        setupDependencies()
    }

    private func setupDependencies() {
        UnifiedDI.register(UserService.self) { UserServiceImpl() }
        UnifiedDI.register(DataManager.self) { CoreDataManager() }
    }
}
```

### 2. Use Protocols
Always register against protocols for better testability:

```swift
// Good ✅
UnifiedDI.register(UserServiceProtocol.self) { UserServiceImpl() }

// Avoid ❌
UnifiedDI.register(UserServiceImpl.self) { UserServiceImpl() }
```

### 3. Handle Resolution Failures
Always handle the case where resolution returns nil:

```swift
// Good ✅
guard let userService = UnifiedDI.resolve(UserService.self) else {
    fatalError("UserService not registered")
}

// Or use resolveOrDefault
let userService = UnifiedDI.resolveOrDefault(
    UserService.self,
    default: MockUserService()
)
```

## Error Handling

UnifiedDI provides several ways to handle registration and resolution errors:

```swift
// Check if a type is registered
if UnifiedDI.resolve(OptionalService.self) != nil {
    print("OptionalService is available")
}

// Use resolveOrDefault for fallback behavior
let logger = UnifiedDI.resolveOrDefault(
    Logger.self,
    default: ConsoleLogger()
)

// Handle missing dependencies gracefully
func performAction() {
    guard let service = UnifiedDI.resolve(RequiredService.self) else {
        print("Cannot perform action: RequiredService not available")
        return
    }
    service.execute()
}
```

## Migration from WeaveDI.Container

If you're migrating from direct `WeaveDI.Container` usage:

```swift
// Old way
let service = WeaveDI.Container.shared.register(UserService.self) {
    UserServiceImpl()
}

// New way with UnifiedDI
let service = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}
```

## See Also

- [WeaveDI.Container API](./coreApis.md) - Lower-level container API
- [Bootstrap](./bootstrap.md) - Initialization patterns
- [@Inject Property Wrapper](./inject.md) - Automatic dependency injection