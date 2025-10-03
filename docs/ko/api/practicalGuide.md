---
title: PracticalGuide
lang: ko-KR
---

# 실전 활용 가이드

> Language: 한국어 | English: (coming soon)

WeaveDI를 실제 프로젝트에서 효과적으로 활용하는 방법을 단계별로 알아봅니다. 실무에서 자주 마주치는 시나리오와 해결책을 중심으로 설명합니다.

## 🏗️ 프로젝트 구조별 적용

### MVVM 아키텍처 적용

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
        // 캐시 확인
        if let cached = cacheService?.getUser(id: id) {
            return cached
        }

        // API 호출
        guard let api = apiService else {
            throw DIError.dependencyNotFound(APIService.self)
        }
        let user = try await api.fetchUser(id: id)

        // 캐시 저장
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
                logger.info("사용자 로딩 완료: \(id)")
            } catch {
                self.errorMessage = error.localizedDescription
                logger.error("사용자 로딩 실패: \(error)")
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
                ProgressView("사용자 정보를 불러오는 중...")
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

### Clean Architecture 적용

```swift
// MARK: - Domain Layer (의존성 없음)
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
        // 검증
        try validationService.validate(profile)

        // 업데이트
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

## 🧪 테스트 전략

### Unit Test 설정

```swift
import XCTest
@testable import MyApp

class UserViewModelTests: XCTestCase {
    var viewModel: UserViewModel!
    var mockRepository: MockUserRepository!
    var mockLogger: MockLogger!

    override func setUp() async throws {
        await super.setUp()

        // 테스트용 깨끗한 DI 컨테이너 설정
        await UnifiedDI.releaseAll()

        // Mock 객체들 생성
        mockRepository = MockUserRepository()
        mockLogger = MockLogger()

        // Mock 의존성 등록
        UnifiedDI.registerMany {
            Registration(UserRepository.self) { mockRepository }
            Registration(LoggerProtocol.self) { mockLogger }
        }

        // 테스트 대상 생성
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
        XCTAssertTrue(mockLogger.infoMessages.contains { $0.contains("사용자 로딩 완료") })
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
        XCTAssertTrue(mockLogger.errorMessages.contains { $0.contains("사용자 로딩 실패") })
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

### Integration Test 설정

```swift
class IntegrationTests: XCTestCase {

    override func setUp() async throws {
        await super.setUp()

        // 통합 테스트용 의존성 설정 (실제 구현체 + 일부 Mock)
        await UnifiedDI.releaseAll()

        UnifiedDI.registerMany {
            // 실제 구현체 사용
            Registration(ValidationService.self) { DefaultValidationService() }
            Registration(CacheService.self) { NSCacheService() }

            // 네트워크는 Mock 사용 (외부 의존성 제거)
            Registration(APIService.self) { MockAPIService() }

            // 로깅은 테스트용
            Registration(LoggerProtocol.self) { TestLogger() }

            // Use Case는 실제 구현체
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

        // 캐시 확인
        let cacheService: CacheService = UnifiedDI.requireResolve(CacheService.self)
        XCTAssertNotNil(cacheService.getUser(id: "1"))
    }
}
```

## 🔧 성능 최적화

### Lazy Loading 패턴

```swift
class ExpensiveService {
    @Injected private var heavyComputation: HeavyComputationService?
    @Injected private var databaseService: DatabaseService?

    // Lazy initialization을 위한 computed property
    private var _processedData: ProcessedData?
    var processedData: ProcessedData {
        if let cached = _processedData {
            return cached
        }

        // 처음 접근할 때만 초기화
        let data = heavyComputation?.process() ?? ProcessedData.empty
        _processedData = data
        return data
    }

    func reset() {
        _processedData = nil
    }
}

// 등록 시에도 lazy loading 적용
UnifiedDI.register(ExpensiveService.self) {
    // 실제로 resolve 될 때까지 생성 지연
    ExpensiveService()
}
```

### Scoped Dependencies

```swift
// Request-scoped 의존성 (예: 웹 요청별)
class RequestScopedService {
    let requestId: String
    let timestamp: Date

    init() {
        self.requestId = UUID().uuidString
        self.timestamp = Date()
    }
}

// Session-scoped 의존성 (예: 사용자 세션별)
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
            // 요청별로 새 인스턴스 생성
            register(type, factory: factory)
        case .session:
            // 세션별로 인스턴스 유지
            let instance = factory()
            register(type) { instance }
        case .instance:
            // 앱 전체 인스턴스 유지
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
        // 캐시 크기 관리
        if cache.count > cacheLimit {
            cleanupCache()
        }

        // Optional service는 weak reference로 메모리 효율성 증대
        if let service = optionalService {
            return service.process(key: key)
        }

        return requiredService.fallbackProcess(key: key)
    }

    private func cleanupCache() {
        // LRU 방식으로 오래된 캐시 제거
        let sortedKeys = cache.keys.sorted { key1, key2 in
            // 실제로는 access time 기반으로 정렬
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

## 🚀 고급 패턴

### Factory Pattern Integration

```swift
// 팩토리 인터페이스
protocol ServiceFactory {
    func createUserService() -> UserService
    func createNetworkService() -> NetworkService
}

// 환경별 팩토리 구현
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

// 팩토리를 통한 의존성 등록
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

// 의존성 등록에서 Observer 설정
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

## 💡 Best Practices 요약

### ✅ DO
1. **일관된 API 사용**: UnifiedDI 또는 DI 중 하나를 선택하여 일관되게 사용
2. **모듈별 등록**: 관련된 의존성들을 모듈별로 그룹화하여 등록
3. **테스트용 Mock 분리**: 테스트에서는 항상 깨끗한 컨테이너로 시작
4. **메모리 관리**: 순환 참조를 피하고 적절한 생명주기 관리
5. **성능 모니터링**: `resolveWithTracking`을 사용하여 성능 이슈 조기 발견

### ❌ DON'T
1. **Mixed API 사용 금지**: UnifiedDI와 DI를 동시에 사용하지 않기
2. **런타임 등록 남용**: 앱 실행 중 빈번한 등록/해제 피하기
3. **Strong Reference Chain**: 순환 참조 유발하는 강한 참조 피하기
4. **Global State 남용**: 의존성 주입으로 해결 가능한 부분을 전역 상태로 해결하지 않기
5. **테스트에서 실제 의존성 사용**: 외부 시스템에 의존하는 테스트 피하기

이러한 실전 패턴들을 적용하여 WeaveDI를 효과적으로 활용하시기 바랍니다.
