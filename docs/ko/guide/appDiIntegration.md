# App DI 통합: AppWeaveDI.Container

실제 애플리케이션에서 **엔터프라이즈 수준**의 의존성 주입(Dependency Injection) 아키텍처를 구현하기 위해 `AppWeaveDI.Container`를 사용하는 완전 가이드입니다.

## 개요(Overview)

`AppWeaveDI.Container`는 애플리케이션 전반의 의존성 주입을 **체계적으로 관리**하는 최상위 컨테이너 클래스입니다. 자동화된 **Factory 패턴**을 통해 각 레이어(Repository, UseCase, Service)를 효율적으로 구성·관리하며, **Clean Architecture**를 지원합니다.

### 아키텍처 철학(Architecture Philosophy)

#### 🏗️ 레이어드 아키텍처 지원 (Layered Architecture Support)
- **Repository 레이어**: 데이터 접근 및 외부 시스템 연동
- **UseCase 레이어**: 비즈니스 로직과 도메인 규칙 캡슐화
- **Service 레이어**: 애플리케이션 서비스 및 UI 지원
- **자동 의존성 해소**: 레이어 간 의존성은 자동으로 주입

#### 🏭 팩토리 기반 모듈화 (Factory-Based Modularization)
- **RepositoryModuleFactory**: Repository 의존성 대량 관리
- **UseCaseModuleFactory**: Repository와 연동되는 UseCase 의존성 자동 구성
- **확장성(Extensibility)**: 신규 팩토리 손쉬운 추가
- **타입 안전성(Type Safety)**: 컴파일 타임 의존성 타입 검증

#### 🔄 라이프사이클 관리 (Lifecycle Management)
- **지연 초기화(Lazy Initialization)**: 실제 필요할 때만 모듈 생성
- **메모리 효율성**: 사용되지 않는 의존성은 생성하지 않음

## 아키텍처 다이어그램(Architecture Diagram)

```
┌─────────────────────────────────────┐
│           AppWeaveDI.Container            │
│                                     │
└─────────────────┬───────────────────┘
                  │
      ┌───────────┼───────────┐
      │           │           │
┌─────▼─────┐ ┌───▼────┐ ┌───▼────────┐
│Repository │ │UseCase │ │   Other    │
│ Factory   │ │Factory │ │ Factories  │
└───────────┘ └────────┘ └────────────┘
      │           │           │
      └───────────┼───────────┘
                  │
┌─────────────────▼───────────────────┐
│        WeaveDI.Container.live     │
│          (Global Registry)          │
└─────────────────────────────────────┘
```

## 동작 방식(How It Works)

### 1단계: 팩토리 준비 (Factory Preparation)

`AppWeaveDI.Container`는 자동 주입을 위해 `@Factory` 프로퍼티 래퍼를 사용합니다:

```swift
@Factory(\.repositoryFactory)
var repositoryFactory: RepositoryModuleFactory

@Factory(\.useCaseFactory)
var useCaseFactory: UseCaseModuleFactory

@Factory(\.scopeFactory)
var scopeFactory: ScopeModuleFactory
```

### 2단계: 모듈 등록 (Module Registration)

```swift
await AppWeaveDI.Container.shared.registerDependencies { container in
    // Repository 모듈 등록
    container.register(UserRepositoryModule())

    // UseCase 모듈 등록
    container.register(UserUseCaseModule())

    // Service 모듈 등록
    container.register(UserServiceModule())
}
```

**내부 처리(Internal Process):**
1. Repository 팩토리가 모든 Repository 모듈을 생성
2. UseCase 팩토리가 Repository와 연결된 UseCase 모듈을 생성
3. 모든 모듈을 병렬로 `WeaveDI.Container.live` 에 등록

### 3단계: 의존성 사용 (Dependency Usage)

```swift
// 어디서든 등록된 의존성을 사용
let userService = WeaveDI.Container.live.resolve(UserServiceProtocol.self)
let userUseCase = WeaveDI.Container.live.resolve(UserUseCaseProtocol.self)
```

## 호환성 및 환경 지원(Compatibility and Environment Support)

### Swift 버전 호환성
- **Swift 5.9+ & iOS 17.0+**: Actor 기반 최적화 구현
- **Swift 5.8 & iOS 16.0+**: 동일 기능의 호환 모드
- **이전 버전**: 핵심 기능을 유지하는 폴백 구현

