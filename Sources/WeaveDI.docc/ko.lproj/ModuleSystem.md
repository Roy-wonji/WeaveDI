# 모듈 시스템

WeaveDI 2.0의 모듈 시스템을 활용하여 대규모 애플리케이션의 의존성을 체계적으로 관리하는 방법을 알아보세요.

## 개요

모듈 시스템은 관련된 의존성들을 논리적으로 그룹화하고 체계적으로 관리할 수 있게 해주는 WeaveDI의 핵심 기능입니다. Clean Architecture의 각 계층을 모듈로 구성하여 유지보수성과 확장성을 크게 향상시킬 수 있습니다.

## 기본 모듈 구조

### Module 프로토콜

모든 모듈은 `Module` 프로토콜을 구현해야 합니다:

```swift
protocol Module {
    func registerDependencies() async
}
```

### 기본 모듈 구현

```swift
struct UserModule: Module {
    func registerDependencies() async {
        // Repository 계층
        DI.register(UserRepository.self) {
            CoreDataUserRepository()
        }

        // UseCase 계층
        DI.register(UserUseCase.self) {
            UserUseCaseImpl()
        }

        // Service 계층
        DI.register(UserService.self) {
            UserServiceImpl()
        }
    }
}
```

## AppDIContainer를 통한 모듈 관리

### Repository 모듈 팩토리

Repository 계층의 모듈들을 체계적으로 관리합니다:

```swift
extension RepositoryModuleFactory {
    public mutating func registerDefaultDefinitions() {
        let registerModuleCopy = registerModule

        repositoryDefinitions = [
            // 사용자 Repository
            registerModuleCopy.makeDependency(UserRepositoryProtocol.self) {
                CoreDataUserRepository()
            },

            // 인증 Repository
            registerModuleCopy.makeDependency(AuthRepositoryProtocol.self) {
                KeychainAuthRepository()
            },

            // 네트워크 Repository
            registerModuleCopy.makeDependency(NetworkRepositoryProtocol.self) {
                URLSessionNetworkRepository()
            },

            // 캐시 Repository
            registerModuleCopy.makeDependency(CacheRepositoryProtocol.self) {
                UserDefaultsCacheRepository()
            }
        ]
    }
}
```

### UseCase 모듈 팩토리

UseCase 계층은 Repository와 자동으로 연결됩니다:

```swift
extension UseCaseModuleFactory {
    public var useCaseDefinitions: [() -> Module] {
        [
            // 사용자 UseCase - Repository 자동 주입
            registerModule.makeUseCaseWithRepository(
                UserUseCaseProtocol.self,
                repositoryProtocol: UserRepositoryProtocol.self,
                repositoryFallback: CoreDataUserRepository()
            ) { repository in
                UserUseCaseImpl(userRepository: repository)
            },

            // 인증 UseCase - Repository 자동 주입
            registerModule.makeUseCaseWithRepository(
                AuthUseCaseProtocol.self,
                repositoryProtocol: AuthRepositoryProtocol.self,
                repositoryFallback: KeychainAuthRepository()
            ) { repository in
                AuthUseCaseImpl(authRepository: repository)
            },

            // 복합 UseCase - 여러 Repository 사용
            registerModule.makeComplexUseCase(
                UserProfileUseCaseProtocol.self
            ) {
                let userRepo = DI.resolve(UserRepositoryProtocol.self)
                let authRepo = DI.resolve(AuthRepositoryProtocol.self)
                return UserProfileUseCaseImpl(
                    userRepository: userRepo,
                    authRepository: authRepo
                )
            }
        ]
    }
}
```

### 전체 모듈 등록

