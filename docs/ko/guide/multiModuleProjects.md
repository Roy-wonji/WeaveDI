# 멀티 모듈 프로젝트

SPM(Swift Package Manager)을 사용한 멀티 모듈 Swift 프로젝트에서 WeaveDI를 사용하는 방법을 학습합니다.

## 개요

멀티 모듈 아키텍처는 다음을 제공합니다:
- **관심사의 더 나은 분리**
- **더 빠른 컴파일** (변경된 모듈만 다시 빌드)
- **향상된 코드 재사용성**
- **명확한 의존성 경계**

WeaveDI는 타입 안전성과 성능을 유지하면서 모듈 경계를 넘나들며 원활하게 작동하도록 설계되었습니다.

## 프로젝트 구조

### 일반적인 멀티 모듈 설정

```
MyApp/
├── Package.swift
├── App/                    # 메인 애플리케이션 타겟
│   └── Sources/
│       └── MyApp.swift
├── Features/
│   ├── UserFeature/       # 기능 모듈
│   │   └── Sources/
│   ├── OrderFeature/      # 기능 모듈
│   │   └── Sources/
│   └── PaymentFeature/    # 기능 모듈
│       └── Sources/
├── Core/
│   ├── Networking/        # 인프라 모듈
│   │   └── Sources/
│   ├── Database/          # 인프라 모듈
│   │   └── Sources/
│   └── SharedModels/      # 공유 타입
│       └── Sources/
└── DI/                    # 의존성 주입 모듈
    └── Sources/
```

## Package.swift 구성

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [
        .iOS(.v15),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MyApp", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.2.0")
    ],
    targets: [
        // 앱 타겟
        .executableTarget(
            name: "App",
            dependencies: [
                "UserFeature",
                "OrderFeature",
                "PaymentFeature",
                "DI"
            ]
        ),

        // 기능 모듈
        .target(
            name: "UserFeature",
            dependencies: [
                "Networking",
                "SharedModels",
                .product(name: "WeaveDI", package: "WeaveDI")
            ]
        ),
        .target(
            name: "OrderFeature",
            dependencies: [
                "Networking",
                "SharedModels",
                .product(name: "WeaveDI", package: "WeaveDI")
            ]
        ),
        .target(
            name: "PaymentFeature",
            dependencies: [
                "Networking",
                "SharedModels",
                .product(name: "WeaveDI", package: "WeaveDI")
            ]
        ),

        // 코어 모듈
        .target(
            name: "Networking",
            dependencies: [
                .product(name: "WeaveDI", package: "WeaveDI")
            ]
        ),
        .target(
            name: "Database",
            dependencies: [
                .product(name: "WeaveDI", package: "WeaveDI")
            ]
        ),
        .target(
            name: "SharedModels",
            dependencies: []
        ),

        // DI 모듈
        .target(
            name: "DI",
            dependencies: [
                "UserFeature",
                "OrderFeature",
                "PaymentFeature",
                "Networking",
                "Database",
                .product(name: "WeaveDI", package: "WeaveDI")
            ]
        ),

        // 테스트
        .testTarget(
            name: "UserFeatureTests",
            dependencies: ["UserFeature"]
        )
    ]
)
```

## 의존성 관리 패턴

### 패턴 1: 중앙 집중식 DI 모듈

**최적:** 소규모에서 중간 규모 프로젝트

모든 기능 모듈을 알고 있고 의존성을 구성하는 전용 `DI` 모듈을 생성합니다.

```swift
// DI/Sources/DI.swift
import WeaveDI
import UserFeature
import OrderFeature
import PaymentFeature
import Networking
import Database

public final class AppDI {
    public static func bootstrap() async {
        await WeaveDI.Container.bootstrap { container in
            // 인프라스트럭처
            container.register(APIClient.self) {
                URLSessionAPIClient(baseURL: Configuration.apiBaseURL)
            }

            container.register(Database.self) {
                RealmDatabase()
            }

            // 기능 의존성
            UserFeatureModule.register(in: container)
            OrderFeatureModule.register(in: container)
            PaymentFeatureModule.register(in: container)
        }
    }
}
```

```swift
// UserFeature/Sources/UserFeatureModule.swift
import WeaveDI

