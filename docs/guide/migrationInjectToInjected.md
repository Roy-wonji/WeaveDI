# Migrating from @Injected to @Injected

Complete guide for migrating from deprecated `@Injected`/`@SafeInject` to modern `@Injected` property wrapper (v3.2.0+).

## Why Migrate?

### @Injected/@SafeInject (Deprecated v3.2.0)
```swift
class ViewModel {
    @Injected var userService: UserService?        // ⚠️ Deprecated
    @SafeInject var apiClient: APIClient?        // ⚠️ Deprecated
}
```

**Limitations:**
- Optional-based, requires nil checking
- Runtime resolution only
- No compile-time safety for KeyPath
- Not TCA-compatible
- Limited testing support

### @Injected (v3.2.0+)
```swift
class ViewModel {
    @Injected(\.userService) var userService     // ✅ Recommended
    @Injected(\.apiClient) var apiClient         // ✅ Type-safe
}
```

**Benefits:**
- Non-optional by default (liveValue/testValue fallback)
- Compile-time type safety with KeyPath
- TCA-style API
- Built-in testing support with `withInjectedValues`
- Better type inference

## Migration Steps

### Step 1: Define InjectedKey

For each service you're using with `@Injected`, create an `InjectedKey`:

**Before (with @Injected):**
```swift
// Just register
let service = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}
```

**After (with @Injected):**
```swift
// 1. Define InjectedKey
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()
}
```

**Explanation:**
- `liveValue`: The production implementation
- `testValue`: The test/mock implementation (optional, defaults to liveValue)
- Conforms to `InjectedKey` protocol
- Provides type-safe access to dependencies

### Step 2: Extend InjectedValues

Create a computed property in `InjectedValues` for KeyPath access:

```swift
extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}
```

**Explanation:**
- `get`: Retrieves the value using the InjectedKey
- `set`: Allows overriding in tests
- Provides KeyPath `\.userService` for type-safe access

### Step 3: Replace @Injected with @Injected

**Before:**
```swift
class UserViewModel {
    @Injected var userService: UserService?

    func loadUser() async {
        guard let service = userService else {
            print("Service not available")
            return
        }
        let user = await service.fetchUser(id: "123")
    }
}
```

**After:**
```swift
class UserViewModel {
    @Injected(\.userService) var userService

    func loadUser() async {
        // No guard needed - non-optional
        let user = await userService.fetchUser(id: "123")
    }
}
```

**What changed:**
- `@Injected var userService: UserService?` → `@Injected(\.userService) var userService`
- Removed `guard let` unwrapping (non-optional)
- Cleaner, more concise code

### Step 4: Update Tests

**Before (with @Injected):**
```swift
override func setUp() {
    UnifiedDI.releaseAll()

    _ = UnifiedDI.register(UserService.self) {
        MockUserService()
    }
}

func testLoadUser() async {
    let viewModel = UserViewModel()
    await viewModel.loadUser()
}
```

**After (with @Injected):**
```swift
func testLoadUser() async {
    await withInjectedValues { values in
        values.userService = MockUserService()
    } operation: {
        let viewModel = UserViewModel()
        await viewModel.loadUser()
    }
}
```

**Explanation:**
- `withInjectedValues`: Scoped dependency override
- Automatically reverts after the operation
- No need for manual cleanup
- Type-safe value assignment

## Complete Migration Example

### Original Code (v3.1.0)

```swift
// Services/UserService.swift
protocol UserService {
    func fetchUser(id: String) async -> User?
}

class UserServiceImpl: UserService {
    func fetchUser(id: String) async -> User? {
        // Implementation
    }
}

// App Initialization
@main
struct MyApp: App {
    init() {
        _ = UnifiedDI.register(UserService.self) {
            UserServiceImpl()
        }
    }
}

// ViewModel
class UserViewModel {
    @Injected var userService: UserService?

    func loadUser() async {
        guard let service = userService else { return }
        let user = await service.fetchUser(id: "123")
    }
}

// Tests
class UserViewModelTests: XCTestCase {
    override func setUp() {
        UnifiedDI.releaseAll()
        _ = UnifiedDI.register(UserService.self) {
            MockUserService()
        }
    }

    func testLoadUser() async {
        let viewModel = UserViewModel()
        await viewModel.loadUser()
    }
}
```

