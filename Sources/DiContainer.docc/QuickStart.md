# Quick Start Guide

Get up and running with DiContainer in minutes.

## Overview

This guide will help you integrate DiContainer into your project and start using dependency injection immediately.

## Installation

### Swift Package Manager

Add DiContainer to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/DiContainer", from: "2.0.0")
]
```

### Xcode

1. File → Add Package Dependencies
2. Enter: `https://github.com/Roy-wonji/DiContainer`
3. Select version: `2.0.0` or later

## Basic Setup

### 1. Define Your Services

```swift
// Define protocols for your services
protocol UserService {
    func getCurrentUser() async throws -> User
    func updateUser(_ user: User) async throws
}

protocol NetworkService {
    func request<T: Codable>(_ endpoint: String) async throws -> T
}

// Implement your services
class UserServiceImpl: UserService {
    @Inject var networkService: NetworkService

    func getCurrentUser() async throws -> User {
        return try await networkService.request("/user/current")
    }

    func updateUser(_ user: User) async throws {
        try await networkService.request("/user/update")
    }
}

class URLSessionNetworkService: NetworkService {
    func request<T: Codable>(_ endpoint: String) async throws -> T {
        // Implementation using URLSession
        // ...
    }
}
```

### 2. Bootstrap Dependencies

In your `App` or `AppDelegate`:

```swift
@main
struct MyApp: App {
    init() {
        Task {
            await setupDependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupDependencies() async {
        await DependencyContainer.bootstrap { container in
            // Register your services
            container.register(NetworkService.self) {
                URLSessionNetworkService()
            }

            container.register(UserService.self) {
                UserServiceImpl()
            }

            #if DEBUG
            // Use mocks in debug builds
            container.register(NetworkService.self) {
                MockNetworkService()
            }
            #endif
        }
    }
}
```

### 3. Use Dependency Injection

#### With Property Wrappers (Recommended)

```swift
class UserViewController: UIViewController {
    // Automatic injection - will be resolved when accessed
    @Inject var userService: UserService

    // Optional injection - returns nil if not registered
    @Inject var analyticsService: AnalyticsService?

    // Required injection - crashes if not registered (use carefully!)
    @RequiredInject var coreService: CoreService

    override func viewDidLoad() {
        super.viewDidLoad()
        loadUserData()
    }

    private func loadUserData() {
        Task {
            do {
                let user = try await userService.getCurrentUser()
                updateUI(with: user)
            } catch {
                showError(error)
            }
        }
    }
}
```

#### With Direct Resolution

```swift
class UserManager {
    private let userService: UserService

    init() {
        // Resolve dependencies manually when needed
        self.userService = DI.resolve(UserService.self) ?? UserServiceImpl()
    }

    func processUser() async {
        // Use with error handling
        let result = DI.resolveResult(UserService.self)
        switch result {
        case .success(let service):
            try await service.getCurrentUser()
        case .failure(let error):
            print("Failed to resolve UserService: \(error)")
        }
    }
}
```

## Advanced Registration Patterns

### Environment-Based Registration

```swift
await DependencyContainer.bootstrap { container in
    #if DEBUG
    container.register(NetworkService.self) { MockNetworkService() }
    container.register(UserService.self) { MockUserService() }
    #elseif STAGING
    container.register(NetworkService.self) { StagingNetworkService() }
    container.register(UserService.self) { UserServiceImpl() }
    #else
    container.register(NetworkService.self) { ProductionNetworkService() }
    container.register(UserService.self) { UserServiceImpl() }
    #endif
}
```

### Factory-Based Registration

```swift
struct ServiceFactory {
    static func createNetworkService() -> NetworkService {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSessionNetworkService(configuration: config)
    }

    static func createUserService() -> UserService {
        return UserServiceImpl()
    }
}

// Register using factories
await DependencyContainer.bootstrap { container in
    container.register(NetworkService.self) {
        ServiceFactory.createNetworkService()
    }

    container.register(UserService.self) {
        ServiceFactory.createUserService()
    }
}
```

### KeyPath-Based Registration

```swift
extension DependencyContainer {
    var userService: UserService? { resolve(UserService.self) }
    var networkService: NetworkService? { resolve(NetworkService.self) }
}

// Register using KeyPaths for type safety
await DependencyContainer.bootstrap { container in
    let userService = container.register(\.userService) {
        UserServiceImpl()
    }

    let networkService = container.register(\.networkService) {
        URLSessionNetworkService()
    }

    // Services are available immediately after registration
    print("Registered services: \(userService), \(networkService)")
}
```

## Testing Setup

```swift
class UserServiceTests: XCTestCase {
    override func setUp() async throws {
        await super.setUp()

        // Reset DI state for clean tests
        await DependencyContainer.releaseAll()

        // Setup test dependencies
        await DependencyContainer.bootstrap { container in
            container.register(NetworkService.self) {
                MockNetworkService()
            }

            container.register(UserService.self) {
                UserServiceImpl()
            }
        }
    }

    func testGetCurrentUser() async throws {
        let userService: UserService = DI.requireResolve(UserService.self)
        let user = try await userService.getCurrentUser()

        XCTAssertEqual(user.id, "test-user")
    }
}
```

## Common Patterns

### Singleton Services

```swift
// Create singleton instances
let sharedAnalytics = AnalyticsManager()
let sharedCache = CacheManager()

await DependencyContainer.bootstrap { container in
    // Register the same instance - acts as singleton
    container.register(AnalyticsManager.self) { sharedAnalytics }
    container.register(CacheManager.self) { sharedCache }
}
```

### Conditional Registration

```swift
await DependencyContainer.bootstrap { container in
    // Register based on runtime conditions
    if UserDefaults.standard.bool(forKey: "useAnalytics") {
        container.register(AnalyticsService.self) {
            GoogleAnalyticsService()
        }
    } else {
        container.register(AnalyticsService.self) {
            NoOpAnalyticsService()
        }
    }
}
```

## Next Steps

- Learn about <doc:Module-System> for organizing large dependency graphs
- Explore <doc:Bootstrap-System> for advanced initialization patterns
- Understand <doc:Actor-Hop-Optimization> for maximum performance
- Review <doc:Best-Practices> for production-ready applications