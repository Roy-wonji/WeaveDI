# TCA Integration Guide

Complete guide for integrating WeaveDI with The Composable Architecture (TCA). This guide covers dependency injection patterns, state management, and advanced techniques for building scalable TCA apps.

## Overview

The Composable Architecture (TCA) is a library for building applications in a consistent and understandable way, with composition, testing, and ergonomics in mind. WeaveDI provides powerful dependency injection capabilities that work seamlessly with TCA's architecture.

### Why WeaveDI + TCA?

| Aspect | TCA Alone | WeaveDI + TCA | Benefit |
|--------|-----------|---------------|---------|
| **Dependency Management** | Manual injection in init | Automatic injection with @Injected | 🎯 Cleaner code, less boilerplate |
| **Testing** | Mock services manually | Automatic mock injection | 🧪 Easier unit testing |
| **Modularization** | Tight coupling | Loose coupling via protocols | 🔗 Better separation of concerns |
| **Swift Concurrency** | Basic support | Full async/await + actor optimization | ⚡ Enhanced performance |
| **Environment Management** | Limited scope | Multi-scope dependency management | 🌍 Flexible environment handling |

## Swift Version Compatibility

### Swift 6.0+ (Recommended)
- Full strict concurrency support
- Actor isolation in reducers
- Sendable compliance verification
- Enhanced performance optimizations

### Swift 5.9+
- Complete async/await support
- Property wrapper integration
- Performance monitoring

### Swift 5.8+
- Core dependency injection
- Basic TCA integration
- Limited concurrency features

## Installation

### Package.swift Configuration

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.5.0"),
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.1.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            "WeaveDI"
        ]
    )
]
```

### Xcode Integration

1. Add both packages via File → Add Package Dependencies
2. Import both frameworks in your Swift files:

```swift
import ComposableArchitecture
import WeaveDI
```

## Component Quick Start

```swift
import WeaveDI

@Component
struct UserComponent {
  @Provide var repository: UserRepository = UserRepositoryImpl()
  @Provide(scope: .singleton) var service: UserService = UserServiceImpl(repository: repository)
}

// Register into the shared container
UserComponent.registerAll()
```

The `@Component` macro inspects every `@Provide` property, orders dependencies based on their usage, and generates the necessary `DIContainer.register` calls at compile time.

## Basic Integration Patterns

### 1. Service Layer Setup

First, define your services and register them with WeaveDI:

```swift
// MARK: - Service Protocols
protocol UserService {
    func fetchUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws -> User
}

protocol AnalyticsService {
    func track(event: String, parameters: [String: Any])
    func setUserId(_ userId: String)
}

protocol NetworkService {
    func request<T: Codable>(_ endpoint: Endpoint) async throws -> T
}

// MARK: - Service Implementations
class UserServiceImpl: UserService {
    @Injected private var networkService: NetworkService?
    @Injected private var analytics: AnalyticsService?

    func fetchUser(id: String) async throws -> User {
        analytics?.track(event: "user_fetch_started", parameters: ["user_id": id])

        guard let network = networkService else {
            throw ServiceError.networkServiceUnavailable
        }

        let user: User = try await network.request(.user(id: id))
        analytics?.track(event: "user_fetch_completed", parameters: ["user_id": id])

        return user
    }

    func updateUser(_ user: User) async throws -> User {
        analytics?.track(event: "user_update_started", parameters: ["user_id": user.id])

        guard let network = networkService else {
            throw ServiceError.networkServiceUnavailable
        }

        let updatedUser: User = try await network.request(.updateUser(user))
        analytics?.track(event: "user_update_completed", parameters: ["user_id": user.id])

        return updatedUser
    }
}

// MARK: - Dependency Registration
extension WeaveDI {
    static func registerTCADependencies() async {
        await WeaveDI.Container.bootstrap { container in
            // Core services
            container.register(NetworkService.self) {
                URLSessionNetworkService()
            }

            container.register(AnalyticsService.self) {
                FirebaseAnalyticsService()
            }

            // Business services
            container.register(UserService.self) {
                UserServiceImpl()
            }
        }
    }
}
```

### 2. Reducer with Dependency Injection

#### Swift 6 Pattern (Recommended)

```swift
import ComposableArchitecture
import WeaveDI

