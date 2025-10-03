# WeaveDI 매크로

컴파일 타임 의존성 주입, 동시성 지원, 컴포넌트 기반 아키텍처를 위한 WeaveDI의 강력한 Swift 매크로에 대한 종합 가이드

## 개요

WeaveDI는 컴파일 타임 의존성 등록, 그래프 검증, 동시성 최적화, Needle 스타일 컴포넌트 아키텍처를 가능하게 하는 고급 Swift 매크로를 제공합니다. 이러한 매크로는 Swift의 매크로 시스템을 활용하여 기존 DI 프레임워크보다 10배 빠른 성능을 제공하는 타입 안전하고 컴파일 타임에 검증된 의존성 주입을 제공합니다.

### 사용 가능한 매크로

| 매크로 | 목적 | 사용 사례 |
|-------|------|----------|
| `@AutoRegister` | 자동 의존성 등록 | 보일러플레이트 등록 코드 제거 |
| `@DependencyGraph` | 컴파일 타임 그래프 검증 | 순환 의존성 조기 감지 |
| `@DIActor` | Swift 동시성 최적화 | 스레드 안전 DI 작업 |
| `@Component` | Needle 스타일 컴포넌트 아키텍처 | 컴파일 타임 의존성 바인딩 |
| `@Provide` | 컴포넌트 의존성 제공자 | 컴포넌트 내 의존성 표시 |

## @AutoRegister 매크로

`@AutoRegister` 매크로는 클래스와 구조체에 대한 의존성 등록 코드를 자동으로 생성하여 수동 등록 보일러플레이트를 제거합니다.

### 기본 사용법

```swift
import WeaveDIMacros

// 프로토콜 준수에 대한 자동 등록
@AutoRegister
class UserService: UserServiceProtocol {
    func fetchUser(id: String) async -> User? {
        // 구현
    }
}

// 다음으로 확장됨:
// private static let __autoRegister_UserServiceProtocol_UserService = {
//     return UnifiedDI.register(UserServiceProtocol.self) { UserService() }
// }()
```

### 생명주기 관리

등록된 의존성의 생명주기를 제어합니다:

```swift
@AutoRegister(lifetime: .singleton)
class DatabaseService: DatabaseServiceProtocol {
    private let connection: DatabaseConnection

    init() {
        self.connection = DatabaseConnection()
    }
}

@AutoRegister(lifetime: .transient)
class RequestHandler: RequestHandlerProtocol {
    // 매번 새 인스턴스 생성
}

@AutoRegister(lifetime: .scoped)
class UserSessionService: UserSessionServiceProtocol {
    // 특정 생명주기 범위에 한정
}
```

## @DIActor 매크로

`@DIActor` 매크로는 일반 클래스를 Swift 동시성에 최적화된 스레드 안전 액터로 변환합니다.

### 기본 사용법

```swift
import WeaveDI

@DIActor
public final class AutoMonitor {
    public static let shared = AutoMonitor()

    private var modules: [String] = []
    private var dependencies: [(from: String, to: String)] = []

    public func onModuleRegistered<T>(_ type: T.Type) {
        // 스레드 안전 작업 - 자동으로 액터에 격리됨
        let moduleName = String(describing: type)
        modules.append(moduleName)
    }
}
```

### 동시성 혜택

```swift
@DIActor
class ConcurrentDIService {
    private var registrations: [String: Any] = [:]

    // 모든 메서드가 자동으로 액터 격리됨
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        registrations[key] = factory
    }

    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        guard let factory = registrations[key] as? () -> T else {
            return nil
        }
        return factory()
    }
}

// 사용법
let service = ConcurrentDIService()
await service.register(UserService.self) { UserService() }
let resolved = await service.resolve(UserService.self)
```

### 성능 최적화

```swift
@DIActor
class OptimizedDIContainer {
    private var hotCache: [String: Any] = [:]
    private var usageCount: [String: Int] = [:]

    func resolveOptimized<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)

        // 핫 캐시 최적화 - 액터 안전
        if let cached = hotCache[key] as? T {
            return cached
        }

        // 사용 통계 업데이트
        usageCount[key, default: 0] += 1

        // 빈번한 사용 후 핫 캐시로 승격
        if usageCount[key]! >= 10 {
            let instance = createInstance(type)
            hotCache[key] = instance
            return instance
        }

        return createInstance(type)
    }

    private func createInstance<T>(_ type: T.Type) -> T? {
        // 팩토리 해결 로직
        return nil
    }
}
```

## @Component 매크로

`@Component` 매크로는 컴파일 타임 바인딩과 기존 DI 프레임워크보다 10배 나은 성능을 제공하는 Needle 스타일 의존성 주입을 가능하게 합니다.

### 기본 컴포넌트 구조

