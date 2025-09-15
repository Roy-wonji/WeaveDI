# Quick Start Guide

Get up and running with DiContainer in minutes

## Overview

This guide will walk you through the basics of setting up and using DiContainer in your Swift project. We'll cover the essential concepts and provide practical examples to get you started quickly.

## Installation

### Swift Package Manager

Add DiContainer to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/your-repo/DiContainer.git", from: "2.0.0")
]
```

## Basic Setup

### 1. Bootstrap Your Dependencies

The first step is to set up your dependencies at app startup:

```swift
import DiContainer

@main
struct MyApp: App {
    init() {
        Task {
            await setupDependencies()
        }
    }

    private func setupDependencies() async {
        await DependencyContainer.bootstrap { container in
            // Register your dependencies here
            container.register(UserService.self) {
                UserService()
            }

            container.register(NetworkService.self) {
                NetworkService()
            }

            container.register(Logger.self) {
                Logger()
            }
        }
    }
}
```

### 2. Define Your Dependencies

Create your dependency interfaces and implementations:

```swift
// Protocol definition
protocol UserService {
    func fetchUser(id: String) async throws -> User
}

// Implementation
class UserServiceImpl: UserService {
    @Inject var networkService: NetworkService?
    @RequiredInject var logger: Logger

    func fetchUser(id: String) async throws -> User {
        logger.info("Fetching user with id: \(id)")

        guard let network = networkService else {
            throw DIError.dependencyNotFound(NetworkService.self)
        }

        return try await network.fetchUser(id: id)
    }
}
```

### 3. Use Dependencies in Your Views

Inject dependencies into your SwiftUI views or UIKit controllers:

```swift
// SwiftUI View
struct UserProfileView: View {
    @Inject var userService: UserService?
    @State private var user: User?

    let userId: String

    var body: some View {
        VStack {
            if let user = user {
                Text("Hello, \(user.name)!")
            } else {
                ProgressView("Loading...")
            }
        }
        .task {
            await loadUser()
        }
    }

    private func loadUser() async {
        do {
            user = try await userService?.fetchUser(id: userId)
        } catch {
            print("Failed to load user: \(error)")
        }
    }
}

// UIKit Controller
class UserViewController: UIViewController {
    @RequiredInject var userService: UserService
    @Inject var logger: Logger?

    override func viewDidLoad() {
        super.viewDidLoad()

        Task {
            do {
                let user = try await userService.fetchUser(id: "123")
                await MainActor.run {
                    updateUI(with: user)
                }
                logger?.info("User loaded successfully")
            } catch {
                logger?.error("Failed to load user: \(error)")
            }
        }
    }
}
```

## Advanced Registration

### Using UnifiedDI for Complex Scenarios

For more advanced use cases, use the UnifiedDI API:

```swift
// Conditional registration
UnifiedDI.registerIf(
    AnalyticsService.self,
    condition: !isDebugMode,
    factory: { GoogleAnalytics() },
    fallback: { NoOpAnalytics() }
)

// Batch registration
UnifiedDI.registerMany {
    Registration(APIClient.self) { URLSessionAPIClient() }
    Registration(DatabaseService.self) { CoreDataService() }
    Registration(CacheService.self) { NSCacheService() }
}

// Direct resolution
let service = UnifiedDI.resolve(UserService.self, default: MockUserService())
```

### Environment-Based Configuration

Configure different dependencies for different environments:

```swift
private func setupEnvironmentDependencies() async {
    await DependencyContainer.bootstrap { container in
        #if DEBUG
        container.register(APIClient.self) { MockAPIClient() }
        container.register(Logger.self) { ConsoleLogger(level: .debug) }
        #else
        container.register(APIClient.self) { ProductionAPIClient() }
        container.register(Logger.self) { CloudLogger(level: .info) }
        #endif

        // Common dependencies
        container.register(UserService.self) { UserServiceImpl() }
        container.register(DatabaseService.self) { CoreDataService() }
    }
}
```

## Property Wrapper Guide

### @Inject vs @RequiredInject

Choose the right property wrapper for your needs:

```swift
class MyService {
    // Optional injection - returns nil if not registered
    @Inject var optionalService: OptionalService?