public struct UserFeatureModule {
    public static func register(in container: WeaveDI.Container) {
        container.register(UserService.self) {
            UserServiceImpl()
        }

        container.register(UserRepository.self) {
            UserRepositoryImpl()
        }
    }
}
```

### 패턴 2: 분산형 모듈 등록

**최적:** 독립적인 팀이 있는 대규모 프로젝트

각 기능 모듈이 자체 등록 방법을 노출합니다.

```swift
// UserFeature/Sources/UserFeatureDI.swift
import WeaveDI

public protocol UserFeatureDependencies {
    var apiClient: APIClient { get }
    var database: Database { get }
}

public struct UserFeatureModule {
    public static func bootstrap(
        dependencies: UserFeatureDependencies
    ) async {
        // 기능별 의존성 등록
        await WeaveDI.Container.bootstrap { container in
            // 제공된 의존성 사용
            container.register(APIClient.self) {
                dependencies.apiClient
            }

            // 기능 서비스 등록
            container.register(UserService.self) {
                UserServiceImpl()
            }
        }
    }
}
```

```swift
// App/Sources/AppDI.swift
import UserFeature
import OrderFeature

struct AppDependencies: UserFeatureDependencies, OrderFeatureDependencies {
    let apiClient: APIClient
    let database: Database

    init() {
        self.apiClient = URLSessionAPIClient(baseURL: Config.apiURL)
        self.database = RealmDatabase()
    }
}

@main
struct MyApp: App {
    init() {
        let deps = AppDependencies()

        Task {
            await UserFeatureModule.bootstrap(dependencies: deps)
            await OrderFeatureModule.bootstrap(dependencies: deps)
        }
    }
}
```

### 패턴 3: 프로토콜 기반 모듈 경계

**최적:** 최대 유연성과 테스트 가능성

모듈 경계에서 프로토콜 인터페이스를 정의합니다.

```swift
// UserFeature/Sources/UserFeatureInterface.swift
public protocol UserServiceProtocol {
    func fetchUser(id: String) async throws -> User
}

public protocol UserFeatureInterface {
    var userService: UserServiceProtocol { get }
}
```

```swift
// UserFeature/Sources/UserFeatureImplementation.swift
import WeaveDI

public struct UserFeatureImpl: UserFeatureInterface {
    @Injected(\.userService) public var userService

    public init() {}
}

// 구현 등록
extension InjectedValues {
    public var userFeature: UserFeatureInterface {
        get { self[UserFeatureKey.self] }
        set { self[UserFeatureKey.self] = newValue }
    }
}

struct UserFeatureKey: InjectedKey {
    static var liveValue: UserFeatureInterface = UserFeatureImpl()
    static var testValue: UserFeatureInterface = MockUserFeature()
}
```

## 모듈 간 의존성 주입

### 모듈 간 의존성 공유

```swift
// Networking/Sources/APIClient.swift
import WeaveDI

public protocol APIClient {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}

public struct NetworkingModule {
    public static func register() async {
        await WeaveDI.Container.bootstrap { container in
            container.register(APIClient.self) {
                URLSessionAPIClient(session: .shared)
            }
        }
    }
}

// APIClient를 주입 가능하게 만들기
extension InjectedValues {
    public var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

public struct APIClientKey: InjectedKey {
    public static var liveValue: APIClient = URLSessionAPIClient(session: .shared)
    public static var testValue: APIClient = MockAPIClient()
}
```

```swift
// UserFeature/Sources/UserService.swift
import WeaveDI
import Networking

public final class UserService {
    @Injected(\.apiClient) var apiClient

    public func fetchUser(id: String) async throws -> User {
        try await apiClient.request(.user(id: id))
    }
}
```

## 기능 모듈 패턴

### 자체 완결형 기능 모듈

```swift
// UserFeature/Sources/UserFeature.swift
import SwiftUI
import WeaveDI

public struct UserFeature {
    public init() {}

    // 공개 API
    public func makeUserProfileView() -> some View {
        UserProfileView()
    }

    public func makeUserListView() -> some View {
        UserListView()
    }
}

// 내부 의존성
extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }

    var userRepository: UserRepository {
        get { self[UserRepositoryKey.self] }
        set { self[UserRepositoryKey.self] = newValue }
    }
}

struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()
}

struct UserRepositoryKey: InjectedKey {
    static var liveValue: UserRepository = UserRepositoryImpl()
    static var testValue: UserRepository = MockUserRepository()
}
```

### 기능 코디네이터 패턴

```swift
// UserFeature/Sources/UserCoordinator.swift
import WeaveDI

public protocol UserCoordinator {
    func showUserProfile(userId: String)
    func showUserList()
}

public final class UserCoordinatorImpl: UserCoordinator {
    @Injected(\.navigationService) var navigation

    public init() {}

    public func showUserProfile(userId: String) {
        let view = UserProfileView(userId: userId)
        navigation.push(view)
    }

    public func showUserList() {
        let view = UserListView()
        navigation.push(view)
    }
}

// 코디네이터 등록
extension InjectedValues {
    public var userCoordinator: UserCoordinator {
        get { self[UserCoordinatorKey.self] }
        set { self[UserCoordinatorKey.self] = newValue }
    }
}

struct UserCoordinatorKey: InjectedKey {
    static var liveValue: UserCoordinator = UserCoordinatorImpl()
    static var testValue: UserCoordinator = MockUserCoordinator()
}
```

## 모듈 간 통신

### 이벤트 기반 통신

```swift
// Core/Sources/EventBus.swift
import WeaveDI

public protocol Event {}

public protocol EventBus {
    func publish(_ event: Event)
    func subscribe<T: Event>(_ type: T.Type, handler: @escaping (T) -> Void)
}

public final class EventBusImpl: EventBus {
    private var handlers: [String: [(Event) -> Void]] = [:]

    public init() {}

    public func publish(_ event: Event) {
        let key = String(describing: type(of: event))
        handlers[key]?.forEach { $0(event) }
    }

    public func subscribe<T: Event>(_ type: T.Type, handler: @escaping (T) -> Void) {
        let key = String(describing: type)
        let wrapper: (Event) -> Void = { event in
            if let typedEvent = event as? T {
                handler(typedEvent)
            }
        }
        handlers[key, default: []].append(wrapper)
    }
}

// EventBus 등록
extension InjectedValues {
    public var eventBus: EventBus {
        get { self[EventBusKey.self] }
        set { self[EventBusKey.self] = newValue }
    }
}

struct EventBusKey: InjectedKey {
    static var liveValue: EventBus = EventBusImpl()
    static var testValue: EventBus = MockEventBus()
}
```

```swift
// UserFeature가 이벤트 게시
public struct UserLoggedInEvent: Event {
    public let userId: String
}

public final class UserService {
    @Injected(\.eventBus) var eventBus

    public func login(credentials: Credentials) async throws {
        // 로그인 로직...
        eventBus.publish(UserLoggedInEvent(userId: user.id))
    }
}
```

```swift
// OrderFeature가 이벤트 구독
public final class OrderService {
    @Injected(\.eventBus) var eventBus

    public init() {
        eventBus.subscribe(UserLoggedInEvent.self) { [weak self] event in
            self?.handleUserLogin(userId: event.userId)
        }
    }

    private func handleUserLogin(userId: String) {
        // 사용자의 주문 로드
    }
}
```

## 멀티 모듈 의존성 테스트

### 모듈 수준 테스트

```swift
// UserFeatureTests/UserServiceTests.swift
import XCTest
@testable import UserFeature
import WeaveDI

final class UserServiceTests: XCTestCase {
    override func setUp() async throws {
        // 각 테스트마다 DI 리셋
        await WeaveDI.Container.reset()
    }

    func testFetchUser() async throws {
        await withInjectedValues { values in
            values.apiClient = MockAPIClient(
                responses: [.user(id: "123"): User.testUser]
            )
        } operation: {
            let service = UserService()
            let user = try await service.fetchUser(id: "123")

            XCTAssertEqual(user.id, "123")
            XCTAssertEqual(user.name, "Test User")
        }
    }
}
```

### 모듈 간 통합 테스트

```swift
// IntegrationTests/UserOrderIntegrationTests.swift
import XCTest
@testable import UserFeature
@testable import OrderFeature
import WeaveDI

