# Frequently Asked Questions (FAQ)

Common questions and answers about WeaveDI.

## General Questions

### What is WeaveDI?

WeaveDI is a modern, Swift-native dependency injection framework that provides:
- **Type-safe dependency injection** with compile-time guarantees
- **Multiple injection patterns**: `@Injected`, `@Factory`, and legacy `@Injected`
- **TCA-compatible API** with KeyPath-based access
- **Swift Concurrency support** with Actor isolation
- **Performance optimization** with built-in caching and lazy loading

**When to use WeaveDI:**
```swift
// ✅ Perfect for:
// - iOS/macOS apps with complex dependency graphs
// - Apps using The Composable Architecture (TCA)
// - Projects requiring strict type safety
// - Apps needing testable architecture

// Example: Clean, testable view model
class UserViewModel {
    @Injected(\.userService) var userService
    @Injected(\.analytics) var analytics

    func loadUser() async {
        let user = await userService.fetchCurrentUser()
        analytics.track("user_loaded")
    }
}
```

### How does WeaveDI compare to other DI frameworks?

| Feature | WeaveDI | Swinject | Needle | Factory |
|---------|---------|----------|--------|---------|
| **Type Safety** | ✅ Compile-time | ⚠️ Runtime | ✅ Compile-time | ✅ Compile-time |
| **TCA Compatible** | ✅ Yes | ❌ No | ❌ No | ⚠️ Limited |
| **Property Wrappers** | ✅ @Injected, @Factory | ✅ @Injected | ❌ No | ✅ @Injected |
| **Swift Concurrency** | ✅ Full support | ⚠️ Partial | ⚠️ Limited | ✅ Full support |
| **Performance** | ✅ Optimized | ⚠️ Moderate | ✅ Fast | ✅ Fast |
| **Learning Curve** | ⚠️ Moderate | ⚠️ Moderate | ❌ Steep | ✅ Easy |

**Migration-friendly:**
```swift
// Easy to migrate from other frameworks
// Old (Swinject-style)
@Injected var service: UserService?

// New (WeaveDI v3.2.0+)
@Injected(\.userService) var service  // Type-safe, non-optional
```

See [Framework Comparison](./frameworkComparison.md) for detailed analysis.

## Installation & Setup

### Which Swift version do I need?

**Version Requirements:**
- **Swift 6.0+**: Full concurrency, strict Sendable (recommended)
- **Swift 5.9+**: Complete async/await support
- **Swift 5.8+**: Core DI features
- **Swift 5.7+**: Limited support (fallback implementations)

**Example SPM setup:**
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.2.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["WeaveDI"],
        swiftSettings: [
            // Swift 6 strict concurrency (optional)
            .enableExperimentalFeature("StrictConcurrency")
        ]
    )
]
```

### How do I set up WeaveDI in my project?

**Quick Setup (3 steps):**

```swift
// 1. Define InjectedKey
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()
}

// 2. Extend InjectedValues
extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

// 3. Use @Injected
class ViewModel {
    @Injected(\.userService) var userService