    // Required injection - crashes with clear error if not registered
    @RequiredInject var requiredService: RequiredService

    // You can also specify default values
    @Inject var serviceWithDefault: ServiceProtocol? = DefaultService()
}
```

### KeyPath-Based Injection

For more explicit dependency management, use KeyPath-based registration:

```swift
// Extend DependencyContainer with your dependencies
extension DependencyContainer {
    var userService: UserService? { resolve(UserService.self) }
    var networkService: NetworkService? { resolve(NetworkService.self) }
}

// Register using KeyPath
let service = DI.register(\.userService) { UserServiceImpl() }

// Inject using KeyPath
class MyController {
    @Inject(\.userService) var userService: UserService?
}
```

## Testing Setup

### Mock Dependencies for Testing

Set up clean testing environments:

```swift
class UserServiceTests: XCTestCase {
    var userService: UserService!
    var mockNetwork: MockNetworkService!

    override func setUp() async throws {
        await super.setUp()

        // Reset DI container for clean testing
        await DependencyContainer.resetForTesting()

        // Register mock dependencies
        mockNetwork = MockNetworkService()

        await DependencyContainer.bootstrap { container in
            container.register(NetworkService.self) { self.mockNetwork }
            container.register(Logger.self) { MockLogger() }
        }

        userService = UserServiceImpl()
    }

    func testFetchUser() async throws {
        // Given
        let expectedUser = User(id: "123", name: "Test User")
        mockNetwork.mockUser = expectedUser

        // When
        let user = try await userService.fetchUser(id: "123")

        // Then
        XCTAssertEqual(user.id, expectedUser.id)
        XCTAssertEqual(user.name, expectedUser.name)
    }
}
```

## Performance Tips

### 1. Use Actor Hop Optimization

DiContainer automatically optimizes Actor transitions, but you can help by structuring your code properly:

```swift
@MainActor
class ViewController {
    @Inject var service: MyService?

    func loadData() {
        // This is optimized - no unnecessary actor hops
        Task {
            let data = await service?.fetchData()
            updateUI(with: data) // Already on MainActor
        }
    }
}
```

### 2. Lazy Registration for Heavy Objects

For expensive-to-create objects, consider lazy initialization:

```swift
// Heavy object that should be created only when needed
UnifiedDI.register(ExpensiveService.self) {
    // This closure is only called when the service is first resolved
    ExpensiveService()
}
```

### 3. Memory Management

Be mindful of retain cycles:

```swift
class ServiceA {
    @Inject weak var serviceB: ServiceB? // Use weak for optional dependencies that might create cycles
    @RequiredInject var serviceC: ServiceC // Strong reference for required dependencies
}
```

## Next Steps

- Read the [Core APIs](CoreAPIs.md) guide for detailed API documentation
- Learn about [Actor Hop Optimization](ActorHopOptimization.md) for performance tuning
- Explore the [Plugin System](PluginSystem.md) for extensibility
- Check out [Property Wrappers](PropertyWrappers.md) for advanced injection patterns

## Common Patterns

### Repository Pattern

```swift
protocol UserRepository {
    func fetchUser(id: String) async throws -> User
}

class UserRepositoryImpl: UserRepository {
    @RequiredInject var apiClient: APIClient
    @Inject var cacheService: CacheService?

    func fetchUser(id: String) async throws -> User {
        // Check cache first
        if let cached = cacheService?.getUser(id: id) {
            return cached
        }

        // Fetch from API
        let user = try await apiClient.fetchUser(id: id)

        // Cache the result
        cacheService?.setUser(user, id: id)

        return user
    }
}

// Register in bootstrap
container.register(UserRepository.self) { UserRepositoryImpl() }
```

### Service Layer Pattern

```swift
class UserService {
    @RequiredInject var repository: UserRepository
    @RequiredInject var validator: UserValidator
    @Inject var analytics: AnalyticsService?

    func updateUser(_ user: User) async throws {
        try validator.validate(user)
        try await repository.updateUser(user)
        analytics?.track("user_updated", parameters: ["user_id": user.id])
    }
}
```

You're now ready to use DiContainer in your project! The framework handles the complexity of dependency management while providing you with a clean, type-safe API.