### 동시성(Concurrency) 지원
- **Swift Concurrency**: `async/await` 패턴 완전 지원
- **GCD 호환**: 기존 `DispatchQueue` 기반 코드와 호환
- **스레드 안전**: 모든 연산은 스레드 안전하게 처리

## 기본 사용법(Basic Usage)

### 간단한 애플리케이션 설정

```swift
@main
struct MyApp {
    static func main() async {
        await AppWeaveDI.Container.shared.registerDependencies { container in
            // Repository modules
            container.register(UserRepositoryModule())
            container.register(OrderRepositoryModule())

            // UseCase modules
            container.register(UserUseCaseModule())
            container.register(OrderUseCaseModule())

            // Service modules
            container.register(UserServiceModule())
        }

        // Use registered dependencies
        let useCase: UserUseCaseProtocol = WeaveDI.Container.live.resolveOrDefault(
            UserUseCaseProtocol.self,
            default: UserUseCase(userRepo: UserRepository())
        )

        print("Loaded user profile: \(await useCase.loadUserProfile().displayName)")
    }
}
```

### 팩토리 패턴 확장(Factory Pattern Extensions)

#### Repository Factory Extension

```swift
extension RepositoryModuleFactory {
    public mutating func registerDefaultDefinitions() {
        let registerModuleCopy = registerModule
        repositoryDefinitions = [
            // User Repository
            registerModuleCopy.makeDependency(UserRepositoryProtocol.self) {
                UserRepositoryImpl(
                    networkService: WeaveDI.Container.live.resolve(NetworkService.self)!,
                    cacheService: WeaveDI.Container.live.resolve(CacheService.self)!
                )
            },

            // Auth Repository
            registerModuleCopy.makeDependency(AuthRepositoryProtocol.self) {
                AuthRepositoryImpl(
                    keychain: KeychainService(),
                    networkService: WeaveDI.Container.live.resolve(NetworkService.self)!
                )
            },

            // Order Repository
            registerModuleCopy.makeDependency(OrderRepositoryProtocol.self) {
                OrderRepositoryImpl(
                    database: WeaveDI.Container.live.resolve(DatabaseService.self)!
                )
            }
        ]
    }
}
```

#### UseCase Factory Extension

```swift
extension UseCaseModuleFactory {
    public var useCaseDefinitions: [() -> Module] {
        [
            // Auth UseCase with Repository dependency
            registerModule.makeUseCaseWithRepository(
                AuthUseCaseProtocol.self,
                repositoryProtocol: AuthRepositoryProtocol.self,
                repositoryFallback: DefaultAuthRepository()
            ) { repo in
                AuthUseCase(
                    repository: repo,
                    validator: AuthValidator(),
                    logger: WeaveDI.Container.live.resolve(LoggerProtocol.self)!
                )
            },

            // User UseCase with Repository dependency
            registerModule.makeUseCaseWithRepository(
                UserUseCaseProtocol.self,
                repositoryProtocol: UserRepositoryProtocol.self,
                repositoryFallback: DefaultUserRepository()
            ) { repo in
                UserUseCase(
                    repository: repo,
                    authUseCase: WeaveDI.Container.live.resolve(AuthUseCaseProtocol.self)!,
                    validator: UserValidator()
                )
            },

            // Order UseCase with multiple dependencies
            registerModule.makeUseCaseWithRepository(
                OrderUseCaseProtocol.self,
                repositoryProtocol: OrderRepositoryProtocol.self,
                repositoryFallback: DefaultOrderRepository()
            ) { repo in
                OrderUseCase(
                    repository: repo,
                    userUseCase: WeaveDI.Container.live.resolve(UserUseCaseProtocol.self)!,
                    paymentService: WeaveDI.Container.live.resolve(PaymentService.self)!
                )
            }
        ]
    }
}
```

## 고급 사용 패턴(Advanced Usage Patterns)

### SwiftUI 앱 통합

