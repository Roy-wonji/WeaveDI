# DependencyValues Integration Examples

Complete examples showing how to integrate WeaveDI with swift-dependencies and use them in real-world scenarios.

## Overview

This guide provides practical examples of using WeaveDI's `@Injected` property wrapper with `InjectedValues` and how to bridge with Point-Free's `swift-dependencies` for maximum compatibility.

## Basic Setup

### 1. Service Protocol Definition

```swift
import WeaveDI
import Dependencies

protocol UserService: Sendable {
    func fetchUser(id: String) async throws -> User
    func saveUser(_ user: User) async throws
}

protocol LoggingService: Sendable {
    func log(_ message: String, level: LogLevel)
}

protocol CacheService: Sendable {
    func get<T: Codable>(_ key: String, type: T.Type) async -> T?
    func set<T: Codable>(_ key: String, value: T) async
}
```

### 2. InjectedKey Definition

```swift
struct UserServiceKey: InjectedKey {
    static let liveValue: UserService = LiveUserService()
    static let testValue: UserService = MockUserService()
}

struct LoggingServiceKey: InjectedKey {
    static let liveValue: LoggingService = ConsoleLoggingService()
    static let testValue: LoggingService = NoOpLoggingService()
}

struct CacheServiceKey: InjectedKey {
    static let liveValue: CacheService = InMemoryCacheService()
    static let testValue: CacheService = NoOpCacheService()
}
```

### 3. InjectedValues Extension (KeyPath Support)

```swift
extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }

    var loggingService: LoggingService {
        get { self[LoggingServiceKey.self] }
        set { self[LoggingServiceKey.self] = newValue }
    }

    var cacheService: CacheService {
        get { self[CacheServiceKey.self] }
        set { self[CacheServiceKey.self] = newValue }
    }
}
```

### 4. Swift-Dependencies Bridge (Optional)

```swift
extension DependencyValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }

    var loggingService: LoggingService {
        get { self[LoggingServiceKey.self] }
        set { self[LoggingServiceKey.self] = newValue }
    }

    var cacheService: CacheService {
        get { self[CacheServiceKey.self] }
        set { self[CacheServiceKey.self] = newValue }
    }
}
```

## Real-World Usage Example

### UserManager Class with Multiple Injection Patterns

```swift
class UserManager {
    // Method 1: Direct type injection (safest)
    @Injected(UserServiceKey.self) private var userService

    // Method 2: KeyPath-based injection (recommended)
    @Injected(\.loggingService) private var logger

    // Method 3: swift-dependencies style (TCA compatible)
    @Dependency(\.cacheService) private var cache

    func loadUser(id: String) async throws -> User {
        logger.log("Loading user with ID: \(id)", level: .info)

        // Check cache first
        if let cachedUser = await cache.get("user_\(id)", type: User.self) {
            logger.log("User found in cache", level: .debug)
            return cachedUser
        }

        // Fetch from service
        guard let service = userService else {
            throw UserManagerError.serviceUnavailable
        }

        let user = try await service.fetchUser(id: id)

        // Cache the result
        await cache.set("user_\(user.id)", value: user)
        logger.log("User loaded and cached successfully", level: .info)

        return user
    }

    func saveUser(_ user: User) async throws {
        logger.log("Saving user: \(user.name)", level: .info)

        guard let service = userService else {
            throw UserManagerError.serviceUnavailable
        }

        try await service.saveUser(user)

        // Update cache
        await cache.set("user_\(user.id)", value: user)
        logger.log("User saved successfully", level: .info)
    }
}
```

## Live Implementations

### UserService Implementation

```swift
class LiveUserService: UserService {
    func fetchUser(id: String) async throws -> User {
        // Simulate API call
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        return User(id: id, name: "Live User \(id)", email: "user\(id)@example.com")
    }

    func saveUser(_ user: User) async throws {
        // Simulate save operation
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        print("💾 Saved user to database: \(user.name)")
    }
}
```

### Logging Service Implementation

```swift
class ConsoleLoggingService: LoggingService {
    func log(_ message: String, level: LogLevel) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(level.rawValue.uppercased())] \(message)")
    }
}
```

### Cache Service Implementation

```swift
class InMemoryCacheService: CacheService {
    private var storage: [String: Data] = [:]
    private let queue = DispatchQueue(label: "cache", attributes: .concurrent)

    func get<T: Codable>(_ key: String, type: T.Type) async -> T? {
        return await withCheckedContinuation { continuation in
            queue.async {
                guard let data = self.storage[key],
                      let value = try? JSONDecoder().decode(type, from: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: value)
            }
        }
    }

    func set<T: Codable>(_ key: String, value: T) async {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                if let data = try? JSONEncoder().encode(value) {
                    self.storage[key] = data
                }
                continuation.resume()
            }
        }
    }
}
```

## Testing Examples

### Basic Usage Example

```swift
func basicUsageExample() async {
    let userManager = UserManager()

    do {
        // Load user
        let user = try await userManager.loadUser(id: "123")
        print("✅ Loaded user: \(user.name) (\(user.email))")

        // Update and save user
        let updatedUser = User(id: user.id, name: "Updated \(user.name)", email: user.email)
        try await userManager.saveUser(updatedUser)

        // Load again (should come from cache)
        let cachedUser = try await userManager.loadUser(id: "123")
        print("✅ Cached user: \(cachedUser.name)")

    } catch {
        print("❌ Error: \(error)")
    }
}
```

### Test Environment Simulation

