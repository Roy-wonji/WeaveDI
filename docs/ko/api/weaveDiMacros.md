# WeaveDI 매크로

컴파일 타임 의존성 주입과 그래프 검증을 위한 WeaveDI의 강력한 Swift 매크로에 대한 종합 가이드

## 개요

WeaveDI는 컴파일 타임 의존성 등록, 그래프 검증, 자동 최적화를 가능하게 하는 고급 Swift 매크로를 제공합니다. 이러한 매크로는 Swift의 매크로 시스템을 활용하여 타입 안전하고 컴파일 타임에 검증된 의존성 주입을 제공합니다.

### 사용 가능한 매크로

| 매크로 | 목적 | 사용 사례 |
|-------|------|----------|
| `@AutoRegister` | 자동 의존성 등록 | 보일러플레이트 등록 코드 제거 |
| `@DependencyGraph` | 컴파일 타임 그래프 검증 | 순환 의존성 조기 감지 |

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

### 프로토콜 기반 등록

매크로는 프로토콜 준수를 자동으로 감지하고 등록합니다:

```swift
@AutoRegister
class NetworkService: NetworkServiceProtocol, Sendable {
    private let session: URLSession

    init() {
        self.session = URLSession.shared
    }

    func request<T: Codable>(_ endpoint: Endpoint) async throws -> T {
        // 구현
    }
}

// 자동으로 생성됨:
// 1. NetworkServiceProtocol에 대한 등록
// 2. NetworkService(구체 타입)에 대한 등록
// 3. Sendable 준수가 유지됨
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
    // 각 해결마다 새 인스턴스 생성
}

@AutoRegister(lifetime: .scoped)
class UserSessionService: UserSessionServiceProtocol {
    // 특정 생명주기 경계에 범위 지정
}
```

### 복잡한 의존성 등록

```swift
@AutoRegister
class AuthenticationService: AuthenticationServiceProtocol {
    private let keychain: KeychainService
    private let networkService: NetworkServiceProtocol
    private let logger: LoggerProtocol

    init() {
        // 등록 중에 의존성이 자동으로 해결됨
        self.keychain = KeychainService()
        self.networkService = UnifiedDI.requireResolve(NetworkServiceProtocol.self)
        self.logger = UnifiedDI.requireResolve(LoggerProtocol.self)
    }

    func authenticate(credentials: Credentials) async throws -> AuthResult {
        logger.info("사용자 인증 중")
        let result = try await networkService.authenticate(credentials)
        try keychain.store(result.token)
        return result
    }
}
```

### 조건부 등록

```swift
#if DEBUG
@AutoRegister
class MockUserService: UserServiceProtocol {
    func fetchUser(id: String) async -> User? {
        return User(id: id, name: "Mock User")
    }
}
#else
@AutoRegister
class ProductionUserService: UserServiceProtocol {
    func fetchUser(id: String) async -> User? {
        // 프로덕션 구현
    }
}
#endif
```

### 제네릭 타입 지원

```swift
@AutoRegister
class Repository<T: Codable>: RepositoryProtocol {
    private let storage: Storage<T>

    init() {
        self.storage = Storage<T>()
    }

    func save(_ entity: T) async throws {
        try await storage.save(entity)
    }

    func fetch(id: String) async throws -> T? {
        return try await storage.fetch(id: id)
    }
}

// 특정 타입과의 사용
typealias UserRepository = Repository<User>
typealias OrderRepository = Repository<Order>
```

## @DependencyGraph 매크로