```swift
@main
struct TestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        registerDependencies()
    }

    var body: some Scene {
        WindowGroup {
            let store = Store(initialState: AppReducer.State()) {
                AppReducer()._printChanges()
            }
            AppView(store: store)
        }
    }

    private func registerDependencies() {
        Task {
            await AppWeaveDI.Container.shared.registerDependencies { container in
                // Repository layer setup
                var repoFactory = AppWeaveDI.Container.shared.repositoryFactory
                repoFactory.registerDefaultDefinitions()

                await repoFactory.makeAllModules().asyncForEach { module in
                    await container.register(module)
                }

                // UseCase layer setup
                let useCaseFactory = AppWeaveDI.Container.shared.useCaseFactory
                await useCaseFactory.makeAllModules().asyncForEach { module in
                    await container.register(module)
                }

                // Service layer setup
                await registerServiceModules(container)
            }
        }
    }

    private func registerServiceModules(_ container: Container) async {
        // Register application services
        await container.register(AnalyticsServiceModule())
        await container.register(NotificationServiceModule())
        await container.register(LocationServiceModule())
    }
}
```

### UIKit(AppDelegate) 통합

```swift
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Configure AppWeaveDI.Container for UIKit apps
        Task {
            await AppWeaveDI.Container.shared.registerDependencies { container in
                // Core infrastructure
                await setupCoreInfrastructure(container)

                // Feature modules
                await setupFeatureModules(container)

                // UI-specific services
                await setupUIServices(container)
            }
        }

        return true
    }

    private func setupCoreInfrastructure(_ container: Container) async {
        // Database setup
        let database = try! await Database.initialize()
        await container.register(DatabaseServiceModule(database: database))

        // Network setup
        await container.register(NetworkServiceModule())

        // Logging setup
        await container.register(LoggingServiceModule())
    }

    private func setupFeatureModules(_ container: Container) async {
        // Repository factory
        var repoFactory = AppWeaveDI.Container.shared.repositoryFactory
        repoFactory.registerDefaultDefinitions()

        let repoModules = await repoFactory.makeAllModules()
        for module in repoModules {
            await container.register(module)
        }

        // UseCase factory
        let useCaseFactory = AppWeaveDI.Container.shared.useCaseFactory
        let useCaseModules = await useCaseFactory.makeAllModules()
        for module in useCaseModules {
            await container.register(module)
        }
    }

    private func setupUIServices(_ container: Container) async {
        // UI-specific services
        await container.register(ViewControllerFactoryModule())
        await container.register(NavigationServiceModule())
        await container.register(AlertServiceModule())
    }
}
```

### ContainerRegister 사용

타입 안전한 의존성 접근을 위해 `ContainerRegister` 패턴을 사용할 수 있습니다:

```swift
extension WeaveDI.Container {
    var authUseCase: AuthUseCaseProtocol? {
        ContainerRegister(\.authUseCase).wrappedValue
    }

    var userService: UserServiceProtocol? {
        ContainerRegister(\.userService).wrappedValue
    }

    var orderRepository: OrderRepositoryProtocol? {
        ContainerRegister(\.orderRepository).wrappedValue
    }
}

// 사용 예시
class AuthenticationViewModel: ObservableObject {
    @Published var isAuthenticated = false

    private let authUseCase: AuthUseCaseProtocol = ContainerRegister(\.authUseCase).wrappedValue

    func login(email: String, password: String) async {
        do {
            let result = try await authUseCase.login(email: email, password: password)
            await MainActor.run {
                self.isAuthenticated = result.isSuccess
            }
        } catch {
            // 인증 실패 처리
            print("Login failed: \(error)")
        }
    }
}
```

### 복잡한 엔터프라이즈 아키텍처(Complex Enterprise Architecture)

```swift
class EnterpriseAppBootstrap {
    static func configure() async {
        await AppWeaveDI.Container.shared.registerDependencies { container in
            // Infrastructure layer
            await setupInfrastructure(container)

            // Data layer
            await setupDataLayer(container)

            // Domain layer
            await setupDomainLayer(container)

            // Application layer
            await setupApplicationLayer(container)

            // Presentation layer
            await setupPresentationLayer(container)
        }
    }

    private static func setupInfrastructure(_ container: Container) async {
        // Core infrastructure services
        await container.register(NetworkServiceModule())
        await container.register(DatabaseServiceModule())
        await container.register(CacheServiceModule())
        await container.register(SecurityServiceModule())
        await container.register(LoggingServiceModule())
    }

    private static func setupDataLayer(_ container: Container) async {
        // Repository factory setup
        var repoFactory = AppWeaveDI.Container.shared.repositoryFactory
        repoFactory.registerDefaultDefinitions()

        let modules = await repoFactory.makeAllModules()
        for module in modules {
            await container.register(module)
        }
    }

    private static func setupDomainLayer(_ container: Container) async {
        // UseCase factory setup
        let useCaseFactory = AppWeaveDI.Container.shared.useCaseFactory
        let modules = await useCaseFactory.makeAllModules()

        for module in modules {
            await container.register(module)
        }
    }

    private static func setupApplicationLayer(_ container: Container) async {
        // Application services
        await container.register(AuthenticationServiceModule())
        await container.register(UserManagementServiceModule())
        await container.register(OrderProcessingServiceModule())
        await container.register(PaymentServiceModule())
    }

    private static func setupPresentationLayer(_ container: Container) async {
        // ViewModels and Presenters
        await container.register(UserViewModelModule())
        await container.register(OrderViewModelModule())
        await container.register(PaymentViewModelModule())
    }
}
```