```swift
@main
struct MyApp: App {
    init() {
        Task {
            await setupModules()
        }
    }

    private func setupModules() async {
        await AppDIContainer.shared.registerDependencies { container in
            // 1. Repository 모듈들 등록
            var repositoryFactory = AppDIContainer.shared.repositoryFactory
            repositoryFactory.registerDefaultDefinitions()

            await repositoryFactory.makeAllModules().asyncForEach { module in
                await container.register(module)
            }

            // 2. UseCase 모듈들 등록 (Repository 의존성 자동 해결)
            let useCaseFactory = AppDIContainer.shared.useCaseFactory
            await useCaseFactory.makeAllModules().asyncForEach { module in
                await container.register(module)
            }

            // 3. Scope 모듈들 등록
            let scopeFactory = AppDIContainer.shared.scopeFactory
            await scopeFactory.makeAllModules().asyncForEach { module in
                await container.register(module)
            }
        }
    }
}
```

## 계층별 모듈 구성

### Repository 계층 모듈

데이터 접근과 외부 시스템 연동을 담당합니다:

```swift
struct DataModule: Module {
    func registerDependencies() async {
        // Core Data Stack
        DI.register(CoreDataStack.self) {
            CoreDataStack(modelName: "DataModel")
        }

        // Repository 구현체들
        DI.register(UserRepository.self) {
            CoreDataUserRepository()
        }

        DI.register(PostRepository.self) {
            CoreDataPostRepository()
        }

        // 네트워크 관련
        DI.register(NetworkRepository.self) {
            URLSessionNetworkRepository()
        }

        DI.register(APIClient.self) {
            RESTAPIClient(baseURL: "https://api.example.com")
        }
    }
}
```

### UseCase 계층 모듈

비즈니스 로직을 캡슐화합니다:

```swift
struct BusinessModule: Module {
    func registerDependencies() async {
        // 사용자 관련 UseCase
        DI.register(GetUserProfileUseCase.self) {
            GetUserProfileUseCaseImpl()
        }

        DI.register(UpdateUserProfileUseCase.self) {
            UpdateUserProfileUseCaseImpl()
        }

        // 게시글 관련 UseCase
        DI.register(CreatePostUseCase.self) {
            CreatePostUseCaseImpl()
        }

        DI.register(GetPostListUseCase.self) {
            GetPostListUseCaseImpl()
        }

        // 복합 비즈니스 로직
        DI.register(UserPostCoordinator.self) {
            UserPostCoordinatorImpl()
        }
    }
}
```

### Service 계층 모듈

애플리케이션 서비스와 UI 지원을 담당합니다:

```swift
struct ServiceModule: Module {
    func registerDependencies() async {
        // UI 관련 서비스
        DI.register(NavigationService.self) {
            NavigationServiceImpl()
        }

        DI.register(AlertService.self) {
            AlertServiceImpl()
        }

        // 시스템 서비스
        DI.register(NotificationService.self) {
            UserNotificationService()
        }

        DI.register(AnalyticsService.self) {
            FirebaseAnalyticsService()
        }

        // 유틸리티 서비스
        DI.register(ValidationService.self) {
            ValidationServiceImpl()
        }

        DI.register(FormatterService.self) {
            FormatterServiceImpl()
        }
    }
}
```

## 환경별 모듈 구성

### 개발/테스트/프로덕션 분리

```swift
protocol EnvironmentModule: Module {
    var environment: Environment { get }
}

struct DevelopmentModule: EnvironmentModule {
    let environment = Environment.development

    func registerDependencies() async {
        // 개발용 Mock 서비스들
        DI.register(NetworkService.self) {
            MockNetworkService()
        }

        DI.register(AnalyticsService.self) {
            ConsoleAnalyticsService() // 콘솔 로깅만
        }

        DI.register(DatabaseService.self) {
            InMemoryDatabaseService() // 메모리 DB
        }
    }
}

struct ProductionModule: EnvironmentModule {
    let environment = Environment.production

    func registerDependencies() async {
        // 프로덕션용 실제 서비스들
        DI.register(NetworkService.self) {
            URLSessionNetworkService()
        }

        DI.register(AnalyticsService.self) {
            FirebaseAnalyticsService()
        }

        DI.register(DatabaseService.self) {
            CoreDataService()
        }
    }
}

// 환경에 따른 모듈 선택
struct EnvironmentModuleFactory {
    static func createModule() -> EnvironmentModule {
        #if DEBUG
        return DevelopmentModule()
        #elseif STAGING
        return StagingModule()
        #else
        return ProductionModule()
        #endif
    }
}
```

