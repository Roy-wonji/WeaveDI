# Multi-Module Projects

Learn how to use WeaveDI in multi-module Swift projects with SPM (Swift Package Manager).

## Overview

Multi-module architecture provides:
- **Better separation of concerns**
- **Faster compilation** (only changed modules rebuild)
- **Improved code reusability**
- **Clearer dependency boundaries**

WeaveDI is designed to work seamlessly across module boundaries while maintaining type safety and performance.

## Project Structure

### Typical Multi-Module Setup

```
MyApp/
├── Package.swift
├── App/                    # Main application target
│   └── Sources/
│       └── MyApp.swift
├── Features/
│   ├── UserFeature/       # Feature module
│   │   └── Sources/
│   ├── OrderFeature/      # Feature module
│   │   └── Sources/
│   └── PaymentFeature/    # Feature module
│       └── Sources/
├── Core/
│   ├── Networking/        # Infrastructure module
│   │   └── Sources/
│   ├── Database/          # Infrastructure module
│   │   └── Sources/
│   └── SharedModels/      # Shared types
│       └── Sources/
└── DI/                    # Dependency injection module
    └── Sources/
```

## Package.swift Configuration

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [
        .iOS(.v15),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MyApp", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.2.0")
    ],
    targets: [
        // App Target
        .executableTarget(
            name: "App",
            dependencies: [
                "UserFeature",
                "OrderFeature",
                "PaymentFeature",
                "DI"
            ]
        ),

        // Feature Modules
        .target(
            name: "UserFeature",
            dependencies: [
                "Networking",
                "SharedModels",
                .product(name: "WeaveDI", package: "WeaveDI")
            ]
        ),
        .target(
            name: "OrderFeature",
            dependencies: [
                "Networking",
                "SharedModels",
                .product(name: "WeaveDI", package: "WeaveDI")
            ]
        ),
        .target(
            name: "PaymentFeature",
            dependencies: [
                "Networking",
                "SharedModels",
                .product(name: "WeaveDI", package: "WeaveDI")
            ]
        ),

        // Core Modules
        .target(
            name: "Networking",
            dependencies: [
                .product(name: "WeaveDI", package: "WeaveDI")
            ]
        ),
        .target(
            name: "Database",
            dependencies: [
                .product(name: "WeaveDI", package: "WeaveDI")
            ]
        ),
        .target(
            name: "SharedModels",
            dependencies: []
        ),

        // DI Module
        .target(
            name: "DI",
            dependencies: [
                "UserFeature",
                "OrderFeature",
                "PaymentFeature",
                "Networking",
                "Database",
                .product(name: "WeaveDI", package: "WeaveDI")
            ]
        ),

        // Tests
        .testTarget(
            name: "UserFeatureTests",
            dependencies: ["UserFeature"]
        )
    ]
)
```

## Dependency Management Patterns

### Pattern 1: Centralized DI Module

**Best for:** Small to medium projects

Create a dedicated `DI` module that knows about all feature modules and configures dependencies.

```swift
// DI/Sources/DI.swift
import WeaveDI
import UserFeature
import OrderFeature
import PaymentFeature
import Networking
import Database

public final class AppDI {
    public static func bootstrap() async {
        await WeaveDI.Container.bootstrap { container in
            // Infrastructure
            container.register(APIClient.self) {
                URLSessionAPIClient(baseURL: Configuration.apiBaseURL)
            }

            container.register(Database.self) {
                RealmDatabase()
            }

            // Feature dependencies
            UserFeatureModule.register(in: container)
            OrderFeatureModule.register(in: container)
            PaymentFeatureModule.register(in: container)
        }
    }
}
```

```swift
// UserFeature/Sources/UserFeatureModule.swift
import WeaveDI