## 성능 최적화(Performance Optimization)

### 자동 최적화 구성(Automatic Optimization Configuration)

`AppWeaveDI.Container`는 성능 최적화를 자동 구성합니다:

```swift
public func registerDependencies(
    registerModules: @escaping @Sendable (Container) async -> Void
) async {
    // 성능 민감 빌드에서 런타임 최적화 활성화 및 로깅 최소화
    UnifiedDI.configureOptimization(debounceMs: 100, threshold: 10, realTimeUpdate: true)
    UnifiedDI.setAutoOptimization(true)
    UnifiedDI.setLogLevel(.errors)

    // ... 나머지 등록 로직
}
```

### 병렬 모듈 등록(Parallel Module Registration)

최적의 성능을 위해 컨테이너는 모듈을 **병렬로 등록**합니다:

```swift
// 모든 모듈이 동시에 등록됩니다
await container.register(module1)  // 병렬
await container.register(module2)  // 병렬
await container.register(module3)  // 병렬
await container.build()            // 모두 완료될 때까지 대기
```

### 메모리 관리(Memory Management)

`AppWeaveDI.Container`는 효율적인 메모리 관리를 구현합니다:

```swift
// 지연 초기화 - 필요할 때만 생성
@Factory(\.repositoryFactory)
var repositoryFactory: RepositoryModuleFactory  // 최초 접근 시 생성

// 사용되지 않는 의존성 자동 정리
private func cleanupUnusedDependencies() {
    // 내부 최적화 로직
}
```

## 테스트 전략(Testing Strategies)

### AppWeaveDI.Container 기반 단위 테스트(Unit Testing)

```swift
class AppWeaveDI.ContainerTests: XCTestCase {
    var container: AppWeaveDI.Container!

    override func setUp() async throws {
        try await super.setUp()
        container = AppWeaveDI.Container()
    }

    func testRepositoryFactoryRegistration() async {
        await container.registerDependencies { container in
            var repoFactory = self.container.repositoryFactory
            repoFactory.registerDefaultDefinitions()

            let modules = await repoFactory.makeAllModules()
            XCTAssertFalse(modules.isEmpty)

            for module in modules {
                await container.register(module)
            }
        }

        // 등록 검증
        let userRepo = WeaveDI.Container.live.resolve(UserRepositoryProtocol.self)
        XCTAssertNotNil(userRepo)
    }

    func testUseCaseFactoryRegistration() async {
        await container.registerDependencies { container in
            // 먼저 Repository 구성
            var repoFactory = self.container.repositoryFactory
            repoFactory.registerDefaultDefinitions()
            await repoFactory.makeAllModules().asyncForEach { module in
                await container.register(module)
            }

            // 이후 UseCase 구성
            let useCaseFactory = self.container.useCaseFactory
            await useCaseFactory.makeAllModules().asyncForEach { module in
                await container.register(module)
            }
        }

        // UseCase 등록 검증
        let authUseCase = WeaveDI.Container.live.resolve(AuthUseCaseProtocol.self)
        XCTAssertNotNil(authUseCase)
    }
}
```

### 통합 테스트(Integration Testing)

