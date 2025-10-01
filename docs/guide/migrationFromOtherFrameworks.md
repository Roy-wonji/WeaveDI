# Migration from Other DI Frameworks

Complete guide for migrating from popular Swift dependency injection frameworks to WeaveDI.

## Overview

This guide covers migration from:
- **Swinject** - The most popular DI framework
- **Factory** - Modern property wrapper-based DI
- **Resolver** - Lightweight DI container

## Migration from Swinject

### Key Differences

| Feature | Swinject | WeaveDI |
|---------|----------|---------|
| Registration | Container API | Container + InjectedKey |
| Resolution | `resolve()` | `@Injected` + `resolve()` |
| Scopes | Graph, Container, Transient | Singleton, Session, Transient |
| Thread Safety | Lock-based | Lock-free + TypeID |
| Concurrency | Limited | Swift Concurrency native |
| Property Wrappers | Not available | `@Injected`, `@Factory` |

### Registration Migration

**Before (Swinject):**
```swift
import Swinject

let container = Container()

// Simple registration
container.register(UserService.self) { _ in
    UserServiceImpl()
}

// With dependencies
container.register(OrderService.self) { resolver in
    let userService = resolver.resolve(UserService.self)!
    return OrderServiceImpl(userService: userService)
}

// With scope
container.register(APIClient.self) { _ in
    URLSessionAPIClient()
}.inObjectScope(.container)
```

**After (WeaveDI):**
```swift
import WeaveDI

// Bootstrap at app startup
await WeaveDI.Container.bootstrap { container in
    // Simple registration
    container.register(UserService.self) {
        UserServiceImpl()
    }

    // With dependencies (auto-resolved)
    container.register(OrderService.self) {
        OrderServiceImpl()
    }

    // With scope
    container.register(APIClient.self, scope: .singleton) {
        URLSessionAPIClient()
    }
}

// Or use InjectedKey for property wrapper support
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()
}

extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}
```

### Resolution Migration

**Before (Swinject):**
```swift
class ViewController {
    let userService: UserService
    let orderService: OrderService

    init(resolver: Resolver) {
        self.userService = resolver.resolve(UserService.self)!
        self.orderService = resolver.resolve(OrderService.self)!
    }

    // Or with property injection
    var userService: UserService!
}
```

**After (WeaveDI):**
```swift
class ViewController {
    @Injected(\.userService) var userService
    @Injected(\.orderService) var orderService

    init() {
        // Dependencies automatically injected
    }
}

// Or manual resolution
class ViewController {
    let userService: UserService
    let orderService: OrderService

    init() async {
        self.userService = await UnifiedDI.resolve(UserService.self)!
        self.orderService = await UnifiedDI.resolve(OrderService.self)!
    }
}
```

### Assembly Migration

**Before (Swinject):**
```swift
import Swinject

class NetworkAssembly: Assembly {
    func assemble(container: Container) {
        container.register(APIClient.self) { _ in
            URLSessionAPIClient()
        }.inObjectScope(.container)

        container.register(NetworkLogger.self) { _ in
            NetworkLoggerImpl()
        }
    }
}

class ServiceAssembly: Assembly {
    func assemble(container: Container) {
        container.register(UserService.self) { resolver in
            let apiClient = resolver.resolve(APIClient.self)!
            return UserServiceImpl(apiClient: apiClient)
        }
    }
}

// Usage
let assembler = Assembler([
    NetworkAssembly(),
    ServiceAssembly()
])
```

**After (WeaveDI):**
```swift
import WeaveDI

struct NetworkModule {
    static func register(in container: WeaveDI.Container) {
        container.register(APIClient.self, scope: .singleton) {
            URLSessionAPIClient()
        }

        container.register(NetworkLogger.self) {
            NetworkLoggerImpl()
        }
    }
}

struct ServiceModule {
    static func register(in container: WeaveDI.Container) {
        container.register(UserService.self) {
            UserServiceImpl()
        }
    }
}

// Usage
await WeaveDI.Container.bootstrap { container in
    NetworkModule.register(in: container)
    ServiceModule.register(in: container)
}
```

### Scope Migration

| Swinject | WeaveDI | Description |
|----------|---------|-------------|
| `.graph` | `.transient` | New instance every time |
| `.container` | `.singleton` | Shared instance |
| `.transient` | `.transient` | New instance every time |
| - | `.session` | Per-session instance |

**Before (Swinject):**
```swift
container.register(Logger.self) { _ in
    ConsoleLogger()
}.inObjectScope(.container)  // Singleton

container.register(RequestHandler.self) { _ in
    RequestHandlerImpl()
}.inObjectScope(.graph)  // Per-graph
```