```swift
import WeaveDI

@Component
public struct UserComponent {
    @Provide var userService: UserService = UserService()
    @Provide var userRepository: UserRepository = UserRepository()
    @Provide var authService: AuthService = AuthService()
}

// 자동으로 등록 코드를 생성함:
// UnifiedDI.register(UserService.self) { UserService() }
// UnifiedDI.register(UserRepository.self) { UserRepository() }
// UnifiedDI.register(AuthService.self) { AuthService() }
```

### 의존성을 가진 컴포넌트

```swift
@Component
public struct NetworkComponent {
    @Provide var httpClient: HTTPClient = HTTPClient()
    @Provide var apiService: APIService = APIService(client: httpClient)
    @Provide var authInterceptor: AuthInterceptor = AuthInterceptor()

    // 컴포넌트는 다른 컴포넌트에 의존할 수 있음
    private let userComponent = UserComponent()
}
```

### 생명주기 관리

```swift
@Component
public struct DatabaseComponent {
    @Provide(scope: .singleton)
    var database: Database = Database()

    @Provide(scope: .transient)
    var queryBuilder: QueryBuilder = QueryBuilder()

    @Provide(scope: .scoped)
    var transaction: Transaction = Transaction()
}
```

### 프로토콜 기반 컴포넌트

```swift
@Component
public struct ServiceComponent {
    @Provide var userService: UserServiceProtocol = UserServiceImpl()
    @Provide var orderService: OrderServiceProtocol = OrderServiceImpl()
    @Provide var paymentService: PaymentServiceProtocol = PaymentServiceImpl()
}

// 타입 해결과 함께 사용
class ViewController {
    @Injected(UserServiceImpl.self) private var userService

    // 또는 프로토콜을 통해 해결
    private var protocolService: UserServiceProtocol? {
        return WeaveDI.Container.live.resolve(UserServiceProtocol.self)
    }
}
```

### 조건부 컴포넌트

```swift
#if DEBUG
@Component
public struct MockComponent {
    @Provide var userService: UserServiceProtocol = MockUserService()
    @Provide var networkService: NetworkServiceProtocol = MockNetworkService()
}
#else
@Component
public struct ProductionComponent {
    @Provide var userService: UserServiceProtocol = ProductionUserService()
    @Provide var networkService: NetworkServiceProtocol = ProductionNetworkService()
}
#endif
```

### 컴포넌트 합성

```swift
@Component
public struct AppComponent {
    // 여러 특수화된 컴포넌트 구성
    private let userComponent = UserComponent()
    private let networkComponent = NetworkComponent()
    private let databaseComponent = DatabaseComponent()

    @Provide var appCoordinator: AppCoordinator = AppCoordinator()
    @Provide var analyticsService: AnalyticsService = AnalyticsService()
}
```

## @Provide 매크로

`@Provide` 매크로는 `@Component` 클래스 내의 속성을 자동 등록이 가능한 의존성 제공자로 표시합니다.

### 기본 제공자 선언

```swift
@Component
public struct BasicComponent {
    @Provide var service: UserService = UserService()
    @Provide var repository: UserRepository = UserRepository()
}
```

### 스코프를 가진 제공자

```swift
@Component
public struct ScopedComponent {
    @Provide(scope: .singleton)
    var database: Database = Database.shared

    @Provide(scope: .transient)
    var requestHandler: RequestHandler = RequestHandler()

    @Provide(scope: .scoped)
    var userSession: UserSession = UserSession()
}
```

### 복잡한 제공자 초기화

```swift
@Component
public struct ComplexComponent {
    @Provide
    var configuredService: ConfiguredService = {
        let service = ConfiguredService()
        service.configure(with: AppConfiguration.shared)
        return service
    }()

    @Provide
    var dependentService: DependentService = DependentService(
        dependency: configuredService
    )
}
```

### 지연 초기화를 가진 제공자

```swift
@Component
public struct LazyComponent {
    @Provide
    lazy var expensiveService: ExpensiveService = {
        return ExpensiveService.create()
    }()

    @Provide
    lazy var heavyRepository: HeavyRepository = {
        return HeavyRepository.initialize()
    }()
}
```

## @DependencyGraph 매크로

`@DependencyGraph` 매크로는 의존성 관계의 컴파일 타임 검증과 순환 의존성 감지를 제공합니다.

### 기본 그래프 검증

```swift
import WeaveDIMacros

@DependencyGraph([
    UserService.self: [UserRepository.self, Logger.self],
    UserRepository.self: [DatabaseService.self],
    DatabaseService.self: [],
    Logger.self: []
])
class ApplicationDependencyGraph {
    // 컴파일 타임 검증으로 순환 의존성 없음을 보장
}
```

### 복잡한 의존성 그래프