### Migrated Code (v3.2.0+)

```swift
// DI/UserServiceKey.swift
import WeaveDI

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

// Services/UserService.swift (unchanged)
protocol UserService {
    func fetchUser(id: String) async -> User?
}

class UserServiceImpl: UserService {
    func fetchUser(id: String) async -> User? {
        // Implementation
    }
}

// App Initialization (optional, InjectedKey handles it)
@main
struct MyApp: App {
    init() {
        // No registration needed - InjectedKey provides liveValue
        // Or use AppDIManager for centralized setup
        WeaveDI.Container.bootstrapInTask { @DIContainerActor _ in
            await AppDIManager.shared.registerDefaultDependencies()
        }
    }
}

// ViewModel
class UserViewModel {
    @Injected(\.userService) var userService

    func loadUser() async {
        // No guard needed - non-optional
        let user = await userService.fetchUser(id: "123")
    }
}

// Tests
class UserViewModelTests: XCTestCase {
    func testLoadUser() async {
        await withInjectedValues { values in
            values.userService = MockUserService()
        } operation: {
            let viewModel = UserViewModel()
            await viewModel.loadUser()
        }
    }
}
```

## Migration Patterns

### Pattern 1: Simple Service

**Before:**
```swift
@Injected var logger: Logger?
```

**After:**
```swift
// 1. Define Key
struct LoggerKey: InjectedKey {
    static var liveValue: Logger = ConsoleLogger()
}

extension InjectedValues {
    var logger: Logger {
        get { self[LoggerKey.self] }
        set { self[LoggerKey.self] = newValue }
    }
}

// 2. Use
@Injected(\.logger) var logger
```

### Pattern 2: Multiple Dependencies

**Before:**
```swift
class ViewModel {
    @Injected var userService: UserService?
    @Injected var apiClient: APIClient?
    @Injected var cache: CacheService?
}
```

**After:**
```swift
// Define all keys
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
}

struct APIClientKey: InjectedKey {
    static var liveValue: APIClient = URLSessionAPIClient()
}

struct CacheServiceKey: InjectedKey {
    static var liveValue: CacheService = MemoryCacheService()
}

// Extend InjectedValues
extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }

    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }

    var cache: CacheService {
        get { self[CacheServiceKey.self] }
        set { self[CacheServiceKey.self] = newValue }
    }
}

// Use in ViewModel
class ViewModel {
    @Injected(\.userService) var userService
    @Injected(\.apiClient) var apiClient
    @Injected(\.cache) var cache
}
```

### Pattern 3: Type-Based Access (Alternative)

For types that implement `InjectedKey` directly:

```swift
// Make your implementation conform to InjectedKey
extension UserServiceImpl: InjectedKey {
    static var liveValue: UserServiceImpl { UserServiceImpl() }
}

// Use with type instead of KeyPath
@Injected(UserServiceImpl.self) var userService
```

## Common Migration Issues

### Issue 1: Optional vs Non-Optional

**Problem:**
```swift
// Old code expects optional
@Injected var service: UserService?
if let service = service {
    // Use service
}
```

**Solution:**
```swift
// @Injected is non-optional, no unwrapping needed
@Injected(\.service) var service
// Directly use service
```

### Issue 2: Circular Dependencies

**Problem:**
```swift
// ServiceA depends on ServiceB
// ServiceB depends on ServiceA
// Causes issues with InjectedKey static initialization
```