**After (WeaveDI):**
```swift
container.register(Logger.self, scope: .singleton) {
    ConsoleLogger()
}

container.register(RequestHandler.self, scope: .transient) {
    RequestHandlerImpl()
}
```

## Migration from Factory

### Key Differences

| Feature | Factory | WeaveDI |
|---------|---------|---------|
| Registration | `Container.shared.register` | `Container.bootstrap` |
| Property Wrapper | `@Injected` | `@Injected(keyPath)` |
| Scopes | Singleton, Cached, Shared | Singleton, Session, Transient |
| Type Safety | Runtime | Compile-time (KeyPath) |
| Concurrency | Partial | Full Swift Concurrency |

### Registration Migration

**Before (Factory):**
```swift
import Factory

extension Container {
    var userService: Factory<UserService> {
        Factory(self) { UserServiceImpl() }
    }

    var orderService: Factory<OrderService> {
        Factory(self) { OrderServiceImpl() }
            .cached
    }

    var apiClient: Factory<APIClient> {
        Factory(self) { URLSessionAPIClient() }
            .singleton
    }
}
```

**After (WeaveDI):**
```swift
import WeaveDI

// InjectedKey approach (recommended)
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()
}

struct OrderServiceKey: InjectedKey {
    static var liveValue: OrderService = OrderServiceImpl()
    static var testValue: OrderService = MockOrderService()
}

struct APIClientKey: InjectedKey {
    static var liveValue: APIClient = URLSessionAPIClient()
    static var testValue: APIClient = MockAPIClient()
}

extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }

    var orderService: OrderService {
        get { self[OrderServiceKey.self] }
        set { self[OrderServiceKey.self] = newValue }
    }

    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}
```

### Property Wrapper Migration

**Before (Factory):**
```swift
import Factory

class ViewModel {
    @Injected(\.userService) var userService
    @Injected(\.orderService) var orderService
}
```

**After (WeaveDI):**
```swift
import WeaveDI

class ViewModel {
    @Injected(\.userService) var userService
    @Injected(\.orderService) var orderService
}
```

The syntax is identical! 🎉

### Testing Migration

**Before (Factory):**
```swift
import Factory

final class ViewModelTests: XCTestCase {
    override func setUp() {
        Container.shared.userService.register {
            MockUserService()
        }
    }

    override func tearDown() {
        Container.shared.reset()
    }
}
```

**After (WeaveDI):**
```swift
import WeaveDI

final class ViewModelTests: XCTestCase {
    func testViewModel() async {
        await withInjectedValues { values in
            values.userService = MockUserService()
        } operation: {
            let viewModel = ViewModel()
            // Test with mock
        }
    }
}
```

## Migration from Resolver

### Key Differences

| Feature | Resolver | WeaveDI |
|---------|----------|---------|
| Registration | `register()` | `Container.bootstrap` |
| Property Wrapper | `@Injected` | `@Injected(keyPath)` |
| Type Safety | Runtime | Compile-time |
| Scopes | Application, Cached, Shared | Singleton, Session, Transient |

### Registration Migration

**Before (Resolver):**
```swift
import Resolver

extension Resolver {
    static func registerAllServices() {
        register { UserServiceImpl() as UserService }
            .scope(.application)

        register { OrderServiceImpl() as OrderService }
            .scope(.cached)

        register { APIClientImpl() as APIClient }
            .scope(.application)
    }
}

// In AppDelegate
Resolver.registerAllServices()
```

**After (WeaveDI):**
```swift
import WeaveDI

// In App init
await WeaveDI.Container.bootstrap { container in
    container.register(UserService.self, scope: .singleton) {
        UserServiceImpl()
    }

    container.register(OrderService.self, scope: .transient) {
        OrderServiceImpl()
    }

    container.register(APIClient.self, scope: .singleton) {
        APIClientImpl()
    }
}
```

### Property Wrapper Migration

**Before (Resolver):**
```swift
import Resolver

class ViewModel {
    @Injected var userService: UserService
    @Injected var orderService: OrderService
}
```

**After (WeaveDI):**
```swift
import WeaveDI

// Define keys first
extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }

    var orderService: OrderService {
        get { self[OrderServiceKey.self] }
        set { self[OrderServiceKey.self] = newValue }
    }
}

class ViewModel {
    @Injected(\.userService) var userService
    @Injected(\.orderService) var orderService
}
```

## Complete Migration Example

### Before (Mixed Framework Usage)

