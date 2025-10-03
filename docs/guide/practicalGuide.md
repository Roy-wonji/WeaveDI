# Practical Usage Guide

Learn how to effectively use WeaveDI in real projects step by step. Focuses on scenarios and solutions frequently encountered in practice.

## 🏗️ Application by Project Structure

### MVVM Architecture Application

```swift
// MARK: - Repository Layer
protocol UserRepository {
    func fetchUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws
}

class UserRepositoryImpl: UserRepository {
    @Injected var apiService: APIService?
    @Injected var cacheService: CacheService?

    func fetchUser(id: String) async throws -> User {
        // Check cache
        if let cached = cacheService?.getUser(id: id) {
            return cached
        }

        // API call
        guard let api = apiService else {
            throw DIError.dependencyNotFound(APIService.self)
        }
        let user = try await api.fetchUser(id: id)

        // Save to cache
        cacheService?.setUser(user, id: id)
        return user
    }
}

// MARK: - ViewModel Layer
class UserViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Injected var userRepository: UserRepository?
    @RequiredInject var logger: LoggerProtocol

    func loadUser(id: String) {
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                guard let repo = userRepository else {
                    throw AppError.repositoryNotAvailable
                }

                self.user = try await repo.fetchUser(id: id)
                logger.info("User loading completed: \(id)")
            } catch {
                self.errorMessage = error.localizedDescription
                logger.error("User loading failed: \(error)")
            }
            self.isLoading = false
        }
    }
}

// MARK: - View Layer
struct UserView: View {
    @StateObject private var viewModel = UserViewModel()
    let userId: String

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading user information...")
            } else if let user = viewModel.user {
                UserDetailView(user: user)
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    viewModel.loadUser(id: userId)
                }
            }
        }
        .onAppear {
            viewModel.loadUser(id: userId)
        }
    }
}
```

### Clean Architecture Application

```swift
// MARK: - Domain Layer (no dependencies)
protocol UserUseCase {
    func getUserProfile(id: String) async throws -> UserProfile
    func updateUserProfile(_ profile: UserProfile) async throws
}

struct UserProfile {
    let id: String
    let name: String
    let email: String
    let avatar: URL?
}

// MARK: - Use Case Implementation
class UserUseCaseImpl: UserUseCase {
    @RequiredInject var userRepository: UserRepository
    @RequiredInject var validationService: ValidationService
    @Injected var analyticsService: AnalyticsService?

    func getUserProfile(id: String) async throws -> UserProfile {
        analyticsService?.track("user_profile_requested", parameters: ["user_id": id])

        let user = try await userRepository.fetchUser(id: id)
        return UserProfile(
            id: user.id,
            name: user.name,
            email: user.email,
            avatar: user.avatarURL
        )
    }

    func updateUserProfile(_ profile: UserProfile) async throws {
        // Validation
        try validationService.validate(profile)

        // Update
        let user = User(from: profile)
        try await userRepository.updateUser(user)

        analyticsService?.track("user_profile_updated",
                               parameters: ["user_id": profile.id])
    }
}

// MARK: - Dependency Setup for Clean Architecture
extension UnifiedDI {
    static func setupCleanArchitecture() {
        registerMany {
            // Domain Layer - Use Cases
            Registration(UserUseCase.self) { UserUseCaseImpl() }
            Registration(AuthUseCase.self) { AuthUseCaseImpl() }

            // Data Layer - Repositories
            Registration(UserRepository.self) { UserRepositoryImpl() }
            Registration(AuthRepository.self) { AuthRepositoryImpl() }

            // Infrastructure Layer - Services
            Registration(APIService.self) { URLSessionAPIService() }
            Registration(CacheService.self) { NSCacheService() }
            Registration(ValidationService.self) { DefaultValidationService() }

            // Cross-cutting Concerns
            Registration(LoggerProtocol.self, default: OSLogLogger())
            Registration(AnalyticsService.self, condition: !isDebug,
                        factory: { FirebaseAnalytics() },
                        fallback: { NoOpAnalytics() })
        }
    }
}
```

## 🧪 Testing Strategy

### Unit Test Setup

