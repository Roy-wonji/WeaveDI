# WeaveDI Best Practices

Recommended patterns and practices for using WeaveDI effectively in production applications.

## Property Wrapper Selection

### Use @Injected for Most Cases (v3.2.0+)

```swift
// ✅ Recommended: Type-safe, TCA-style
@Injected(\.userService) var userService
@Injected(\.apiClient) var apiClient
```

**Why:**
- Compile-time type safety with KeyPath
- Non-optional by default (liveValue/testValue fallback)
- Better testing support with `withInjectedValues`
- TCA-compatible API

### Use @Factory for Fresh Instances

```swift
// ✅ Good: Stateless operations
@Factory var pdfGenerator: PDFGenerator
@Factory var reportBuilder: ReportBuilder
@Factory var dateFormatter: DateFormatter
```

**When to use:**
- Stateless services (PDF generators, formatters, parsers)
- Each operation needs isolated state
- Concurrent processing with independent instances
- Builder patterns requiring fresh instances

**Example:**
```swift
class DocumentService {
    @Factory var pdfGenerator: PDFGenerator

    func generateReports(data: [ReportData]) async {
        await withTaskGroup(of: PDF.self) { group in
            for item in data {
                group.addTask {
                    // Each task gets fresh generator - no state conflicts
                    let generator = self.pdfGenerator
                    return generator.generate(item)
                }
            }
        }
    }
}
```

### Avoid @Injected/@SafeInject (Deprecated v3.2.0)

```swift
// ❌ Avoid: Deprecated
@Injected var service: UserService?
@SafeInject var api: APIClient?

// ✅ Use instead:
@Injected(\.service) var service
@Injected(\.api) var api
```

## Dependency Organization

### Group Dependencies by Feature

```swift
// ✅ Good: Feature-based organization
// File: DI/UserFeatureDependencies.swift
extension InjectedValues {
    // User feature dependencies
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }

    var userRepository: UserRepository {
        get { self[UserRepositoryKey.self] }
        set { self[UserRepositoryKey.self] = newValue }
    }
}

// File: DI/AuthFeatureDependencies.swift
extension InjectedValues {
    // Auth feature dependencies
    var authService: AuthService {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }

    var tokenManager: TokenManager {
        get { self[TokenManagerKey.self] }
        set { self[TokenManagerKey.self] = newValue }
    }
}
```

**Benefits:**
- Clear feature boundaries
- Easy to find related dependencies
- Easier to remove features
- Better code organization

### Centralize InjectedKey Definitions

```swift
// ✅ Good: All keys in one place
// File: DI/InjectedKeys.swift
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()
}

struct APIClientKey: InjectedKey {
    static var liveValue: APIClient = URLSessionAPIClient()
    static var testValue: APIClient = MockAPIClient()
}

// Then extend InjectedValues in feature files
```

## Scope Management

### Use Appropriate Scopes

```swift
// ✅ Singleton for app-wide services
struct LoggerKey: InjectedKey {
    static var liveValue: Logger = ConsoleLogger()  // Shared instance
}

// ✅ Scoped for feature-specific services
await WeaveDI.Container.bootstrap { container in
    container.register(SessionService.self, scope: .session) {
        SessionServiceImpl()
    }
}
```

**Scope Guidelines:**
| Scope | Use Case | Example |
|-------|----------|---------|
| Singleton | App-wide services | Logger, Analytics, Config |
| Session | User session services | Auth token, User preferences |
| Request | Per-request services | API client per network call |
| Transient | Fresh instances | Formatters, Builders |

### Example: Multi-Scope Architecture

```swift
// App-wide singleton
struct AnalyticsKey: InjectedKey {
    static var liveValue: Analytics = FirebaseAnalytics()
}

// Session-scoped service
class SessionManager {
    @Injected(\.authToken) var authToken  // Changes per session
    @Injected(\.analytics) var analytics  // Shared singleton

    func login(credentials: Credentials) async {
        // authToken is session-specific
        // analytics is app-wide
    }
}
```

## Performance Optimization

### Minimize Dependency Count

```swift
// ❌ Bad: Too many dependencies
class ViewModel {
    @Injected(\.service1) var service1
    @Injected(\.service2) var service2
    @Injected(\.service3) var service3
    @Injected(\.service4) var service4
    @Injected(\.service5) var service5  // Too many!
}

// ✅ Good: Compose services
class ViewModel {
    @Injected(\.userFacade) var userFacade  // Facade pattern
}

// Facade combines related services
class UserFacade {
    @Injected(\.userService) var userService
    @Injected(\.authService) var authService
    @Injected(\.profileService) var profileService

    func performUserAction() {
        // Coordinate multiple services
    }
}
```

### Lazy Loading for Heavy Dependencies

```swift
// ✅ Good: Lazy initialization
struct DatabaseKey: InjectedKey {
    static var liveValue: Database {
        // Expensive initialization deferred
        Database.shared
    }
}

// Access only when needed
class DataService {
    @Injected(\.database) var database

    func saveData() {
        // Database initialized only when first accessed
        database.save()
    }
}
```

