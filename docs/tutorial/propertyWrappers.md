# Mastering WeaveDI Property Wrappers

Deep dive into WeaveDI's powerful property wrapper system based on actual source code analysis. Learn how to use @Injected and @Factory effectively.

## 🎯 What You'll Learn

- **@Injected**: Dependency injection with KeyPath or type-based resolution
- **@Factory**: Creating new instances every time
- **Advanced patterns**: Custom property wrappers
- **Performance optimization**: Hot path caching
- **Real-world usage**: Practical examples from actual projects

## 📚 Understanding the Source Code

Let's examine the actual WeaveDI property wrapper implementations from `PropertyWrappers.swift`:

### @Injected - The Core Property Wrapper

```swift
// From actual WeaveDI source: Dependency.swift
@propertyWrapper
public struct Injected<Value> {
    private let keyPath: KeyPath<InjectedValues, Value>?
    private let keyType: (any InjectedKey.Type)?

    /// KeyPath-based initialization (Type-safe)
    /// This provides compile-time safety by using KeyPaths
    public init(_ keyPath: KeyPath<InjectedValues, Value>) {
        self.keyPath = keyPath
        self.keyType = nil
    }

    /// Type-based initialization (For direct type resolution)
    /// When you need to resolve by type directly
    public init<K: InjectedKey>(_ type: K.Type) where K.Value == Value, K.Value: Sendable {
        self.keyPath = nil
        self.keyType = type
    }

    // The magic happens here - dependency resolution
    public var wrappedValue: Value {
        get {
            if let keyPath = keyPath {
                // KeyPath resolution - type-safe and fast
                return InjectedValues.current[keyPath: keyPath]
            } else if let keyType = keyType {
                // Type-based resolution
                return _getValue(from: keyType)
            } else {
                fatalError("@Injected requires either keyPath or keyType")
            }
        }
    }
}
```

**🔍 What this means:**
- **KeyPath Resolution**: When you use `@Injected(\.someService)`, it uses compile-time safe KeyPaths with `InjectedValues`
- **Type Resolution**: When you use `@Injected(SomeKey.self)`, it resolves by `InjectedKey` type
- **Non-Optional Return**: Returns the value directly (use liveValue or testValue as fallback)

### @Factory - Always New Instances

```swift
// From actual WeaveDI source: PropertyWrappers.swift
@propertyWrapper
public struct Factory<T> {
    private let keyPath: KeyPath<WeaveDI.Container, T?>?
    private let directFactory: (() -> T)?

    /// KeyPath-based factory (registered factory function)
    public init(_ keyPath: KeyPath<WeaveDI.Container, T?>) {
        self.keyPath = keyPath
        self.directFactory = nil
    }

    /// Direct factory function (inline creation)
    public init(factory: @escaping () -> T) {
        self.keyPath = nil
        self.directFactory = factory
    }

    /// Always returns a NEW instance
    public var wrappedValue: T {
        // Direct factory - call every time
        if let factory = directFactory {
            return factory()
        }

        // KeyPath factory - resolve every time
        if let keyPath = keyPath {
            guard let instance = WeaveDI.Container.live[keyPath: keyPath] else {
                fatalError("🚨 [Factory] Factory not found for keyPath: \(keyPath)")
            }
            return instance
        }

        fatalError("🚨 [Factory] Factory not properly configured")
    }
}
```

**🔍 What this means:**
- **Always New**: Every access creates a fresh instance
- **Two Modes**: Either registered factory or direct factory
- **Non-Optional**: Always returns a value (crashes if not available)

## 🛠️ Practical Usage Patterns

### 1. Basic @Injected Usage

```swift
import WeaveDI

class UserViewController: UIViewController {
    // ✅ Most common pattern - Optional injection
    @Injected var userService: UserService?
    @Injected var logger: LoggerProtocol?

    // ✅ Required service with guard check
    @Injected var authService: AuthService?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Safe unwrapping pattern
        guard let auth = authService else {
            logger?.error("AuthService not available - cannot proceed")
            showError("Authentication service unavailable")
            return
        }

        // Now safely use the service
        if auth.isUserLoggedIn {
            loadUserData()
        } else {
            showLoginScreen()
        }
    }

    private func loadUserData() {
        // Optional chaining for non-critical services
        userService?.fetchCurrentUser { [weak self] result in
            switch result {
            case .success(let user):
                self?.displayUser(user)
            case .failure(let error):
                self?.logger?.error("Failed to load user: \(error)")
            }
        }
    }
}
```

**🎯 Key Points:**
- Use optional injection for most services
- Always guard against nil for critical services
- Use logger injection for debugging
- Optional chaining for safe access

### 2. KeyPath-Based Type-Safe Injection

