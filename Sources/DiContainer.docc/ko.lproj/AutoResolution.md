# 자동 의존성 해결

DiContainer의 강력한 자동 의존성 해결 시스템을 활용하여 리플렉션 기반의 자동 주입을 구현하는 방법

## 개요

DiContainer의 자동 의존성 해결 시스템은 Swift의 Mirror API를 활용하여 런타임에 객체의 프로퍼티를 분석하고, `@Inject` 프로퍼티 래퍼가 적용된 의존성들을 자동으로 해결합니다. 이를 통해 복잡한 의존성 그래프도 간단한 어노테이션만으로 관리할 수 있습니다.

## <doc:AutoResolvable> 프로토콜

### 기본 개념

`AutoResolvable` 프로토콜을 구현하면 해당 클래스의 `@Inject` 프로퍼티들이 자동으로 해결됩니다.

```swift
import DiContainer

// AutoResolvable 프로토콜 구현
class UserService: AutoResolvable {
    @Inject var repository: UserRepositoryProtocol?
    @Inject var logger: LoggingServiceProtocol?
    @Inject var cache: CacheServiceProtocol?

    init() {
        // 자동 해결 시작
        AutoDependencyResolver.resolve(self)
    }

    // 자동 해결 완료 시 호출되는 콜백
    public func didAutoResolve() {
        print("✅ UserService 자동 해결 완료")
        logger?.log("UserService가 모든 의존성과 함께 초기화되었습니다", level: .info)
    }

    func getUserById(_ id: String) async throws -> User {
        logger?.log("사용자 조회 시작: \(id)", level: .info)

        guard let repository = repository else {
            throw ServiceError.dependencyNotResolved("UserRepository")
        }

        let user = try await repository.fetchUser(id: id)
        cache?.set(user, forKey: "user_\(id)")

        return user
    }
}
```

### 고급 자동 해결 패턴

```swift
// 복잡한 의존성을 가진 서비스
class NotificationManager: AutoResolvable {
    @Inject var notificationService: NotificationServiceProtocol?
    @Inject var userService: UserService?
    @Inject var templateEngine: TemplateEngineProtocol?
    @Inject var logger: LoggingServiceProtocol?

    private var resolvedDependencies: [String] = []

    init() {
        // 비동기 자동 해결 사용
        Task {
            await AutoDependencyResolver.resolveAsync(self)
        }
    }

    public func didAutoResolve() {
        print("✅ NotificationManager 자동 해결 완료")
        logger?.log("NotificationManager 준비됨", level: .info)

        // 해결된 의존성들 확인
        validateDependencies()
    }

    private func validateDependencies() {
        if notificationService != nil { resolvedDependencies.append("NotificationService") }
        if userService != nil { resolvedDependencies.append("UserService") }
        if templateEngine != nil { resolvedDependencies.append("TemplateEngine") }
        if logger != nil { resolvedDependencies.append("Logger") }

        logger?.log("해결된 의존성들: \(resolvedDependencies.joined(separator: ", "))", level: .debug)
    }

    func sendUserNotification(userId: String, templateId: String, data: [String: Any]) async throws {
        logger?.log("사용자 알림 전송 시작: \(userId)", level: .info)

        guard let notificationService = notificationService else {
            throw ServiceError.dependencyNotResolved("NotificationService")
        }

        guard let templateEngine = templateEngine else {
            throw ServiceError.dependencyNotResolved("TemplateEngine")
        }

        let template = templateEngine.renderTemplate(templateId, with: data)
        try await notificationService.send(template, to: userId)

        logger?.log("알림 전송 완료", level: .info)
    }
}
```

## <doc:AutoDependencyResolver> - 핵심 해결자

### 기본 해결 방법