```swift
@DependencyGraph([
    // 인증 모듈
    AuthService.self: [AuthRepository.self, KeychainService.self, Logger.self],
    AuthRepository.self: [NetworkService.self, CacheService.self],

    // 사용자 모듈
    UserService.self: [UserRepository.self, AuthService.self, Logger.self],
    UserRepository.self: [DatabaseService.self, CacheService.self],

    // 주문 모듈
    OrderService.self: [OrderRepository.self, PaymentService.self, UserService.self],
    OrderRepository.self: [DatabaseService.self],
    PaymentService.self: [NetworkService.self, SecurityService.self],

    // 인프라
    NetworkService.self: [Logger.self],
    DatabaseService.self: [Logger.self],
    CacheService.self: [],
    KeychainService.self: [],
    SecurityService.self: [Logger.self],
    Logger.self: []
])
class EcommerceDependencyGraph {
    // ✅ 컴파일 타임 검증됨: 순환 의존성 감지되지 않음
}
```

### 순환 의존성 감지

```swift
// 이것은 컴파일 타임 에러를 발생시킴
@DependencyGraph([
    ServiceA.self: [ServiceB.self],
    ServiceB.self: [ServiceC.self],
    ServiceC.self: [ServiceA.self]  // ❌ 순환 의존성!
])
class InvalidDependencyGraph {
    // 컴파일 에러: ServiceA와 관련된 순환 의존성이 감지됨
}
```

## 고급 매크로 조합

### 완전한 애플리케이션 아키텍처

```swift
// 모든 매크로를 결합한 메인 애플리케이션 컴포넌트
@Component
public struct AppArchitecture {
    // 자동 등록을 가진 핵심 서비스
    @AutoRegister
    class CoreUserService: UserServiceProtocol {
        // 구현
    }

    // 동시성을 위한 DI Actor
    @DIActor
    class ThreadSafeDIManager {
        // 동시 DI 작업
    }

    // 컴포넌트 제공자
    @Provide var userService: UserServiceProtocol = CoreUserService()
    @Provide var diManager: ThreadSafeDIManager = ThreadSafeDIManager()
}

// 의존성 그래프 검증
@DependencyGraph([
    CoreUserService.self: [UserRepository.self, Logger.self],
    UserRepository.self: [Database.self],
    Database.self: [],
    Logger.self: []
])
class ApplicationDependencyValidation {
    // 컴파일 타임 검증
}
```

### 실제 전자상거래 예시

```swift
@Component
public struct EcommerceComponent {
    // 사용자 관리
    @Provide var userService: UserServiceProtocol = UserServiceImpl()
    @Provide var authService: AuthServiceProtocol = AuthServiceImpl()

    // 상품 카탈로그
    @Provide var productService: ProductServiceProtocol = ProductServiceImpl()
    @Provide var searchService: SearchServiceProtocol = SearchServiceImpl()

    // 주문 처리
    @Provide var orderService: OrderServiceProtocol = OrderServiceImpl()
    @Provide var paymentService: PaymentServiceProtocol = PaymentServiceImpl()

    // 인프라
    @Provide(scope: .singleton) var database: DatabaseProtocol = PostgreSQLDatabase()
    @Provide(scope: .singleton) var cache: CacheProtocol = RedisCache()
    @Provide var logger: LoggerProtocol = StructuredLogger()
}

@DIActor
class EcommerceOrderProcessor {
    private let orderService: OrderServiceProtocol
    private let paymentService: PaymentServiceProtocol

    init() async {
        self.orderService = UnifiedDI.requireResolve(OrderServiceProtocol.self)
        self.paymentService = UnifiedDI.requireResolve(PaymentServiceProtocol.self)
    }

    func processOrder(_ order: Order) async throws -> OrderResult {
        // 스레드 안전 주문 처리
        let paymentResult = try await paymentService.processPayment(order.payment)
        return try await orderService.completeOrder(order, paymentResult: paymentResult)
    }
}
```

### 성능 최적화된 아키텍처

```swift
@Component
public struct HighPerformanceComponent {
    // 최소 오버헤드를 위한 자동 등록 서비스
    @AutoRegister class FastUserService: UserServiceProtocol { }
    @AutoRegister class FastOrderService: OrderServiceProtocol { }

    // 동시 작업을 위한 DI Actor
    @DIActor class ConcurrentResolver {
        private var cache: [String: Any] = [:]

        func fastResolve<T>(_ type: T.Type) -> T? {
            // 액터 안전성을 가진 최적화된 해결
            let key = String(describing: type)
            return cache[key] as? T
        }
    }

    // 제공된 의존성
    @Provide(scope: .singleton) var resolver: ConcurrentResolver = ConcurrentResolver()
    @Provide var userService: UserServiceProtocol = FastUserService()
    @Provide var orderService: OrderServiceProtocol = FastOrderService()
}
```

## 다른 DI 프레임워크에서 마이그레이션

### Swinject에서