@Reducer
struct UserFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var user: User?
        var isLoading = false
        var errorMessage: String?
    }

    enum Action: Sendable {
        case loadUser(String)
        case userLoaded(User)
        case userLoadFailed(String)
        case updateUser(User)
        case userUpdated(User)
    }

    // Dependency injection using WeaveDI
    @Injected private var userService: UserService?
    @Injected private var analytics: AnalyticsService?

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadUser(let userId):
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    do {
                        guard let service = userService else {
                            throw ServiceError.userServiceUnavailable
                        }

                        let user = try await service.fetchUser(id: userId)
                        await send(.userLoaded(user))
                    } catch {
                        await send(.userLoadFailed(error.localizedDescription))
                    }
                }

            case .userLoaded(let user):
                state.isLoading = false
                state.user = user
                analytics?.track(event: "user_loaded_in_view", parameters: ["user_id": user.id])
                return .none

            case .userLoadFailed(let message):
                state.isLoading = false
                state.errorMessage = message
                analytics?.track(event: "user_load_failed", parameters: ["error": message])
                return .none

            case .updateUser(let user):
                return .run { send in
                    do {
                        guard let service = userService else {
                            throw ServiceError.userServiceUnavailable
                        }

                        let updatedUser = try await service.updateUser(user)
                        await send(.userUpdated(updatedUser))
                    } catch {
                        await send(.userLoadFailed(error.localizedDescription))
                    }
                }

            case .userUpdated(let user):
                state.user = user
                analytics?.track(event: "user_updated", parameters: ["user_id": user.id])
                return .none
            }
        }
    }
}
```

#### Swift 5.9 Pattern (Compatible)

```swift
import ComposableArchitecture
import WeaveDI

struct UserFeature: Reducer {
    struct State: Equatable {
        var user: User?
        var isLoading = false
        var errorMessage: String?
    }

    enum Action: Equatable {
        case loadUser(String)
        case userLoaded(User)
        case userLoadFailed(String)
        case updateUser(User)
        case userUpdated(User)
    }

    // Dependency injection using WeaveDI
    @Injected private var userService: UserService?
    @Injected private var analytics: AnalyticsService?

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .loadUser(let userId):
            state.isLoading = true
            state.errorMessage = nil

            return .run { send in
                do {
                    guard let service = userService else {
                        throw ServiceError.userServiceUnavailable
                    }

                    let user = try await service.fetchUser(id: userId)
                    await send(.userLoaded(user))
                } catch {
                    await send(.userLoadFailed(error.localizedDescription))
                }
            }

        case .userLoaded(let user):
            state.isLoading = false
            state.user = user
            analytics?.track(event: "user_loaded_in_view", parameters: ["user_id": user.id])
            return .none

        case .userLoadFailed(let message):
            state.isLoading = false
            state.errorMessage = message
            analytics?.track(event: "user_load_failed", parameters: ["error": message])
            return .none

        case .updateUser(let user):
            return .run { send in
                do {
                    guard let service = userService else {
                        throw ServiceError.userServiceUnavailable
                    }

                    let updatedUser = try await service.updateUser(user)
                    await send(.userUpdated(updatedUser))
                } catch {
                    await send(.userLoadFailed(error.localizedDescription))
                }
            }

        case .userUpdated(let user):
            state.user = user
            analytics?.track(event: "user_updated", parameters: ["user_id": user.id])
            return .none
        }
    }
}
```

### 3. SwiftUI View Integration

```swift
import SwiftUI
import ComposableArchitecture
import WeaveDI

struct UserProfileView: View {
    let store: StoreOf<UserFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationView {
                VStack(spacing: 20) {
                    if viewStore.isLoading {
                        ProgressView("Loading user...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let user = viewStore.user {
                        UserDetailView(user: user) { updatedUser in
                            viewStore.send(.updateUser(updatedUser))
                        }
                    } else if let error = viewStore.errorMessage {
                        ErrorView(message: error) {
                            // Retry logic would go here
                        }
                    } else {
                        EmptyView()
                    }
                }
                .navigationTitle("User Profile")
                .onAppear {
                    // Load user when view appears
                    viewStore.send(.loadUser("current-user-id"))
                }
            }
        }
    }
}