```swift
// 동기 자동 해결
class SyncService: AutoResolvable {
    @Inject var dependency: SomeDependencyProtocol?

    init() {
        AutoDependencyResolver.resolve(self)
    }

    func didAutoResolve() {
        print("동기 해결 완료")
    }
}

// 비동기 자동 해결
class AsyncService: AutoResolvable {
    @Inject var heavyDependency: HeavyDependencyProtocol?

    init() {
        Task {
            await AutoDependencyResolver.resolveAsync(self)
        }
    }

    func didAutoResolve() {
        print("비동기 해결 완료")
    }
}
```

### 전역 설정과 제어

```swift
// 자동 해결 시스템 전역 제어
class AutoResolutionConfiguration {
    static func setupAutoResolution() {
        // 자동 해결 활성화
        AutoDependencyResolver.enable()

        // 특정 타입을 자동 해결에서 제외
        AutoDependencyResolver.excludeType(LegacyService.self)
        AutoDependencyResolver.excludeType(ManualService.self)

        // 성능상의 이유로 무거운 타입들 제외
        AutoDependencyResolver.excludeType(MachineLearningService.self)
        AutoDependencyResolver.excludeType(VideoProcessingService.self)
    }

    static func disableAutoResolutionForTesting() {
        // 테스트에서는 자동 해결 비활성화하여 명시적 제어
        AutoDependencyResolver.disable()
    }

    static func enableSelectiveAutoResolution() {
        // 선택적으로 특정 타입들만 자동 해결
        AutoDependencyResolver.disable()
        AutoDependencyResolver.includeType(UserService.self)
        AutoDependencyResolver.includeType(NotificationService.self)
        AutoDependencyResolver.enable()
    }
}
```

### 타입별 일괄 해결

```swift
// 특정 타입의 모든 인스턴스에 대해 자동 해결 수행
class AutoResolutionManager {
    static func refreshAllUserServices() {
        // 이미 생성된 UserService 인스턴스들을 모두 재해결
        AutoDependencyResolver.resolveAllInstances(of: UserService.self)
        print("🔄 모든 UserService 인스턴스 재해결 완료")
    }

    static func refreshAllServicesAfterConfigChange() {
        // 설정 변경 후 모든 서비스 재해결
        AutoDependencyResolver.resolveAllInstances(of: UserService.self)
        AutoDependencyResolver.resolveAllInstances(of: NotificationService.self)
        AutoDependencyResolver.resolveAllInstances(of: AnalyticsService.self)
    }
}
```

## <doc:AutoInjectible> 프로토콜 - 수동 주입 인터페이스

### 기본 사용법

Swift의 리플렉션 한계로 인해 일부 시나리오에서는 수동 주입이 필요합니다.

```swift
class AdvancedService: AutoResolvable, AutoInjectible {
    @Inject var repository: UserRepositoryProtocol?
    @Inject var logger: LoggingServiceProtocol?

    private var customDependencies: [String: Any] = [:]

    init() {
        AutoDependencyResolver.resolve(self)
    }

    // AutoInjectible 구현 - 수동 주입 처리
    public func injectResolvedValue(_ value: Any, forProperty propertyName: String) {
        customDependencies[propertyName] = value

        // 타입별 수동 주입 처리
        switch propertyName {
        case "repository":
            if let repo = value as? UserRepositoryProtocol {
                print("🔧 UserRepository 주입됨")
                // 추가 초기화 로직
                setupRepositoryConnection(repo)
            }

        case "logger":
            if let logger = value as? LoggingServiceProtocol {
                print("🔧 Logger 주입됨")
                logger.log("AdvancedService 초기화 시작", level: .info)
            }

        default:
            print("⚠️ 알려지지 않은 프로퍼티: \(propertyName)")
        }
    }

    public func didAutoResolve() {
        print("✅ AdvancedService 자동 해결 완료")
        print("주입된 의존성들: \(customDependencies.keys.joined(separator: ", "))")
    }

    private func setupRepositoryConnection(_ repository: UserRepositoryProtocol) {
        // Repository별 초기 설정
        Task {
            await repository.initialize()
        }
    }
}
```

