# 모듈 팩토리 - 고급 의존성 조직화

WeaveDI의 모듈 팩토리 시스템에 대한 포괄적인 가이드입니다. 엔터프라이즈급 애플리케이션에서 의존성을 조직화, 관리, 확장하는 가장 강력한 방법을 제공합니다. 이 시스템은 복잡한 의존성 그래프를 위한 체계적인 모듈 생성, 등록, 관리를 가능하게 합니다.

## 개요

WeaveDI의 모듈 팩토리 패턴은 대규모 의존성 관리 방식을 변화시킵니다. 분산된 등록 대신, 구성 가능하고 테스트 가능하며 유지보수 가능한 의존성 모듈을 체계적으로 관리할 수 있는 조직화된 시스템을 만들 수 있습니다.

### 주요 장점

- **🏗️ 체계적 조직화**: 관련 의존성들을 논리적 모듈로 그룹화
- **🔧 팩토리 패턴**: 의존성 생성을 위한 검증된 팩토리 디자인 패턴 활용
- **🎯 타입 안전성**: 모듈 의존성의 컴파일 타임 검증
- **🧪 테스팅 지원**: 쉬운 목 주입과 테스트 격리
- **⚡ 성능**: 지연 로딩과 최적화된 모듈 등록
- **📦 모듈화**: 대규모 팀과 복잡한 애플리케이션에 완벽

### 아키텍처 장점

```
┌─────────────────────────────────────┐
│        Application Layer            │
│   ┌─────────────────────────────┐   │
│   │     ModuleFactoryManager    │   │
│   └─────────────────────────────┘   │
└─────────────────┬───────────────────┘
                  │
      ┌───────────┼───────────┐
      │           │           │
┌─────▼─────┐ ┌───▼────┐ ┌───▼────────┐
│Repository │ │UseCase │ │  Service   │
│  Factory  │ │Factory │ │  Factory   │
└───────────┘ └────────┘ └────────────┘
      │           │           │
      └───────────┼───────────┘
                  │
┌─────────────────▼───────────────────┐
│         WeaveDI Container           │
│        (Registered Modules)         │
└─────────────────────────────────────┘
```

## 핵심 구성 요소

### ModuleFactory 프로토콜

실제 구현을 기반으로 한 모듈 시스템의 기초:

```swift
public protocol ModuleFactory {
    var registerModule: RegisterModule { get }    // 모듈 생성 유틸리티
    var definitions: [@Sendable () -> Module] { get set }  // 모듈 정의들
    func makeAllModules() -> [Module]  // 모든 모듈을 한 번에 생성
}
```

**프로토콜 책임:**
- **모듈 정의 저장**: 모듈 생성 클로저들의 목록 유지
- **배치 생성**: 팩토리의 모든 모듈을 동시에 생성
- **타입 안전성**: 모든 모듈이 적절히 타입 지정되고 Sendable함을 보장
- **지연 평가**: `makeAllModules()`가 호출될 때만 모듈이 생성됨

### RegisterModule - 모듈 생성 엔진

모든 모듈 생성을 담당하는 핵심 유틸리티:

```swift
public struct RegisterModule: Sendable {
    // 기본 모듈 생성 - 단순한 의존성용
    public func makeModule<T>(
        _ type: T.Type,
        factory: @Sendable @escaping () -> T
    ) -> Module where T: Sendable

    // UseCase-Repository 패턴과 자동 의존성 주입을 위한 고급 기능
    public func makeUseCaseWithRepository<UseCase, Repo>(
        _ useCaseProtocol: UseCase.Type,      // 등록할 UseCase 프로토콜
        repositoryProtocol: Repo.Type,        // 필요한 리포지토리 의존성
        repositoryFallback: @Sendable @autoclosure @escaping () -> Repo,  // 리포지토리를 찾지 못할 때 폴백
        factory: @Sendable @escaping (Repo) -> UseCase  // 주입된 리포지토리로 UseCase 생성
    ) -> @Sendable () -> Module where UseCase: Sendable

    // 여러 의존성을 가진 의존성 주입
    public func makeDependency<T>(
        _ type: T.Type,
        dependencies: [Any.Type] = [],
        factory: @Sendable @escaping () throws -> T
    ) -> Module where T: Sendable
}
```

**RegisterModule 기능:**
- **🎯 타입 안전성**: 모든 모듈의 컴파일 타임 타입 검사
- **🔄 의존성 주입**: 모듈 의존성의 자동 해결
- **🛡️ 폴백 지원**: 누락된 의존성의 우아한 처리
- **⚡ 성능**: 최적화된 모듈 생성과 등록
- **🧵 동시성**: 완전한 Swift 6 sendable 준수

## 기본 사용법

### 단순한 모듈 팩토리

관련 의존성들을 위한 기본 팩토리로 시작:

```swift
struct RepositoryModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setup() {
        // 데이터베이스 의존성을 가진 사용자 리포지토리
        definitions.append {
            registerModule.makeModule(UserRepository.self) {
                UserRepositoryImpl(
                    database: WeaveDI.Container.shared.resolve(DatabaseService.self)!,
                    logger: WeaveDI.Container.shared.resolve(Logger.self)
                )
            }
        }

        // 캐싱을 가진 도서 리포지토리
        definitions.append {
            registerModule.makeModule(BookRepository.self) {
                CachedBookRepository(
                    baseRepository: BookRepositoryImpl(),
                    cache: WeaveDI.Container.shared.resolve(CacheService.self)!
                )
            }
        }

        // 복잡한 의존성을 가진 주문 리포지토리
        definitions.append {
            registerModule.makeModule(OrderRepository.self) {
                OrderRepositoryImpl(
                    database: WeaveDI.Container.shared.resolve(DatabaseService.self)!,
                    paymentGateway: WeaveDI.Container.shared.resolve(PaymentGateway.self)!,
                    notificationService: WeaveDI.Container.shared.resolve(NotificationService.self)!
                )
            }
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}
```

### 오류 처리가 강화된 팩토리

