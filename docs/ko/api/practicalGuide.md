# 실전 사용 가이드

실제 프로젝트에서 WeaveDI를 효과적으로 사용하는 방법을 단계별로 학습합니다. 실무에서 자주 마주치는 시나리오와 해결책에 중점을 둡니다.

## 🏗️ 프로젝트 구조별 적용

### MVVM 아키텍처 애플리케이션

```swift
// MARK: - Repository Layer
protocol UserRepository {
    func fetchUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws
}

class UserRepositoryImpl: UserRepository {
    @Inject var apiService: APIService?
    @Inject var cacheService: CacheService?

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

        // 캐시에 저장
        cacheService?.setUser(user, id: id)
        return user
    }
}

// MARK: - ViewModel Layer
class UserViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Inject var userRepository: UserRepository?
    @SafeInject var logger: LoggerProtocol

    func loadUser(id: String) {
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                guard let repo = userRepository else {
                    throw AppError.repositoryNotAvailable
                }

                self.user = try await repo.fetchUser(id: id)

                // SafeInject 사용법
                if case .success(let log) = logger {
                    log.info("사용자 로딩 완료: \(id)")
                }
            } catch {
                self.errorMessage = error.localizedDescription

                if case .success(let log) = logger {
                    log.error("사용자 로딩 실패: \(error)")
                }
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
                ProgressView("사용자 정보 로딩 중...")
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

### Clean Architecture 애플리케이션

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

// MARK: - Use Case 구현
class UserUseCaseImpl: UserUseCase {
    @Inject var userRepository: UserRepository?
    @Inject var validationService: ValidationService?
    @Inject var analyticsService: AnalyticsService?

    func getUserProfile(id: String) async throws -> UserProfile {
        analyticsService?.track("user_profile_requested", parameters: ["user_id": id])

        guard let repo = userRepository else {
            throw UseCaseError.repositoryNotAvailable
        }

        let user = try await repo.fetchUser(id: id)
        return UserProfile(
            id: user.id,
            name: user.name,
            email: user.email,
            avatar: user.avatarURL
        )
    }

    func updateUserProfile(_ profile: UserProfile) async throws {
        // 검증
        guard let validation = validationService else {
            throw UseCaseError.validationServiceNotAvailable
        }
        try validation.validate(profile)

        // 업데이트
        guard let repo = userRepository else {
            throw UseCaseError.repositoryNotAvailable
        }

        let user = User(from: profile)
        try await repo.updateUser(user)

        analyticsService?.track("user_profile_updated",
                               parameters: ["user_id": profile.id])
    }
}

// MARK: - Clean Architecture용 의존성 설정
extension UnifiedDI {
    static func setupCleanArchitecture() async {
        await WeaveDI.Container.bootstrap { container in
            // Domain Layer - Use Cases
            _ = container.register(UserUseCase.self) { UserUseCaseImpl() }
            _ = container.register(AuthUseCase.self) { AuthUseCaseImpl() }

            // Data Layer - Repositories
            _ = container.register(UserRepository.self) { UserRepositoryImpl() }
            _ = container.register(AuthRepository.self) { AuthRepositoryImpl() }

            // Infrastructure Layer - Services
            _ = container.register(APIService.self) { URLSessionAPIService() }
            _ = container.register(CacheService.self) { NSCacheService() }
            _ = container.register(ValidationService.self) { DefaultValidationService() }

            // Cross-cutting Concerns
            _ = container.register(LoggerProtocol.self) { OSLogLogger() }

            #if !DEBUG
            _ = container.register(AnalyticsService.self) { FirebaseAnalytics() }
            #else
            _ = container.register(AnalyticsService.self) { NoOpAnalytics() }
            #endif
        }
    }
}
```

## 🧪 테스트 전략

### 단위 테스트 설정

