# 고급 패턴 및 모범 사례

이 종합적인 가이드는 고급 의존성 주입 패턴, 아키텍처 모범 사례, 그리고 WeaveDI를 사용하여 프로덕션 준비가 완료된 애플리케이션을 구축하기 위한 전문 기법을 다룹니다.

## 목차

1. [고급 Property Wrapper 패턴](#고급-property-wrapper-패턴)
2. [복잡한 의존성 그래프](#복잡한-의존성-그래프)
3. [성능 최적화 기법](#성능-최적화-기법)
4. [오류 처리 전략](#오류-처리-전략)
5. [테스팅 패턴](#테스팅-패턴)
6. [멀티 모듈 아키텍처](#멀티-모듈-아키텍처)
7. [프로덕션 배포](#프로덕션-배포)

## 고급 Property Wrapper 패턴

### 조건부 주입

런타임 조건에 따라 의존성을 주입합니다:

```swift
// 환경 기반 조건부 주입
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

    // 대안: 런타임 조건 기반 주입
    @Injected private var userService: UserService?
    @Injected private var adminService: AdminService?

    private func getService(for user: User) -> UserServiceProtocol? {
        return user.isAdmin ? adminService : userService
    }
}
```

### 제네릭 의존성 주입

타입 안전한 제네릭 의존성 패턴을 생성합니다:

```swift
// 제네릭 레포지토리 패턴
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
        logger?.info("\(T.self) 타입의 엔티티를 저장합니다")
        // CoreData 구현
    }

    func fetch(id: String) async throws -> T? {
        logger?.info("id가 \(id)인 \(T.self)를 가져옵니다")
        // CoreData 구현
        return nil
    }

    func fetchAll() async throws -> [T] {
        logger?.info("\(T.self) 타입의 모든 엔티티를 가져옵니다")
        // CoreData 구현
        return []
    }
}

// 등록
await WeaveDI.Container.bootstrap { container in
    container.register(Repository<User>.self) {
        CoreDataRepository<User>()
    }

    container.register(Repository<Product>.self) {
        CoreDataRepository<Product>()
    }
}

// 사용
class UserManager {
    @Injected private var userRepository: Repository<User>?

    func createUser(_ user: User) async throws {
        try await userRepository?.save(user)
    }
}
```

### DI를 사용한 데코레이터 패턴

데코레이터를 사용하여 횡단 관심사를 구현합니다:

```swift
// 기본 서비스
protocol OrderService {
    func processOrder(_ order: Order) async throws -> OrderResult
}

class BasicOrderService: OrderService {
    @Injected private var paymentService: PaymentService?
    @Injected private var inventoryService: InventoryService?

    func processOrder(_ order: Order) async throws -> OrderResult {
        // 기본 주문 처리 로직
        return OrderResult(orderId: order.id, status: .processed)
    }
}

// 로깅 데코레이터
class LoggingOrderService: OrderService {
    @Injected private var logger: Logger?
    private let decorated: OrderService

    init(decorated: OrderService) {
        self.decorated = decorated
    }

    func processOrder(_ order: Order) async throws -> OrderResult {
        logger?.info("주문 처리 중: \(order.id)")

        do {
            let result = try await decorated.processOrder(order)
            logger?.info("주문 처리 완료: \(order.id)")
            return result
        } catch {
            logger?.error("주문 처리 실패: \(order.id), 오류: \(error)")
            throw error
        }
    }
}

// 분석 데코레이터
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

// 데코레이터 체인으로 등록
await WeaveDI.Container.bootstrap { container in
    // 기본 서비스 등록
    container.register("BasicOrderService", OrderService.self) {
        BasicOrderService()
    }

    // 데코레이터된 서비스 등록
    container.register(OrderService.self) {
        let basicService = container.resolve("BasicOrderService", OrderService.self)!
        let loggingService = LoggingOrderService(decorated: basicService)
        return AnalyticsOrderService(decorated: loggingService)
    }
}
```

## 복잡한 의존성 그래프

### 순환 의존성 해결

순환 의존성을 안전하게 처리합니다:

```swift
// 지연 주입을 사용하여 순환 의존성 해결
class UserService {
    @Injected private var orderService: OrderService?  // 처음에는 nil

    // 순환을 끊기 위한 지연 해결
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
        // 사용자의 주문 반환
        return []
    }
}

// 대안: 프로토콜을 사용하여 순환 해결
protocol UserServiceProtocol {
    func getUser(id: String) async throws -> User?
}

protocol OrderServiceProtocol {
    func getOrdersForUser(_ userId: String) async throws -> [Order]
}

class UserServiceImpl: UserServiceProtocol {
    @Injected private var orderService: OrderServiceProtocol?

    func getUser(id: String) async throws -> User? {
        // 구현
        return nil
    }
}

class OrderServiceImpl: OrderServiceProtocol {
    @Injected private var userService: UserServiceProtocol?

    func getOrdersForUser(_ userId: String) async throws -> [Order] {
        // 구현
        return []
    }
}
```

### 계층적 의존성

부모-자식 의존성 관계를 생성합니다:

```swift
// 공유 의존성을 가진 부모 컨테이너
class ParentContainer {
    static func configure() async {
        await WeaveDI.Container.bootstrap { container in
            // 공유/전역 의존성
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

// 기능별 의존성을 위한 자식 컨테이너
class FeatureContainer {
    static func configure() async {
        // 부모 컨테이너가 이미 구성되었다고 가정
        await WeaveDI.Container.bootstrap { container in
            // 부모 의존성을 사용할 수 있는 기능별 의존성
            container.register(UserRepository.self) {
                UserRepositoryImpl() // 데이터베이스 및 네트워크 서비스를 자동 주입
            }

            container.register(UserService.self) {
                UserServiceImpl() // 사용자 레포지토리 및 로거를 자동 주입
            }
        }
    }
}

// 앱에서 사용
@main
struct MyApp: App {
    init() {
        Task {
            // 순서대로 구성: 부모 먼저, 그 다음 자식
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

## 성능 최적화 기법

### 지연 초기화 패턴

지연 초기화로 메모리 사용량을 최적화합니다:

```swift
class PerformanceOptimizedService {
    // 비용이 많이 드는 작업을 위한 지연 프로퍼티
    @Injected private var _expensiveService: ExpensiveService?
    private lazy var expensiveService: ExpensiveService? = {
        print("💰 비용이 많이 드는 서비스가 생성되었습니다")
        return _expensiveService
    }()

    // 임시 객체를 위한 팩토리
    @Factory private var temporaryProcessor: TemporaryProcessor

    // 캐시된 계산 프로퍼티
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
        // 비용이 많이 드는 작업
        return "computed_result"
    }

    func performLightOperation() {
        // 이것은 비용이 많이 드는 서비스 생성을 트리거하지 않습니다
        print("가벼운 작업이 완료되었습니다")
    }

    func performHeavyOperation() async {
        // 이것은 필요할 때만 비용이 많이 드는 서비스를 생성합니다
        await expensiveService?.performHeavyWork()
    }

    func processTemporaryData(_ data: Data) {
        // 각 호출마다 새로운 프로세서 인스턴스
        let processor = temporaryProcessor
        processor.process(data)
        // processor는 사용 후 자동으로 해제됩니다
    }
}
```

### 배치 의존성 해결

여러 의존성 해결을 최적화합니다:

```swift
class BatchOptimizedService {
    // 여러 의존성을 한 번에 배치로 해결
    private let dependencies: (
        userService: UserService?,
        orderService: OrderService?,
        paymentService: PaymentService?,
        notificationService: NotificationService?
    )

    init() {
        // 모든 의존성을 한 번에 배치 해결
        dependencies = (
            userService: UnifiedDI.resolve(UserService.self),
            orderService: UnifiedDI.resolve(OrderService.self),
            paymentService: UnifiedDI.resolve(PaymentService.self),
            notificationService: UnifiedDI.resolve(NotificationService.self)
        )
    }

    func processComplexWorkflow() async throws {
        // 모든 의존성이 이미 해결됨 - 조회 비용 없음
        guard let userService = dependencies.userService,
              let orderService = dependencies.orderService,
              let paymentService = dependencies.paymentService,
              let notificationService = dependencies.notificationService else {
            throw ServiceError.dependenciesNotAvailable
        }

        // 사전 해결된 의존성 사용
        let user = try await userService.getCurrentUser()
        let orders = try await orderService.getOrdersForUser(user.id)

        for order in orders {
            try await paymentService.processPayment(for: order)
            await notificationService.sendOrderConfirmation(order: order, to: user)
        }
    }
}
```

### 메모리 풀 패턴

비용이 많이 드는 객체를 재사용합니다:

```swift
// 생성 비용이 많이 드는 객체를 위한 객체 풀
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

        // 풀이 최대 용량이 아니면 새 프로세서 생성
        if allProcessors.count < maxPoolSize {
            let processor = processorFactory // 새 인스턴스 생성
            allProcessors.append(processor)
            return processor
        }

        // 풀이 가득 참, 대기하고 재사용
        return availableProcessors.first ?? processorFactory
    }

    func returnProcessor(_ processor: ImageProcessor) {
        lock.lock()
        defer { lock.unlock() }

        processor.reset() // 상태 지우기
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

## 오류 처리 전략

### 우아한 성능 저하

누락된 의존성을 우아하게 처리합니다:

```swift
class ResilientService {
    @Injected private var primaryService: PrimaryService?
    @Injected private var fallbackService: FallbackService?
    @Injected private var logger: Logger?

    func performOperation() async throws -> Result {
        // 먼저 주 서비스 시도
        if let primary = primaryService {
            do {
                return try await primary.performOperation()
            } catch {
                logger?.warning("주 서비스 실패, 대체 서비스 시도: \(error)")
            }
        }

        // 보조 서비스로 대체
        if let fallback = fallbackService {
            do {
                return try await fallback.performOperation()
            } catch {
                logger?.error("대체 서비스도 실패: \(error)")
                throw ServiceError.allServicesFailed
            }
        }

        // 우아한 성능 저하 - 캐시된 또는 기본 결과 반환
        logger?.info("사용 가능한 서비스가 없음, 캐시된 결과 반환")
        return getCachedResult() ?? getDefaultResult()
    }

    private func getCachedResult() -> Result? {
        // 사용 가능한 경우 캐시된 데이터 반환
        return nil
    }

    private func getDefaultResult() -> Result {
        // 안전한 기본값 반환
        return Result.empty
    }
}
```

### 의존성 상태 검사

의존성 상태를 모니터링합니다:

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

        // 모든 주입 가능한 의존성 검사
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
                    logger?.info("\(serviceName): 정상")
                case .degraded(let reason):
                    logger?.warning("\(serviceName): 성능 저하 - \(reason)")
                case .unhealthy(let error):
                    logger?.error("\(serviceName): 비정상 - \(error)")
                }
            }
        }

        return results
    }
}
```

## 테스팅 패턴

### 테스트 더블 주입

고급 모킹 패턴:

```swift
// 테스트 더블 프로토콜
protocol TestDouble {
    var callHistory: [String] { get set }
    func reset()
}

// 모든 상호작용을 기록하는 스파이 서비스
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

// 미리 정의된 응답을 가진 스텁 서비스
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

// 테스트 더블을 사용하는 테스트 케이스
class PaymentProcessorTests: XCTestCase {
    var spyUserService: SpyUserService!
    var stubPaymentService: StubPaymentService!
    var processor: PaymentProcessor!

    override func setUp() async throws {
        await super.setUp()

        // 테스트 더블 생성
        spyUserService = SpyUserService()
        stubPaymentService = StubPaymentService()

        // 테스트 더블 등록
        await WeaveDI.Container.bootstrap { container in
            container.register(UserService.self, instance: spyUserService)
            container.register(PaymentService.self, instance: stubPaymentService)
        }

        processor = PaymentProcessor()
    }

    override func tearDown() async throws {
        await super.tearDown()

        // 테스트 더블 리셋
        spyUserService.reset()
        stubPaymentService.reset()
    }

    func testSuccessfulPayment() async throws {
        // Given
        let user = User(id: "test", name: "테스트 사용자", email: "test@example.com")
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

        // 상호작용 검증
        XCTAssertEqual(spyUserService.callHistory, ["getUser(id: test)"])
        XCTAssertEqual(stubPaymentService.callHistory.count, 1)
        XCTAssertTrue(stubPaymentService.callHistory[0].contains("processPayment"))
    }
}
```

### 통합 테스트 컨테이너

통합 테스트를 위한 전문 컨테이너를 생성합니다:

```swift
class IntegrationTestContainer {
    static func configure() async {
        await WeaveDI.Container.bootstrap { container in
            // 통합 테스트를 위한 실제 구현 사용
            container.register(NetworkService.self) {
                URLSessionNetworkService(baseURL: "https://test-api.example.com")
            }

            // 테스트를 위한 인메모리 데이터베이스 사용
            container.register(DatabaseService.self) {
                InMemoryDatabaseService()
            }

            // 데이터를 전송하지 않는 테스트 분석 사용
            container.register(AnalyticsService.self) {
                TestAnalyticsService()
            }

            // 실제 비즈니스 로직 서비스 사용
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
        // 실제 서비스로 완전한 플로우 테스트
        let userService = UnifiedDI.resolve(UserService.self)!

        // 사용자 생성
        let newUser = User(id: "integration_test", name: "통합 테스트", email: "test@integration.com")
        try await userService.createUser(newUser)

        // 사용자 생성 확인
        let retrievedUser = try await userService.getUser(id: newUser.id)
        XCTAssertEqual(retrievedUser?.name, newUser.name)

        // 사용자 업데이트
        var updatedUser = newUser
        updatedUser.name = "업데이트된 이름"
        try await userService.updateUser(updatedUser)

        // 업데이트 확인
        let finalUser = try await userService.getUser(id: newUser.id)
        XCTAssertEqual(finalUser?.name, "업데이트된 이름")
    }
}
```

## 멀티 모듈 아키텍처

### 기능 모듈 패턴

대형 애플리케이션을 기능 모듈로 조직화합니다:

```swift
// 기본 기능 모듈 프로토콜
protocol FeatureModule {
    static var name: String { get }
    static func configure() async
    static func dependencies() -> [String] // 모듈 의존성
}

// 사용자 기능 모듈
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

// 주문 기능 모듈
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

// 의존성 순서 로딩을 위한 모듈 매니저
class ModuleManager {
    private static var configuredModules: Set<String> = []

    static func configureModules(_ modules: [FeatureModule.Type]) async {
        let sortedModules = topologicalSort(modules)

        for moduleType in sortedModules {
            if !configuredModules.contains(moduleType.name) {
                print("🔧 모듈 구성 중: \(moduleType.name)")
                await moduleType.configure()
                configuredModules.insert(moduleType.name)
                print("✅ 모듈 구성 완료: \(moduleType.name)")
            }
        }
    }

    private static func topologicalSort(_ modules: [FeatureModule.Type]) -> [FeatureModule.Type] {
        // 의존성에 기반한 위상 정렬 구현
        var sorted: [FeatureModule.Type] = []
        var visited: Set<String> = []
        var visiting: Set<String> = []

        func visit(_ moduleType: FeatureModule.Type) {
            let moduleName = moduleType.name

            if visiting.contains(moduleName) {
                fatalError("\(moduleName)과 관련된 순환 의존성이 감지되었습니다")
            }

            if visited.contains(moduleName) {
                return
            }

            visiting.insert(moduleName)

            // 의존성 먼저 방문
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

// 앱에서 사용
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
            print("🚀 모든 모듈이 성공적으로 구성되었습니다")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## 프로덕션 배포

### 환경 구성

다양한 환경을 구성합니다:

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
            // 개발 서비스
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

        // 개발 최적화 활성화
        UnifiedDI.setLogLevel(.all)
    }

    private static func configureStaging() async {
        await WeaveDI.Container.bootstrap { container in
            // 스테이징 서비스
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

        // 스테이징 최적화
        UnifiedDI.setLogLevel(.warnings)
    }

    private static func configureProduction() async {
        await WeaveDI.Container.bootstrap { container in
            // 프로덕션 서비스
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

        // 프로덕션 최적화
        UnifiedRegistry.shared.enableOptimization()
        UnifiedDI.setLogLevel(.errors)
    }
}
```

### 성능 모니터링

프로덕션에서 DI 성능을 모니터링합니다:

```swift
class ProductionMonitoring {
    @Injected private var logger: Logger?

    static func setupMonitoring() {
        // 느린 의존성 해결 모니터링
        UnifiedDI.onSlowResolution { serviceName, duration in
            if duration > 0.01 { // 10ms 임계값
                print("⚠️ 느린 DI 해결: \(serviceName)가 \(duration * 1000)ms 소요")
            }
        }

        // 메모리 사용량 모니터링
        UnifiedDI.onMemoryPressure {
            print("💾 DI 컨테이너 메모리 압박 상태")
        }

        // 오류 비율 모니터링
        UnifiedDI.onResolutionError { serviceName, error in
            print("❌ DI 해결 실패: \(serviceName) - \(error)")
        }
    }
}
```

이 종합적인 가이드는 프로덕션 애플리케이션에서 WeaveDI를 사용하기 위한 고급 패턴과 모범 사례를 제공합니다. 이러한 패턴은 정교한 의존성 주입 요구사항을 가진 확장 가능하고 유지보수 가능하며 성능이 뛰어난 애플리케이션을 구축하는 데 도움이 됩니다.