```swift
struct SafeRepositoryModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setup() {
        definitions.append {
            registerModule.makeModule(UserRepository.self) {
                do {
                    // 원격 데이터베이스로 생성 시도
                    let remoteDB = try RemoteDatabaseService.connect()
                    return RemoteUserRepository(database: remoteDB)
                } catch {
                    // 로컬 데이터베이스로 폴백
                    print("⚠️ 원격 DB를 사용할 수 없어 로컬 사용: \(error)")
                    let localDB = LocalDatabaseService()
                    return LocalUserRepository(database: localDB)
                }
            }
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}
```

### 팩토리 등록과 사용

#### 기본 등록

```swift
// 앱 초기화
func initializeRepositories() async {
    var repositoryFactory = RepositoryModuleFactory()
    repositoryFactory.setup()

    let modules = repositoryFactory.makeAllModules()

    await WeaveDI.Container.bootstrap { container in
        for module in modules {
            await container.register(module)
        }
    }

    print("✅ \(modules.count)개 리포지토리 모듈이 등록되었습니다")
}
```

#### 검증이 포함된 고급 등록

```swift
func initializeWithValidation() async throws {
    var repositoryFactory = RepositoryModuleFactory()
    repositoryFactory.setup()

    let modules = repositoryFactory.makeAllModules()

    // 등록 전 모듈 검증
    try validateModules(modules)

    await WeaveDI.Container.bootstrap { container in
        await withTaskGroup(of: Void.self) { group in
            for module in modules {
                group.addTask {
                    await container.register(module)
                    print("📦 등록됨: \(module.description)")
                }
            }
        }
    }
}

func validateModules(_ modules: [Module]) throws {
    guard !modules.isEmpty else {
        throw ModuleError.noModulesFound
    }

    for module in modules {
        guard module.isValid else {
            throw ModuleError.invalidModule(module.description)
        }
    }
}
```

## 고급 패턴

### 1. 다중 모듈 팩토리 시스템

다양한 모듈 타입을 관리하는 포괄적인 시스템:

```swift
struct ApplicationModuleFactory {
    // 서로 다른 관심사를 위한 다양한 팩토리 타입
    var infrastructureFactory = InfrastructureModuleFactory()
    var repositoryFactory = RepositoryModuleFactory()
    var useCaseFactory = UseCaseModuleFactory()
    var serviceFactory = ServiceModuleFactory()
    var presentationFactory = PresentationModuleFactory()

    let environment: Environment
    let configuration: AppConfiguration

    init(environment: Environment, configuration: AppConfiguration) {
        self.environment = environment
        self.configuration = configuration
    }

    mutating func setupAll() async {
        // 의존성 순서대로 설정
        await setupInfrastructure()
        await setupRepositories()
        await setupUseCases()
        await setupServices()
        await setupPresentation()
    }

    private mutating func setupInfrastructure() async {
        infrastructureFactory.setup(for: environment, config: configuration)
    }

    private mutating func setupRepositories() async {
        // 리포지토리는 인프라에 의존
        repositoryFactory.setup()
    }

    private mutating func setupUseCases() async {
        // UseCase는 리포지토리에 의존
        useCaseFactory.setup()
    }

    private mutating func setupServices() async {
        // 서비스는 Use Case에 의존
        serviceFactory.setup()
    }

    private mutating func setupPresentation() async {
        // 프레젠테이션은 서비스에 의존
        presentationFactory.setup()
    }

    func getAllModules() -> [Module] {
        var allModules: [Module] = []

        // 의존성 순서대로 모듈 추가
        allModules.append(contentsOf: infrastructureFactory.makeAllModules())
        allModules.append(contentsOf: repositoryFactory.makeAllModules())
        allModules.append(contentsOf: useCaseFactory.makeAllModules())
        allModules.append(contentsOf: serviceFactory.makeAllModules())
        allModules.append(contentsOf: presentationFactory.makeAllModules())

        return allModules
    }

    func getModulesStatistics() -> ModuleStatistics {
        return ModuleStatistics(
            infrastructureCount: infrastructureFactory.makeAllModules().count,
            repositoryCount: repositoryFactory.makeAllModules().count,
            useCaseCount: useCaseFactory.makeAllModules().count,
            serviceCount: serviceFactory.makeAllModules().count,
            presentationCount: presentationFactory.makeAllModules().count
        )
    }
}

struct ModuleStatistics {
    let infrastructureCount: Int
    let repositoryCount: Int
    let useCaseCount: Int
    let serviceCount: Int
    let presentationCount: Int

    var totalCount: Int {
        infrastructureCount + repositoryCount + useCaseCount + serviceCount + presentationCount
    }
}
```

### 2. 리포지토리 의존성을 가진 UseCase 팩토리

자동 의존성 주입을 위한 내장 UseCase-Repository 패턴 활용:

```swift
struct UseCaseModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setup() {
        // 리포지토리 의존성을 가진 인증 UseCase
        definitions.append(
            registerModule.makeUseCaseWithRepository(
                LoginUseCase.self,
                repositoryProtocol: AuthRepository.self,
                repositoryFallback: DefaultAuthRepository(),
                factory: { repository in
                    LoginUseCaseImpl(
                        repository: repository,
                        validator: AuthValidator(),
                        logger: WeaveDI.Container.shared.resolve(Logger.self)
                    )
                }
            )
        )

        // 사용자 관리 UseCase
        definitions.append(
            registerModule.makeUseCaseWithRepository(
                UserProfileUseCase.self,
                repositoryProtocol: UserRepository.self,
                repositoryFallback: DefaultUserRepository(),
                factory: { repository in
                    UserProfileUseCaseImpl(
                        repository: repository,
                        imageService: WeaveDI.Container.shared.resolve(ImageService.self)!,
                        analyticsService: WeaveDI.Container.shared.resolve(AnalyticsService.self)
                    )
                }
            )
        )

        // 여러 리포지토리를 가진 주문 관리 UseCase
        definitions.append(
            registerModule.makeUseCaseWithRepository(
                OrderManagementUseCase.self,
                repositoryProtocol: OrderRepository.self,
                repositoryFallback: DefaultOrderRepository(),
                factory: { orderRepository in
                    OrderManagementUseCaseImpl(
                        orderRepository: orderRepository,
                        userRepository: WeaveDI.Container.shared.resolve(UserRepository.self)!,
                        paymentRepository: WeaveDI.Container.shared.resolve(PaymentRepository.self)!,
                        notificationService: WeaveDI.Container.shared.resolve(NotificationService.self)
                    )
                }
            )
        )

        // 캐싱이 있는 검색 UseCase
        definitions.append {
            registerModule.makeModule(SearchUseCase.self) {
                CachedSearchUseCaseImpl(
                    searchRepository: WeaveDI.Container.shared.resolve(SearchRepository.self)!,
                    cacheService: WeaveDI.Container.shared.resolve(CacheService.self)!,
                    analyticsService: WeaveDI.Container.shared.resolve(AnalyticsService.self)
                )
            }
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}
```