### Use @Factory for Concurrent Operations

```swift
// ✅ Good: Parallel processing with @Factory
class ImageProcessor {
    @Factory var imageFilter: ImageFilter

    func processImages(_ images: [UIImage]) async -> [UIImage] {
        await withTaskGroup(of: UIImage.self) { group in
            for image in images {
                group.addTask {
                    // Fresh filter for each image - no thread conflicts
                    let filter = self.imageFilter
                    return filter.apply(to: image)
                }
            }

            var results: [UIImage] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
}
```

## Testing Strategies

### Use withInjectedValues for Tests

```swift
// ✅ Good: Scoped dependency override
func testUserLogin() async {
    await withInjectedValues { values in
        values.authService = MockAuthService()
        values.userService = MockUserService()
    } operation: {
        let viewModel = LoginViewModel()
        await viewModel.login(credentials: testCredentials)

        XCTAssertTrue(viewModel.isLoggedIn)
    }
}
```

**Benefits:**
- Automatic cleanup after test
- No global state pollution
- Type-safe value assignment
- Works with async/await

### Define Test Values in InjectedKey

```swift
// ✅ Good: Built-in test values
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()  // Predefined mock
}

// Tests use testValue automatically in test context
func testWithDefaults() async {
    await withInjectedValues { values in
        // testValue used automatically
    } operation: {
        // Test code
    }
}
```

### Create Test Helpers

```swift
// ✅ Good: Reusable test setup
extension XCTestCase {
    func withTestDependencies(
        userService: UserService = MockUserService(),
        apiClient: APIClient = MockAPIClient(),
        operation: () async throws -> Void
    ) async rethrows {
        await withInjectedValues { values in
            values.userService = userService
            values.apiClient = apiClient
        } operation: {
            try await operation()
        }
    }
}

// Use in tests
func testExample() async throws {
    await withTestDependencies {
        // Test with standard mocks
    }
}
```

## Error Handling

### Handle Missing Dependencies Gracefully

```swift
// ✅ Good: Fallback values
struct LoggerKey: InjectedKey {
    static var liveValue: Logger = ConsoleLogger()
    static var testValue: Logger = NoOpLogger()  // Silent in tests
}

// Service always has a logger, even if not configured
class Service {
    @Injected(\.logger) var logger  // Never nil

    func performAction() {
        logger.log("Action performed")  // Safe to call
    }
}
```

### Validate Critical Dependencies at Startup

```swift
// ✅ Good: Early validation
@main
struct MyApp: App {
    init() {
        validateDependencies()
        setupDependencies()
    }

    func validateDependencies() {
        // Check critical dependencies exist
        precondition(
            type(of: InjectedValues.current.apiClient) != Never.self,
            "API Client must be configured"
        )
    }

    func setupDependencies() {
        // Configure dependencies
    }
}
```

### Provide Meaningful Error Messages

```swift
// ✅ Good: Descriptive errors
struct APIClientKey: InjectedKey {
    static var liveValue: APIClient {
        guard let baseURL = ProcessInfo.processInfo.environment["API_BASE_URL"] else {
            fatalError("""
                ❌ API_BASE_URL environment variable not set

                Please configure API_BASE_URL in your scheme's environment variables:
                1. Edit Scheme → Run → Arguments → Environment Variables
                2. Add: API_BASE_URL = https://api.example.com
                """)
        }
        return URLSessionAPIClient(baseURL: baseURL)
    }
}
```

## Architecture Patterns

### Use Protocol-Based Design

```swift
// ✅ Good: Protocol for abstraction
protocol UserService {
    func fetchUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws
}

// Multiple implementations possible
class ProductionUserService: UserService { /* ... */ }
class MockUserService: UserService { /* ... */ }
class CachedUserService: UserService { /* ... */ }

// Define once, swap implementations
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = ProductionUserService()
    static var testValue: UserService = MockUserService()
}
```

### Layer Your Dependencies

```swift
// ✅ Good: Clear layers
// Layer 1: Infrastructure (bottom)
extension InjectedValues {
    var networkClient: NetworkClient { /* ... */ }
    var database: Database { /* ... */ }
    var logger: Logger { /* ... */ }
}

// Layer 2: Data/Repository
extension InjectedValues {
    var userRepository: UserRepository { /* ... */ }
    var productRepository: ProductRepository { /* ... */ }
}

// Layer 3: Domain/Business Logic
extension InjectedValues {
    var userService: UserService { /* ... */ }
    var orderService: OrderService { /* ... */ }
}

// Layer 4: Presentation
// ViewModels inject services from layer 3
```

### Avoid Circular Dependencies