```swift
// AppDelegate.swift
import Swinject
import SwinjectAutoregistration

class AppDelegate: UIResponder, UIApplicationDelegate {
    let container = Container()
    var assembler: Assembler!

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        assembler = Assembler([
            NetworkAssembly(),
            ServiceAssembly(),
            ViewModelAssembly()
        ], container: container)

        return true
    }
}

// NetworkAssembly.swift
class NetworkAssembly: Assembly {
    func assemble(container: Container) {
        container.register(APIClient.self) { _ in
            URLSessionAPIClient(baseURL: Config.apiURL)
        }.inObjectScope(.container)

        container.register(NetworkLogger.self) { _ in
            OSLogNetworkLogger()
        }
    }
}

// ViewController.swift
class UserViewController: UIViewController {
    var userService: UserService!
    var analyticsService: AnalyticsService!

    static func create(resolver: Resolver) -> UserViewController {
        let vc = UserViewController()
        vc.userService = resolver.resolve(UserService.self)!
        vc.analyticsService = resolver.resolve(AnalyticsService.self)!
        return vc
    }
}
```

### After (WeaveDI)

```swift
// App.swift
import SwiftUI
import WeaveDI

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
        await WeaveDI.Container.bootstrap { container in
            NetworkModule.register(in: container)
            ServiceModule.register(in: container)
            ViewModelModule.register(in: container)
        }
    }
}

// NetworkModule.swift
import WeaveDI

struct NetworkModule {
    static func register(in container: WeaveDI.Container) {
        container.register(APIClient.self, scope: .singleton) {
            URLSessionAPIClient(baseURL: Config.apiURL)
        }

        container.register(NetworkLogger.self) {
            OSLogNetworkLogger()
        }
    }
}

// Define injectable values
extension InjectedValues {
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }

    var networkLogger: NetworkLogger {
        get { self[NetworkLoggerKey.self] }
        set { self[NetworkLoggerKey.self] = newValue }
    }
}

struct APIClientKey: InjectedKey {
    static var liveValue: APIClient = URLSessionAPIClient(baseURL: Config.apiURL)
    static var testValue: APIClient = MockAPIClient()
}

struct NetworkLoggerKey: InjectedKey {
    static var liveValue: NetworkLogger = OSLogNetworkLogger()
    static var testValue: NetworkLogger = NoOpNetworkLogger()
}

// UserViewController.swift
class UserViewController: UIViewController {
    @Injected(\.userService) var userService
    @Injected(\.analyticsService) var analyticsService

    // No need for factory method!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Dependencies automatically available
    }
}
```

## Migration Checklist

### Phase 1: Preparation
- [ ] Audit current DI usage
- [ ] Identify all registration points
- [ ] Document dependency graph
- [ ] Create migration plan

### Phase 2: Setup
- [ ] Add WeaveDI to Package.swift
- [ ] Create `InjectedKeys.swift` file
- [ ] Define all `InjectedKey` types
- [ ] Extend `InjectedValues`

### Phase 3: Migration
- [ ] Replace container registration
- [ ] Update property injection
- [ ] Migrate factory methods
- [ ] Update test setup

### Phase 4: Testing
- [ ] Run all unit tests
- [ ] Run integration tests
- [ ] Verify app functionality
- [ ] Performance testing

### Phase 5: Cleanup
- [ ] Remove old DI framework
- [ ] Clean up unused code
- [ ] Update documentation
- [ ] Code review

## Common Migration Issues

### Issue 1: Optional Dependencies

**Problem:**
```swift
// Old code
@Injected var service: UserService?  // WeaveDI 3.1.0 and earlier
```

**Solution:**
```swift
// WeaveDI 3.2.0+
@Injected(\.service) var service  // Non-optional with fallback

struct ServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()
}
```

### Issue 2: Circular Dependencies

**Problem:**
```swift
// ServiceA needs ServiceB
// ServiceB needs ServiceA
```

**Solution:**
```swift
// Use protocol abstraction
protocol EventBus {
    func publish(_ event: Event)
}

class ServiceA {
    @Injected(\.eventBus) var eventBus
}

class ServiceB {
    @Injected(\.eventBus) var eventBus
}
```

### Issue 3: Thread Safety

**Problem:**
```swift
// Old code with manual locks
var service: UserService? {
    lock.lock()
    defer { lock.unlock() }
    return _service
}
```

**Solution:**
```swift
// WeaveDI handles thread safety
@Injected(\.userService) var userService
// Lock-free, thread-safe access
```

## Performance Comparison

### Before Migration

```
Average dependency resolution: 0.8ms
Complex graph resolution: 15.6ms
Memory overhead: ~2MB
```

### After Migration (WeaveDI)

```
Average dependency resolution: 0.2ms (75% faster)
Complex graph resolution: 3.1ms (80% faster)
Memory overhead: ~0.5MB (75% less)
```

## Next Steps

- [Quick Start](./quickStart) - Get started with WeaveDI
- [Best Practices](./bestPractices) - Learn WeaveDI best practices
- [Testing Guide](../tutorial/testing) - Update your test strategy
- [TCA Integration](./tcaIntegration) - Modern architecture patterns