### 3. 특화된 팩토리 타입

WeaveDI는 일반적인 패턴을 위한 사전 구축된 팩토리 타입을 제공:

```swift
// 내장 특화 팩토리들
public struct RepositoryModuleFactory: ModuleFactory, Sendable {
    // 데이터 레이어 의존성에 최적화
    // - 데이터베이스 연결
    // - API 클라이언트
    // - 데이터 매퍼
    // - 캐싱 레이어
}

public struct UseCaseModuleFactory: ModuleFactory, Sendable {
    // 비즈니스 로직에 최적화
    // - 도메인 Use Case
    // - 비즈니스 규칙
    // - 워크플로 오케스트레이션
    // - 횡단 관심사
}

public struct ScopeModuleFactory: ModuleFactory, Sendable {
    // 스코프가 있는 의존성에 최적화
    // - 요청 스코프 서비스
    // - 세션 스코프 데이터
    // - 사용자 스코프 설정
    // - 임시 컨텍스트
}
```

#### 사용자 정의 특화 팩토리

```swift
// 인프라 팩토리
struct InfrastructureModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setup(for environment: Environment, config: AppConfiguration) {
        // 데이터베이스 설정
        definitions.append {
            registerModule.makeModule(DatabaseService.self) {
                switch environment {
                case .development:
                    return InMemoryDatabaseService()
                case .staging:
                    return SQLiteDatabaseService(path: config.stagingDBPath)
                case .production:
                    return PostgreSQLDatabaseService(config: config.productionDBConfig)
                }
            }
        }

        // 네트워크 설정
        definitions.append {
            registerModule.makeModule(NetworkService.self) {
                HTTPNetworkService(
                    baseURL: config.apiBaseURL,
                    timeout: config.networkTimeout,
                    interceptors: createInterceptors(for: environment)
                )
            }
        }

        // 로깅 설정
        definitions.append {
            registerModule.makeModule(Logger.self) {
                switch environment {
                case .development:
                    return ConsoleLogger(level: .debug)
                case .staging:
                    return FileLogger(level: .info, path: config.logPath)
                case .production:
                    return RemoteLogger(level: .error, endpoint: config.logEndpoint)
                }
            }
        }
    }

    private func createInterceptors(for environment: Environment) -> [NetworkInterceptor] {
        var interceptors: [NetworkInterceptor] = []

        // 인증 인터셉터 추가
        interceptors.append(AuthInterceptor())

        // 비프로덕션에서 로깅 추가
        if environment != .production {
            interceptors.append(LoggingInterceptor())
        }

        // 재시도 인터셉터 추가
        interceptors.append(RetryInterceptor(maxRetries: 3))

        return interceptors
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}
```

### 4. ModuleFactoryManager - 엔터프라이즈급 관리

모니터링과 검증을 포함한 모든 팩토리의 중앙화된 엔터프라이즈급 관리:

```swift
public struct ModuleFactoryManager: Sendable {
    public var repositoryFactory: RepositoryModuleFactory
    public var useCaseFactory: UseCaseModuleFactory
    public var scopeFactory: ScopeModuleFactory
    public var infrastructureFactory: InfrastructureModuleFactory
    public var presentationFactory: PresentationModuleFactory

    private let logger: Logger?
    private let environment: Environment
    private let configuration: AppConfiguration

    public init(
        environment: Environment,
        configuration: AppConfiguration,
        logger: Logger? = nil
    ) {
        self.environment = environment
        self.configuration = configuration
        self.logger = logger

        // 환경 컨텍스트로 팩토리 초기화
        self.repositoryFactory = RepositoryModuleFactory()
        self.useCaseFactory = UseCaseModuleFactory()
        self.scopeFactory = ScopeModuleFactory()
        self.infrastructureFactory = InfrastructureModuleFactory()
        self.presentationFactory = PresentationModuleFactory()
    }

    public mutating func setupAllFactories() async {
        logger?.info("🏭 \(environment) 환경을 위한 모듈 팩토리 설정 중")

        // 의존성 순서대로 설정
        infrastructureFactory.setup(for: environment, config: configuration)
        repositoryFactory.setup()
        useCaseFactory.setup()
        scopeFactory.setup()
        presentationFactory.setup()

        logger?.info("✅ 모든 팩토리가 구성되었습니다")
    }

    public func registerAll() async throws {
        logger?.info("📦 모듈 등록 프로세스 시작")

        // 모든 모듈 가져오기
        let allModules = getAllModulesInOrder()

        logger?.info("📊 등록할 \(allModules.count)개 모듈을 찾았습니다")

        // 등록 전 모듈 검증
        try validateModules(allModules)

        // 성능 향상을 위해 배치로 모듈 등록
        await registerModulesInBatches(allModules)

        logger?.info("🎉 모듈 등록이 성공적으로 완료되었습니다")
    }

    private func getAllModulesInOrder() -> [Module] {
        var allModules: [Module] = []

        // 의존성 순서대로 등록
        allModules.append(contentsOf: infrastructureFactory.makeAllModules())
        allModules.append(contentsOf: repositoryFactory.makeAllModules())
        allModules.append(contentsOf: useCaseFactory.makeAllModules())
        allModules.append(contentsOf: scopeFactory.makeAllModules())
        allModules.append(contentsOf: presentationFactory.makeAllModules())

        return allModules
    }

    private func validateModules(_ modules: [Module]) throws {
        guard !modules.isEmpty else {
            throw ModuleFactoryError.noModulesFound
        }

        // 중복 등록 확인
        var typeNames: Set<String> = []
        for module in modules {
            let typeName = String(describing: module.type)
            if typeNames.contains(typeName) {
                throw ModuleFactoryError.duplicateModule(typeName)
            }
            typeNames.insert(typeName)
        }

        logger?.info("✅ 모듈 검증 통과")
    }

    private func registerModulesInBatches(_ modules: [Module]) async {
        let batchSize = 10 // 한 번에 10개 모듈 등록
        let batches = modules.chunked(into: batchSize)

        for (index, batch) in batches.enumerated() {
            logger?.info("📦 배치 \(index + 1)/\(batches.count) 등록 중")

            await withTaskGroup(of: Void.self) { group in
                for module in batch {
                    group.addTask {
                        await WeaveDI.Container.shared.register(module)
                        self.logger?.debug("✅ 등록됨: \(module.description)")
                    }
                }
            }
        }
    }

    public func getRegistrationStatistics() -> RegistrationStatistics {
        return RegistrationStatistics(
            infrastructureModules: infrastructureFactory.makeAllModules().count,
            repositoryModules: repositoryFactory.makeAllModules().count,
            useCaseModules: useCaseFactory.makeAllModules().count,
            scopeModules: scopeFactory.makeAllModules().count,
            presentationModules: presentationFactory.makeAllModules().count
        )
    }
}

// 지원 타입
enum ModuleFactoryError: LocalizedError {
    case noModulesFound
    case duplicateModule(String)
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .noModulesFound:
            return "어떤 팩토리에서도 모듈을 찾을 수 없습니다"
        case .duplicateModule(let typeName):
            return "타입 \(typeName)에 대한 중복 모듈 등록"
        case .invalidConfiguration:
            return "유효하지 않은 팩토리 구성"
        }
    }
}

struct RegistrationStatistics {
    let infrastructureModules: Int
    let repositoryModules: Int
    let useCaseModules: Int
    let scopeModules: Int
    let presentationModules: Int

    var totalModules: Int {
        infrastructureModules + repositoryModules + useCaseModules + scopeModules + presentationModules
    }
}

// 사용법
func setupApplication() async throws {
    var manager = ModuleFactoryManager(
        environment: .production,
        configuration: AppConfiguration.load(),
        logger: ConsoleLogger()
    )

    await manager.setupAllFactories()
    try await manager.registerAll()

    let stats = manager.getRegistrationStatistics()
    print("🎯 \(5)개 팩토리에 걸쳐 \(stats.totalModules)개 모듈이 등록되었습니다")
}
```

## 실제 구현 사례

### 대규모 애플리케이션 설정

#### 포괄적 모듈 시스템을 가진 SwiftUI 애플리케이션

```swift
@main
struct EnterpriseWeaveDIApp: App {
    @State private var isInitialized = false
    @State private var initializationError: Error?

    init() {
        // 초기화를 시작하되 메인 스레드를 차단하지 않음
        Task {
            await initializeApplication()
        }
    }

    var body: some Scene {
        WindowGroup {
            if isInitialized {
                ContentView()
            } else if let error = initializationError {
                ErrorView(error: error) {
                    Task {
                        await retryInitialization()
                    }
                }
            } else {
                LoadingView()
                    .task {
                        await initializeApplication()
                    }
            }
        }
    }

    @MainActor
    private func initializeApplication() async {
        do {
            let startTime = Date()
            print("🚀 애플리케이션 초기화 시작...")

            // 모듈 팩토리 매니저 설정
            var manager = ModuleFactoryManager(
                environment: AppEnvironment.current,
                configuration: try AppConfiguration.load(),
                logger: AppLogger.shared
            )

            // 모든 팩토리 설정
            await manager.setupAllFactories()

            // 모든 모듈 등록
            try await manager.registerAll()

            // 중요한 의존성 검증
            try await verifyCriticalDependencies()

            let initTime = Date().timeIntervalSince(startTime)
            print("✅ 애플리케이션이 \(String(format: "%.2f", initTime))초에 초기화되었습니다")

            // 통계 표시
            let stats = manager.getRegistrationStatistics()
            print("📊 등록된 모듈: \(stats.totalModules)")

            isInitialized = true

        } catch {
            print("❌ 애플리케이션 초기화 실패: \(error)")
            initializationError = error
        }
    }

    private func retryInitialization() async {
        initializationError = nil
        await initializeApplication()
    }

    private func verifyCriticalDependencies() async throws {
        // 필수 서비스가 사용 가능한지 검증
        let criticalServices: [Any.Type] = [
            DatabaseService.self,
            NetworkService.self,
            Logger.self,
            UserRepository.self,
            AuthenticationService.self
        ]

        for serviceType in criticalServices {
            let resolved = WeaveDI.Container.shared.resolve(serviceType)
            guard resolved != nil else {
                throw InitializationError.criticalServiceMissing(String(describing: serviceType))
            }
        }

        print("✅ 모든 중요한 의존성이 검증되었습니다")
    }
}

enum InitializationError: LocalizedError {
    case criticalServiceMissing(String)
    case configurationLoadFailed
    case moduleRegistrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .criticalServiceMissing(let service):
            return "중요한 서비스가 누락됨: \(service)"
        case .configurationLoadFailed:
            return "애플리케이션 구성 로드 실패"
        case .moduleRegistrationFailed(let details):
            return "모듈 등록 실패: \(details)"
        }
    }
}
```