```swift
import XCTest
@testable import MyApp

class UserViewModelTests: XCTestCase {
    var viewModel: UserViewModel!
    var mockRepository: MockUserRepository!
    var mockLogger: MockLogger!

    override func setUp() async throws {
        try await super.setUp()

        // 테스트용 DI 컨테이너 정리
        await UnifiedDI.releaseAll()

        // Mock 객체 생성
        mockRepository = MockUserRepository()
        mockLogger = MockLogger()

        // Mock 의존성 등록
        await WeaveDI.Container.bootstrap { container in
            _ = container.register(UserRepository.self) { self.mockRepository }
            _ = container.register(LoggerProtocol.self) { self.mockLogger }
        }

        // 테스트 대상 생성
        viewModel = UserViewModel()
    }

    func testLoadUser_Success() async throws {
        // Given
        let expectedUser = User(id: "1", name: "테스트 사용자", email: "test@example.com")
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

// MARK: - Mock 객체
class MockUserRepository: UserRepository {
    var mockUser: User?
    var shouldThrowError = false
    var fetchUserCalled = false

    func fetchUser(id: String) async throws -> User {
        fetchUserCalled = true

        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }

        return mockUser ?? User(id: id, name: "기본값", email: "default@example.com")
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

### 통합 테스트 설정

```swift
class IntegrationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()

        // 통합 테스트 의존성 설정 (실제 구현 + 일부 Mock)
        await UnifiedDI.releaseAll()

        await WeaveDI.Container.bootstrap { container in
            // 실제 구현 사용
            _ = container.register(ValidationService.self) { DefaultValidationService() }
            _ = container.register(CacheService.self) { NSCacheService() }

            // 네트워크는 Mock 사용 (외부 의존성 제거)
            _ = container.register(APIService.self) { MockAPIService() }

            // 테스트용 로거 사용
            _ = container.register(LoggerProtocol.self) { TestLogger() }

            // 실제 Use Case 구현 사용
            _ = container.register(UserUseCase.self) { UserUseCaseImpl() }
            _ = container.register(UserRepository.self) { UserRepositoryImpl() }
        }
    }

    func testUserProfileFlow_EndToEnd() async throws {
        // Given
        let userUseCase = UnifiedDI.resolve(UserUseCase.self)
        let mockAPI = UnifiedDI.resolve(APIService.self) as! MockAPIService
        mockAPI.mockUserData = ["id": "1", "name": "홍길동", "email": "hong@example.com"]

        // When
        guard let useCase = userUseCase else {
            XCTFail("UserUseCase 해결 실패")
            return
        }

        let profile = try await useCase.getUserProfile(id: "1")

        // Then
        XCTAssertEqual(profile.id, "1")
        XCTAssertEqual(profile.name, "홍길동")
        XCTAssertEqual(profile.email, "hong@example.com")

        // 캐시 확인
        let cacheService = UnifiedDI.resolve(CacheService.self)
        XCTAssertNotNil(cacheService?.getUser(id: "1"))
    }
}
```

## 🔧 성능 최적화

### 지연 로딩 패턴

```swift
class ExpensiveService {
    @Inject private var heavyComputation: HeavyComputationService?
    @Inject private var databaseService: DatabaseService?

    // 지연 초기화를 위한 computed property
    private var _processedData: ProcessedData?
    var processedData: ProcessedData {
        if let cached = _processedData {
            return cached
        }

        // 첫 접근 시에만 초기화
        let data = heavyComputation?.process() ?? ProcessedData.empty
        _processedData = data
        return data
    }

    func reset() {
        _processedData = nil
    }
}

// 등록 시 지연 로딩 적용
UnifiedDI.register(ExpensiveService.self) {
    // 실제 해결될 때까지 생성 지연
    ExpensiveService()
}
```

### 스코프 기반 의존성

```swift
// 요청 스코프 의존성 (예: 웹 요청별)
class RequestScopedService {
    let requestId: String
    let timestamp: Date

    init() {
        self.requestId = UUID().uuidString
        self.timestamp = Date()
    }
}