struct UserDetailView: View {
    let user: User
    let onUpdate: (User) -> Void

    var body: some View {
        Form {
            Section("User Information") {
                HStack {
                    AsyncImage(url: user.avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())

                    VStack(alignment: .leading) {
                        Text(user.name)
                            .font(.headline)
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }

            Section("Actions") {
                Button("Edit Profile") {
                    // Edit profile action
                    var updatedUser = user
                    updatedUser.name = "Updated Name"
                    onUpdate(updatedUser)
                }
            }
        }
    }
}
```

## Advanced Patterns

### 1. Multi-Module Architecture

For large applications, organize your features into modules:

```swift
// MARK: - Feature Module Protocol
protocol FeatureModule {
    static func registerDependencies() async
}

// MARK: - User Feature Module
struct UserFeatureModule: FeatureModule {
    static func registerDependencies() async {
        await WeaveDI.Container.bootstrap { container in
            // User-specific services
            container.register(UserRepository.self) {
                CoreDataUserRepository()
            }

            container.register(UserService.self) {
                UserServiceImpl()
            }
        }
    }
}

// MARK: - Order Feature Module
struct OrderFeatureModule: FeatureModule {
    static func registerDependencies() async {
        await WeaveDI.Container.bootstrap { container in
            container.register(OrderRepository.self) {
                APIOrderRepository()
            }

            container.register(OrderService.self) {
                OrderServiceImpl()
            }

            container.register(PaymentService.self) {
                StripePaymentService()
            }
        }
    }
}

// MARK: - App Module Registration
extension App {
    static func registerAllFeatures() async {
        await UserFeatureModule.registerDependencies()
        await OrderFeatureModule.registerDependencies()
        // Add other feature modules...
    }
}
```

### 2. Environment-Based Dependency Configuration

```swift
import ComposableArchitecture
import WeaveDI

// MARK: - Environment Configuration
enum AppEnvironment {
    case development
    case staging
    case production

    var apiBaseURL: String {
        switch self {
        case .development: return "https://dev-api.example.com"
        case .staging: return "https://staging-api.example.com"
        case .production: return "https://api.example.com"
        }
    }
}

// MARK: - Environment-Specific Registration
extension WeaveDI {
    static func registerForEnvironment(_ environment: AppEnvironment) async {
        await WeaveDI.Container.bootstrap { container in
            switch environment {
            case .development:
                // Development services
                container.register(NetworkService.self) {
                    MockNetworkService() // Use mocks in development
                }
                container.register(AnalyticsService.self) {
                    ConsoleAnalyticsService() // Log to console only
                }

            case .staging:
                // Staging services
                container.register(NetworkService.self) {
                    URLSessionNetworkService(baseURL: environment.apiBaseURL)
                }
                container.register(AnalyticsService.self) {
                    TestAnalyticsService() // Test analytics
                }

            case .production:
                // Production services
                container.register(NetworkService.self) {
                    URLSessionNetworkService(baseURL: environment.apiBaseURL)
                }
                container.register(AnalyticsService.self) {
                    FirebaseAnalyticsService() // Full analytics
                }
            }

            // Common services for all environments
            container.register(UserService.self) {
                UserServiceImpl()
            }
        }
    }
}
```

### 3. Testing with WeaveDI + TCA

#### Mock Services for Testing

```swift
import XCTest
import ComposableArchitecture
import WeaveDI
@testable import YourApp

// MARK: - Mock Services
class MockUserService: UserService {
    var mockUsers: [String: User] = [:]
    var shouldThrowError = false
    var errorToThrow: Error = ServiceError.unknown

    func fetchUser(id: String) async throws -> User {
        if shouldThrowError {
            throw errorToThrow
        }

        return mockUsers[id] ?? User.mockUser(id: id)
    }

    func updateUser(_ user: User) async throws -> User {
        if shouldThrowError {
            throw errorToThrow
        }

        mockUsers[user.id] = user
        return user
    }
}

class MockAnalyticsService: AnalyticsService {
    var trackedEvents: [(event: String, parameters: [String: Any])] = []
    var currentUserId: String?

    func track(event: String, parameters: [String: Any]) {
        trackedEvents.append((event: event, parameters: parameters))
    }

    func setUserId(_ userId: String) {
        currentUserId = userId
    }
}

// MARK: - Test Case
class UserFeatureTests: XCTestCase {
    var mockUserService: MockUserService!
    var mockAnalytics: MockAnalyticsService!

    override func setUp() async throws {
        await super.setUp()

        // Reset WeaveDI container for each test
        WeaveDI.Container.live = WeaveDI.Container()

        // Create and register mock services
        mockUserService = MockUserService()
        mockAnalytics = MockAnalyticsService()

        await WeaveDI.Container.bootstrap { container in
            container.register(UserService.self, instance: mockUserService)
            container.register(AnalyticsService.self, instance: mockAnalytics)
        }
    }

    @MainActor
    func testLoadUserSuccess() async {
        // Given
        let expectedUser = User(id: "test-123", name: "Test User", email: "test@example.com")
        mockUserService.mockUsers["test-123"] = expectedUser

        let store = TestStore(initialState: UserFeature.State()) {
            UserFeature()
        }

        // When
        await store.send(.loadUser("test-123")) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        // Then
        await store.receive(.userLoaded(expectedUser)) {
            $0.isLoading = false
            $0.user = expectedUser
        }

        // Verify analytics
        XCTAssertEqual(mockAnalytics.trackedEvents.count, 2) // fetch_started + loaded_in_view
        XCTAssertEqual(mockAnalytics.trackedEvents.last?.event, "user_loaded_in_view")
    }

    @MainActor
    func testLoadUserFailure() async {
        // Given
        mockUserService.shouldThrowError = true
        mockUserService.errorToThrow = ServiceError.networkError("Connection failed")

        let store = TestStore(initialState: UserFeature.State()) {
            UserFeature()
        }

        // When
        await store.send(.loadUser("test-123")) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        // Then
        await store.receive(.userLoadFailed("Connection failed")) {
            $0.isLoading = false
            $0.errorMessage = "Connection failed"
        }

        // Verify analytics
        XCTAssertEqual(mockAnalytics.trackedEvents.last?.event, "user_load_failed")
    }

    @MainActor
    func testUpdateUser() async {
        // Given
        let initialUser = User(id: "test-123", name: "Test User", email: "test@example.com")
        let updatedUser = User(id: "test-123", name: "Updated User", email: "test@example.com")

        let store = TestStore(initialState: UserFeature.State(user: initialUser)) {
            UserFeature()
        }

        // When
        await store.send(.updateUser(updatedUser))

        // Then
        await store.receive(.userUpdated(updatedUser)) {
            $0.user = updatedUser
        }

        // Verify the user was actually updated in the mock service
        XCTAssertEqual(mockUserService.mockUsers["test-123"]?.name, "Updated User")

        // Verify analytics
        let updateEvents = mockAnalytics.trackedEvents.filter { $0.event.contains("user_update") }
        XCTAssertEqual(updateEvents.count, 2) // started + completed
    }
}
```

### 4. Complex State Management

For apps with complex state requirements:

```swift
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var user: UserFeature.State = .init()
        var orders: OrderFeature.State = .init()
        var settings: SettingsFeature.State = .init()
        var isAuthenticated = false
    }