    func loadData() async {
        await userService.fetchUser()
    }
}
```

**App-wide setup:**
```swift
@main
struct MyApp: App {
    init() {
        // Optional: Bootstrap for complex dependencies
        Task {
            await WeaveDI.Container.bootstrap { container in
                container.register(DatabaseService.self) {
                    CoreDataService()
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

See [Quick Start Guide](./quickStart.md) for complete setup.

## Property Wrappers

### When should I use @Injected vs @Factory?

**Use @Injected (default):**
```swift
// ✅ Shared services (singleton-like)
@Injected(\.userService) var userService
@Injected(\.apiClient) var apiClient
@Injected(\.database) var database

// Why: Reuses same instance, better performance
```

**Use @Factory:**
```swift
// ✅ Fresh instances needed
@Factory var pdfGenerator: PDFGenerator
@Factory var dateFormatter: DateFormatter
@Factory var reportBuilder: ReportBuilder

// Why: Each access creates new instance
// Perfect for: Stateless operations, concurrent processing

// Example: Parallel PDF generation
class DocumentService {
    @Factory var pdfGenerator: PDFGenerator

    func generateReports(_ data: [Report]) async -> [PDF] {
        await withTaskGroup(of: PDF.self) { group in
            for report in data {
                group.addTask {
                    let gen = self.pdfGenerator  // Fresh instance per task
                    return gen.generate(report)
                }
            }

            var results: [PDF] = []
            for await pdf in group {
                results.append(pdf)
            }
            return results
        }
    }
}
```

**Decision Tree:**
```
Need new instance each time?
├─ Yes → Use @Factory
│   └─ Examples: Formatters, Builders, Parsers
└─ No → Use @Injected
    └─ Examples: Services, Repositories, Managers
```

### What happened to @Injected and @SafeInject?

**Deprecated in v3.2.0:**
```swift
// ❌ Deprecated (still works but not recommended)
@Injected var service: UserService?
@SafeInject var api: APIClient?

// ✅ Migrate to @Injected
@Injected(\.userService) var service
@Injected(\.apiClient) var api
```

**Why deprecated:**
- Optional-based (requires nil checking)
- No compile-time KeyPath safety
- Not TCA-compatible
- Limited testing support

**Migration Guide:**
See [Migration: @Injected → @Injected](./migrationInjectToInjected.md)

### Can I use constructor injection instead?

**Yes! Both patterns are supported:**

```swift
// Pattern 1: Property injection (recommended)
class UserViewModel {
    @Injected(\.userService) var userService
    @Injected(\.analytics) var analytics
}

// Pattern 2: Constructor injection
class UserViewModel {
    private let userService: UserService
    private let analytics: Analytics

    init(
        userService: UserService,
        analytics: Analytics
    ) {
        self.userService = userService
        self.analytics = analytics
    }
}

// Register with constructor injection
container.register(UserViewModel.self) {
    UserViewModel(
        userService: container.resolve(UserService.self),
        analytics: container.resolve(Analytics.self)
    )
}
```

**When to use constructor injection:**
- Dependencies are required (not optional)
- Immutable dependencies preferred
- Testing with different implementations
- Explicit dependency declaration

**When to use property wrappers:**
- Simpler, less boilerplate
- TCA integration
- Dynamic dependency swapping
- Most typical use cases

## Testing

### How do I mock dependencies in tests?

**Recommended: Use `withInjectedValues`:**

```swift
func testUserLogin() async {
    // Create mocks
    let mockAuth = MockAuthService()
    let mockUser = MockUserService()

    // Scope dependency overrides to test
    await withInjectedValues { values in
        values.authService = mockAuth
        values.userService = mockUser
    } operation: {
        // Test with mocked dependencies
        let viewModel = LoginViewModel()
        await viewModel.login(username: "test", password: "pass")

        // Verify mock interactions
        XCTAssertTrue(mockAuth.loginCalled)
        XCTAssertEqual(mockAuth.lastUsername, "test")
    }
    // Dependencies automatically revert after test
}
```

**Why this approach:**
- ✅ Automatic cleanup (no global state pollution)
- ✅ Type-safe
- ✅ Works with async/await
- ✅ Scoped to test execution

**Alternative: Define testValue in InjectedKey:**
```swift
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()  // Auto-used in tests
}

// Tests automatically use testValue
func testWithDefaults() async {
    let viewModel = UserViewModel()
    await viewModel.loadUser()
    // Uses MockUserService automatically
}
```

See [Testing Guide](../tutorial/testing.md) for advanced patterns.

### How do I test code that uses @Injected?

**Pattern 1: Override dependencies:**
```swift
class UserViewModel {
    @Injected(\.userService) var userService

    func loadUser() async -> User? {
        await userService.fetchUser(id: "123")
    }
}

// Test
func testLoadUser() async {
    let mockService = MockUserService()
    mockService.stubbedUser = User(id: "123", name: "Test")

    await withInjectedValues { values in
        values.userService = mockService
    } operation: {
        let viewModel = UserViewModel()
        let user = await viewModel.loadUser()

        XCTAssertEqual(user?.name, "Test")
        XCTAssertTrue(mockService.fetchUserCalled)
    }
}
```

**Pattern 2: Constructor injection for testing:**
```swift
class UserViewModel {
    @Injected(\.userService) var userService

    // Test-friendly initializer
    init(userService: UserService? = nil) {
        if let service = userService {
            // Override for testing
            self._userService = Injected(wrappedValue: service)
        }
    }
}

// Test
func testLoadUser() async {
    let mockService = MockUserService()
    let viewModel = UserViewModel(userService: mockService)

    await viewModel.loadUser()

    XCTAssertTrue(mockService.fetchUserCalled)
}
```

### Do I need to clean up dependencies between tests?

**With `withInjectedValues`: No cleanup needed**
```swift
func testA() async {
    await withInjectedValues { values in
        values.service = MockA()
    } operation: {
        // Test A
    }
    // Auto-cleanup
}

func testB() async {
    await withInjectedValues { values in
        values.service = MockB()
    } operation: {
        // Test B - clean state
    }
}
```

**Without `withInjectedValues`: Manual cleanup**
```swift
class MyTests: XCTestCase {
    override func tearDown() async throws {
        await WeaveDI.Container.releaseAll()
    }
}
```

## Performance

### Does WeaveDI impact app performance?

**Performance characteristics:**

| Operation | Time | Impact |
|-----------|------|--------|
| @Injected resolution | ~0.0001ms | ✅ Negligible |
| @Factory creation | ~0.001ms | ✅ Minimal |
| Container bootstrap | ~1-5ms | ✅ One-time cost |

**Benchmark example:**
```swift
// Resolution performance (1000 iterations)
let start = CFAbsoluteTimeGetCurrent()

for _ in 0..<1000 {
    let service = InjectedValues.current.userService
    _ = service.fetchUser()
}

let duration = CFAbsoluteTimeGetCurrent() - start
print("Total: \(duration * 1000)ms, Avg: \(duration)ms per resolution")
// Typical: ~0.1ms total = 0.0001ms per resolution
```

**Optimization tips:**
```swift
// 1. Enable runtime optimization
UnifiedRegistry.shared.enableOptimization()

// 2. Use @Injected for frequently accessed dependencies
@Injected(\.logger) var logger  // Cached

// 3. Use @Factory only when fresh instances needed
@Factory var tempService: TempService  // Creates new instance

// 4. Minimize dependency count per class (< 5)
class ViewModel {
    @Injected(\.facade) var facade  // Facade combines multiple services
}
```

See [Performance Guide](./runtimeOptimization.md) for optimization techniques.

### Should I use @Factory or @Injected for better performance?

**@Injected is faster (shared instance):**
```swift
@Injected(\.service) var service
// First access: Resolves and caches
// Subsequent: Returns cached instance (very fast)
```

**@Factory creates new instances (slower but necessary):**
```swift
@Factory var generator: PDFGenerator
// Every access: Creates new instance
// Use when: State isolation needed
```

**Performance comparison:**
```swift
// Benchmark
class PerformanceTest {
    @Injected(\.sharedService) var shared
    @Factory var factory: Service

    func benchmark() {
        // @Injected: ~0.0001ms per access
        measure {
            for _ in 0..<1000 {
                _ = shared.doWork()
            }
        }

        // @Factory: ~0.001ms per access (10x slower but still fast)
        measure {
            for _ in 0..<1000 {
                let service = factory
                _ = service.doWork()
            }
        }
    }
}
```

**Recommendation:**
- Default to `@Injected` (faster, shared state)
- Use `@Factory` only when fresh instances required

## Architecture

### Can I use WeaveDI with SwiftUI?

**Yes! Perfect integration:**

```swift
// 1. Define dependencies
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
}

extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

// 2. Use in ViewModel
@MainActor
class UserViewModel: ObservableObject {
    @Injected(\.userService) var userService
    @Published var user: User?

    func loadUser() async {
        user = await userService.fetchCurrentUser()
    }
}

// 3. Use in SwiftUI View
struct UserView: View {
    @StateObject private var viewModel = UserViewModel()

    var body: some View {
        VStack {
            if let user = viewModel.user {
                Text("Hello, \(user.name)")
            }
        }
        .task {
            await viewModel.loadUser()
        }
    }
}
```

**SwiftUI Previews:**
```swift
struct UserView_Previews: PreviewProvider {
    static var previews: some View {
        UserView()
            .withInjectedValues { values in
                values.userService = MockUserService()
            }
    }
}
```

### Can I use WeaveDI with The Composable Architecture (TCA)?

**Yes! WeaveDI is TCA-inspired:**

```swift
// Dependencies (TCA-style)
extension InjectedValues {
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

// Reducer
struct UserFeature: Reducer {
    @Injected(\.apiClient) var apiClient

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .loadUser:
            return .run { send in
                let user = await apiClient.fetchUser()
                await send(.userLoaded(user))
            }
        }
    }
}

// Tests
func testLoadUser() async {
    await withInjectedValues { values in
        values.apiClient = MockAPIClient()
    } operation: {
        let store = TestStore(initialState: UserFeature.State()) {
            UserFeature()
        }

        await store.send(.loadUser)
        await store.receive(.userLoaded)
    }
}
```

See [TCA Integration Guide](./tcaIntegration.md) for complete patterns.

### How do I structure dependencies in a large app?

**Recommended: Feature-based organization:**

```swift
// File: DI/CoreDependencies.swift
extension InjectedValues {
    // Infrastructure
    var logger: Logger {
        get { self[LoggerKey.self] }
        set { self[LoggerKey.self] = newValue }
    }

    var database: Database {
        get { self[DatabaseKey.self] }
        set { self[DatabaseKey.self] = newValue }
    }
}

// File: DI/UserFeatureDependencies.swift
extension InjectedValues {
    // User feature
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }

    var userRepository: UserRepository {
        get { self[UserRepositoryKey.self] }
        set { self[UserRepositoryKey.self] = newValue }
    }
}

// File: DI/PaymentFeatureDependencies.swift
extension InjectedValues {
    // Payment feature
    var paymentService: PaymentService {
        get { self[PaymentServiceKey.self] }
        set { self[PaymentServiceKey.self] = newValue }
    }
}
```

**Layer structure:**
```swift
// Layer 1: Infrastructure (bottom)
extension InjectedValues {
    var networkClient: NetworkClient { ... }
    var database: Database { ... }
    var logger: Logger { ... }
}

// Layer 2: Data/Repository
extension InjectedValues {
    var userRepository: UserRepository { ... }
    var productRepository: ProductRepository { ... }
}

// Layer 3: Domain/Business Logic
extension InjectedValues {
    var userService: UserService { ... }
    var orderService: OrderService { ... }
}

// Layer 4: Presentation
// ViewModels inject from Layer 3
```

See [Best Practices](./bestPractices.md) for architecture patterns.

## Common Issues

### Why is my dependency nil?

**Common causes:**

1. **Dependency not registered:**
```swift
// ❌ Problem: Never registered
@Injected(\.userService) var service  // Might use default/nil

// ✅ Solution: Define InjectedKey
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
}
```

2. **Wrong type:**
```swift
// ❌ Problem: Type mismatch
container.register(Animal.self) { Dog() }
@Injected var cat: Cat?  // Wrong type!

// ✅ Solution: Use correct type
container.register(Dog.self) { Dog() }
@Injected var dog: Dog?
```

3. **Accessing too early:**
```swift
// ❌ Problem: Access in init
class ViewModel {
    @Injected(\.service) var service

    init() {
        service.doWork()  // Might not be ready
    }
}

// ✅ Solution: Access after init
class ViewModel {
    @Injected(\.service) var service

    func start() {
        service.doWork()  // ✅ Works
    }
}
```

See [Troubleshooting Guide](./troubleshooting.md) for solutions.

### How do I avoid circular dependencies?

**Problem:**
```swift
class ServiceA {
    @Injected(\.serviceB) var serviceB  // ServiceA → ServiceB
}

class ServiceB {
    @Injected(\.serviceA) var serviceA  // ServiceB → ServiceA (circular!)
}
```

**Solution 1: Introduce abstraction**
```swift
protocol EventBus {
    func publish(_ event: Event)
}

class ServiceA {
    @Injected(\.eventBus) var eventBus  // Both depend on abstraction

    func doWork() {
        eventBus.publish(WorkEvent())
    }
}

class ServiceB {
    @Injected(\.eventBus) var eventBus

    init() {
        eventBus.subscribe(WorkEvent.self) { event in
            // Handle event
        }
    }
}
```

**Solution 2: Weak reference**
```swift
class ServiceA {
    weak var serviceB: ServiceB?  // Weak breaks cycle
}

class ServiceB {
    @Injected(\.serviceA) var serviceA
}
```

**Solution 3: Refactor shared logic**
```swift
class SharedDependency {
    func performSharedWork() {
        // Logic both services need
    }
}

class ServiceA {
    @Injected(\.shared) var shared
}

class ServiceB {
    @Injected(\.shared) var shared
}
```

## Migration

### How do I migrate from Swinject/Resolver?

**Swinject → WeaveDI:**

```swift
// Old (Swinject)
let container = Container()
container.register(UserService.self) { _ in
    UserServiceImpl()
}

class ViewModel {
    let service = container.resolve(UserService.self)!
}

// New (WeaveDI)
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
}

extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

class ViewModel {
    @Injected(\.userService) var service
}
```

### How do I migrate from @Injected to @Injected?

See complete [Migration Guide](./migrationInjectToInjected.md).

**Quick migration:**
```swift
// Step 1: Old code
@Injected var service: UserService?

// Step 2: Define InjectedKey
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
}

extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

// Step 3: New code
@Injected(\.userService) var service  // Non-optional!
```

## Advanced Topics

### Can I use WeaveDI with UIKit?

**Yes:**

```swift
class UserViewController: UIViewController {
    @Injected(\.userService) var userService
    @Injected(\.analytics) var analytics

    override func viewDidLoad() {
        super.viewDidLoad()

        Task {
            await loadUser()
        }
    }

    func loadUser() async {
        let user = await userService.fetchCurrentUser()
        updateUI(with: user)
        analytics.track("user_view_loaded")
    }
}
```

### How do I handle environment-specific dependencies?

```swift
struct APIClientKey: InjectedKey {
    static var liveValue: APIClient {
        #if DEBUG
        return MockAPIClient()  // Development
        #else
        return URLSessionAPIClient()  // Production
        #endif
    }
}

// Or with build configuration
struct ConfigurableAPIKey: InjectedKey {
    static var liveValue: APIClient {
        if ProcessInfo.processInfo.environment["USE_MOCK"] == "1" {
            return MockAPIClient()
        }
        return URLSessionAPIClient()
    }
}
```

### Can I use WeaveDI in a Swift Package?

**Yes:**

```swift
// Package.swift
let package = Package(
    name: "MyFeature",
    dependencies: [
        .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.2.0")
    ],
    targets: [
        .target(
            name: "MyFeature",
            dependencies: ["WeaveDI"]
        )
    ]
)

// MyFeature/Sources/DI.swift
import WeaveDI

public extension InjectedValues {
    var myFeatureService: MyFeatureService {
        get { self[MyFeatureServiceKey.self] }
        set { self[MyFeatureServiceKey.self] = newValue }
    }
}
```

## Getting Help

### Where can I find more examples?

- [Quick Start Guide](./quickStart.md)
- [Tutorial: First App](../tutorial/firstApp.md)
- [GitHub Examples](https://github.com/Roy-wonji/WeaveDI/tree/main/Examples)
- [Best Practices](./bestPractices.md)

### How do I report a bug or request a feature?

- [GitHub Issues](https://github.com/Roy-wonji/WeaveDI/issues)
- [GitHub Discussions](https://github.com/Roy-wonji/WeaveDI/discussions)

### Is there a community?

- [GitHub Discussions](https://github.com/Roy-wonji/WeaveDI/discussions)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/weave-di) (tag: `weave-di`)

## Next Steps

- [Quick Start Guide](./quickStart.md) - Get started in 5 minutes
- [Best Practices](./bestPractices.md) - Recommended patterns
- [Troubleshooting](./troubleshooting.md) - Common issues
- [API Reference](../api/coreApis.md) - Complete API documentation