### 조건부 자동 해결

```swift
class ConditionalService: AutoResolvable {
    @Inject var analyticsService: AnalyticsServiceProtocol?
    @Inject var logger: LoggingServiceProtocol?

    private let isAnalyticsEnabled: Bool

    init(enableAnalytics: Bool = true) {
        self.isAnalyticsEnabled = enableAnalytics

        // 조건부 자동 해결
        if isAnalyticsEnabled {
            AutoDependencyResolver.resolve(self)
        } else {
            // 분석 서비스 없이 제한된 해결
            resolveEssentialDependenciesOnly()
        }
    }

    private func resolveEssentialDependenciesOnly() {
        // 필수 의존성만 수동으로 해결
        logger = DI.resolve(LoggingServiceProtocol.self)
        print("필수 의존성만 해결됨")
    }

    func didAutoResolve() {
        if isAnalyticsEnabled {
            logger?.log("분석 기능이 활성화된 ConditionalService 초기화 완료", level: .info)
        }
    }

    func performOperation() {
        logger?.log("작업 수행 중", level: .info)

        if isAnalyticsEnabled {
            analyticsService?.track(event: "operation_performed")
        }
    }
}
```

## 성능 추적과 모니터링

### 자동 해결 성능 측정

```swift
class PerformanceTrackedService: AutoResolvable {
    @Inject var service1: Service1Protocol?
    @Inject var service2: Service2Protocol?
    @Inject var service3: Service3Protocol?

    init() {
        let startTime = CFAbsoluteTimeGetCurrent()

        AutoDependencyResolver.resolve(self)

        let endTime = CFAbsoluteTimeGetCurrent()
        let resolutionTime = (endTime - startTime) * 1000 // ms

        print("🔄 자동 해결 시간: \(String(format: "%.2f", resolutionTime))ms")
    }

    func didAutoResolve() {
        print("성능 추적 완료")
    }
}
```

### 성능 최적화를 위한 자동 해결

```swift
class OptimizedAutoService: AutoResolvable {
    @Inject var criticalService: CriticalServiceProtocol?
    @Inject var backgroundService: BackgroundServiceProtocol?

    // 지연 로딩으로 필요시에만 해결
    @Inject lazy var heavyService: HeavyServiceProtocol?

    init() {
        // 성능 추적과 함께 자동 해결
        AutoDependencyResolver.resolveWithPerformanceTracking(self)
    }

    func didAutoResolve() {
        // 중요한 서비스만 즉시 검증
        validateCriticalDependencies()
    }

    private func validateCriticalDependencies() {
        guard criticalService != nil else {
            fatalError("CriticalService는 반드시 필요합니다")
        }

        // 백그라운드 서비스는 선택적
        if backgroundService == nil {
            print("⚠️ BackgroundService를 사용할 수 없습니다. 제한된 기능으로 실행됩니다.")
        }
    }

    func performHeavyOperation() async {
        // 실제 사용 시점에 heavy service 해결
        guard let heavyService = heavyService else {
            throw ServiceError.dependencyNotResolved("HeavyService")
        }

        await heavyService.performIntensiveWork()
    }
}
```

## 실제 사용 시나리오

### MVVM 아키텍처에서의 활용

