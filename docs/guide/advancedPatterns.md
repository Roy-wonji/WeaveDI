# Advanced Patterns & Best Practices

This comprehensive guide covers advanced dependency injection patterns, architectural best practices, and expert techniques for building production-ready applications with WeaveDI.

## Table of Contents

1. [Advanced Property Wrapper Patterns](#advanced-property-wrapper-patterns)
2. [Complex Dependency Graphs](#complex-dependency-graphs)
3. [Performance Optimization Techniques](#performance-optimization-techniques)
4. [Error Handling Strategies](#error-handling-strategies)
5. [Testing Patterns](#testing-patterns)
6. [Multi-Module Architecture](#multi-module-architecture)
7. [Production Deployment](#production-deployment)

## Advanced Property Wrapper Patterns

### Conditional Injection

Inject dependencies based on runtime conditions:

```swift
// Environment-based conditional injection
class EnvironmentAwareService {
    @Injected private var productionAPI: ProductionAPIService?
    @Injected private var developmentAPI: DevelopmentAPIService?

    private var apiService: APIServiceProtocol? {
        #if DEBUG
        return developmentAPI
        #else
        return productionAPI
        #endif
    }

    // Alternative: Runtime condition-based injection
    @Injected private var userService: UserService?
    @Injected private var adminService: AdminService?

    private func getService(for user: User) -> UserServiceProtocol? {
        return user.isAdmin ? adminService : userService
    }
}
```

### Generic Dependency Injection

Create type-safe generic dependency patterns:

```swift
// Generic repository pattern
protocol Repository<Entity> {
    associatedtype Entity: Codable
    func save(_ entity: Entity) async throws
    func fetch(id: String) async throws -> Entity?
    func fetchAll() async throws -> [Entity]
}

class CoreDataRepository<T: Codable>: Repository {
    typealias Entity = T

    @Injected private var coreDataStack: CoreDataStack?
    @Injected private var logger: Logger?

    func save(_ entity: T) async throws {
        logger?.info("Saving entity of type \(T.self)")
        // CoreData implementation
    }

    func fetch(id: String) async throws -> T? {
        logger?.info("Fetching \(T.self) with id: \(id)")
        // CoreData implementation
        return nil
    }

    func fetchAll() async throws -> [T] {
        logger?.info("Fetching all entities of type \(T.self)")
        // CoreData implementation
        return []
    }
}

// Registration
await WeaveDI.Container.bootstrap { container in
    container.register(Repository<User>.self) {
        CoreDataRepository<User>()
    }

    container.register(Repository<Product>.self) {
        CoreDataRepository<Product>()
    }
}

// Usage
class UserManager {
    @Injected private var userRepository: Repository<User>?

    func createUser(_ user: User) async throws {
        try await userRepository?.save(user)
    }
}
```

### Decorator Pattern with DI

Implement cross-cutting concerns using decorators:

```swift
// Base service
protocol OrderService {
    func processOrder(_ order: Order) async throws -> OrderResult
}

class BasicOrderService: OrderService {
    @Injected private var paymentService: PaymentService?
    @Injected private var inventoryService: InventoryService?

    func processOrder(_ order: Order) async throws -> OrderResult {
        // Basic order processing logic
        return OrderResult(orderId: order.id, status: .processed)
    }
}

// Logging decorator
class LoggingOrderService: OrderService {
    @Injected private var logger: Logger?
    private let decorated: OrderService

    init(decorated: OrderService) {
        self.decorated = decorated
    }

    func processOrder(_ order: Order) async throws -> OrderResult {
        logger?.info("Processing order: \(order.id)")

        do {
            let result = try await decorated.processOrder(order)
            logger?.info("Order processed successfully: \(order.id)")
            return result
        } catch {
            logger?.error("Order processing failed: \(order.id), error: \(error)")
            throw error
        }
    }
}

// Analytics decorator
class AnalyticsOrderService: OrderService {
    @Injected private var analytics: AnalyticsService?
    private let decorated: OrderService

    init(decorated: OrderService) {
        self.decorated = decorated
    }

    func processOrder(_ order: Order) async throws -> OrderResult {
        let startTime = Date()
        analytics?.track("order_processing_started", parameters: ["order_id": order.id])

        do {
            let result = try await decorated.processOrder(order)
            let duration = Date().timeIntervalSince(startTime)

            analytics?.track("order_processing_completed", parameters: [
                "order_id": order.id,
                "duration_ms": Int(duration * 1000),
                "status": result.status.rawValue
            ])

            return result
        } catch {
            analytics?.track("order_processing_failed", parameters: [
                "order_id": order.id,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
}

// Registration with decorator chain
await WeaveDI.Container.bootstrap { container in
    // Register base service
    container.register("BasicOrderService", OrderService.self) {
        BasicOrderService()
    }

    // Register decorated service
    container.register(OrderService.self) {
        let basicService = container.resolve("BasicOrderService", OrderService.self)!
        let loggingService = LoggingOrderService(decorated: basicService)
        return AnalyticsOrderService(decorated: loggingService)
    }
}
```

## Complex Dependency Graphs

### Circular Dependency Resolution

Handle circular dependencies safely:

```swift
// Use lazy injection to break circular dependencies
class UserService {
    @Injected private var orderService: OrderService?  // Will be nil initially

    // Lazy resolution to break cycles
    private lazy var lazyOrderService: OrderService? = {
        UnifiedDI.resolve(OrderService.self)
    }()

    func getUserOrders(userId: String) async throws -> [Order] {
        return try await lazyOrderService?.getOrdersForUser(userId) ?? []
    }
}

class OrderService {
    @Injected private var userService: UserService?

    private lazy var lazyUserService: UserService? = {
        UnifiedDI.resolve(UserService.self)
    }()

    func getOrdersForUser(_ userId: String) async throws -> [Order] {
        guard let user = try await lazyUserService?.getUser(id: userId) else {
            return []
        }
        // Return orders for user
        return []
    }
}

// Alternative: Use protocols to break cycles
protocol UserServiceProtocol {
    func getUser(id: String) async throws -> User?
}

protocol OrderServiceProtocol {
    func getOrdersForUser(_ userId: String) async throws -> [Order]
}

class UserServiceImpl: UserServiceProtocol {
    @Injected private var orderService: OrderServiceProtocol?

    func getUser(id: String) async throws -> User? {
        // Implementation
        return nil
    }
}

class OrderServiceImpl: OrderServiceProtocol {
    @Injected private var userService: UserServiceProtocol?

    func getOrdersForUser(_ userId: String) async throws -> [Order] {
        // Implementation
        return []
    }
}
```

### Hierarchical Dependencies

Create parent-child dependency relationships:

```swift
// Parent container with shared dependencies
class ParentContainer {
    static func configure() async {
        await WeaveDI.Container.bootstrap { container in
            // Shared/global dependencies
            container.register(DatabaseService.self) {
                CoreDataService()
            }

            container.register(NetworkService.self) {
                URLSessionNetworkService()
            }

            container.register(Logger.self) {
                ConsoleLogger()
            }
        }
    }
}

// Child container for feature-specific dependencies
class FeatureContainer {
    static func configure() async {
        // Assumes parent container is already configured
        await WeaveDI.Container.bootstrap { container in
            // Feature-specific dependencies that can use parent dependencies
            container.register(UserRepository.self) {
                UserRepositoryImpl() // Will auto-inject database and network services
            }

            container.register(UserService.self) {
                UserServiceImpl() // Will auto-inject user repository and logger
            }
        }
    }
}

// Usage in app
@main
struct MyApp: App {
    init() {
        Task {
            // Configure in order: parent first, then children
            await ParentContainer.configure()
            await FeatureContainer.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Performance Optimization Techniques

### Lazy Initialization Patterns

Optimize memory usage with lazy initialization:

```swift
class PerformanceOptimizedService {
    // Lazy property for expensive operations
    @Injected private var _expensiveService: ExpensiveService?
    private lazy var expensiveService: ExpensiveService? = {
        print("💰 Expensive service created")
        return _expensiveService
    }()

    // Factory for temporary objects
    @Factory private var temporaryProcessor: TemporaryProcessor

    // Cached computed property
    private var _cachedResult: String?
    private var cachedResult: String {
        if let cached = _cachedResult {
            return cached
        }

        let result = performExpensiveComputation()
        _cachedResult = result
        return result
    }

    private func performExpensiveComputation() -> String {
        // Expensive operation
        return "computed_result"
    }

    func performLightOperation() {
        // This won't trigger expensive service creation
        print("Light operation completed")
    }

    func performHeavyOperation() async {
        // This will create the expensive service only when needed
        await expensiveService?.performHeavyWork()
    }

    func processTemporaryData(_ data: Data) {
        // New processor instance for each call
        let processor = temporaryProcessor
        processor.process(data)
        // processor is automatically deallocated after use
    }
}
```

### Batch Dependency Resolution

Optimize multiple dependency resolutions:

```swift
class BatchOptimizedService {
    // Resolve multiple dependencies in a single batch
    private let dependencies: (
        userService: UserService?,
        orderService: OrderService?,
        paymentService: PaymentService?,
        notificationService: NotificationService?
    )

    init() {
        // Batch resolve all dependencies at once
        dependencies = (
            userService: UnifiedDI.resolve(UserService.self),
            orderService: UnifiedDI.resolve(OrderService.self),
            paymentService: UnifiedDI.resolve(PaymentService.self),
            notificationService: UnifiedDI.resolve(NotificationService.self)
        )
    }

    func processComplexWorkflow() async throws {
        // All dependencies are already resolved - no lookup cost
        guard let userService = dependencies.userService,
              let orderService = dependencies.orderService,
              let paymentService = dependencies.paymentService,
              let notificationService = dependencies.notificationService else {
            throw ServiceError.dependenciesNotAvailable
        }

        // Use pre-resolved dependencies
        let user = try await userService.getCurrentUser()
        let orders = try await orderService.getOrdersForUser(user.id)

        for order in orders {
            try await paymentService.processPayment(for: order)
            await notificationService.sendOrderConfirmation(order: order, to: user)
        }
    }
}
```

### Memory Pool Pattern

Reuse expensive objects:

```swift
// Object pool for expensive-to-create objects
class ImageProcessorPool {
    private var availableProcessors: [ImageProcessor] = []
    private var allProcessors: [ImageProcessor] = []
    private let maxPoolSize = 5
    private let lock = NSLock()

    @Factory private var processorFactory: ImageProcessor

    func borrowProcessor() -> ImageProcessor {
        lock.lock()
        defer { lock.unlock() }

        if let processor = availableProcessors.popLast() {
            return processor
        }

        // Create new processor if pool not at max capacity
        if allProcessors.count < maxPoolSize {
            let processor = processorFactory // Create new instance
            allProcessors.append(processor)
            return processor
        }

        // Pool is full, wait and reuse
        return availableProcessors.first ?? processorFactory
    }

    func returnProcessor(_ processor: ImageProcessor) {
        lock.lock()
        defer { lock.unlock() }

        processor.reset() // Clear any state
        availableProcessors.append(processor)
    }
}

class ImageService {
    @Injected private var processorPool: ImageProcessorPool?

    func processImages(_ images: [UIImage]) async -> [UIImage] {
        var processedImages: [UIImage] = []

        for image in images {
            guard let pool = processorPool else { continue }

            let processor = pool.borrowProcessor()
            let processed = await processor.process(image)
            processedImages.append(processed)
            pool.returnProcessor(processor)
        }

        return processedImages
    }
}
```

## Error Handling Strategies

### Graceful Degradation

Handle missing dependencies gracefully:

```swift
class ResilientService {
    @Injected private var primaryService: PrimaryService?
    @Injected private var fallbackService: FallbackService?
    @Injected private var logger: Logger?

    func performOperation() async throws -> Result {
        // Try primary service first
        if let primary = primaryService {
            do {
                return try await primary.performOperation()
            } catch {
                logger?.warning("Primary service failed, trying fallback: \(error)")
            }
        }

        // Fall back to secondary service
        if let fallback = fallbackService {
            do {
                return try await fallback.performOperation()
            } catch {
                logger?.error("Fallback service also failed: \(error)")
                throw ServiceError.allServicesFailed
            }
        }

        // Graceful degradation - return cached or default result
        logger?.info("No services available, returning cached result")
        return getCachedResult() ?? getDefaultResult()
    }

    private func getCachedResult() -> Result? {
        // Return cached data if available
        return nil
    }

    private func getDefaultResult() -> Result {
        // Return safe default
        return Result.empty
    }
}
```

### Dependency Health Checks

Monitor dependency health:

```swift
protocol HealthCheckable {
    func healthCheck() async -> HealthStatus
}

enum HealthStatus {
    case healthy
    case degraded(reason: String)
    case unhealthy(error: Error)
}

class HealthMonitorService {
    @Injected private var userService: UserService?
    @Injected private var databaseService: DatabaseService?
    @Injected private var networkService: NetworkService?
    @Injected private var logger: Logger?

    func performHealthCheck() async -> [String: HealthStatus] {
        var results: [String: HealthStatus] = [:]

        // Check all injectable dependencies
        await withTaskGroup(of: (String, HealthStatus).self) { group in
            if let service = userService as? HealthCheckable {
                group.addTask { ("UserService", await service.healthCheck()) }
            }

            if let service = databaseService as? HealthCheckable {
                group.addTask { ("DatabaseService", await service.healthCheck()) }
            }

            if let service = networkService as? HealthCheckable {
                group.addTask { ("NetworkService", await service.healthCheck()) }
            }

            for await (serviceName, status) in group {
                results[serviceName] = status

                switch status {
                case .healthy:
                    logger?.info("\(serviceName): Healthy")
                case .degraded(let reason):
                    logger?.warning("\(serviceName): Degraded - \(reason)")
                case .unhealthy(let error):
                    logger?.error("\(serviceName): Unhealthy - \(error)")
                }
            }
        }

        return results
    }
}
```

## Testing Patterns

### Test Double Injection

Advanced mocking patterns:

```swift
// Test double protocol
protocol TestDouble {
    var callHistory: [String] { get set }
    func reset()
}

// Spy service that records all interactions
class SpyUserService: UserService, TestDouble {
    var callHistory: [String] = []
    var users: [String: User] = [:]

    func reset() {
        callHistory.removeAll()
        users.removeAll()
    }

    func getUser(id: String) async throws -> User? {
        callHistory.append("getUser(id: \(id))")
        return users[id]
    }

    func createUser(_ user: User) async throws {
        callHistory.append("createUser(\(user.name))")
        users[user.id] = user
    }

    func updateUser(_ user: User) async throws {
        callHistory.append("updateUser(\(user.name))")
        users[user.id] = user
    }
}

// Stub service with predefined responses
class StubPaymentService: PaymentService, TestDouble {
    var callHistory: [String] = []
    var shouldSucceed = true
    var predefinedResults: [String: PaymentResult] = [:]

    func reset() {
        callHistory.removeAll()
        shouldSucceed = true
        predefinedResults.removeAll()
    }

    func processPayment(amount: Decimal, method: PaymentMethod) async throws -> PaymentResult {
        callHistory.append("processPayment(amount: \(amount), method: \(method))")

        let key = "\(amount)_\(method.rawValue)"
        if let predefinedResult = predefinedResults[key] {
            return predefinedResult
        }

        if shouldSucceed {
            return PaymentResult(success: true, transactionId: "test_\(UUID().uuidString)")
        } else {
            throw PaymentError.processingFailed
        }
    }
}

// Test case using test doubles
class PaymentProcessorTests: XCTestCase {
    var spyUserService: SpyUserService!
    var stubPaymentService: StubPaymentService!
    var processor: PaymentProcessor!

    override func setUp() async throws {
        await super.setUp()

        // Create test doubles
        spyUserService = SpyUserService()
        stubPaymentService = StubPaymentService()

        // Register test doubles
        await WeaveDI.Container.bootstrap { container in
            container.register(UserService.self, instance: spyUserService)
            container.register(PaymentService.self, instance: stubPaymentService)
        }

        processor = PaymentProcessor()
    }

    override func tearDown() async throws {
        await super.tearDown()

        // Reset test doubles
        spyUserService.reset()
        stubPaymentService.reset()
    }

    func testSuccessfulPayment() async throws {
        // Given
        let user = User(id: "test", name: "Test User", email: "test@example.com")
        spyUserService.users[user.id] = user

        stubPaymentService.shouldSucceed = true

        // When
        let result = try await processor.processUserPayment(
            userId: user.id,
            amount: 99.99,
            method: .creditCard
        )

        // Then
        XCTAssertTrue(result.success)

        // Verify interactions
        XCTAssertEqual(spyUserService.callHistory, ["getUser(id: test)"])
        XCTAssertEqual(stubPaymentService.callHistory.count, 1)
        XCTAssertTrue(stubPaymentService.callHistory[0].contains("processPayment"))
    }
}
```

### Integration Test Containers

Create specialized containers for integration testing:

```swift
class IntegrationTestContainer {
    static func configure() async {
        await WeaveDI.Container.bootstrap { container in
            // Use real implementations for integration testing
            container.register(NetworkService.self) {
                URLSessionNetworkService(baseURL: "https://test-api.example.com")
            }

            // Use in-memory database for testing
            container.register(DatabaseService.self) {
                InMemoryDatabaseService()
            }

            // Use test analytics that don't send data
            container.register(AnalyticsService.self) {
                TestAnalyticsService()
            }

            // Use real business logic services
            container.register(UserService.self) {
                UserServiceImpl()
            }
        }
    }
}

class IntegrationTests: XCTestCase {
    override func setUp() async throws {
        await super.setUp()
        await IntegrationTestContainer.configure()
    }

    func testCompleteUserFlow() async throws {
        // Test the complete flow with real services
        let userService = UnifiedDI.resolve(UserService.self)!

        // Create user
        let newUser = User(id: "integration_test", name: "Integration Test", email: "test@integration.com")
        try await userService.createUser(newUser)

        // Verify user was created
        let retrievedUser = try await userService.getUser(id: newUser.id)
        XCTAssertEqual(retrievedUser?.name, newUser.name)

        // Update user
        var updatedUser = newUser
        updatedUser.name = "Updated Name"
        try await userService.updateUser(updatedUser)

        // Verify update
        let finalUser = try await userService.getUser(id: newUser.id)
        XCTAssertEqual(finalUser?.name, "Updated Name")
    }
}
```

## Multi-Module Architecture

### Feature Module Pattern

Organize large applications into feature modules:

```swift
// Base feature module protocol
protocol FeatureModule {
    static var name: String { get }
    static func configure() async
    static func dependencies() -> [String] // Module dependencies
}

// User feature module
struct UserFeatureModule: FeatureModule {
    static let name = "UserFeature"

    static func dependencies() -> [String] {
        return ["CoreFeature", "NetworkFeature"]
    }

    static func configure() async {
        await WeaveDI.Container.bootstrap { container in
            container.register(UserRepository.self) {
                CoreDataUserRepository()
            }

            container.register(UserService.self) {
                UserServiceImpl()
            }

            container.register(UserViewController.self) {
                UserViewController()
            }
        }
    }
}

// Order feature module
struct OrderFeatureModule: FeatureModule {
    static let name = "OrderFeature"

    static func dependencies() -> [String] {
        return ["UserFeature", "PaymentFeature"]
    }

    static func configure() async {
        await WeaveDI.Container.bootstrap { container in
            container.register(OrderRepository.self) {
                APIOrderRepository()
            }

            container.register(OrderService.self) {
                OrderServiceImpl()
            }
        }
    }
}

// Module manager for dependency-ordered loading
class ModuleManager {
    private static var configuredModules: Set<String> = []

    static func configureModules(_ modules: [FeatureModule.Type]) async {
        let sortedModules = topologicalSort(modules)

        for moduleType in sortedModules {
            if !configuredModules.contains(moduleType.name) {
                print("🔧 Configuring module: \(moduleType.name)")
                await moduleType.configure()
                configuredModules.insert(moduleType.name)
                print("✅ Module configured: \(moduleType.name)")
            }
        }
    }

    private static func topologicalSort(_ modules: [FeatureModule.Type]) -> [FeatureModule.Type] {
        // Implement topological sort based on dependencies
        var sorted: [FeatureModule.Type] = []
        var visited: Set<String> = []
        var visiting: Set<String> = []

        func visit(_ moduleType: FeatureModule.Type) {
            let moduleName = moduleType.name

            if visiting.contains(moduleName) {
                fatalError("Circular dependency detected involving \(moduleName)")
            }

            if visited.contains(moduleName) {
                return
            }

            visiting.insert(moduleName)

            // Visit dependencies first
            for dependencyName in moduleType.dependencies() {
                if let dependencyModule = modules.first(where: { $0.name == dependencyName }) {
                    visit(dependencyModule)
                }
            }

            visiting.remove(moduleName)
            visited.insert(moduleName)
            sorted.append(moduleType)
        }

        for moduleType in modules {
            visit(moduleType)
        }

        return sorted
    }
}

// Usage in app
@main
struct MyApp: App {
    init() {
        Task {
            await ModuleManager.configureModules([
                CoreFeatureModule.self,
                NetworkFeatureModule.self,
                UserFeatureModule.self,
                PaymentFeatureModule.self,
                OrderFeatureModule.self
            ])
            print("🚀 All modules configured successfully")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Production Deployment

### Environment Configuration

Configure different environments:

```swift
enum Environment {
    case development
    case staging
    case production

    static var current: Environment {
        #if DEBUG
        return .development
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }
}

class ProductionConfiguration {
    static func configure() async {
        switch Environment.current {
        case .development:
            await configureDevelopment()
        case .staging:
            await configureStaging()
        case .production:
            await configureProduction()
        }
    }

    private static func configureDevelopment() async {
        await WeaveDI.Container.bootstrap { container in
            // Development services
            container.register(APIService.self) {
                MockAPIService()
            }

            container.register(Logger.self) {
                ConsoleLogger(level: .debug)
            }

            container.register(AnalyticsService.self) {
                ConsoleAnalyticsService()
            }
        }

        // Enable development optimizations
        UnifiedDI.setLogLevel(.all)
    }

    private static func configureStaging() async {
        await WeaveDI.Container.bootstrap { container in
            // Staging services
            container.register(APIService.self) {
                HTTPAPIService(baseURL: "https://staging-api.example.com")
            }

            container.register(Logger.self) {
                FileLogger(level: .info, file: "staging.log")
            }

            container.register(AnalyticsService.self) {
                TestAnalyticsService()
            }
        }

        // Staging optimizations
        UnifiedDI.setLogLevel(.warnings)
    }

    private static func configureProduction() async {
        await WeaveDI.Container.bootstrap { container in
            // Production services
            container.register(APIService.self) {
                HTTPAPIService(baseURL: "https://api.example.com")
            }

            container.register(Logger.self) {
                RemoteLogger(level: .error, endpoint: "https://logs.example.com")
            }

            container.register(AnalyticsService.self) {
                FirebaseAnalyticsService()
            }
        }

        // Production optimizations
        UnifiedRegistry.shared.enableOptimization()
        UnifiedDI.setLogLevel(.errors)
    }
}
```

### Performance Monitoring

Monitor DI performance in production:

```swift
class ProductionMonitoring {
    @Injected private var logger: Logger?

    static func setupMonitoring() {
        // Monitor slow dependency resolutions
        UnifiedDI.onSlowResolution { serviceName, duration in
            if duration > 0.01 { // 10ms threshold
                print("⚠️ Slow DI resolution: \(serviceName) took \(duration * 1000)ms")
            }
        }

        // Monitor memory usage
        UnifiedDI.onMemoryPressure {
            print("💾 DI Container under memory pressure")
        }

        // Monitor error rates
        UnifiedDI.onResolutionError { serviceName, error in
            print("❌ DI Resolution failed: \(serviceName) - \(error)")
        }
    }
}
```

This comprehensive guide provides advanced patterns and best practices for using WeaveDI in production applications. These patterns help you build scalable, maintainable, and performant applications with sophisticated dependency injection requirements.