### 플랫폼별 모듈

```swift
struct iOSModule: Module {
    func registerDependencies() async {
        DI.register(HapticService.self) {
            UIImpactFeedbackService()
        }

        DI.register(PhotoService.self) {
            UIImagePickerService()
        }

        DI.register(BiometricService.self) {
            TouchIDService()
        }
    }
}

struct macOSModule: Module {
    func registerDependencies() async {
        DI.register(MenuService.self) {
            NSMenuService()
        }

        DI.register(WindowService.self) {
            NSWindowService()
        }

        DI.register(FileService.self) {
            NSOpenPanelService()
        }
    }
}

// 플랫폼 감지 및 모듈 등록
struct PlatformModuleLoader {
    static func loadPlatformModules() async {
        let container = DependencyContainer.live

        #if os(iOS)
        await container.register(iOSModule())
        #elseif os(macOS)
        await container.register(macOSModule())
        #endif
    }
}
```

## 모듈 의존성 관리

### 모듈 간 의존성

```swift
struct NetworkModule: Module {
    func registerDependencies() async {
        DI.register(HTTPClient.self) {
            URLSessionHTTPClient()
        }

        DI.register(JSONDecoder.self) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }
    }
}

struct APIModule: Module {
    // NetworkModule에 의존
    func registerDependencies() async {
        DI.register(UserAPI.self) {
            UserAPIImpl() // HTTPClient 자동 주입
        }

        DI.register(PostAPI.self) {
            PostAPIImpl() // HTTPClient 자동 주입
        }
    }
}

// 의존성 순서를 고려한 등록
await DependencyContainer.bootstrap { container in
    // 기본 모듈 먼저
    await container.register(NetworkModule())

    // 의존 모듈 나중에
    await container.register(APIModule())
}
```

### 순환 의존성 해결

```swift
protocol UserServiceProtocol: AnyObject {
    var postService: PostServiceProtocol? { get set }
}

protocol PostServiceProtocol: AnyObject {
    var userService: UserServiceProtocol? { get set }
}

struct CircularDependencyModule: Module {
    func registerDependencies() async {
        // 1. 먼저 모든 서비스 등록
        DI.register(UserServiceProtocol.self) {
            UserService()
        }

        DI.register(PostServiceProtocol.self) {
            PostService()
        }

        // 2. 나중에 순환 의존성 설정
        if let userService = DI.resolve(UserServiceProtocol.self),
           let postService = DI.resolve(PostServiceProtocol.self) {
            userService.postService = postService
            postService.userService = userService
        }
    }
}
```

## 동적 모듈 로딩

### 지연 로딩 모듈

```swift
struct LazyModule: Module {
    private let moduleLoader: () async -> Module

    init(_ loader: @escaping () async -> Module) {
        self.moduleLoader = loader
    }

    func registerDependencies() async {
        let actualModule = await moduleLoader()
        await actualModule.registerDependencies()
    }
}

// 사용 예시
let heavyModule = LazyModule {
    // 필요할 때만 로드
    await HeavyComputationModule()
}

await container.register(heavyModule)
```

### 조건부 모듈 로딩

```swift
struct ConditionalModuleLoader {
    static func loadModules() async {
        await DependencyContainer.bootstrap { container in
            // 기본 모듈은 항상 로드
            await container.register(CoreModule())

            // 기능별 조건부 로드
            if FeatureFlags.analyticsEnabled {
                await container.register(AnalyticsModule())
            }

            if FeatureFlags.pushNotificationEnabled {
                await container.register(PushNotificationModule())
            }

            if UserDefaults.standard.bool(forKey: "premium") {
                await container.register(PremiumFeaturesModule())
            }
        }
    }
}
```

## 모듈 테스팅

### 모듈별 단위 테스트