public struct UserFeatureModule {
    public static func register(in container: WeaveDI.Container) {
        container.register(UserService.self) {
            UserServiceImpl()
        }

        container.register(UserRepository.self) {
            UserRepositoryImpl()
        }
    }
}
```

### Pattern 2: Decentralized Module Registration

**Best for:** Large projects with independent teams

Each feature module exposes its own registration method.

```swift
// UserFeature/Sources/UserFeatureDI.swift
import WeaveDI

public protocol UserFeatureDependencies {
    var apiClient: APIClient { get }
    var database: Database { get }
}

public struct UserFeatureModule {
    public static func bootstrap(
        dependencies: UserFeatureDependencies
    ) async {
        // Register feature-specific dependencies
        await WeaveDI.Container.bootstrap { container in
            // Use provided dependencies
            container.register(APIClient.self) {
                dependencies.apiClient
            }

            // Register feature services
            container.register(UserService.self) {
                UserServiceImpl()
            }
        }
    }
}
```

```swift
// App/Sources/AppDI.swift
import UserFeature
import OrderFeature

struct AppDependencies: UserFeatureDependencies, OrderFeatureDependencies {
    let apiClient: APIClient
    let database: Database

    init() {
        self.apiClient = URLSessionAPIClient(baseURL: Config.apiURL)
        self.database = RealmDatabase()
    }
}

@main
struct MyApp: App {
    init() {
        let deps = AppDependencies()

        Task {
            await UserFeatureModule.bootstrap(dependencies: deps)
            await OrderFeatureModule.bootstrap(dependencies: deps)
        }
    }
}
```

### Pattern 3: Protocol-Based Module Boundaries

**Best for:** Maximum flexibility and testability

Define protocol interfaces at module boundaries.

```swift
// UserFeature/Sources/UserFeatureInterface.swift
public protocol UserServiceProtocol {
    func fetchUser(id: String) async throws -> User
}

public protocol UserFeatureInterface {
    var userService: UserServiceProtocol { get }
}
```

```swift
// UserFeature/Sources/UserFeatureImplementation.swift
import WeaveDI

public struct UserFeatureImpl: UserFeatureInterface {
    @Injected(\.userService) public var userService

    public init() {}
}

// Register implementation
extension InjectedValues {
    public var userFeature: UserFeatureInterface {
        get { self[UserFeatureKey.self] }
        set { self[UserFeatureKey.self] = newValue }
    }
}

struct UserFeatureKey: InjectedKey {
    static var liveValue: UserFeatureInterface = UserFeatureImpl()
    static var testValue: UserFeatureInterface = MockUserFeature()
}
```

## Cross-Module Dependency Injection

### Sharing Dependencies Across Modules

```swift
// Networking/Sources/APIClient.swift
import WeaveDI

public protocol APIClient {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}

public struct NetworkingModule {
    public static func register() async {
        await WeaveDI.Container.bootstrap { container in
            container.register(APIClient.self) {
                URLSessionAPIClient(session: .shared)
            }
        }
    }
}

// Make APIClient injectable
extension InjectedValues {
    public var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

public struct APIClientKey: InjectedKey {
    public static var liveValue: APIClient = URLSessionAPIClient(session: .shared)
    public static var testValue: APIClient = MockAPIClient()
}
```

```swift
// UserFeature/Sources/UserService.swift
import WeaveDI
import Networking

public final class UserService {
    @Injected(\.apiClient) var apiClient

    public func fetchUser(id: String) async throws -> User {
        try await apiClient.request(.user(id: id))
    }
}
```

## Feature Module Pattern

### Self-Contained Feature Module

```swift
// UserFeature/Sources/UserFeature.swift
import SwiftUI
import WeaveDI

public struct UserFeature {
    public init() {}

    // Public API
    public func makeUserProfileView() -> some View {
        UserProfileView()
    }

    public func makeUserListView() -> some View {
        UserListView()
    }
}

// Internal dependencies
extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }

    var userRepository: UserRepository {
        get { self[UserRepositoryKey.self] }
        set { self[UserRepositoryKey.self] = newValue }
    }
}

struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()
}

struct UserRepositoryKey: InjectedKey {
    static var liveValue: UserRepository = UserRepositoryImpl()
    static var testValue: UserRepository = MockUserRepository()
}
```

### Feature Coordinator Pattern

```swift
// UserFeature/Sources/UserCoordinator.swift
import WeaveDI

public protocol UserCoordinator {
    func showUserProfile(userId: String)
    func showUserList()
}

public final class UserCoordinatorImpl: UserCoordinator {
    @Injected(\.navigationService) var navigation

    public init() {}

    public func showUserProfile(userId: String) {
        let view = UserProfileView(userId: userId)
        navigation.push(view)
    }

    public func showUserList() {
        let view = UserListView()
        navigation.push(view)
    }
}

// Register coordinator
extension InjectedValues {
    public var userCoordinator: UserCoordinator {
        get { self[UserCoordinatorKey.self] }
        set { self[UserCoordinatorKey.self] = newValue }
    }
}

struct UserCoordinatorKey: InjectedKey {
    static var liveValue: UserCoordinator = UserCoordinatorImpl()
    static var testValue: UserCoordinator = MockUserCoordinator()
}
```

## Module Communication

### Event-Based Communication

```swift
// Core/Sources/EventBus.swift
import WeaveDI

public protocol Event {}

public protocol EventBus {
    func publish(_ event: Event)
    func subscribe<T: Event>(_ type: T.Type, handler: @escaping (T) -> Void)
}

public final class EventBusImpl: EventBus {
    private var handlers: [String: [(Event) -> Void]] = [:]

    public init() {}

    public func publish(_ event: Event) {
        let key = String(describing: type(of: event))
        handlers[key]?.forEach { $0(event) }
    }

    public func subscribe<T: Event>(_ type: T.Type, handler: @escaping (T) -> Void) {
        let key = String(describing: type)
        let wrapper: (Event) -> Void = { event in
            if let typedEvent = event as? T {
                handler(typedEvent)
            }
        }
        handlers[key, default: []].append(wrapper)
    }
}

// Register EventBus
extension InjectedValues {
    public var eventBus: EventBus {
        get { self[EventBusKey.self] }
        set { self[EventBusKey.self] = newValue }
    }
}

struct EventBusKey: InjectedKey {
    static var liveValue: EventBus = EventBusImpl()
    static var testValue: EventBus = MockEventBus()
}
```

```swift
// UserFeature publishes event
public struct UserLoggedInEvent: Event {
    public let userId: String
}

public final class UserService {
    @Injected(\.eventBus) var eventBus

    public func login(credentials: Credentials) async throws {
        // Login logic...
        eventBus.publish(UserLoggedInEvent(userId: user.id))
    }
}
```

```swift
// OrderFeature subscribes to event
public final class OrderService {
    @Injected(\.eventBus) var eventBus

    public init() {
        eventBus.subscribe(UserLoggedInEvent.self) { [weak self] event in
            self?.handleUserLogin(userId: event.userId)
        }
    }

    private func handleUserLogin(userId: String) {
        // Load user's orders
    }
}
```

## Testing Multi-Module Dependencies

### Module-Level Testing

```swift
// UserFeatureTests/UserServiceTests.swift
import XCTest
@testable import UserFeature
import WeaveDI

final class UserServiceTests: XCTestCase {
    override func setUp() async throws {
        // Reset DI for each test
        await WeaveDI.Container.reset()
    }

    func testFetchUser() async throws {
        await withInjectedValues { values in
            values.apiClient = MockAPIClient(
                responses: [.user(id: "123"): User.testUser]
            )
        } operation: {
            let service = UserService()
            let user = try await service.fetchUser(id: "123")

            XCTAssertEqual(user.id, "123")
            XCTAssertEqual(user.name, "Test User")
        }
    }
}
```

### Integration Testing Across Modules

```swift
// IntegrationTests/UserOrderIntegrationTests.swift
import XCTest
@testable import UserFeature
@testable import OrderFeature
import WeaveDI