```swift
// First, extend WeaveDI.Container with KeyPaths
extension WeaveDI.Container {
    var userRepository: UserRepository? {
        resolve(UserRepository.self)
    }

    var apiClient: APIClient? {
        resolve(APIClient.self)
    }

    var imageCache: ImageCache? {
        resolve(ImageCache.self)
    }
}

// Then use type-safe injection
class DataManager {
    // ✅ Type-safe with compile-time checking
    @Injected(\.userRepository) var userRepo: UserRepository?
    @Injected(\.apiClient) var api: APIClient?
    @Injected(\.imageCache) var cache: ImageCache?

    func syncUserData() async {
        // Compiler ensures these types are correct
        guard let repo = userRepo, let api = api else {
            print("❌ Required services not available")
            return
        }

        do {
            let userData = try await api.fetchUserData()
            try await repo.save(userData)
            print("✅ User data synced successfully")
        } catch {
            print("❌ Sync failed: \(error)")
        }
    }
}
```

**🎯 Benefits:**
- **Compile-time safety**: Typos caught at build time
- **Refactoring support**: IDE can rename safely
- **Auto-completion**: Better developer experience

### 3. @Factory for Stateless Objects

```swift
class DocumentProcessor {
    // ✅ New PDF generator for each document
    @Factory var pdfGenerator: PDFGenerator

    // ✅ New report builder for each report
    @Factory var reportBuilder: ReportBuilder

    // ✅ Inline factory for simple objects
    @Factory(factory: { DateFormatter() }) var dateFormatter: DateFormatter

    func processDocuments(_ documents: [Document]) async {
        await withTaskGroup(of: Void.self) { group in
            for document in documents {
                group.addTask { [self] in
                    // Each task gets a fresh PDF generator
                    // No shared state between concurrent operations
                    let generator = self.pdfGenerator

                    await generator.configure(for: document)
                    let pdf = await generator.generate()
                    await saveToDatabase(pdf)
                }
            }
        }
    }

    func generateReport(for data: AnalyticsData) -> Report {
        // Fresh report builder ensures clean state
        let builder = reportBuilder

        return builder
            .setTitle("Analytics Report")
            .setData(data)
            .setTimestamp(dateFormatter.string(from: Date()))
            .build()
    }
}
```

**🎯 When to use @Factory:**
- **Stateless operations**: PDF generation, data parsing
- **Concurrent processing**: Each task needs isolated instance
- **Builder patterns**: Fresh builder for each construction
- **Formatters**: Avoid shared state issues

### 4. Advanced @Injected Pattern

```swift
// Custom SafeInject for required dependencies
@propertyWrapper
struct RequiredInject<T> {
    private let keyPath: KeyPath<WeaveDI.Container, T?>?
    private let type: T.Type

    init(_ keyPath: KeyPath<WeaveDI.Container, T?>) {
        self.keyPath = keyPath
        self.type = T.self
    }

    init() {
        self.keyPath = nil
        self.type = T.self
    }

    var wrappedValue: T {
        let resolved: T?

        if let keyPath = keyPath {
            resolved = WeaveDI.Container.live[keyPath: keyPath]
        } else {
            resolved = WeaveDI.Container.live.resolve(type)
        }

        guard let value = resolved else {
            #if DEBUG
            fatalError("""
            🚨 Required dependency not found!

            Type: \(T.self)
            KeyPath: \(keyPath?.debugDescription ?? "none")

            💡 Solution:
            Register this dependency in your bootstrap:
            container.register(\(T.self).self) { YourImplementation() }
            """)
            #else
            // In production, try to provide a safe fallback
            fatalError("Critical dependency missing: \(T.self)")
            #endif
        }

        return value
    }
}

// Usage in critical systems
class PaymentProcessor {
    // ❌ Don't use optional for critical services
    // @Injected var paymentGateway: PaymentGateway?

    // ✅ Use RequiredInject for critical dependencies
    @RequiredInject var paymentGateway: PaymentGateway
    @RequiredInject var fraudDetection: FraudDetectionService
    @RequiredInject var auditLogger: AuditLogger

    func processPayment(_ payment: Payment) async throws {
        // No need to check for nil - guaranteed to exist
        auditLogger.logPaymentAttempt(payment)

        // Critical services are always available
        let fraudResult = await fraudDetection.analyze(payment)
        guard fraudResult.isValid else {
            auditLogger.logFraudAttempt(payment, reason: fraudResult.reason)
            throw PaymentError.fraudDetected
        }

        // Process with confidence
        let result = try await paymentGateway.charge(payment)
        auditLogger.logPaymentSuccess(payment, transactionId: result.id)
    }
}
```

## 🚀 Performance Optimization Patterns

### Hot Path Optimization

```swift
class HighFrequencyService {
    // ✅ Cache frequently used dependencies
    @Injected var dataProcessor: DataProcessor?
    private var cachedProcessor: DataProcessor?

    // Optimized access pattern
    private var processor: DataProcessor {
        if let cached = cachedProcessor {
            return cached
        }

        guard let injected = dataProcessor else {
            fatalError("DataProcessor not registered")
        }

        cachedProcessor = injected
        return injected
    }

    func processData(_ data: [DataPoint]) async {
        // Hot path - uses cached instance
        await processor.process(data)
    }
}
```