```swift
@MainActor
class UserProfileViewModel: AutoResolvable, ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Inject var userService: UserServiceProtocol?
    @Inject var imageService: ImageServiceProtocol?
    @Inject var logger: LoggingServiceProtocol?

    init() {
        AutoDependencyResolver.resolve(self)
    }

    func didAutoResolve() {
        logger?.log("UserProfileViewModel 초기화 완료", level: .info)

        // 의존성 확인
        if userService == nil {
            logger?.error("UserService를 사용할 수 없습니다")
        }
        if imageService == nil {
            logger?.warning("ImageService를 사용할 수 없습니다. 이미지 기능이 제한됩니다")
        }
    }

    func loadUserProfile(userId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            guard let userService = userService else {
                throw ViewModelError.serviceUnavailable("UserService")
            }

            let loadedUser = try await userService.getUser(id: userId)
            self.user = loadedUser

            // 프로필 이미지 미리 로드
            if let imageService = imageService {
                await imageService.preloadImage(url: loadedUser.profileImageURL)
            }

            logger?.log("사용자 프로필 로드 완료: \(loadedUser.name)", level: .info)

        } catch {
            self.errorMessage = error.localizedDescription
            logger?.error("사용자 프로필 로드 실패: \(error)")
        }

        isLoading = false
    }
}
```

### Clean Architecture에서의 활용

```swift
// Domain Layer - UseCase
class GetUserUseCase: AutoResolvable {
    @Inject var userRepository: UserRepositoryProtocol?
    @Inject var logger: LoggingServiceProtocol?

    init() {
        AutoDependencyResolver.resolve(self)
    }

    func didAutoResolve() {
        logger?.log("GetUserUseCase 준비 완료", level: .debug)
    }

    func execute(userId: String) async throws -> User {
        logger?.debug("사용자 조회 UseCase 실행: \(userId)")

        guard let repository = userRepository else {
            throw UseCaseError.repositoryNotAvailable
        }

        return try await repository.findUser(by: userId)
    }
}

// Presentation Layer - Presenter
class UserPresenter: AutoResolvable {
    @Inject var getUserUseCase: GetUserUseCase?
    @Inject var updateUserUseCase: UpdateUserUseCase?
    @Inject var logger: LoggingServiceProtocol?

    weak var view: UserViewProtocol?

    init(view: UserViewProtocol) {
        self.view = view
        AutoDependencyResolver.resolve(self)
    }

    func didAutoResolve() {
        logger?.log("UserPresenter 초기화 완료", level: .debug)
        validateUseCases()
    }

    private func validateUseCases() {
        if getUserUseCase == nil {
            logger?.error("GetUserUseCase를 사용할 수 없습니다")
        }
        if updateUserUseCase == nil {
            logger?.warning("UpdateUserUseCase를 사용할 수 없습니다")
        }
    }

    func loadUser(id: String) {
        Task {
            view?.showLoading(true)

            do {
                guard let useCase = getUserUseCase else {
                    throw PresenterError.useCaseNotAvailable
                }

                let user = try await useCase.execute(userId: id)
                await MainActor.run {
                    view?.showUser(user)
                    view?.showLoading(false)
                }

            } catch {
                await MainActor.run {
                    view?.showError(error.localizedDescription)
                    view?.showLoading(false)
                }
                logger?.error("사용자 로드 실패: \(error)")
            }
        }
    }
}
```

## 테스트에서의 자동 해결

### Mock 자동 주입

```swift
class UserServiceTests: XCTestCase {
    var mockRepository: MockUserRepository!
    var mockLogger: MockLogger!
    var userService: UserService!

    override func setUp() async throws {
        await super.setUp()

        // Mock 객체들 생성
        mockRepository = MockUserRepository()
        mockLogger = MockLogger()

        // Mock들을 DI 컨테이너에 등록
        DI.register(UserRepositoryProtocol.self, instance: mockRepository)
        DI.register(LoggingServiceProtocol.self, instance: mockLogger)

        // 테스트 대상 생성 (자동으로 Mock들이 주입됨)
        userService = UserService()
    }

    func testAutoInjectedMocks() {
        // 자동 주입이 제대로 되었는지 확인
        XCTAssertNotNil(userService.repository)
        XCTAssertNotNil(userService.logger)

        // Mock 인스턴스가 정확히 주입되었는지 확인
        XCTAssertTrue(userService.repository is MockUserRepository)
        XCTAssertTrue(userService.logger is MockLogger)
    }

    func testUserServiceWithAutoResolvedMocks() async throws {
        // Given
        let expectedUser = User(id: "test", name: "Test User")
        mockRepository.mockUser = expectedUser

        // When
        let user = try await userService.getUserById("test")

        // Then
        XCTAssertEqual(user.id, expectedUser.id)
        XCTAssertEqual(user.name, expectedUser.name)
        XCTAssertTrue(mockLogger.loggedMessages.contains { $0.contains("사용자 조회") })
    }
}
```