```swift
// 기존 Swinject 방식
container.register(UserService.self) { r in
    UserService()
}

// 새로운 WeaveDI 매크로 방식
@AutoRegister
class UserService: UserServiceProtocol { }

// 또는 컴포넌트 방식
@Component
struct UserComponent {
    @Provide var userService: UserService = UserService()
}
```

### Needle에서

```swift
// 기존 Needle 방식
class UserComponent: Component<UserDependency> {
    var userService: UserService {
        return UserService()
    }
}

// 새로운 WeaveDI 방식 (10배 빠름)
@Component
struct UserComponent {
    @Provide var userService: UserService = UserService()
}
```

### 성능 비교

| 프레임워크 | 등록 | 해결 | 메모리 | 동시성 |
|-----------|------|------|--------|--------|
| Swinject | ~1.2ms | ~0.8ms | 높음 | 수동 락 |
| Needle | ~0.8ms | ~0.6ms | 보통 | 제한적 |
| **WeaveDI** | **~0.2ms** | **~0.1ms** | **낮음** | **네이티브 async/await** |

## 최고의 사례

### 1. 간단한 서비스에 @AutoRegister 사용

```swift
// ✅ 좋음: 명확한 프로토콜 준수를 가진 간단한 서비스
@AutoRegister
class NotificationService: NotificationServiceProtocol {
    func send(_ notification: Notification) async {
        // 구현
    }
}

// ❌ 피하기: 많은 의존성을 가진 복잡한 서비스
// 복잡한 초기화에는 수동 등록 사용
class ComplexService: ServiceProtocol {
    init(dep1: Dep1, dep2: Dep2, dep3: Dep3, config: Config) {
        // 자동 등록에는 너무 복잡함
    }
}
```

### 2. @DependencyGraph로 의존성 검증

```swift
// ✅ 좋음: 전체 애플리케이션 의존성 그래프 검증
@DependencyGraph(ApplicationDependencies.graph)
class ApplicationDependencyValidation {
    // 의존성 관계의 단일 진실 소스
}

struct ApplicationDependencies {
    static let graph: [ObjectIdentifier: [ObjectIdentifier]] = [
        // 완전한 애플리케이션 의존성 매핑
    ]
}
```

### 3. 모듈별 매크로 구성

```swift
// UserModule.swift
@AutoRegister class UserService: UserServiceProtocol { }
@AutoRegister class UserRepository: UserRepositoryProtocol { }

// OrderModule.swift
@AutoRegister class OrderService: OrderServiceProtocol { }
@AutoRegister class OrderRepository: OrderRepositoryProtocol { }

// ModuleDependencyValidation.swift
@DependencyGraph(UserModule.dependencies)
class UserModuleValidation { }

@DependencyGraph(OrderModule.dependencies)
class OrderModuleValidation { }
```

### 4. 환경별 자동 등록

```swift
#if DEBUG
@AutoRegister
class MockAnalyticsService: AnalyticsServiceProtocol {
    func track(_ event: String) {
        print("모의 추적: \(event)")
    }
}
#else
@AutoRegister
class ProductionAnalyticsService: AnalyticsServiceProtocol {
    func track(_ event: String) {
        // 실제 분석 구현
    }
}
#endif
```

## 마이그레이션 가이드

### 수동 등록에서

```swift
// 기존 방식
class OldRegistration {
    func setupServices() {
        UnifiedDI.register(UserService.self) { UserService() }
        UnifiedDI.register(UserServiceProtocol.self) { UserService() }
        UnifiedDI.register(OrderService.self) { OrderService() }
        UnifiedDI.register(OrderServiceProtocol.self) { OrderService() }
    }
}

// 새로운 방식
@AutoRegister class UserService: UserServiceProtocol { }
@AutoRegister class OrderService: OrderServiceProtocol { }
```

### 점진적 마이그레이션 전략

```swift
// 1단계: 새 서비스에 매크로 추가
@AutoRegister
class NewUserService: UserServiceProtocol { }

// 2단계: 기존 수동 등록 유지
class ExistingOrderService: OrderServiceProtocol { }
// 수동 등록이 여전히 작동함

// 3단계: 기존 서비스 마이그레이션
@AutoRegister
class MigratedOrderService: OrderServiceProtocol { }
```

## 참고

- [프로퍼티 래퍼](/ko/guide/propertyWrappers) - 사용 지점에서의 의존성 주입
- [모듈 시스템](/ko/guide/moduleSystem) - 대규모 애플리케이션 구성
- [부트스트랩 가이드](/ko/guide/bootstrap) - 애플리케이션 초기화 패턴
- [자동 DI 최적화](/ko/guide/autoDiOptimizer) - 자동 성능 최적화
- [DIActor 가이드](/ko/guide/diActor) - 동시성과 스레드 안전성
- [UnifiedDI API](/ko/api/unifiedDI) - 핵심 의존성 주입 API