    enum Action {
        case user(UserFeature.Action)
        case orders(OrderFeature.Action)
        case settings(SettingsFeature.Action)
        case authenticate
        case logout
    }

    @Injected private var authService: AuthService?
    @Injected private var analytics: AnalyticsService?

    var body: some ReducerOf<Self> {
        Scope(state: \.user, action: \.user) {
            UserFeature()
        }

        Scope(state: \.orders, action: \.orders) {
            OrderFeature()
        }

        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }

        Reduce { state, action in
            switch action {
            case .authenticate:
                return .run { send in
                    // Authentication logic
                    guard let auth = authService else { return }

                    do {
                        let isAuthenticated = try await auth.authenticate()
                        if isAuthenticated {
                            analytics?.track(event: "user_authenticated", parameters: [:])
                        }
                    } catch {
                        analytics?.track(event: "authentication_failed", parameters: ["error": error.localizedDescription])
                    }
                }

            case .logout:
                state.isAuthenticated = false
                analytics?.track(event: "user_logged_out", parameters: [:])
                return .none

            case .user, .orders, .settings:
                return .none
            }
        }
    }
}
```

## Performance Optimization

### 1. Runtime Optimization

Enable WeaveDI's runtime optimization for better performance:

```swift
// In your App.swift or AppDelegate
@main
struct MyApp: App {
    init() {
        Task {
            // Enable optimization before registering dependencies
            UnifiedRegistry.shared.enableOptimization()

            // Register all dependencies
            await WeaveDI.registerTCADependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. Lazy Loading Pattern

For better performance, use lazy loading for expensive dependencies:

```swift
@Reducer
struct DataProcessingFeature {
    // Lazy injection - only created when first accessed
    @Factory private var dataProcessor: ExpensiveDataProcessor
    @Injected private var cache: CacheService?

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .processLargeDataSet(let data):
                return .run { send in
                    // dataProcessor is created only when needed
                    let processor = dataProcessor
                    let result = await processor.process(data)
                    await send(.dataProcessed(result))
                }

            default:
                return .none
            }
        }
    }
}
```

## Best Practices

### 1. Dependency Organization

```swift
// Group related dependencies
protocol UserDependencies {
    var userService: UserService { get }
    var userRepository: UserRepository { get }
    var userCache: UserCacheService { get }
}

class UserDependenciesImpl: UserDependencies {
    @Injected var userService: UserService
    @Injected var userRepository: UserRepository
    @Injected var userCache: UserCacheService
}

@Reducer
struct UserFeature {
    @Injected private var dependencies: UserDependencies?

    // Use grouped dependencies
    private var userService: UserService? {
        dependencies?.userService
    }
}
```

### 2. Error Handling

```swift
enum ReducerError: LocalizedError {
    case dependencyNotFound(String)
    case serviceUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .dependencyNotFound(let dependency):
            return "Required dependency '\(dependency)' not found"
        case .serviceUnavailable(let service):
            return "Service '\(service)' is currently unavailable"
        }
    }
}

@Reducer
struct SafeUserFeature {
    @SafeInject private var userService: UserService?

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadUser(let id):
                return .run { send in
                    do {
                        let service = try userService.getValue() // Throws if nil
                        let user = try await service.fetchUser(id: id)
                        await send(.userLoaded(user))
                    } catch {
                        await send(.userLoadFailed(error.localizedDescription))
                    }
                }
            }
        }
    }
}
```

### 3. Modular Testing

```swift
// Create test-specific modules
struct TestUserModule: FeatureModule {
    static func registerDependencies() async {
        await WeaveDI.Container.bootstrap { container in
            // Register mock services for testing
            container.register(UserService.self) {
                MockUserService()
            }

            container.register(NetworkService.self) {
                MockNetworkService()
            }
        }
    }
}

// Use in tests
class UserFeatureIntegrationTests: XCTestCase {
    override func setUp() async throws {
        await TestUserModule.registerDependencies()
    }
}
```

## Migration Guide

### From TCA Dependencies to WeaveDI

If you're currently using TCA's dependency system, here's how to migrate:

#### Before (TCA Dependencies)

```swift
struct UserFeature: Reducer {
    @Dependency(\.userService) var userService
    @Dependency(\.analytics) var analytics

    // ... reducer implementation
}

extension DependencyValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}
```

#### After (WeaveDI)

```swift
struct UserFeature: Reducer {
    @Injected private var userService: UserService?
    @Injected private var analytics: AnalyticsService?

    // ... same reducer implementation
}

// Registration happens once at app startup
await WeaveDI.registerTCADependencies()
```

## Common Issues and Solutions

### Issue 1: Services Not Found

**Problem:** `@Injected` returns `nil`

**Solution:** Ensure dependencies are registered before creating stores:

```swift
// ❌ Wrong - creating store before registration
let store = Store(initialState: UserFeature.State()) {
    UserFeature()
}
await WeaveDI.registerTCADependencies()

// ✅ Correct - register dependencies first
await WeaveDI.registerTCADependencies()
let store = Store(initialState: UserFeature.State()) {
    UserFeature()
}
```

### Issue 2: Swift 6 Sendable Errors

**Problem:** Sendable compliance errors with injected services

**Solution:** Ensure all services conform to `Sendable`:

```swift
// ✅ Make services Sendable
protocol UserService: Sendable {
    func fetchUser(id: String) async throws -> User
}

class UserServiceImpl: UserService, Sendable {
    // Implementation...
}
```

### Issue 3: Memory Issues with Factories

**Problem:** `@Factory` creating too many instances

**Solution:** Use `@Injected` for stateless services, `@Factory` only when needed:

```swift
// ✅ Use @Injected for singleton services
@Injected private var apiClient: APIClient?

// ✅ Use @Factory for stateful or temporary objects
@Factory private var documentGenerator: DocumentGenerator
```

## Conclusion

WeaveDI and TCA work exceptionally well together, providing a robust architecture for building maintainable, testable, and performant iOS applications. The combination offers:

- **Clean Architecture**: Clear separation between business logic and dependency management
- **Type Safety**: Compile-time verification of dependencies
- **Easy Testing**: Automatic mock injection and isolated test environments
- **Performance**: Optimized dependency resolution with minimal overhead
- **Swift 6 Ready**: Full compatibility with modern Swift concurrency features

By following the patterns and best practices in this guide, you'll be able to build scalable TCA applications with powerful dependency injection capabilities.

## Next Steps

- [Property Wrappers Guide](./propertyWrappers.md) - Deep dive into WeaveDI's injection patterns
- [Testing Guide](/tutorial/testing) - Advanced testing strategies with WeaveDI
- [Performance Optimization](./runtimeOptimization.md) - Optimize your DI container for production
- [Migration Guide](./migration-3.0.0.md) - Migrate from other DI frameworks

## Swift-Dependencies Integration

WeaveDI provides seamless integration with Point-Free's `swift-dependencies` package, allowing you to use both systems together or migrate gradually between them.

### Setup and Configuration

Add both packages to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.2.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "Dependencies", package: "swift-dependencies"),
            "WeaveDI"
        ]
    )
]
```

### Basic Integration Pattern

```swift
import Dependencies
import WeaveDI