```swift
import XCTest
@testable import MyApp

class UserViewModelTests: XCTestCase {
    var viewModel: UserViewModel!
    var mockRepository: MockUserRepository!
    var mockLogger: MockLogger!

    override func setUp() async throws {
        await super.setUp()

        // Clean DI container setup for testing
        await UnifiedDI.releaseAll()

        // Create mock objects
        mockRepository = MockUserRepository()
        mockLogger = MockLogger()

        // Register mock dependencies
        UnifiedDI.registerMany {
            Registration(UserRepository.self) { mockRepository }
            Registration(LoggerProtocol.self) { mockLogger }
        }

        // Create test subject
        viewModel = UserViewModel()
    }

    func testLoadUser_Success() async throws {
        // Given
        let expectedUser = User(id: "1", name: "Test User", email: "test@example.com")
        mockRepository.mockUser = expectedUser

        // When
        await viewModel.loadUser(id: "1")

        // Then
        XCTAssertEqual(viewModel.user, expectedUser)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(mockRepository.fetchUserCalled)
        XCTAssertTrue(mockLogger.infoMessages.contains { $0.contains("User loading completed") })
    }

    func testLoadUser_RepositoryError() async throws {
        // Given
        mockRepository.shouldThrowError = true

        // When
        await viewModel.loadUser(id: "1")

        // Then
        XCTAssertNil(viewModel.user)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(mockLogger.errorMessages.contains { $0.contains("User loading failed") })
    }
}

// MARK: - Mock Objects
class MockUserRepository: UserRepository {
    var mockUser: User?
    var shouldThrowError = false
    var fetchUserCalled = false

    func fetchUser(id: String) async throws -> User {
        fetchUserCalled = true

        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }

        return mockUser ?? User(id: id, name: "Default", email: "default@example.com")
    }

    func updateUser(_ user: User) async throws {
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
    }
}

class MockLogger: LoggerProtocol {
    var infoMessages: [String] = []
    var errorMessages: [String] = []

    func info(_ message: String) {
        infoMessages.append(message)
    }

    func error(_ message: String) {
        errorMessages.append(message)
    }
}
```

### Integration Test Setup

```swift
class IntegrationTests: XCTestCase {

    override func setUp() async throws {
        await super.setUp()

        // Integration test dependency setup (real implementations + some mocks)
        await UnifiedDI.releaseAll()

        UnifiedDI.registerMany {
            // Use real implementations
            Registration(ValidationService.self) { DefaultValidationService() }
            Registration(CacheService.self) { NSCacheService() }

            // Use mock for network (remove external dependencies)
            Registration(APIService.self) { MockAPIService() }

            // Use test logger
            Registration(LoggerProtocol.self) { TestLogger() }

            // Use real use case implementations
            Registration(UserUseCase.self) { UserUseCaseImpl() }
            Registration(UserRepository.self) { UserRepositoryImpl() }
        }
    }

    func testUserProfileFlow_EndToEnd() async throws {
        // Given
        let userUseCase: UserUseCase = UnifiedDI.requireResolve(UserUseCase.self)
        let mockAPI = UnifiedDI.resolve(APIService.self) as! MockAPIService
        mockAPI.mockUserData = ["id": "1", "name": "John", "email": "john@example.com"]

        // When
        let profile = try await userUseCase.getUserProfile(id: "1")

        // Then
        XCTAssertEqual(profile.id, "1")
        XCTAssertEqual(profile.name, "John")
        XCTAssertEqual(profile.email, "john@example.com")

        // Check cache
        let cacheService: CacheService = UnifiedDI.requireResolve(CacheService.self)
        XCTAssertNotNil(cacheService.getUser(id: "1"))
    }
}
```

## 🔧 Performance Optimization

### Lazy Loading Pattern

```swift
class ExpensiveService {
    @Injected private var heavyComputation: HeavyComputationService?
    @Injected private var databaseService: DatabaseService?

    // Computed property for lazy initialization
    private var _processedData: ProcessedData?
    var processedData: ProcessedData {
        if let cached = _processedData {
            return cached
        }

        // Initialize only on first access
        let data = heavyComputation?.process() ?? ProcessedData.empty
        _processedData = data
        return data
    }

    func reset() {
        _processedData = nil
    }
}

// Apply lazy loading during registration
UnifiedDI.register(ExpensiveService.self) {
    // Defer creation until actually resolved
    ExpensiveService()
}
```

### Scoped Dependencies

```swift
// Request-scoped dependency (e.g., per web request)
class RequestScopedService {
    let requestId: String
    let timestamp: Date

    init() {
        self.requestId = UUID().uuidString
        self.timestamp = Date()
    }
}

// Session-scoped dependency (e.g., per user session)
class SessionScopedService {
    let sessionId: String
    let user: User

    init(user: User) {
        self.sessionId = UUID().uuidString
        self.user = user
    }
}

// Scoped registration helper
extension UnifiedDI {
    static func registerScoped<T>(
        _ type: T.Type,
        scope: DependencyScope,
        factory: @escaping @Sendable () -> T
    ) {
        switch scope {
        case .request:
            // Create new instance per request
            register(type, factory: factory)
        case .session:
            // Maintain instance per session
            let instance = factory()
            register(type) { instance }
        case .instance:
            // Maintain app-wide instance
            let instance = factory()
            register(type) { instance }
        }
    }
}

enum DependencyScope {
    case request
    case session
    case instance
}
```