```swift
class UserModuleTests: XCTestCase {
    override func setUp() async throws {
        await super.setUp()

        // 테스트용 깨끗한 컨테이너
        await DependencyContainer.releaseAll()

        // 테스트용 의존성만 등록
        await DependencyContainer.bootstrap { container in
            await container.register(TestUserModule())
        }
    }

    func testUserModuleRegistration() async {
        // Repository 등록 확인
        let userRepo = DI.resolve(UserRepository.self)
        XCTAssertNotNil(userRepo)

        // UseCase 등록 확인
        let userUseCase = DI.resolve(UserUseCase.self)
        XCTAssertNotNil(userUseCase)

        // 의존성 주입 확인
        if let useCase = userUseCase as? UserUseCaseImpl {
            XCTAssertNotNil(useCase.userRepository)
        }
    }
}

struct TestUserModule: Module {
    func registerDependencies() async {
        DI.register(UserRepository.self) {
            MockUserRepository()
        }

        DI.register(UserUseCase.self) {
            UserUseCaseImpl()
        }
    }
}
```

### 통합 테스트

```swift
class ModuleIntegrationTests: XCTestCase {
    func testCompleteModuleStack() async throws {
        // 전체 모듈 스택 테스트
        await AppDIContainer.shared.registerDefaultDependencies()

        // Repository → UseCase 의존성 체인 검증
        let userUseCase = DI.resolve(UserUseCaseProtocol.self)
        XCTAssertNotNil(userUseCase)

        // 실제 비즈니스 로직 테스트
        let result = try await userUseCase?.getUserProfile(id: "test")
        XCTAssertNotNil(result)
    }
}
```

## 성능 최적화

### 병렬 모듈 등록

```swift
await AppDIContainer.shared.registerDependencies { container in
    // 독립적인 모듈들을 병렬로 등록
    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            await container.register(NetworkModule())
        }

        group.addTask {
            await container.register(StorageModule())
        }

        group.addTask {
            await container.register(UtilityModule())
        }
    }

    // 의존성이 있는 모듈들은 순차적으로
    await container.register(BusinessModule()) // NetworkModule 필요
    await container.register(ServiceModule())  // BusinessModule 필요
}
```

### 모듈 사전 초기화

```swift
class ModulePreloader {
    static func preloadCriticalModules() async {
        // 앱 시작 시 중요한 모듈들만 미리 로드
        await DependencyContainer.bootstrap { container in
            await container.register(CoreModule())
            await container.register(AuthModule())
            await container.register(NavigationModule())
        }
    }

    static func loadRemainingModules() async {
        // 나머지 모듈들은 필요시 로드
        let container = DependencyContainer.live
        await container.register(AnalyticsModule())
        await container.register(SocialModule())
        await container.register(PremiumModule())
    }
}
```

## 모범 사례

### 1. 단일 책임 원칙

```swift
// ✅ 좋은 예: 각 모듈이 명확한 책임을 가짐
struct AuthModule: Module {
    func registerDependencies() async {
        // 인증 관련 의존성만 등록
    }
}

struct NetworkModule: Module {
    func registerDependencies() async {
        // 네트워크 관련 의존성만 등록
    }
}

// ❌ 나쁜 예: 여러 관심사가 섞임
struct MixedModule: Module {
    func registerDependencies() async {
        // 인증, 네트워크, UI가 섞여있음
    }
}
```

### 2. 의존성 방향 관리

```swift
// ✅ 좋은 의존성 방향: Service → UseCase → Repository
struct LayeredArchitectureModules {
    static func register() async {
        await DependencyContainer.bootstrap { container in
            await container.register(RepositoryModule()) // 하위 계층
            await container.register(UseCaseModule())    // 중간 계층
            await container.register(ServiceModule())    // 상위 계층
        }
    }
}
```

### 3. 환경 분리

```swift
struct EnvironmentAwareModule: Module {
    func registerDependencies() async {
        #if DEBUG
        DI.register(LoggerService.self) {
            ConsoleLogger(level: .debug)
        }
        #else
        DI.register(LoggerService.self) {
            FileLogger(level: .warning)
        }
        #endif
    }
}
```

## 다음 단계

- <doc:CoreAPIs>
- <doc:PropertyWrappers>
- <doc:AutoDIOptimizer>
- <doc:ModuleFactory>
