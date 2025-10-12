# UnifiedDI

## Overview

`UnifiedDI` is a modern and intuitive dependency injection API. It focuses on core functionality while removing complex features, making it easy to understand and use.

## Design Philosophy

- **Simplicity First**: Clear API over complex features
- **Type Safety**: All errors verified at compile time
- **Intuitive Usage**: API that's self-explanatory from the code

## Basic Usage

```swift
// 1. Register and use immediately
let repository = UnifiedDI.register(UserRepository.self) {
    UserRepositoryImpl()
}

// 2. Resolve later
let service = UnifiedDI.resolve(UserService.self)

// 3. Required dependency (crashes if not found)
let logger = UnifiedDI.requireResolve(Logger.self)
```

## Core API

### Registration Methods

#### `register(_:factory:)`

Register a dependency and return the created instance immediately (recommended approach).

```swift
public static func register<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () -> T
) -> T where T: Sendable
```

**Usage:**
```swift
let repository = UnifiedDI.register(UserRepository.self) {
    UserRepositoryImpl()
}
// repository is immediately available for use
```

#### `registerAsync(_:factory:)`

Register dependencies asynchronously using `@DIContainerActor` for thread-safe registration.

```swift
public static func registerAsync<T>(
    _ type: T.Type,
    factory: @escaping @Sendable () async -> T
) async -> T where T: Sendable
```

**Usage:**
```swift
Task {
    let instance = await UnifiedDI.registerAsync(UserService.self) {
        UserServiceImpl()
    }
    // instance is immediately available for use
}
```

### Resolution Methods

#### `resolve(_:)`

Safely resolve a dependency, returning `nil` if not registered.

```swift
public static func resolve<T>(_ type: T.Type) -> T? where T: Sendable
```

**Usage:**
```swift
if let service = UnifiedDI.resolve(UserService.self) {
    // Use service
} else {
    // Handle fallback logic
}
```

#### `resolveAsync(_:)`

Asynchronously resolve dependencies using `@DIContainerActor`.

```swift
public static func resolveAsync<T>(_ type: T.Type) async -> T? where T: Sendable
```

**Usage:**
```swift
Task {
    if let service = await UnifiedDI.resolveAsync(UserService.self) {
        // Use service
    }
}
```

#### `requireResolve(_:)`

Resolve required dependencies, crashing with a clear error message if not found.

```swift
public static func requireResolve<T>(_ type: T.Type) -> T where T: Sendable
```

**⚠️ Note:** Use `resolve(_:)` in production environments for safer handling.

**Usage:**
```swift
let logger = UnifiedDI.requireResolve(Logger.self)
// logger is always a valid instance
```

#### `resolve(_:default:)`

Resolve dependencies with a fallback default value (always succeeds).

```swift
public static func resolve<T>(
    _ type: T.Type,
    default defaultValue: @autoclosure () -> T
) -> T where T: Sendable
```

**Usage:**
```swift
let logger = UnifiedDI.resolve(Logger.self, default: ConsoleLogger())
// logger is always a valid instance
```

### Management Methods

#### `release(_:)`

Remove a specific dependency from the container.

```swift
public static func release<T>(_ type: T.Type) where T: Sendable
```

**Usage:**
```swift
UnifiedDI.release(UserService.self)
// Subsequent resolve calls will return nil
```

#### `releaseAll()`

Remove all registered dependencies (primarily for testing).

```swift
public static func releaseAll()
```

**⚠️ Note:** Should only be called from the main thread.

**Usage:**
```swift
// In test setUp
override func setUp() {
    super.setUp()
    UnifiedDI.releaseAll()
}
```

## Advanced Features

### Performance Optimization

UnifiedDI includes built-in performance optimization features:

```swift
// Enable performance tracking (debug mode only)
#if DEBUG && DI_MONITORING_ENABLED
UnifiedDI.enableOptimization()
let stats = await UnifiedDI.getPerformanceStats()
#endif
```

### Component Diagnostics

Automatic detection of configuration issues:

```swift
let diagnostics = UnifiedDI.analyzeComponentMetadata()
if !diagnostics.issues.isEmpty {
    print("⚠️ Configuration issues found:")
    for issue in diagnostics.issues {
        print("  - \(issue.type): \(issue.detail ?? "")")
    }
}
```

## Integration Examples

### SwiftUI Integration