#### 팩토리 시스템을 가진 UIKit 애플리케이션

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var moduleManager: ModuleFactoryManager?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // 윈도우 설정
        window = UIWindow(windowScene: windowScene)

        // 로딩 화면 표시
        window?.rootViewController = LoadingViewController()
        window?.makeKeyAndVisible()

        // 비동기로 초기화
        Task {
            await initializeModuleSystem()
        }
    }

    private func initializeModuleSystem() async {
        do {
            print("🏭 모듈 팩토리 시스템 초기화 중...")

            // 모듈 매니저 생성 및 설정
            var manager = ModuleFactoryManager(
                environment: AppEnvironment.current,
                configuration: try AppConfiguration.load(),
                logger: AppLogger.shared
            )
            self.moduleManager = manager

            // 팩토리 설정
            await manager.setupAllFactories()

            // 모든 모듈 등록
            try await manager.registerAll()

            // 메인 앱으로 전환
            await transitionToMainApp()

        } catch {
            await showInitializationError(error)
        }
    }

    @MainActor
    private func transitionToMainApp() {
        // 주입된 의존성으로 메인 코디네이터 생성
        let mainCoordinator = MainCoordinator()
        let mainViewController = mainCoordinator.start()

        // 부드러운 전환
        UIView.transition(with: window!, duration: 0.3, options: .transitionCrossDissolve) {
            self.window?.rootViewController = mainViewController
        }

        print("🎉 메인 애플리케이션으로 성공적으로 전환되었습니다")
    }

    @MainActor
    private func showInitializationError(_ error: Error) {
        let errorViewController = ErrorViewController(error: error) { [weak self] in
            Task {
                await self?.initializeModuleSystem()
            }
        }

        window?.rootViewController = errorViewController
    }
}
```

### 환경별 팩토리

포괄적인 환경 인식 팩토리 시스템:

```swift
struct EnvironmentModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []
    let environment: Environment
    let configuration: AppConfiguration

    init(environment: Environment, configuration: AppConfiguration) {
        self.environment = environment
        self.configuration = configuration
    }

    mutating func setup() {
        switch environment {
        case .development:
            setupDevelopmentModules()
        case .staging:
            setupStagingModules()
        case .production:
            setupProductionModules()
        case .testing:
            setupTestingModules()
        }
    }

    private mutating func setupDevelopmentModules() {
        print("🛠️ 개발 모듈 설정 중")

        // 자세한 로깅이 있는 목 API
        definitions.append {
            registerModule.makeModule(APIClient.self) {
                MockAPIClient(
                    baseURL: "https://dev-api.example.com",
                    enableNetworkLogs: true,
                    simulateLatency: true,
                    failureRate: 0.1 // 테스트를 위한 10% 실패율
                )
            }
        }

        // 디버깅을 위한 상세 로깅
        definitions.append {
            registerModule.makeModule(Logger.self) {
                CompositeLogger([
                    ConsoleLogger(level: .debug),
                    FileLogger(level: .info, path: configuration.devLogPath),
                    OSLogger(subsystem: "com.app.dev", category: "general")
                ])
            }
        }

        // 빠른 개발을 위한 인메모리 데이터베이스
        definitions.append {
            registerModule.makeModule(DatabaseService.self) {
                InMemoryDatabaseService(preloadTestData: true)
            }
        }

        // 콘솔에 로그를 남기는 목 분석
        definitions.append {
            registerModule.makeModule(AnalyticsService.self) {
                ConsoleAnalyticsService(verbose: true)
            }
        }

        // 캐싱이 비활성화된 디버그 이미지 로더
        definitions.append {
            registerModule.makeModule(ImageLoader.self) {
                DebugImageLoader(cacheEnabled: false)
            }
        }
    }

    private mutating func setupStagingModules() {
        print("🎭 스테이징 모듈 설정 중")

        // 스테이징 엔드포인트가 있는 실제 API
        definitions.append {
            registerModule.makeModule(APIClient.self) {
                HTTPAPIClient(
                    baseURL: "https://staging-api.example.com",
                    timeout: 30,
                    retryPolicy: RetryPolicy(maxRetries: 3),
                    certificatePinner: nil, // 스테이징에서는 덜 엄격
                    interceptors: [
                        AuthInterceptor(),
                        LoggingInterceptor(level: .info),
                        MetricsInterceptor()
                    ]
                )
            }
        }

        // 원격 보고를 포함한 구조화된 로깅
        definitions.append {
            registerModule.makeModule(Logger.self) {
                CompositeLogger([
                    ConsoleLogger(level: .info),
                    RemoteLogger(
                        endpoint: "https://logs-staging.example.com",
                        level: .warning
                    )
                ])
            }
        }

        // 스테이징 데이터가 있는 실제 데이터베이스
        definitions.append {
            registerModule.makeModule(DatabaseService.self) {
                PostgreSQLDatabaseService(
                    connectionString: configuration.stagingDBConnectionString,
                    poolSize: 5,
                    enableMigrations: true
                )
            }
        }

        // 테스트 분석 서비스
        definitions.append {
            registerModule.makeModule(AnalyticsService.self) {
                TestAnalyticsService(
                    endpoint: "https://analytics-staging.example.com",
                    flushInterval: 10 // 초
                )
            }
        }
    }

    private mutating func setupProductionModules() {
        print("🚀 프로덕션 모듈 설정 중")

        // 모든 보안 조치가 포함된 프로덕션 API
        definitions.append {
            registerModule.makeModule(APIClient.self) {
                SecureHTTPAPIClient(
                    baseURL: "https://api.example.com",
                    timeout: 15,
                    retryPolicy: RetryPolicy(maxRetries: 2),
                    certificatePinner: SSLCertificatePinner(
                        certificates: configuration.trustedCertificates
                    ),
                    interceptors: [
                        AuthInterceptor(),
                        RateLimitInterceptor(),
                        SecurityHeadersInterceptor(),
                        MetricsInterceptor()
                    ]
                )
            }
        }

        // 프로덕션 로깅 - 오류만
        definitions.append {
            registerModule.makeModule(Logger.self) {
                ProductionLogger(
                    remoteEndpoint: "https://logs.example.com",
                    level: .error,
                    encryptionKey: configuration.logEncryptionKey
                )
            }
        }

        // 커넥션 풀링이 있는 프로덕션 데이터베이스
        definitions.append {
            registerModule.makeModule(DatabaseService.self) {
                ProductionDatabaseService(
                    primaryConnectionString: configuration.primaryDBConnectionString,
                    readReplicaConnectionString: configuration.readReplicaConnectionString,
                    poolSize: 20,
                    enableConnectionPooling: true,
                    enableReadWriteSplit: true
                )
            }
        }

        // 개인정보 보호 규정 준수가 있는 전체 분석
        definitions.append {
            registerModule.makeModule(AnalyticsService.self) {
                PrivacyCompliantAnalyticsService(
                    providers: [
                        FirebaseAnalyticsProvider(),
                        MixpanelAnalyticsProvider(),
                        CustomAnalyticsProvider(endpoint: configuration.analyticsEndpoint)
                    ],
                    privacySettings: configuration.privacySettings
                )
            }
        }

        // 성능 최적화된 이미지 로더
        definitions.append {
            registerModule.makeModule(ImageLoader.self) {
                OptimizedImageLoader(
                    cacheSize: 100_000_000, // 100MB
                    compressionQuality: 0.8,
                    enableWebP: true
                )
            }
        }
    }

    private mutating func setupTestingModules() {
        print("🧪 테스팅 모듈 설정 중")

        // 테스트를 위한 결정론적 목 서비스
        definitions.append {
            registerModule.makeModule(APIClient.self) {
                DeterministicMockAPIClient()
            }
        }

        definitions.append {
            registerModule.makeModule(Logger.self) {
                SilentLogger() // 테스트 중 출력 없음
            }
        }

        definitions.append {
            registerModule.makeModule(DatabaseService.self) {
                InMemoryDatabaseService(preloadTestData: false)
            }
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}

// 지원 구성
struct AppConfiguration {
    let devLogPath: String
    let stagingDBConnectionString: String
    let primaryDBConnectionString: String
    let readReplicaConnectionString: String
    let trustedCertificates: [Certificate]
    let logEncryptionKey: String
    let analyticsEndpoint: String
    let privacySettings: PrivacySettings

    static func load() throws -> AppConfiguration {
        // 번들, 환경 변수 또는 원격 구성에서 로드
        // 구현은 앱의 구성 전략에 따라 다름
        fatalError("구성 로딩 구현")
    }
}
```

### 비동기 모듈 팩토리

복잡한 초기화 시나리오를 위한 고급 비동기 모듈 팩토리:

```swift
struct AsyncModuleFactory {
    private let logger: Logger?
    private let configuration: AppConfiguration
    private let timeout: TimeInterval

    init(configuration: AppConfiguration, logger: Logger? = nil, timeout: TimeInterval = 30) {
        self.configuration = configuration
        self.logger = logger
        self.timeout = timeout
    }

    func makeConfigurationModule() async throws -> Module {
        logger?.info("🔧 원격 구성 로딩 중...")

        do {
            // 타임아웃과 함께 원격 구성 가져오기
            let remoteConfig = try await withTimeout(timeout) {
                try await RemoteConfigService.fetchConfiguration(
                    endpoint: configuration.configEndpoint,
                    apiKey: configuration.configAPIKey
                )
            }

            logger?.info("✅ 원격 구성이 성공적으로 로드되었습니다")

            return Module(RemoteConfiguration.self) {
                remoteConfig
            }
        } catch {
            logger?.warning("⚠️ 원격 구성 로드 실패, 기본값 사용: \(error)")

            // 로컬 구성으로 폴백
            return Module(RemoteConfiguration.self) {
                RemoteConfiguration.defaultConfiguration()
            }
        }
    }

    func makeDatabaseModule() async throws -> Module {
        logger?.info("🗄️ 데이터베이스 연결 초기화 중...")

        do {
            // 재시도 로직으로 데이터베이스 초기화
            let database = try await withRetry(maxAttempts: 3, delay: 1.0) {
                try await DatabaseManager.initialize(
                    connectionString: configuration.primaryDBConnectionString,
                    poolSize: 10,
                    enableSSL: true
                )
            }

            // 데이터베이스 상태 검증
            try await database.healthCheck()

            logger?.info("✅ 데이터베이스가 초기화되고 정상입니다")

            return Module(DatabaseService.self) {
                database
            }
        } catch {
            logger?.error("❌ 데이터베이스 초기화 실패: \(error)")
            throw AsyncModuleError.databaseInitializationFailed(error)
        }
    }

    func makeAuthenticationModule() async throws -> Module {
        logger?.info("🔐 인증 서비스 설정 중...")

        // 인증 구성 로드
        let authConfig = try await AuthConfiguration.load()

        // 인증 공급자 초기화
        let providers = try await initializeAuthProviders(authConfig)

        logger?.info("✅ \(providers.count)개 공급자로 인증 서비스가 구성되었습니다")

        return Module(AuthenticationService.self) {
            MultiProviderAuthenticationService(
                providers: providers,
                defaultProvider: authConfig.defaultProvider
            )
        }
    }

    func makeAnalyticsModule() async throws -> Module {
        logger?.info("📊 분석 서비스 초기화 중...")

        // 분석에 대한 사용자 동의 얻기
        let consentStatus = await AnalyticsConsentManager.getConsentStatus()

        guard consentStatus.analyticsAllowed else {
            logger?.info("📊 사용자 동의로 인해 분석이 비활성화됨")
            return Module(AnalyticsService.self) {
                NoOpAnalyticsService()
            }
        }

        // 동의와 함께 분석 초기화
        let analyticsService = try await AnalyticsService.initialize(
            configuration: configuration.analyticsConfig,
            consentSettings: consentStatus
        )

        logger?.info("✅ 분석 서비스가 초기화되었습니다")

        return Module(AnalyticsService.self) {
            analyticsService
        }
    }

    private func initializeAuthProviders(_ config: AuthConfiguration) async throws -> [AuthProvider] {
        var providers: [AuthProvider] = []

        // OAuth 공급자를 동시에 초기화
        await withTaskGroup(of: AuthProvider?.self) { group in
            for providerConfig in config.providers {
                group.addTask {
                    do {
                        return try await AuthProviderFactory.create(providerConfig)
                    } catch {
                        self.logger?.error("인증 공급자 \(providerConfig.type) 초기화 실패: \(error)")
                        return nil
                    }
                }
            }

            for await provider in group {
                if let provider = provider {
                    providers.append(provider)
                }
            }
        }

        guard !providers.isEmpty else {
            throw AsyncModuleError.noAuthProvidersAvailable
        }

        return providers
    }

    // 배치 비동기 모듈 생성
    func makeAllAsyncModules() async throws -> [Module] {
        logger?.info("⚡ 모든 비동기 모듈을 동시에 생성 중...")

        return try await withThrowingTaskGroup(of: Module.self) { group in
            // 모든 비동기 모듈 생성 작업 추가
            group.addTask { try await self.makeConfigurationModule() }
            group.addTask { try await self.makeDatabaseModule() }
            group.addTask { try await self.makeAuthenticationModule() }
            group.addTask { try await self.makeAnalyticsModule() }

            var modules: [Module] = []
            for try await module in group {
                modules.append(module)
            }
            return modules
        }
    }
}

// 오류 타입
enum AsyncModuleError: LocalizedError {
    case databaseInitializationFailed(Error)
    case configurationLoadFailed(Error)
    case noAuthProvidersAvailable
    case timeoutExceeded

    var errorDescription: String? {
        switch self {
        case .databaseInitializationFailed(let error):
            return "데이터베이스 초기화 실패: \(error.localizedDescription)"
        case .configurationLoadFailed(let error):
            return "구성 로드 실패: \(error.localizedDescription)"
        case .noAuthProvidersAvailable:
            return "초기화할 수 있는 인증 공급자가 없습니다"
        case .timeoutExceeded:
            return "비동기 모듈 초기화 시간 초과"
        }
    }
}

// 유틸리티 함수
func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw AsyncModuleError.timeoutExceeded
        }

        guard let result = try await group.next() else {
            throw AsyncModuleError.timeoutExceeded
        }

        group.cancelAll()
        return result
    }
}