```swift
// ❌ Bad: Circular dependency
class ServiceA {
    @Injected(\.serviceB) var serviceB
}

class ServiceB {
    @Injected(\.serviceA) var serviceA  // Circular!
}

// ✅ Good: Introduce abstraction
protocol EventBus {
    func publish(_ event: Event)
}

class ServiceA {
    @Injected(\.eventBus) var eventBus  // Both depend on abstraction
}

class ServiceB {
    @Injected(\.eventBus) var eventBus  // No circular dependency
}
```

### Use Composition Over Inheritance

```swift
// ❌ Bad: Inheritance-based
class BaseService {
    @Injected(\.logger) var logger
}

class UserService: BaseService {
    // Inherits logger
}

// ✅ Good: Composition-based
class UserService {
    @Injected(\.logger) var logger  // Explicit
    @Injected(\.database) var database

    // Clear, self-contained
}
```

## Code Organization Checklist

- [ ] Use `@Injected` for new code (v3.2.0+)
- [ ] Group dependencies by feature/module
- [ ] Define clear dependency layers
- [ ] Minimize dependencies per class (< 5)
- [ ] Use protocols for abstractions
- [ ] Provide both liveValue and testValue in InjectedKey
- [ ] Validate critical dependencies at startup
- [ ] Document dependency relationships
- [ ] Avoid circular dependencies
- [ ] Use appropriate scopes for services

## Anti-Patterns to Avoid

### ❌ Service Locator Pattern

```swift
// ❌ Bad: Manual service location
class ViewModel {
    func loadData() {
        let service = InjectedValues.current.userService  // Bad!
        // Use service
    }
}

// ✅ Good: Inject dependencies
class ViewModel {
    @Injected(\.userService) var userService

    func loadData() {
        // Use userService
    }
}
```

### ❌ Global Singletons

```swift
// ❌ Bad: Global singleton
class APIClient {
    static let shared = APIClient()
}

// ✅ Good: Managed by DI
struct APIClientKey: InjectedKey {
    static var liveValue: APIClient = APIClient()
}

// Inject where needed
@Injected(\.apiClient) var apiClient
```

### ❌ Constructor Injection with Defaults

```swift
// ❌ Bad: Hidden dependencies
class UserService {
    init(
        apiClient: APIClient = InjectedValues.current.apiClient,  // Bad!
        database: Database = InjectedValues.current.database
    ) { }
}

// ✅ Good: Explicit dependency injection
class UserService {
    @Injected(\.apiClient) var apiClient
    @Injected(\.database) var database

    init() { }  // Clean initializer
}
```

## Runtime Diagnostics Control

- `WEAVEDI_REGISTRY_HEALTH_LOGGING=1`: opt in if you want auto health-check/auto-fix logs (default is off).
- `WEAVEDI_REGISTRY_AUTO_HEALTH=0`: disable the UnifiedRegistry health-check loop entirely.
- `WEAVEDI_REGISTRY_AUTO_FIX=0`: avoid triggering automatic fixes when the score drops.

All flags are consumed by `WeaveDIConfiguration.applyFromEnvironment()`, so you can toggle them per scheme or CI job.

### Log levels for runtime diagnostics

Tune noise without touching env vars by calling `UnifiedDI.setLogLevel(_:)`:

| Level | Emits |
| ----- | ----- |
| `.all` | every diagnostic message (default) |
| `.registration` | registration successes + critical errors |
| `.optimization` | optimization lifecycle + errors |
| `.errors` | errors plus registration failures/overwrites |
| `.off` | silent mode |

```swift
WeaveDIConfiguration.applyFromEnvironment()
UnifiedDI.setLogLevel(.errors)
```

Registry health/auto-fix logs stay disabled unless you explicitly enable `WEAVEDI_REGISTRY_HEALTH_LOGGING`.

## Next Steps

- [Migration Guide](./migrationInjectToInjected) - Upgrading from @Inject
- [TCA Integration](./tcaIntegration) - Using with The Composable Architecture
- [Performance Guide](./runtimeOptimization) - Optimization techniques
- [Testing Guide](../tutorial/testing) - Advanced testing patterns

## CI Diagnostics Automation

### Catch duplicate providers/scope drifts
Add `WeaveDITools diagnose-components --json` to your CI pipeline to block duplicate providers or scope mismatches before the build stage. The `deploy.yml` example:

```yaml
- name: 🧩 Component diagnostics
  run: |
    swift run --configuration release WeaveDITools diagnose-components --json > component-report.json
    python3 - <<'PY'
    import json, sys
    data = json.load(open('component-report.json'))
    issues = data.get('issues', [])
    if issues:
        for item in issues:
            print(f"- {item['type']}: {', '.join(item['providers'])} -> {item.get('detail')}")
        sys.exit(1)
    PY
```

### Metadata-powered cycle hints
The new `check-cycles` subcommand inspects compile-time component metadata to surface simple component cycles:

```bash
swift run WeaveDITools check-cycles --json
```

For CI, call the bundled `Scripts/check-component-cycles.sh` helper. It exits with code `1` when a cycle is found, enriching your “compile-time hint channel” with actionable failures.