```swift
import SwiftUI

struct ContentView: View {
    private let userService = UnifiedDI.resolve(
        UserService.self,
        default: MockUserService()
    )

    var body: some View {
        Text("User: \(userService.currentUser.name)")
    }
}
```

### TCA Integration

```swift
import ComposableArchitecture

struct AppFeature: Reducer {
    struct State: Equatable {
        // State definition
    }

    enum Action {
        // Action definition
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            let userService = UnifiedDI.requireResolve(UserService.self)
            // Use userService
            return .none
        }
    }
}
```

### Testing Setup

```swift
import XCTest
import WeaveDI

class UserServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()

        // Clear previous registrations
        UnifiedDI.releaseAll()

        // Register test dependencies
        _ = UnifiedDI.register(UserRepository.self) {
            MockUserRepository()
        }

        _ = UnifiedDI.register(UserService.self) {
            UserServiceImpl(
                repository: UnifiedDI.requireResolve(UserRepository.self)
            )
        }
    }

    func testUserCreation() {
        let service = UnifiedDI.requireResolve(UserService.self)
        let user = service.createUser(name: "Test User")
        XCTAssertEqual(user.name, "Test User")
    }
}
```

## Error Handling

### Common Error Patterns

```swift
// ❌ Avoid: This will crash if not registered
let service = UnifiedDI.requireResolve(UnregisteredService.self)

// ✅ Better: Safe resolution with fallback
let service = UnifiedDI.resolve(UnregisteredService.self) ?? DefaultService()

// ✅ Best: Resolution with default value
let service = UnifiedDI.resolve(UnregisteredService.self, default: DefaultService())
```

### Debug Information

```swift
#if DEBUG
// Check if a dependency is registered
if UnifiedDI.resolve(SomeService.self) == nil {
    print("⚠️ SomeService is not registered")
}

// Analyze configuration issues
let diagnostics = UnifiedDI.analyzeComponentMetadata()
for issue in diagnostics.issues {
    print("🔍 Issue: \(issue.type) - \(issue.detail ?? "")")
}
#endif
```

## Best Practices

### 1. Registration Order

Register dependencies in dependency order (dependencies first):

```swift
// ✅ Good: Register dependencies first
_ = UnifiedDI.register(APIClient.self) {
    APIClientImpl()
}

_ = UnifiedDI.register(UserRepository.self) {
    UserRepositoryImpl(
        apiClient: UnifiedDI.requireResolve(APIClient.self)
    )
}

_ = UnifiedDI.register(UserService.self) {
    UserServiceImpl(
        repository: UnifiedDI.requireResolve(UserRepository.self)
    )
}
```

### 2. Use Safe Resolution in Production

```swift
// ✅ Production: Safe resolution
guard let service = UnifiedDI.resolve(CriticalService.self) else {
    // Handle gracefully
    return
}

// ✅ Development: Fail fast for debugging
#if DEBUG
let service = UnifiedDI.requireResolve(CriticalService.self)
#else
guard let service = UnifiedDI.resolve(CriticalService.self) else {
    // Fallback logic
    return
}
#endif
```

### 3. Centralized Registration

```swift
enum DependencyContainer {
    static func registerAll() {
        registerNetworking()
        registerRepositories()
        registerServices()
    }

    private static func registerNetworking() {
        _ = UnifiedDI.register(HTTPClient.self) {
            URLSessionHTTPClient()
        }

        _ = UnifiedDI.register(APIClient.self) {
            APIClientImpl(
                httpClient: UnifiedDI.requireResolve(HTTPClient.self)
            )
        }
    }

    private static func registerRepositories() {
        _ = UnifiedDI.register(UserRepository.self) {
            UserRepositoryImpl(
                apiClient: UnifiedDI.requireResolve(APIClient.self)
            )
        }
    }

    private static func registerServices() {
        _ = UnifiedDI.register(UserService.self) {
            UserServiceImpl(
                repository: UnifiedDI.requireResolve(UserRepository.self)
            )
        }
    }
}
```

## Related APIs

- [`@Injected`](./injected.md) - Property wrapper for dependency injection
- [`DIAdvanced`](./diAdvanced.md) - Advanced dependency injection features
- [`ComponentDiagnostics`](./componentDiagnostics.md) - Automatic issue detection
- [`Performance Optimization`](./performanceOptimizations.md) - Performance monitoring and optimization

---

*UnifiedDI is the recommended API for dependency injection in WeaveDI v3.3.0+*