// 1. Define your service protocol
protocol UserService: Sendable {
    func fetchUser(id: String) async throws -> User
}

// 2. Create WeaveDI key for the service
struct UserServiceKey: InjectedKey {
    static let liveValue: UserService = UserServiceImpl()
    static let testValue: UserService = MockUserService()
}

// 3. Extend DependencyValues to bridge WeaveDI and swift-dependencies
extension DependencyValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

// 4. Use in your reducer with either system
struct UserFeature: Reducer {
    // Option A: Use swift-dependencies (recommended for new projects)
    @Dependency(\.userService) var userService

    // Option B: Use WeaveDI directly
    // @Injected var userService: UserService?

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadUser(let id):
                return .run { send in
                    let user = try await userService.fetchUser(id: id)
                    await send(.userLoaded(user))
                }
            }
        }
    }
}
```

### Advanced Bridge Implementation

For complex scenarios, create a comprehensive bridge:

```swift
// MARK: - WeaveDI ↔ swift-dependencies Bridge

extension DependencyValues {

    /// Access WeaveDI container directly from DependencyValues
    var diContainer: WeaveDI.Container {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }

    /// Generic subscript for any WeaveDI InjectedKey
    subscript<K: InjectedKey>(key: K.Type) -> K.Value where K.Value: Sendable {
        get {
            // Try to get from WeaveDI first, fallback to swift-dependencies
            if let value = diContainer.resolve(K.Value.self) {
                return value
            }
            return K.liveValue
        }
        set {
            // Register in both systems for maximum compatibility
            diContainer.register(K.Value.self, instance: newValue)
            InjectedValues.current[K.self] = newValue
        }
    }