### 자동 해결 시스템 테스트

```swift
class AutoResolutionSystemTests: XCTestCase {

    func testAutoResolutionEnabled() {
        // Given
        AutoDependencyResolver.enable()

        class TestService: AutoResolvable {
            @Inject var dependency: TestDependencyProtocol?
            var wasAutoResolved = false

            func didAutoResolve() {
                wasAutoResolved = true
            }
        }

        DI.register(TestDependencyProtocol.self) { MockTestDependency() }

        // When
        let service = TestService()
        AutoDependencyResolver.resolve(service)

        // Then
        XCTAssertNotNil(service.dependency)
        XCTAssertTrue(service.wasAutoResolved)
    }

    func testAutoResolutionDisabled() {
        // Given
        AutoDependencyResolver.disable()

        class TestService: AutoResolvable {
            @Inject var dependency: TestDependencyProtocol?
            var wasAutoResolved = false

            func didAutoResolve() {
                wasAutoResolved = true
            }
        }

        DI.register(TestDependencyProtocol.self) { MockTestDependency() }

        // When
        let service = TestService()
        AutoDependencyResolver.resolve(service)

        // Then
        XCTAssertNil(service.dependency) // 비활성화되어 있으므로 주입되지 않음
        XCTAssertFalse(service.wasAutoResolved)
    }
}
```

## 주의사항과 모범 사례

### 성능 고려사항

```swift
// ✅ 좋은 예: 선택적 자동 해결
class OptimalService: AutoResolvable {
    @Inject var essentialService: EssentialServiceProtocol?

    // 무거운 의존성은 lazy loading
    @Inject lazy var heavyService: HeavyServiceProtocol?

    init() {
        // 필수 의존성만 즉시 해결
        AutoDependencyResolver.resolve(self)
    }

    func didAutoResolve() {
        // 필수 의존성 검증만 수행
        guard essentialService != nil else {
            fatalError("필수 서비스가 주입되지 않았습니다")
        }
    }
}

// ❌ 피해야 할 예: 모든 것을 즉시 해결
class SuboptimalService: AutoResolvable {
    @Inject var service1: Service1Protocol?
    @Inject var service2: Service2Protocol?
    // ... 20개의 서비스들
    @Inject var service20: Service20Protocol?

    init() {
        // 모든 의존성을 즉시 해결 (성능 저하)
        AutoDependencyResolver.resolve(self)
    }
}
```

### 순환 의존성 방지

```swift
// ✅ 좋은 예: 인터페이스 분리로 순환 의존성 방지
protocol ServiceADelegate {
    func handleEvent(_ event: String)
}

class ServiceA: AutoResolvable, ServiceADelegate {
    @Inject var serviceB: ServiceBProtocol?

    func didAutoResolve() {
        serviceB?.setDelegate(self)
    }

    func handleEvent(_ event: String) {
        print("Event handled: \(event)")
    }
}

class ServiceB: ServiceBProtocol {
    weak var delegate: ServiceADelegate?

    func setDelegate(_ delegate: ServiceADelegate) {
        self.delegate = delegate
    }
}
```

DiContainer의 자동 의존성 해결 시스템은 복잡한 의존성 그래프를 단순하게 관리할 수 있게 해주는 강력한 도구입니다. 적절히 사용하면 코드의 간결성과 유지보수성을 크게 향상시킬 수 있습니다.