`@DependencyGraph` 매크로는 의존성 관계에 대한 컴파일 타임 검증과 순환 의존성 감지를 제공합니다.

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
    // 컴파일 타임 검증으로 순환 의존성이 없음을 보장
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

    // 인프라스트럭처
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
// 이것은 컴파일 타임 오류를 발생시킵니다
@DependencyGraph([
    ServiceA.self: [ServiceB.self],
    ServiceB.self: [ServiceC.self],
    ServiceC.self: [ServiceA.self]  // ❌ 순환 의존성!
])
class InvalidDependencyGraph {
    // 컴파일 오류: ServiceA와 관련된 순환 의존성 감지됨
}
```

### 모듈 기반 그래프 검증

```swift
// 특정 모듈 내의 의존성 검증
@DependencyGraph([
    UserModule.UserService.self: [UserModule.UserRepository.self],
    UserModule.UserRepository.self: [CoreModule.DatabaseService.self],
    UserModule.UserViewModel.self: [UserModule.UserService.self]
])
class UserModuleDependencyGraph {
    // 사용자 모듈 의존성만 검증
}
```

## 고급 매크로 사용법

### 매크로 결합

```swift
@AutoRegister
class CompleteUserService: UserServiceProtocol {
    private let repository: UserRepositoryProtocol
    private let logger: LoggerProtocol

    init() {
        self.repository = UnifiedDI.requireResolve(UserRepositoryProtocol.self)
        self.logger = UnifiedDI.requireResolve(LoggerProtocol.self)
    }
}

@DependencyGraph([
    CompleteUserService.self: [UserRepositoryProtocol.self, LoggerProtocol.self],
    UserRepositoryProtocol.self: [DatabaseServiceProtocol.self],
    LoggerProtocol.self: []
])
class UserServiceDependencyGraph {
    // 자동 등록과 그래프 검증 모두
}
```

### 커스텀 매크로 구성

```swift
// 커스텀 옵션으로 자동 등록 구성
@AutoRegister(
    lifetime: .singleton,
    interfaces: [UserServiceProtocol.self, CacheableService.self],
    priority: .high
)
class AdvancedUserService: UserServiceProtocol, CacheableService {
    // 고급 구성 옵션
}
```

### 매크로 생성 코드 검사

```swift
// @AutoRegister 매크로는 다음과 유사한 코드를 생성합니다:
private static let __autoRegister_UserServiceProtocol_UserService = {
    return UnifiedDI.register(UserServiceProtocol.self) { UserService() }
}()

// @DependencyGraph 매크로는 검증 코드를 생성합니다:
private func validateDependencyGraph() -> Void {
    // 컴파일 타임 검증된 의존성 그래프
    // 의존성: ["UserService": ["UserRepository", "Logger"]]
    // ✅ 순환 의존성 감지되지 않음
}
```

## 성능 이점

### 컴파일 타임 최적화

```swift
// 전통적인 수동 등록
class ManualRegistration {
    func setupDependencies() {
        UnifiedDI.register(UserService.self) { UserService() }
        UnifiedDI.register(OrderService.self) { OrderService() }
        UnifiedDI.register(PaymentService.self) { PaymentService() }
        // ... 50개 이상의 등록
    }
}

// 매크로 기반 등록
@AutoRegister class UserService: UserServiceProtocol { }
@AutoRegister class OrderService: OrderServiceProtocol { }
@AutoRegister class PaymentService: PaymentServiceProtocol { }
// 런타임 오버헤드 제로로 자동 등록
```

### 타입 안전성 검증

```swift
// 컴파일 타임 타입 안전성
@AutoRegister
class TypeSafeService: ServiceProtocol {
    // ✅ 컴파일러가 ServiceProtocol 준수를 검증
    // ✅ 올바른 타입에 대한 자동 등록
    // ✅ 런타임 타입 캐스팅 불필요
}
```

### 보일러플레이트 감소

```swift
// 이전: 수동 등록 (서비스당 10개 이상의 라인)
class ManualUserService: UserServiceProtocol {
    // 구현
}

extension WeaveDI.Container {
    func registerUserService() {
        register(UserServiceProtocol.self) {
            ManualUserService()
        }
        register(UserService.self) {
            ManualUserService()
        }
    }
}