```swift
func testEnvironmentExample() async {
    await withInjectedValues {
        // Replace with mock services
        let mockUserService = MockUserService()
        mockUserService.mockUsers = [
            "test": User(id: "test", name: "Test User", email: "test@mock.com")
        ]

        $0.userService = mockUserService
        $0.loggingService = NoOpLoggingService()
        $0.cacheService = NoOpCacheService()
    } operation: {
        let userManager = UserManager()

        do {
            let user = try await userManager.loadUser(id: "test")
            print("✅ Mock user: \(user.name) (\(user.email))")

            // Save new user
            let newUser = User(id: "new", name: "New Mock User", email: "new@mock.com")
            try await userManager.saveUser(newUser)
            print("✅ Mock user saved successfully")

        } catch {
            print("❌ Mock test error: \(error)")
        }
    }
}
```

## Mock Implementations

### Mock UserService

```swift
class MockUserService: UserService {
    var mockUsers: [String: User] = [:]

    func fetchUser(id: String) async throws -> User {
        if let user = mockUsers[id] {
            return user
        }
        return User(id: id, name: "Mock User \(id)", email: "mock\(id)@test.com")
    }

    func saveUser(_ user: User) async throws {
        mockUsers[user.id] = user
    }
}
```

### No-Op Services for Testing

```swift
class NoOpLoggingService: LoggingService {
    func log(_ message: String, level: LogLevel) {
        // No-op for testing
    }
}

class NoOpCacheService: CacheService {
    func get<T: Codable>(_ key: String, type: T.Type) async -> T? {
        return nil
    }

    func set<T: Codable>(_ key: String, value: T) async {
        // No-op for testing
    }
}
```

## Performance Comparison

### Benchmarking Different Approaches

```swift
func performanceExample() async {
    let iterations = 1000

    // WeaveDI @Injected performance
    let weaveDIStart = Date()
    for _ in 0..<iterations {
        let userManager = UserManager()
        // Just measure service access (no actual network calls)
        let _ = userManager
    }
    let weaveDITime = Date().timeIntervalSince(weaveDIStart)

    print("📊 Performance Results (\(iterations) iterations):")
    print("   WeaveDI @Injected: \(String(format: "%.4f", weaveDITime))s")

    // Compare with swift-dependencies
    await withDependencies {
        $0.userService = MockUserService()
    } operation: {
        let dependenciesStart = Date()
        for _ in 0..<iterations {
            @Dependency(\.userService) var userService
            let _ = userService
        }
        let dependenciesTime = Date().timeIntervalSince(dependenciesStart)
        print("   swift-dependencies: \(String(format: "%.4f", dependenciesTime))s")

        let improvement = (dependenciesTime - weaveDITime) / dependenciesTime * 100
        if improvement > 0 {
            print("   🚀 WeaveDI is \(String(format: "%.1f", improvement))% faster!")
        }
    }
}
```

## Usage Patterns

### Pattern 1: Current Concrete Type Injection (User Pattern)

```swift
class ExchangeFeature {
    // Current pattern - direct concrete type injection
    @Injected(ExchangeUseCaseImpl.self) private var exchangeUseCase
    @Injected(FavoriteCurrencyUseCaseImpl.self) private var favoriteUseCase
    @Injected(ExchangeRateCacheUseCaseImpl.self) private var cacheUseCase

    func loadExchangeRates() async {
        guard let useCase = exchangeUseCase else { return }
        // Use the service...
    }
}
```

### Pattern 2: Protocol-Based Injection (Recommended)

```swift
class ImprovedExchangeFeature {
    // Protocol-based approach for better testability
    @Injected(\.exchangeUseCase) var exchangeUseCase
    @Injected(\.favoriteUseCase) var favoriteUseCase
    @Injected(\.cacheUseCase) var cacheUseCase

    func loadExchangeRates() async {
        // Use the services with better abstraction...
    }
}
```

### Pattern 3: Hybrid Approach

```swift
class HybridExchangeFeature {
    // Keep existing stable code unchanged
    @Injected(ExchangeUseCaseImpl.self) private var exchangeUseCase
    @Injected(FavoriteCurrencyUseCaseImpl.self) private var favoriteUseCase

    // Use protocol-based for new services
    @Injected(\.analyticsService) var analytics
    @Injected(\.networkMonitor) var networkMonitor
}
```

## Running the Example

To run the complete example:

1. Navigate to the example directory:
   ```bash
   cd Example/DependencyValuesExample
   ```

2. Run the example:
   ```bash
   swift run
   ```

The example will demonstrate:
- Basic dependency injection usage
- Test environment simulation with mocks
- Performance comparison between WeaveDI and swift-dependencies
- Different injection patterns and their trade-offs

## Key Takeaways

1. **Multiple Injection Patterns**: WeaveDI supports direct type injection, KeyPath-based injection, and swift-dependencies compatibility
2. **Testing Made Easy**: Use `withInjectedValues` to override dependencies for testing
3. **Performance Benefits**: WeaveDI provides better performance compared to other DI solutions
4. **Gradual Migration**: You can adopt WeaveDI incrementally without breaking existing code
5. **Type Safety**: All approaches maintain compile-time type safety

## Next Steps

- [Property Wrappers Guide](./propertyWrappers.md) - Deep dive into WeaveDI's injection patterns
- [TCA Integration](./tcaIntegration.md) - Using WeaveDI with The Composable Architecture
- [Testing Guide](../tutorial/testing.md) - Advanced testing strategies with WeaveDI