    // Specific service bridges
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }

    var database: Database {
        get { self[DatabaseKey.self] }
        set { self[DatabaseKey.self] = newValue }
    }

    var analytics: AnalyticsService {
        get { self[AnalyticsKey.self] }
        set { self[AnalyticsKey.self] = newValue }
    }
}

// Container key for DI system access
private struct DIContainerKey: DependencyKey {
    static let liveValue = WeaveDI.Container.live
    static let testValue = WeaveDI.Container()
}
```

### Real-World Migration Example

#### Scenario: Existing TCA app with swift-dependencies, adding WeaveDI gradually

```swift
// MARK: - Before: Pure swift-dependencies
struct OldUserFeature: Reducer {
    @Dependency(\.userService) var userService
    @Dependency(\.analytics) var analytics

    // ... existing implementation
}

extension DependencyValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

// MARK: - After: Hybrid approach
struct NewUserFeature: Reducer {
    // Keep existing swift-dependencies for critical services
    @Dependency(\.userService) var userService

    // Add WeaveDI for new services with better performance
    @Injected var cacheService: CacheService?
    @Injected var imageProcessor: ImageProcessor?

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadUser(let id):
                return .run { send in
                    // Use swift-dependencies service
                    let user = try await userService.fetchUser(id: id)

                    // Use WeaveDI services for caching
                    await cacheService?.cache(user)
                    await imageProcessor?.preloadAvatar(user.avatarURL)

                    await send(.userLoaded(user))
                }
            }
        }
    }
}