// 이후: 매크로 등록 (1줄)
@AutoRegister
class AutoUserService: UserServiceProtocol {
    // 구현
}
// 모든 등록 코드가 자동으로 생성됨
```

## 오류 처리 및 디버깅

### 컴파일 타임 오류 메시지

```swift
@AutoRegister
struct InvalidService {
    // ❌ 컴파일 오류: @AutoRegister는 클래스나 구조체에만 적용 가능
}

@DependencyGraph([
    InvalidType: [SomeService.self]  // ❌ InvalidType은 유효한 타입이 아님
])
class InvalidGraph { }
```

### 매크로 확장 디버깅

```swift
// Swift의 매크로 확장을 사용하여 생성된 코드 디버그
// 빌드 설정에 -Xfrontend -dump-macro-expansions 추가
@AutoRegister
class DebugService: ServiceProtocol {
    // 컴파일 중에 확장된 매크로 코드 보기
}
```

### 런타임 검증

```swift
@AutoRegister
class VerifiableService: ServiceProtocol {
    init() {
        // 매크로 생성 등록의 런타임 검증
        assert(UnifiedDI.isRegistered(ServiceProtocol.self),
               "ServiceProtocol이 자동 등록되어야 함")
    }
}
```

## 다른 WeaveDI 기능과의 통합

### Property Wrapper 통합

```swift
@AutoRegister
class ServiceUsingPropertyWrappers: ServiceProtocol {
    @Inject var logger: LoggerProtocol?
    @Factory var httpClient: HTTPClient
    @SafeInject var database: DatabaseProtocol?

    func performOperation() async throws {
        logger?.info("작업 시작")

        guard let db = database else {
            throw ServiceError.databaseUnavailable
        }

        let client = httpClient
        // 의존성 사용
    }
}
```

### 모듈 팩토리 통합

```swift
@AutoRegister
class AutoRegisteredRepository: RepositoryProtocol {
    // ModuleFactory 시스템과 자동으로 통합됨
}

extension RepositoryModuleFactory {
    mutating func setupAutoRegisteredDependencies() {
        // 자동 등록된 서비스가 자동으로 사용 가능
        let repo = UnifiedDI.resolve(RepositoryProtocol.self)
        assert(repo != nil, "자동 등록된 repository가 사용 가능해야 함")
    }
}
```

### Bootstrap 통합

```swift
class MacroEnabledBootstrap {
    static func configure() async {
        await DIContainer.bootstrap { container in
            // 자동 등록된 서비스가 자동으로 사용 가능
            // @AutoRegister 클래스에 대한 수동 등록 불필요

            // 자동 등록 검증
            let services = UnifiedDI.getAllRegisteredTypes()
            print("자동 등록된 서비스: \(services)")
        }
    }
}
```

## 모범 사례

### 1. 간단한 서비스에 @AutoRegister 사용

```swift
// ✅ 좋음: 명확한 프로토콜 준수가 있는 간단한 서비스
@AutoRegister
class NotificationService: NotificationServiceProtocol {
    func send(_ notification: Notification) async {
        // 구현
    }
}

// ❌ 피하기: 많은 의존성이 있는 복잡한 서비스
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
    // 의존성 관계에 대한 단일 진실의 원천
}

struct ApplicationDependencies {
    static let graph: [ObjectIdentifier: [ObjectIdentifier]] = [
        // 완전한 애플리케이션 의존성 매핑
    ]
}
```

### 3. 모듈별로 매크로 구성

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
        print("Mock 추적: \(event)")
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
// 수동 등록 여전히 동작

// 3단계: 기존 서비스 마이그레이션
@AutoRegister
class MigratedOrderService: OrderServiceProtocol { }
```

## 관련 문서

- [Property Wrapper](/ko/guide/propertyWrappers) - 사용 지점에서의 의존성 주입
- [모듈 시스템](/ko/guide/moduleSystem) - 대규모 애플리케이션 구성
- [Bootstrap 가이드](/ko/guide/bootstrap) - 애플리케이션 초기화 패턴
- [자동 DI 최적화](/ko/guide/autoDiOptimizer) - 자동 성능 최적화