// 세션 스코프 의존성 (예: 사용자 세션별)
class SessionScopedService {
    let sessionId: String
    let user: User

    init(user: User) {
        self.sessionId = UUID().uuidString
        self.user = user
    }
}

// 스코프 등록 헬퍼
extension UnifiedDI {
    static func registerScoped<T>(
        _ type: T.Type,
        scope: DependencyScope,
        factory: @escaping @Sendable () -> T
    ) where T: Sendable {
        switch scope {
        case .request:
            // 요청별 새 인스턴스 생성
            register(type, factory: factory)
        case .session:
            // 세션별 인스턴스 유지
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

### 메모리 관리

```swift
class MemoryEfficientService {
    @Inject private var optionalService: OptionalService?
    @Inject private var requiredService: RequiredService?

    private var cache: [String: Any] = [:]
    private let cacheLimit = 100

    func performOperation(key: String) -> Result? {
        // 캐시 크기 관리
        if cache.count > cacheLimit {
            cleanupCache()
        }

        // 옵셔널 서비스는 weak 참조로 메모리 효율성 확보
        if let service = optionalService {
            return service.process(key: key)
        }

        return requiredService?.fallbackProcess(key: key)
    }

    private func cleanupCache() {
        // LRU 방식으로 오래된 캐시 제거
        let sortedKeys = cache.keys.sorted { key1, key2 in
            // 실제로는 접근 시간 기준으로 정렬
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

### Factory 패턴 통합

```swift
// Factory 인터페이스
protocol ServiceFactory {
    func createUserService() -> UserService
    func createNetworkService() -> NetworkService
}

// 환경별 Factory 구현
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

// Factory를 통한 의존성 등록
class AppDependencySetup {
    static func configure() async {
        let factory: ServiceFactory = isProduction ?
            ProductionServiceFactory() : DevelopmentServiceFactory()

        await WeaveDI.Container.bootstrap { container in
            _ = container.register(ServiceFactory.self) { factory }
            _ = container.register(UserService.self) { factory.createUserService() }
            _ = container.register(NetworkService.self) { factory.createNetworkService() }
        }
    }
}
```

### Observer 패턴 통합

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

    @Inject private var dependentService: DependentService?

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

// Observer 설정을 포함한 의존성 등록
extension UnifiedDI {
    static func setupObservableServices() async {
        let stateMonitor = ServiceStateMonitor()

        await WeaveDI.Container.bootstrap { container in
            _ = container.register(ServiceStateMonitor.self) { stateMonitor }
            _ = container.register(ObservableService.self) {
                let service = ObservableService()
                service.setObserver(stateMonitor)
                return service
            }
        }
    }
}
```

## 💡 베스트 프랙티스 요약

### ✅ DO
1. **일관된 API 사용**: UnifiedDI 또는 WeaveDI.Container 중 하나를 선택해서 일관되게 사용
2. **모듈 기반 등록**: 관련 의존성들을 모듈별로 그룹화
3. **테스트 Mock 분리**: 테스트에서는 항상 깨끗한 컨테이너로 시작
4. **메모리 관리**: 순환 참조를 피하고 생명주기를 적절히 관리
5. **성능 모니터링**: 초기 성능 이슈 감지를 위해 해결 과정 추적

### ❌ DON'T
1. **혼합 API 사용 금지**: UnifiedDI와 WeaveDI.Container를 동시에 사용하지 말 것
2. **런타임 등록 남용 피하기**: 앱 실행 중 빈번한 등록/해제 피하기
3. **강한 참조 체인**: 순환 의존성을 야기하는 강한 참조 피하기
4. **전역 상태 남용**: 의존성 주입으로 해결할 수 있는 문제를 전역 상태로 해결하지 말 것
5. **테스트에서 실제 의존성**: 외부 시스템에 의존하는 테스트 피하기

이러한 실전 패턴을 적용하여 WeaveDI를 효과적으로 활용하세요.

---

📖 **문서**: [한국어](practicalGuide) | [English](../api/practicalGuide)