### Lazy Injection Pattern

```swift
class ExpensiveResourceManager {
    // ✅ Lazy initialization for expensive resources
    @Injected private var expensiveService: ExpensiveService?

    private lazy var service: ExpensiveService = {
        guard let injected = expensiveService else {
            fatalError("ExpensiveService not registered")
        }
        print("🚀 Initializing expensive service...")
        return injected
    }()

    func performExpensiveOperation() {
        // Only initialized when first accessed
        service.doExpensiveWork()
    }
}
```

## 🧪 Testing with Property Wrappers

### Mock Registration Strategy

```swift
class NetworkManagerTests: XCTestCase {
    var networkManager: NetworkManager!

    override func setUp() async throws {
        await super.setUp()

        // Clean DI state for each test
        await WeaveDI.Container.bootstrap { container in
            // Register test doubles
            container.register(HTTPClient.self) {
                MockHTTPClient()
            }

            container.register(AuthTokenProvider.self) {
                MockAuthTokenProvider()
            }

            container.register(RequestLogger.self) {
                MockRequestLogger()
            }
        }

        // Create system under test
        networkManager = NetworkManager()
    }

    func testNetworkRequest_Success() async throws {
        // Given
        let mockClient = UnifiedDI.resolve(HTTPClient.self) as! MockHTTPClient
        mockClient.mockResponse = MockResponse.success

        // When
        let result = try await networkManager.fetchUserData(id: "123")

        // Then
        XCTAssertEqual(result.id, "123")
        XCTAssertTrue(mockClient.requestCalled)
    }
}

class NetworkManager {
    @Injected var httpClient: HTTPClient?
    @Injected var authProvider: AuthTokenProvider?
    @Injected var logger: RequestLogger?

    func fetchUserData(id: String) async throws -> UserData {
        guard let client = httpClient else {
            throw NetworkError.clientNotAvailable
        }

        logger?.logRequest("fetchUserData", id: id)

        let request = URLRequest(url: URL(string: "/users/\(id)")!)
        let data = try await client.perform(request)

        return try JSONDecoder().decode(UserData.self, from: data)
    }
}
```

## 📋 Best Practices Summary

### ✅ DO

1. **Use @Injected for most dependencies**
   ```swift
   @Injected var service: SomeService?
   ```

2. **Use KeyPaths for type safety**
   ```swift
   @Injected(\.userRepository) var repo: UserRepository?
   ```

3. **Use @Factory for stateless objects**
   ```swift
   @Factory var generator: ReportGenerator
   ```

4. **Guard against nil for critical services**
   ```swift
   guard let service = injectedService else {
       handleMissingDependency()
       return
   }
   ```

5. **Cache frequently accessed dependencies**
   ```swift
   private lazy var cachedService = injectedService!
   ```

### ❌ DON'T

1. **Don't force unwrap injected dependencies**
   ```swift
   // ❌ Dangerous
   @Injected var service: SomeService?
   let result = service!.doSomething()

   // ✅ Safe
   guard let service = service else { return }
   let result = service.doSomething()
   ```

2. **Don't use @Factory for stateful objects**
   ```swift
   // ❌ Creates new state every time
   @Factory var userSession: UserSession

   // ✅ Shared state
   @Injected var userSession: UserSession?
   ```

3. **Don't ignore injection failures in production**
   ```swift
   // ❌ Silent failure
   @Injected var analytics: AnalyticsService?
   analytics?.track(event) // Silently fails

   // ✅ Explicit handling
   guard let analytics = analytics else {
       logger.warning("Analytics not available")
       return
   }
   analytics.track(event)
   ```

## 🔄 Migration Patterns

### From Manual DI to Property Wrappers

```swift
// Before: Manual dependency injection
class UserService {
    private let repository: UserRepository
    private let validator: UserValidator

    init(repository: UserRepository, validator: UserValidator) {
        self.repository = repository
        self.validator = validator
    }
}

// After: Property wrapper injection
class UserService {
    @Injected var repository: UserRepository?
    @Injected var validator: UserValidator?

    func processUser(_ user: User) async throws {
        guard let repo = repository, let val = validator else {
            throw ServiceError.dependenciesNotAvailable
        }

        try val.validate(user)
        try await repo.save(user)
    }
}
```

## 🎯 Next Steps

- [Concurrency Integration Tutorial](/tutorial/concurrencyIntegration)
- [Testing Strategies](/tutorial/testing)
- [Performance Optimization](/tutorial/performanceOptimization)

---

**Congratulations!** You now understand the full power of WeaveDI's property wrapper system. You can build maintainable, testable, and performant applications with confidence.
