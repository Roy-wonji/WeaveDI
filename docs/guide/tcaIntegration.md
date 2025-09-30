# TCA Integration Guide

Complete guide for integrating WeaveDI with The Composable Architecture (TCA). This guide covers dependency injection patterns, state management, and advanced techniques for building scalable TCA apps.

## Overview

The Composable Architecture (TCA) is a library for building applications in a consistent and understandable way, with composition, testing, and ergonomics in mind. WeaveDI provides powerful dependency injection capabilities that work seamlessly with TCA's architecture.

### Why WeaveDI + TCA?

| Aspect | TCA Alone | WeaveDI + TCA | Benefit |
|--------|-----------|---------------|---------|
| **Dependency Management** | Manual injection in init | Automatic injection with @Inject | 🎯 Cleaner code, less boilerplate |
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
    @Inject private var networkService: NetworkService?
    @Inject private var analytics: AnalyticsService?

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
        await Container.bootstrap { container in
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
    @Inject private var userService: UserService?
    @Inject private var analytics: AnalyticsService?

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
    @Inject private var userService: UserService?
    @Inject private var analytics: AnalyticsService?

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
        await Container.bootstrap { container in
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

    @Inject private var authService: AuthService?
    @Inject private var analytics: AnalyticsService?

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
    @Inject private var cache: CacheService?

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
    @Inject var userService: UserService
    @Inject var userRepository: UserRepository
    @Inject var userCache: UserCacheService
}

@Reducer
struct UserFeature {
    @Inject private var dependencies: UserDependencies?

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
    @Inject private var userService: UserService?
    @Inject private var analytics: AnalyticsService?

    // ... same reducer implementation
}

// Registration happens once at app startup
await WeaveDI.registerTCADependencies()
```

## Common Issues and Solutions

### Issue 1: Services Not Found

**Problem:** `@Inject` returns `nil`

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

**Solution:** Use `@Inject` for stateless services, `@Factory` only when needed:

```swift
// ✅ Use @Inject for singleton services
@Inject private var apiClient: APIClient?

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
- [Testing Guide](./testing.md) - Advanced testing strategies with WeaveDI
- [Performance Optimization](./runtimeOptimization.md) - Optimize your DI container for production
- [Migration Guide](./migration-3.0.0.md) - Migrate from other DI frameworks