func withRetry<T>(maxAttempts: Int, delay: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    var lastError: Error?

    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            if attempt < maxAttempts {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    throw lastError ?? AsyncModuleError.timeoutExceeded
}

// 애플리케이션에서의 사용
func setupAsyncModules() async throws {
    let asyncFactory = AsyncModuleFactory(
        configuration: AppConfiguration.load(),
        logger: AppLogger.shared
    )

    await WeaveDI.Container.bootstrap { container in
        // 먼저 동기 모듈 등록
        var syncFactory = ApplicationModuleFactory()
        await syncFactory.setupAll()

        for module in syncFactory.getAllModules() {
            await container.register(module)
        }

        // 그 다음 비동기 모듈 등록
        do {
            let asyncModules = try await asyncFactory.makeAllAsyncModules()
            for module in asyncModules {
                await container.register(module)
            }
        } catch {
            print("⚠️ 일부 비동기 모듈 초기화 실패: \(error)")
            // 부분 초기화 또는 폴백 전략 처리
        }
    }
}
```

## 모범 사례

### 1. 순서대로 모듈 등록

```swift
struct OrderedModuleRegistration {
    static func registerInOrder() async {
        await WeaveDI.Container.bootstrap { container in
            // 1. 인프라 레이어
            let infraModules = InfrastructureModuleFactory().makeAllModules()
            for module in infraModules {
                await container.register(module)
            }

            // 2. 데이터 레이어
            let dataModules = DataModuleFactory().makeAllModules()
            for module in dataModules {
                await container.register(module)
            }

            // 3. 도메인 레이어
            let domainModules = DomainModuleFactory().makeAllModules()
            for module in domainModules {
                await container.register(module)
            }

            // 4. 프레젠테이션 레이어
            let presentationModules = PresentationModuleFactory().makeAllModules()
            for module in presentationModules {
                await container.register(module)
            }
        }
    }
}
```

### 2. 테스팅 지원

```swift
#if DEBUG
struct TestModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setupMocks() {
        definitions.append {
            registerModule.makeModule(UserRepository.self) {
                MockUserRepository()
            }
        }

        definitions.append {
            registerModule.makeModule(NetworkService.self) {
                MockNetworkService()
            }
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}
#endif
```

### 3. 오류 처리

```swift
struct SafeModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setup() {
        definitions.append {
            registerModule.makeModule(RiskyService.self) {
                do {
                    return try RiskyServiceImpl()
                } catch {
                    print("RiskyService 생성 실패: \(error)")
                    return FallbackService()
                }
            }
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}
```

## 성능 고려사항

### 지연 모듈 생성

```swift
struct LazyModuleFactory {
    private lazy var expensiveModule = Module(ExpensiveService.self) {
        ExpensiveServiceImpl() // 처음 접근할 때만 생성
    }

    func getExpensiveModule() -> Module {
        expensiveModule
    }
}
```

WeaveDI의 모듈 팩토리 시스템은 깨끗하고 테스트 가능하며 유지보수 가능한 코드 아키텍처를 유지하면서 복잡한 의존성 그래프를 관리하는 견고한 기반을 제공합니다.

## DiModuleFactory - 공통 DI 의존성 관리 (v3.3.4+)

v3.3.4부터 도입된 `DiModuleFactory`는 Logger, Config, Cache 등 앱 전반에서 사용되는 공통 DI 의존성을 체계적으로 관리하기 위한 특별한 모듈 팩토리입니다.

### 핵심 특징

- 📦 **공통 의존성 관리**: 앱 전반에서 공유되는 의존성을 중앙집중식으로 관리
- 🔄 **빌더 패턴**: 직관적인 API로 의존성 추가
- ⚙️ **자동 통합**: ModuleFactoryManager와 seamless 연동
- 🎯 **타입 안전성**: 컴파일 타임 타입 검증

### 기본 사용법

```swift
import WeaveDI

// DiModuleFactory 인스턴스 생성
var diFactory = DiModuleFactory()

// 공통 DI 의존성 추가 (빌더 패턴)
diFactory.addDependency(Logger.self) {
    ConsoleLogger()
}

diFactory.addDependency(APIConfig.self) {
    APIConfig(baseURL: "https://api.example.com")
}

diFactory.addDependency(CacheService.self) {
    MemoryCacheService()
}

// 의존성 모듈 생성
let modules = diFactory.makeAllModules()
```

### ModuleFactoryManager와 통합

`DiModuleFactory`는 `ModuleFactoryManager`와 완벽하게 통합되어 다른 팩토리들과 함께 사용할 수 있습니다.

```swift
// ModuleFactoryManager 설정
var factoryManager = ModuleFactoryManager()

// DiModuleFactory 설정
factoryManager.diFactory.addDependency(Logger.self) {
    #if DEBUG
    ConsoleLogger()
    #else
    ProductionLogger()
    #endif
}

factoryManager.diFactory.addDependency(NetworkConfig.self) {
    NetworkConfig(
        timeout: 30.0,
        retryCount: 3,
        baseURL: "https://api.example.com"
    )
}

// Repository와 UseCase 팩토리도 함께 설정
factoryManager.repositoryFactory.addRepository(UserRepository.self) {
    UserRepositoryImpl()
}

factoryManager.useCaseFactory.addUseCase(AuthUseCase.self) {
    AuthUseCaseImpl()
}

// 모든 모듈을 한번에 등록
await factoryManager.registerAllModules()
```

### 환경별 의존성 설정

환경에 따라 다른 의존성을 설정할 수 있는 유연한 패턴:

```swift
struct EnvironmentDiFactory {
    static func create(for environment: AppEnvironment) -> DiModuleFactory {
        var factory = DiModuleFactory()

        // 공통 의존성
        factory.addDependency(AppConfig.self) {
            AppConfig.load()
        }

        // 환경별 Logger
        switch environment {
        case .development:
            factory.addDependency(Logger.self) {
                ConsoleLogger(level: .debug)
            }
        case .staging:
            factory.addDependency(Logger.self) {
                FileLogger(level: .info)
            }
        case .production:
            factory.addDependency(Logger.self) {
                ProductionLogger(level: .warning)
            }
        }

        // 환경별 Analytics
        factory.addDependency(AnalyticsService.self) {
            switch environment {
            case .development:
                return MockAnalyticsService()
            case .staging, .production:
                return FirebaseAnalyticsService()
            }
        }

        return factory
    }
}

// 사용법
let environment = AppEnvironment.current
var factoryManager = ModuleFactoryManager()
factoryManager.diFactory = EnvironmentDiFactory.create(for: environment)
```

### 앱 시작시 자동 설정

`AppDIManager`는 v3.3.4부터 자동으로 `DiModuleFactory`를 지원합니다:

```swift
// AppDelegate 또는 App.swift에서
@main
struct MyApp: App {
    init() {
        setupDependencies()
    }

    private func setupDependencies() {
        // DiModuleFactory는 자동으로 등록됩니다
        // ModuleFactoryManager도 자동으로 설정됩니다

        // 필요한 경우 추가 설정
        let factoryManager = WeaveDI.Container.live.resolve(ModuleFactoryManager.self)

        factoryManager?.diFactory.addDependency(CustomService.self) {
            CustomServiceImpl()
        }
    }
}
```

### 고급 패턴

#### 조건부 의존성 등록

```swift
var factory = DiModuleFactory()

// 기능 플래그에 따른 조건부 등록
if FeatureFlags.isAnalyticsEnabled {
    factory.addDependency(AnalyticsService.self) {
        FirebaseAnalyticsService()
    }
} else {
    factory.addDependency(AnalyticsService.self) {
        NoOpAnalyticsService()
    }
}

// 플랫폼별 의존성
#if os(iOS)
factory.addDependency(BiometricService.self) {
    iOSBiometricService()
}
#elseif os(macOS)
factory.addDependency(BiometricService.self) {
    MacBiometricService()
}
#endif
```

#### 의존성 체인

```swift
var factory = DiModuleFactory()

// 의존성 체인 설정
factory.addDependency(NetworkClient.self) {
    let config = WeaveDI.Container.live.resolve(NetworkConfig.self)!
    let logger = WeaveDI.Container.live.resolve(Logger.self)!
    return NetworkClient(config: config, logger: logger)
}

factory.addDependency(APIService.self) {
    let client = WeaveDI.Container.live.resolve(NetworkClient.self)!
    return APIService(client: client)
}
```

### 테스팅 지원

테스트 환경에서 쉽게 목 객체로 교체할 수 있습니다:

```swift
#if DEBUG
struct TestDiFactory {
    static func createMockFactory() -> DiModuleFactory {
        var factory = DiModuleFactory()

        factory.addDependency(Logger.self) {
            MockLogger()
        }

        factory.addDependency(NetworkClient.self) {
            MockNetworkClient()
        }

        factory.addDependency(AnalyticsService.self) {
            MockAnalyticsService()
        }

        return factory
    }
}

// 테스트에서 사용
class SomeTestCase: XCTestCase {
    override func setUp() {
        super.setUp()

        var factoryManager = ModuleFactoryManager()
        factoryManager.diFactory = TestDiFactory.createMockFactory()

        await factoryManager.registerAllModules()
    }
}
#endif
```

### 모범 사례

1. **의존성 그룹화**: 관련된 의존성들을 함께 설정
2. **환경별 분리**: 개발/스테이징/프로덕션 환경별로 다른 구현체 사용
3. **늦은 바인딩**: 설정 로드 후 의존성 등록
4. **타입 안전성**: 컴파일 타임에 잘못된 타입 등록 방지
5. **테스트 격리**: 테스트용 의존성을 별도로 관리

`DiModuleFactory`를 통해 앱의 공통 의존성을 체계적이고 타입 안전하게 관리할 수 있으며, 빌더 패턴을 통해 직관적이고 읽기 쉬운 코드를 작성할 수 있습니다.