final class UserOrderIntegrationTests: XCTestCase {
    func testUserLoginTriggersOrderLoad() async throws {
        var orderLoadCalled = false

        await withInjectedValues { values in
            values.apiClient = MockAPIClient()
            values.eventBus = MockEventBus { event in
                if event is UserLoggedInEvent {
                    orderLoadCalled = true
                }
            }
        } operation: {
            let userService = UserService()
            let orderService = OrderService()

            try await userService.login(credentials: .test)

            XCTAssertTrue(orderLoadCalled)
        }
    }
}
```

## Best Practices

### ✅ Do's

```swift
// ✅ Define clear module boundaries
public protocol UserFeatureInterface {
    var userService: UserServiceProtocol { get }
}

// ✅ Use protocols for cross-module dependencies
public protocol APIClient {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}

// ✅ Keep module dependencies minimal
// UserFeature only depends on Networking and SharedModels

// ✅ Register dependencies at module level
public struct UserFeatureModule {
    public static func register(in container: WeaveDI.Container) {
        // Register all feature dependencies
    }
}

// ✅ Use event bus for loose coupling
eventBus.publish(UserLoggedInEvent(userId: user.id))
```

### ❌ Don'ts

```swift
// ❌ Don't create circular module dependencies
// UserFeature → OrderFeature → UserFeature (BAD!)

// ❌ Don't expose internal implementation details
public class UserServiceImpl { }  // Should be internal

// ❌ Don't register dependencies in multiple places
// Register in one central location per module

// ❌ Don't use concrete types across modules
func process(service: UserServiceImpl)  // Use protocol instead

// ❌ Don't bypass module boundaries
import UserFeature
let service = UserServiceImpl()  // Use DI instead
```

## Migration Strategy

### Monolith to Multi-Module

**Step 1: Identify Modules**
```
Current: Single target with folders
Target: Separate SPM packages

App/
├── User/       → UserFeature module
├── Order/      → OrderFeature module
├── Payment/    → PaymentFeature module
├── Network/    → Networking module
└── Database/   → Database module
```

**Step 2: Extract Core Infrastructure**
```swift
// Create Networking module first
// Move all networking code to Networking module
// Update imports: import Networking
```

**Step 3: Extract Feature Modules**
```swift
// Create UserFeature module
// Move user-related code
// Define public interfaces
// Register dependencies
```

**Step 4: Wire Up DI**
```swift
// Create DI module
// Configure all module dependencies
// Bootstrap in App target
```

## Performance Considerations

### Lazy Module Loading

```swift
// Lazy load feature modules
public final class FeatureLoader {
    private var loadedFeatures: Set<String> = []

    public func load(_ feature: Feature) async {
        guard !loadedFeatures.contains(feature.name) else { return }

        switch feature {
        case .user:
            await UserFeatureModule.bootstrap()
        case .order:
            await OrderFeatureModule.bootstrap()
        case .payment:
            await PaymentFeatureModule.bootstrap()
        }

        loadedFeatures.insert(feature.name)
    }
}
```

### Module Preloading

```swift
// Preload critical modules at app launch
@main
struct MyApp: App {
    init() {
        Task {
            // Preload core modules
            await NetworkingModule.bootstrap()
            await DatabaseModule.bootstrap()

            // Lazily load feature modules
            await FeatureLoader.shared.load(.user)
        }
    }
}
```

## Next Steps

- [TCA Integration](./tcaIntegration) - Using WeaveDI with The Composable Architecture
- [Module System](./moduleSystem) - Understanding WeaveDI's module system
- [Best Practices](./bestPractices) - General DI best practices
- [Testing Guide](../tutorial/testing) - Testing multi-module applications