### Memory Management

```swift
class MemoryEfficientService {
    @Injected private weak var optionalService: OptionalService?
    @RequiredInject private var requiredService: RequiredService

    private var cache: [String: Any] = [:]
    private let cacheLimit = 100

    func performOperation(key: String) -> Result {
        // Manage cache size
        if cache.count > cacheLimit {
            cleanupCache()
        }

        // Optional service uses weak reference for memory efficiency
        if let service = optionalService {
            return service.process(key: key)
        }

        return requiredService.fallbackProcess(key: key)
    }

    private func cleanupCache() {
        // Remove old cache in LRU fashion
        let sortedKeys = cache.keys.sorted { key1, key2 in
            // Actually sort based on access time
            key1 < key2
        }

        for key in sortedKeys.prefix(cacheLimit / 2) {
            cache.removeValue(forKey: key)
        }
    }

    deinit {
        cache.removeAll()
    }
}
```

## 🚀 Advanced Patterns

### Factory Pattern Integration

```swift
// Factory interface
protocol ServiceFactory {
    func createUserService() -> UserService
    func createNetworkService() -> NetworkService
}

// Environment-specific factory implementations
class ProductionServiceFactory: ServiceFactory {
    func createUserService() -> UserService {
        return ProductionUserService()
    }

    func createNetworkService() -> NetworkService {
        return HTTPNetworkService()
    }
}

class DevelopmentServiceFactory: ServiceFactory {
    func createUserService() -> UserService {
        return MockUserService()
    }

    func createNetworkService() -> NetworkService {
        return MockNetworkService()
    }
}

// Dependency registration through factory
class AppDependencySetup {
    static func configure() {
        let factory: ServiceFactory = isProduction ?
            ProductionServiceFactory() : DevelopmentServiceFactory()

        UnifiedDI.registerMany {
            Registration(ServiceFactory.self) { factory }
            Registration(UserService.self) { factory.createUserService() }
            Registration(NetworkService.self) { factory.createNetworkService() }
        }
    }
}
```

### Observer Pattern Integration

```swift
protocol ServiceStateObserver: AnyObject {
    func serviceDidChangeState(_ service: ObservableService, newState: ServiceState)
}

class ObservableService {
    private weak var observer: ServiceStateObserver?
    private var _state: ServiceState = .idle {
        didSet {
            observer?.serviceDidChangeState(self, newState: _state)
        }
    }

    @Injected private var dependentService: DependentService?

    var state: ServiceState { _state }

    func setObserver(_ observer: ServiceStateObserver) {
        self.observer = observer
    }

    func performOperation() async {
        _state = .loading

        defer { _state = .idle }

        do {
            try await dependentService?.performDependentOperation()
            _state = .success
        } catch {
            _state = .error(error)
        }
    }
}

enum ServiceState {
    case idle
    case loading
    case success
    case error(Error)
}

// Observer setup in dependency registration
extension UnifiedDI {
    static func setupObservableServices() {
        let stateMonitor = ServiceStateMonitor()

        registerMany {
            Registration(ServiceStateMonitor.self) { stateMonitor }
            Registration(ObservableService.self) {
                let service = ObservableService()
                service.setObserver(stateMonitor)
                return service
            }
        }
    }
}
```

## 💡 Best Practices Summary

### ✅ DO
1. **Consistent API Usage**: Choose either UnifiedDI or DI and use consistently
2. **Module-based Registration**: Group related dependencies by modules
3. **Separate Test Mocks**: Always start with clean container in tests
4. **Memory Management**: Avoid circular references and manage lifecycles properly
5. **Performance Monitoring**: Use `resolveWithTracking` for early performance issue detection

### ❌ DON'T
1. **No Mixed API Usage**: Don't use UnifiedDI and DI simultaneously
2. **Avoid Runtime Registration Abuse**: Avoid frequent registration/deregistration during app execution
3. **Strong Reference Chains**: Avoid strong references that cause circular dependencies
4. **Global State Abuse**: Don't solve issues with global state when dependency injection can solve them
5. **Real Dependencies in Tests**: Avoid tests that depend on external systems

Apply these practical patterns to effectively utilize WeaveDI.