**Solution:**
```swift
// Use lazy initialization in InjectedKey
struct ServiceAKey: InjectedKey {
    static var liveValue: ServiceA {
        ServiceAImpl()  // Don't inject ServiceB in initializer
    }
}

// Or use property injection instead
class ServiceAImpl: ServiceA {
    @Injected(\.serviceB) var serviceB  // Lazy injection
}
```

### Issue 3: Test Setup Changes

**Problem:**
```swift
// Old test setup doesn't work
override func setUp() {
    UnifiedDI.releaseAll()  // Doesn't affect InjectedValues
}
```

**Solution:**
```swift
// Use withInjectedValues for each test
func testExample() async {
    await withInjectedValues { values in
        values.serviceA = MockServiceA()
        values.serviceB = MockServiceB()
    } operation: {
        // Run test with mocks
    }
}
```

## Gradual Migration Strategy

You don't need to migrate everything at once. Here's a gradual approach:

### Phase 1: New Code Only
```swift
// Keep existing @Injected code
class OldViewModel {
    @Injected var service: UserService?  // Keep as-is
}

// Use @Injected for new code
class NewViewModel {
    @Injected(\.userService) var service  // New code
}
```

### Phase 2: Module by Module
```swift
// Migrate one feature/module at a time
// Example: User module first
extension InjectedValues {
    // User module dependencies
    var userService: UserService { ... }
    var userRepository: UserRepository { ... }
}

// Then Auth module
extension InjectedValues {
    var authService: AuthService { ... }
    var tokenManager: TokenManager { ... }
}
```

### Phase 3: Critical Paths
```swift
// Migrate high-traffic code paths first
// Example: Main feed, authentication, etc.
class MainFeedViewModel {
    @Injected(\.feedService) var feedService  // Migrated
    @Injected(\.userService) var userService  // Migrated
}

// Less critical features can wait
class SettingsViewModel {
    @Injected var settingsService: SettingsService?  // Not migrated yet
}
```

## Compatibility Notes

### Both @Injected and @Injected Can Coexist

```swift
// This is valid during migration
class HybridViewModel {
    @Injected var oldService: OldService?           // Works
    @Injected(\.newService) var newService        // Works
    @Factory var generator: ReportGenerator       // Works
}
```

### UnifiedDI Still Works

```swift
// Legacy registration still works alongside InjectedKey
_ = UnifiedDI.register(LegacyService.self) {
    LegacyServiceImpl()
}

// Can be resolved with @Inject
@Injected var legacy: LegacyService?
```

## Performance Considerations

**@Injected is faster:**
- Compile-time KeyPath resolution
- No runtime dictionary lookups for KeyPath access
- Better optimization by the compiler

**Benchmarks (approximate):**
- @Injected: ~0.001ms per resolution
- @Injected: ~0.0001ms per resolution (10x faster)

## Migration Checklist

- [ ] Review all `@Injected` and `@SafeInject` usage in codebase
- [ ] Create `InjectedKey` for each service
- [ ] Extend `InjectedValues` with computed properties
- [ ] Replace `@Injected` with `@Injected(\.keyPath)`
- [ ] Remove optional unwrapping code
- [ ] Update test setup to use `withInjectedValues`
- [ ] Remove `UnifiedDI.register` calls (if using InjectedKey.liveValue)
- [ ] Test thoroughly
- [ ] Update documentation

## Next Steps

- [Best Practices Guide](./bestPractices.md) - Recommended patterns
- [@Injected API Reference](../api/injected.md) - Complete API documentation
- [TCA Integration](./tcaIntegration.md) - Using @Injected with TCA
- [Testing Guide](../tutorial/testing.md) - Advanced testing strategies

## Need Help?

- [Troubleshooting Guide](./troubleshooting.md) - Common issues and solutions
- [GitHub Issues](https://github.com/Roy-wonji/WeaveDI/issues) - Report migration problems
- [Migration Roadmap](./roadmap.md) - Deprecation timeline