final class UserOrderIntegrationTests: XCTestCase {
    func testUserLoginTriggersOrderLoad() async throws {
        var orderLoadCalled = false

        await withInjectedValues { values in
            values.apiClient = MockAPIClient()
            values.eventBus = MockEventBus { event in
                if event is UserLoggedInEvent {
                    orderLoadCalled = true
                }
            }
        } operation: {
            let userService = UserService()
            let orderService = OrderService()

            try await userService.login(credentials: .test)

            XCTAssertTrue(orderLoadCalled)
        }
    }
}
```

## 모범 사례

### ✅ 할 것들

```swift
// ✅ 명확한 모듈 경계 정의
public protocol UserFeatureInterface {
    var userService: UserServiceProtocol { get }
}

// ✅ 모듈 간 의존성에 프로토콜 사용
public protocol APIClient {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}

// ✅ 모듈 의존성을 최소화
// UserFeature는 Networking과 SharedModels에만 의존

// ✅ 모듈 수준에서 의존성 등록
public struct UserFeatureModule {
    public static func register(in container: WeaveDI.Container) {
        // 모든 기능 의존성 등록
    }
}

// ✅ 느슨한 결합을 위한 이벤트 버스 사용
eventBus.publish(UserLoggedInEvent(userId: user.id))
```

### ❌ 하지 말 것들

```swift
// ❌ 순환 모듈 의존성 생성 금지
// UserFeature → OrderFeature → UserFeature (나쁨!)

// ❌ 내부 구현 세부사항 노출 금지
public class UserServiceImpl { }  // internal이어야 함

// ❌ 여러 곳에서 의존성 등록 금지
// 모듈당 하나의 중앙 위치에서 등록

// ❌ 모듈 간 구체 타입 사용 금지
func process(service: UserServiceImpl)  // 대신 프로토콜 사용

// ❌ 모듈 경계 우회 금지
import UserFeature
let service = UserServiceImpl()  // 대신 DI 사용
```

## 마이그레이션 전략

### 모놀리스에서 멀티 모듈로

**1단계: 모듈 식별**
```
현재: 폴더가 있는 단일 타겟
목표: 별도의 SPM 패키지

App/
├── User/       → UserFeature 모듈
├── Order/      → OrderFeature 모듈
├── Payment/    → PaymentFeature 모듈
├── Network/    → Networking 모듈
└── Database/   → Database 모듈
```

**2단계: 핵심 인프라 추출**
```swift
// 먼저 Networking 모듈 생성
// 모든 네트워킹 코드를 Networking 모듈로 이동
// import 업데이트: import Networking
```

**3단계: 기능 모듈 추출**
```swift
// UserFeature 모듈 생성
// 사용자 관련 코드 이동
// 공개 인터페이스 정의
// 의존성 등록
```

**4단계: DI 연결**
```swift
// DI 모듈 생성
// 모든 모듈 의존성 구성
// App 타겟에서 부트스트랩
```

## 성능 고려 사항

### 지연 모듈 로딩

```swift
// 기능 모듈을 지연 로드
public final class FeatureLoader {
    private var loadedFeatures: Set<String> = []

    public func load(_ feature: Feature) async {
        guard !loadedFeatures.contains(feature.name) else { return }

        switch feature {
        case .user:
            await UserFeatureModule.bootstrap()
        case .order:
            await OrderFeatureModule.bootstrap()
        case .payment:
            await PaymentFeatureModule.bootstrap()
        }

        loadedFeatures.insert(feature.name)
    }
}
```

### 모듈 사전 로딩

```swift
// 앱 시작 시 중요한 모듈 사전 로드
@main
struct MyApp: App {
    init() {
        Task {
            // 핵심 모듈 사전 로드
            await NetworkingModule.bootstrap()
            await DatabaseModule.bootstrap()

            // 기능 모듈 지연 로드
            await FeatureLoader.shared.load(.user)
        }
    }
}
```

## 다음 단계

- [TCA 통합](./tcaIntegration) - The Composable Architecture와 WeaveDI 사용하기
- [모듈 시스템](./moduleSystem) - WeaveDI의 모듈 시스템 이해하기
- [모범 사례](./bestPractices) - 일반적인 DI 모범 사례
- [테스트 가이드](../tutorial/testing) - 멀티 모듈 애플리케이션 테스트하기