```swift
class IntegrationTests: XCTestCase {
    override func setUp() async throws {
        // 테스트마다 컨테이너 초기화
          WeaveDI.Container.live = WeaveDI.Container()

        await AppWeaveDI.Container.shared.registerDependencies { container in
            // 테스트 전용 의존성 등록
            await self.registerTestDependencies(container)
        }
    }

    private func registerTestDependencies(_ container: Container) async {
        // 통합 테스트용 Mock 저장소
        await container.register(MockUserRepositoryModule())
        await container.register(MockAuthRepositoryModule())

        // 통합 테스트에 실제 UseCase 사용
        let useCaseFactory = AppWeaveDI.Container.shared.useCaseFactory
        await useCaseFactory.makeAllModules().asyncForEach { module in
            await container.register(module)
        }
    }

    func testUserAuthenticationFlow() async throws {
        let authUseCase = WeaveDI.Container.live.resolve(AuthUseCaseProtocol.self)!
        let userUseCase = WeaveDI.Container.live.resolve(UserUseCaseProtocol.self)!

        // 전체 인증 플로우 테스트
        let authResult = try await authUseCase.login(email: "test@example.com", password: "password")
        XCTAssertTrue(authResult.isSuccess)

        let userProfile = try await userUseCase.loadUserProfile()
        XCTAssertNotNil(userProfile)
    }
}
```

## 베스트 프랙티스(Best Practices)

### 1) 기능(Feature) 모듈 단위로 구성

```swift
// 기능 단위 모듈 구성
struct UserFeatureModule {
    static func register(_ container: Container) async {
        // User 관련 repositories
        await container.register(UserRepositoryModule())
        await container.register(UserPreferencesRepositoryModule())

        // User 관련 use cases
        await container.register(UserUseCaseModule())
        await container.register(UserPreferencesUseCaseModule())

        // User 관련 services
        await container.register(UserServiceModule())
    }
}

struct OrderFeatureModule {
    static func register(_ container: Container) async {
        await container.register(OrderRepositoryModule())
        await container.register(OrderUseCaseModule())
        await container.register(OrderServiceModule())
    }
}
```

### 2) 환경별 구성(Environment-Specific Configuration)

```swift
extension AppWeaveDI.Container {
    func registerDependenciesForEnvironment(_ environment: AppEnvironment) async {
        await registerDependencies { container in
            switch environment {
            case .development:
                await self.registerDevelopmentDependencies(container)
            case .staging:
                await self.registerStagingDependencies(container)
            case .production:
                await self.registerProductionDependencies(container)
            }
        }
    }

    private func registerDevelopmentDependencies(_ container: Container) async {
        // 개발 환경 전용 구현
        await container.register(MockNetworkServiceModule())
        await container.register(InMemoryDatabaseModule())
        await container.register(DetailedLoggingModule())
    }

    private func registerProductionDependencies(_ container: Container) async {
        // 운영 환경 구현
        await container.register(ProductionNetworkServiceModule())
        await container.register(SQLiteDatabaseModule())
        await container.register(OptimizedLoggingModule())
    }
}
```

### 3) 점진적 마이그레이션 전략(Gradual Migration Strategy)

```swift
class LegacyAppMigration {
    static func migrateToAppWeaveDI.Container() async {
        await AppWeaveDI.Container.shared.registerDependencies { container in
            // 기존 의존성을 점진적으로 마이그레이션
            await migrateCoreServices(container)
            await migrateUserServices(container)
            await migrateOrderServices(container)
        }
    }

    private static func migrateCoreServices(_ container: Container) async {
        // 필요 시 기존 인스턴스를 재사용
        if let existingLogger = LegacyServiceLocator.shared.logger {
            await container.register(ExistingLoggerModule(logger: existingLogger))
        } else {
            await container.register(NewLoggerModule())
        }
    }
}
```

## 논의(Discussion)

- `AppWeaveDI.Container`는 **의존성 관리의 단일 진입점** 역할을 합니다.
- 앱 초기화 시 모듈을 등록해두면 런타임에서 **빠르고 신뢰성 있게** 의존성 객체를 생성·조회할 수 있습니다.
- 내부 `Container`는 등록된 모든 모듈을 **병렬로 실행**하여 성능을 최적화합니다.
- Factory 패턴으로 Repository, UseCase, Scope 레이어를 **체계적으로 관리**합니다.
- 자동 최적화 구성을 통해 **기본값만으로도 최적의 성능**을 제공합니다.

## 더 보기(See Also)

- [Module System](/ko/guide/moduleSystem) — 대규모 앱을 모듈로 조직화
- [Property Wrappers](/ko/guide/propertyWrappers) — `@Factory` 와 `@Inject` 사용법
- [Bootstrap Guide](/ko/guide/bootstrap) — 애플리케이션 초기화 패턴
- [UnifiedDI vs WeaveDI.Container](/ko/guide/unifiedDi) — 어떤 API를 선택할지 가이드