// MARK: - Registration in App startup
@main
struct MyApp: App {
    init() {
        Task {
            // Register WeaveDI services
            await WeaveDI.Container.bootstrap { container in
                container.register(CacheService.self) {
                    RedisCache()
                }
                container.register(ImageProcessor.self) {
                    GPUImageProcessor()
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .store(store: AppStore())
        }
    }
}
```

### Testing with Both Systems

```swift
import XCTest
import Dependencies
import WeaveDI
@testable import YourApp

class HybridFeatureTests: XCTestCase {

    override func setUp() async throws {
        await super.setUp()

        // Setup WeaveDI mocks
        WeaveDI.Container.live = WeaveDI.Container()
        await WeaveDI.Container.bootstrap { container in
            container.register(CacheService.self) {
                MockCacheService()
            }
            container.register(ImageProcessor.self) {
                MockImageProcessor()
            }
        }
    }

    @MainActor
    func testHybridFeature() async {
        let store = TestStore(initialState: NewUserFeature.State()) {
            NewUserFeature()
        } withDependencies: {
            // Override swift-dependencies services
            $0.userService = MockUserService()
            $0.analytics = MockAnalytics()
            // WeaveDI services are automatically mocked from setUp
        }

        // Test with both systems working together
        await store.send(.loadUser("123"))
        await store.receive(.userLoaded(expectedUser))
    }
}
```

### Performance Comparison

| Aspect | swift-dependencies | WeaveDI | Hybrid Approach |
|--------|-------------------|---------|-----------------|
| **Resolution Speed** | Fast (TaskLocal) | **Very Fast** (Direct registry) | **Optimal** |
| **Memory Usage** | Low | **Very Low** | **Balanced** |
| **Compile Time** | Good | **Excellent** | Good |
| **Type Safety** | Strong | **Very Strong** | **Maximum** |
| **Testing Support** | Excellent | **Excellent** | **Best of Both** |

### Best Practices for Hybrid Usage

#### 1. Service Categorization Strategy

```swift
// Use swift-dependencies for:
// - Core TCA dependencies (effects, schedulers)
// - Simple value types
// - Services that benefit from TaskLocal scoping

@Dependency(\.mainQueue) var mainQueue
@Dependency(\.uuid) var uuid
@Dependency(\.date) var date

// Use WeaveDI for:
// - Heavy services (networking, database)
// - Services with complex initialization
// - Services that need performance optimization

@Injected var networkService: NetworkService?
@Injected var database: Database?
@Injected var cacheCluster: CacheCluster?
```

#### 2. Gradual Migration Pattern

```swift
// Phase 1: Add WeaveDI alongside swift-dependencies
extension DependencyValues {
    var expensiveService: ExpensiveService {
        get {
            // Try WeaveDI first for better performance
            if let service = WeaveDI.Container.live.resolve(ExpensiveService.self) {
                return service
            }
            // Fallback to swift-dependencies
            return self[ExpensiveServiceKey.self]
        }
        set { self[ExpensiveServiceKey.self] = newValue }
    }
}

// Phase 2: Fully migrate high-impact services to WeaveDI
struct OptimizedFeature: Reducer {
    // Migrated to WeaveDI for 10x performance improvement
    @Injected var dataProcessor: DataProcessor?
    @Injected var networkLayer: NetworkLayer?

    // Keep swift-dependencies for simple values
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.uuid) var uuid
}
```

#### 3. Error Handling and Fallbacks

```swift
struct RobustFeature: Reducer {
    @Dependency(\.userService) var userService
    @Injected var enhancedUserService: EnhancedUserService?

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadUser(let id):
                return .run { send in
                    do {
                        // Try enhanced service first
                        if let enhanced = enhancedUserService {
                            let user = try await enhanced.fetchUserWithAnalytics(id: id)
                            await send(.userLoaded(user))
                        } else {
                            // Fallback to basic service
                            let user = try await userService.fetchUser(id: id)
                            await send(.userLoaded(user))
                        }
                    } catch {
                        await send(.userLoadFailed(error))
                    }
                }
            }
        }
    }
}
```

### Common Integration Issues and Solutions

#### Issue 1: Service Not Found in Either System

**Problem:**
```swift
@Dependency(\.myService) var myService  // nil
@Injected var myService: MyService?     // nil
```

**Solution:**
```swift
// Ensure service is registered in both systems
extension DependencyValues {
    var myService: MyService {
        get {
            // Check WeaveDI first
            if let service = WeaveDI.Container.live.resolve(MyService.self) {
                return service
            }
            // Then check swift-dependencies
            return self[MyServiceKey.self]
        }
        set {
            // Register in both systems
            self[MyServiceKey.self] = newValue
            Task {
                await WeaveDI.Container.bootstrap { container in
                    container.register(MyService.self, instance: newValue)
                }
            }
        }
    }
}
```

#### Issue 2: Conflicting Dependencies in Tests

**Problem:** Different mock implementations in swift-dependencies vs WeaveDI

**Solution:**
```swift
// Create unified test setup
extension TestCase {
    func setupUnifiedMocks() async {
        let mockService = MockUserService()

        // Setup WeaveDI
        WeaveDI.Container.live = WeaveDI.Container()
        await WeaveDI.Container.bootstrap { container in
            container.register(UserService.self, instance: mockService)
        }

        // Setup swift-dependencies
        DependencyValues.withDependencies {
            $0.userService = mockService
        }
    }
}
```

#### Issue 3: Performance Degradation with Double Resolution

**Problem:** Services being resolved by both systems causing overhead

**Solution:**
```swift
// Use caching layer to prevent double resolution
class HybridServiceCache {
    private var cache: [String: Any] = [:]

    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)

        if let cached = cache[key] as? T {
            return cached
        }

        // Try WeaveDI first (faster)
        if let service = WeaveDI.Container.live.resolve(type) {
            cache[key] = service
            return service
        }

        // Fallback to swift-dependencies
        let service = DependencyValues.current[type]
        cache[key] = service
        return service
    }
}
```

### FAQ

**Q: Can I use both @Dependency and @Injected in the same reducer?**

A: Yes! This is the recommended approach for gradual migration.

**Q: Which system should I use for new services?**

A: For new projects, use WeaveDI for better performance. For existing swift-dependencies projects, add WeaveDI gradually for heavy services.

**Q: How do I handle service initialization order?**

A: WeaveDI handles initialization automatically. For swift-dependencies, use the standard dependency override patterns.

**Q: Can I access WeaveDI services from swift-dependencies tests?**

A: Yes, through the bridge extension shown above. The systems work seamlessly together.

**Q: What about performance impact of using both systems?**

A: Minimal impact. WeaveDI is actually faster, so using both often improves overall performance.

### Conclusion

WeaveDI's integration with swift-dependencies provides the best of both worlds:
- **Gradual Migration**: Move at your own pace
- **Performance Optimization**: Use WeaveDI for heavy lifting
- **Maximum Compatibility**: Keep existing swift-dependencies code
- **Enhanced Testing**: Unified mock management

This hybrid approach is particularly valuable for large codebases where complete migration would be risky or time-consuming.
