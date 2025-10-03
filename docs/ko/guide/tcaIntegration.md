# TCA 통합 가이드

WeaveDI를 The Composable Architecture (TCA)와 통합하는 완벽한 가이드입니다. 이 가이드는 의존성 주입 패턴, 상태 관리, 그리고 확장 가능한 TCA 앱을 구축하기 위한 고급 기법을 다룹니다.

## 개요

The Composable Architecture (TCA)는 일관되고 이해하기 쉬운 방식으로 애플리케이션을 구축하기 위한 라이브러리로, 컴포지션, 테스팅, 인체공학을 염두에 두고 설계되었습니다. WeaveDI는 TCA의 아키텍처와 완벽하게 작동하는 강력한 의존성 주입 기능을 제공합니다.

### 왜 WeaveDI + TCA인가?

| 측면 | TCA만 사용 | WeaveDI + TCA | 장점 |
|-----|----------|---------------|------|
| **의존성 관리** | init에서 수동 주입 | @Injected로 자동 주입 | 🎯 더 깔끔한 코드, 보일러플레이트 감소 |
| **테스팅** | 서비스 수동 모킹 | 자동 모킹 주입 | 🧪 더 쉬운 단위 테스팅 |
| **모듈화** | 강한 결합 | 프로토콜을 통한 느슨한 결합 | 🔗 더 나은 관심사 분리 |
| **Swift Concurrency** | 기본 지원 | 완전한 async/await + actor 최적화 | ⚡ 향상된 성능 |
| **환경 관리** | 제한된 범위 | 다중 범위 의존성 관리 | 🌍 유연한 환경 처리 |

## Swift 버전 호환성

### Swift 6.0+ (권장)
- 완전한 strict concurrency 지원
- 리듀서의 actor 격리
- Sendable 준수 검증
- 향상된 성능 최적화

### Swift 5.9+
- 완전한 async/await 지원
- 프로퍼티 래퍼 통합
- 성능 모니터링

### Swift 5.8+
- 핵심 의존성 주입
- 기본 TCA 통합
- 제한적인 동시성 기능

## 설치

### Package.swift 구성

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.5.0"),
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.1.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            "WeaveDI"
        ]
    )
]
```

### Xcode 통합

1. File → Add Package Dependencies를 통해 두 패키지 모두 추가
2. Swift 파일에서 두 프레임워크 모두 import:

```swift
import ComposableArchitecture
import WeaveDI
```

## Component 빠른 시작

```swift
import WeaveDI

@Component
struct UserComponent {
    @Provide var repository: UserRepository = UserRepositoryImpl()
    @Provide(scope: .singleton) var service: UserService = UserServiceImpl(repository: repository)
}

// 공유 컨테이너에 등록
UserComponent.registerAll()
```

`@Component` 매크로는 구조체 내부의 `@Provide` 속성을 분석해 의존성 순서를 정렬하고 `DIContainer` 등록 코드를 컴파일 타임에 생성합니다.

## 기본 통합 패턴

### 1. 서비스 레이어 설정

먼저 서비스를 정의하고 WeaveDI에 등록합니다:

```swift
// MARK: - 서비스 프로토콜
protocol UserService {
    func fetchUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws -> User
}

protocol AnalyticsService {
    func track(event: String, parameters: [String: Any])
    func setUserId(_ userId: String)
}

protocol NetworkService {
    func request<T: Codable>(_ endpoint: Endpoint) async throws -> T
}

// MARK: - 서비스 구현
class UserServiceImpl: UserService {
    @Injected private var networkService: NetworkService?
    @Injected private var analytics: AnalyticsService?

    func fetchUser(id: String) async throws -> User {
        analytics?.track(event: "user_fetch_started", parameters: ["user_id": id])

        guard let network = networkService else {
            throw ServiceError.networkServiceUnavailable
        }

        let user: User = try await network.request(.user(id: id))
        analytics?.track(event: "user_fetch_completed", parameters: ["user_id": id])

        return user
    }

    func updateUser(_ user: User) async throws -> User {
        analytics?.track(event: "user_update_started", parameters: ["user_id": user.id])

        guard let network = networkService else {
            throw ServiceError.networkServiceUnavailable
        }

        let updatedUser: User = try await network.request(.updateUser(user))
        analytics?.track(event: "user_update_completed", parameters: ["user_id": user.id])

        return updatedUser
    }
}

// MARK: - 의존성 등록
extension WeaveDI {
    static func registerTCADependencies() async {
        await WeaveDI.Container.bootstrap { container in
            // 핵심 서비스
            container.register(NetworkService.self) {
                URLSessionNetworkService()
            }

            container.register(AnalyticsService.self) {
                FirebaseAnalyticsService()
            }

            // 비즈니스 서비스
            container.register(UserService.self) {
                UserServiceImpl()
            }
        }
    }
}
```

### 2. 의존성 주입을 사용하는 리듀서

#### Swift 6 패턴 (권장)

```swift
import ComposableArchitecture
import WeaveDI

@Reducer
struct UserFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var user: User?
        var isLoading = false
        var errorMessage: String?
    }

    enum Action: Sendable {
        case loadUser(String)
        case userLoaded(User)
        case userLoadFailed(String)
        case updateUser(User)
        case userUpdated(User)
    }

    // WeaveDI를 사용한 의존성 주입
    @Injected private var userService: UserService?
    @Injected private var analytics: AnalyticsService?

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadUser(let userId):
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    do {
                        guard let service = userService else {
                            throw ServiceError.userServiceUnavailable
                        }

                        let user = try await service.fetchUser(id: userId)
                        await send(.userLoaded(user))
                    } catch {
                        await send(.userLoadFailed(error.localizedDescription))
                    }
                }

            case .userLoaded(let user):
                state.isLoading = false
                state.user = user
                analytics?.track(event: "user_loaded_in_view", parameters: ["user_id": user.id])
                return .none

            case .userLoadFailed(let message):
                state.isLoading = false
                state.errorMessage = message
                analytics?.track(event: "user_load_failed", parameters: ["error": message])
                return .none

            case .updateUser(let user):
                return .run { send in
                    do {
                        guard let service = userService else {
                            throw ServiceError.userServiceUnavailable
                        }

                        let updatedUser = try await service.updateUser(user)
                        await send(.userUpdated(updatedUser))
                    } catch {
                        await send(.userLoadFailed(error.localizedDescription))
                    }
                }

            case .userUpdated(let user):
                state.user = user
                analytics?.track(event: "user_updated", parameters: ["user_id": user.id])
                return .none
            }
        }
    }
}
```

#### Swift 5.9 패턴 (호환)

```swift
import ComposableArchitecture
import WeaveDI

struct UserFeature: Reducer {
    struct State: Equatable {
        var user: User?
        var isLoading = false
        var errorMessage: String?
    }

    enum Action: Equatable {
        case loadUser(String)
        case userLoaded(User)
        case userLoadFailed(String)
        case updateUser(User)
        case userUpdated(User)
    }

    // WeaveDI를 사용한 의존성 주입
    @Injected private var userService: UserService?
    @Injected private var analytics: AnalyticsService?

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .loadUser(let userId):
            state.isLoading = true
            state.errorMessage = nil

            return .run { send in
                do {
                    guard let service = userService else {
                        throw ServiceError.userServiceUnavailable
                    }

                    let user = try await service.fetchUser(id: userId)
                    await send(.userLoaded(user))
                } catch {
                    await send(.userLoadFailed(error.localizedDescription))
                }
            }

        case .userLoaded(let user):
            state.isLoading = false
            state.user = user
            analytics?.track(event: "user_loaded_in_view", parameters: ["user_id": user.id])
            return .none

        case .userLoadFailed(let message):
            state.isLoading = false
            state.errorMessage = message
            analytics?.track(event: "user_load_failed", parameters: ["error": message])
            return .none

        case .updateUser(let user):
            return .run { send in
                do {
                    guard let service = userService else {
                        throw ServiceError.userServiceUnavailable
                    }

                    let updatedUser = try await service.updateUser(user)
                    await send(.userUpdated(updatedUser))
                } catch {
                    await send(.userLoadFailed(error.localizedDescription))
                }
            }

        case .userUpdated(let user):
            state.user = user
            analytics?.track(event: "user_updated", parameters: ["user_id": user.id])
            return .none
        }
    }
}
```

### 3. SwiftUI 뷰 통합

```swift
import SwiftUI
import ComposableArchitecture
import WeaveDI

struct UserProfileView: View {
    let store: StoreOf<UserFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationView {
                VStack(spacing: 20) {
                    if viewStore.isLoading {
                        ProgressView("사용자 로딩 중...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let user = viewStore.user {
                        UserDetailView(user: user) { updatedUser in
                            viewStore.send(.updateUser(updatedUser))
                        }
                    } else if let error = viewStore.errorMessage {
                        ErrorView(message: error) {
                            // 재시도 로직이 여기에 들어갑니다
                        }
                    } else {
                        EmptyView()
                    }
                }
                .navigationTitle("사용자 프로필")
                .onAppear {
                    // 뷰가 나타날 때 사용자 로드
                    viewStore.send(.loadUser("current-user-id"))
                }
            }
        }
    }
}

struct UserDetailView: View {
    let user: User
    let onUpdate: (User) -> Void

    var body: some View {
        Form {
            Section("사용자 정보") {
                HStack {
                    AsyncImage(url: user.avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())

                    VStack(alignment: .leading) {
                        Text(user.name)
                            .font(.headline)
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }

            Section("작업") {
                Button("프로필 수정") {
                    // 프로필 수정 작업
                    var updatedUser = user
                    updatedUser.name = "업데이트된 이름"
                    onUpdate(updatedUser)
                }
            }
        }
    }
}
```

## 고급 패턴

### 1. 멀티 모듈 아키텍처

대형 애플리케이션의 경우 기능을 모듈로 조직화합니다:

```swift
// MARK: - 피처 모듈 프로토콜
protocol FeatureModule {
    static func registerDependencies() async
}

// MARK: - 사용자 피처 모듈
struct UserFeatureModule: FeatureModule {
    static func registerDependencies() async {
        await WeaveDI.Container.bootstrap { container in
            // 사용자 전용 서비스
            container.register(UserRepository.self) {
                CoreDataUserRepository()
            }

            container.register(UserService.self) {
                UserServiceImpl()
            }
        }
    }
}

// MARK: - 주문 피처 모듈
struct OrderFeatureModule: FeatureModule {
    static func registerDependencies() async {
        await WeaveDI.Container.bootstrap { container in
            container.register(OrderRepository.self) {
                APIOrderRepository()
            }

            container.register(OrderService.self) {
                OrderServiceImpl()
            }

            container.register(PaymentService.self) {
                StripePaymentService()
            }
        }
    }
}

// MARK: - 앱 모듈 등록
extension App {
    static func registerAllFeatures() async {
        await UserFeatureModule.registerDependencies()
        await OrderFeatureModule.registerDependencies()
        // 다른 피처 모듈들 추가...
    }
}
```

### 2. 환경 기반 의존성 구성

```swift
import ComposableArchitecture
import WeaveDI

// MARK: - 환경 구성
enum AppEnvironment {
    case development
    case staging
    case production

    var apiBaseURL: String {
        switch self {
        case .development: return "https://dev-api.example.com"
        case .staging: return "https://staging-api.example.com"
        case .production: return "https://api.example.com"
        }
    }
}

// MARK: - 환경별 등록
extension WeaveDI {
    static func registerForEnvironment(_ environment: AppEnvironment) async {
        await WeaveDI.Container.bootstrap { container in
            switch environment {
            case .development:
                // 개발 서비스
                container.register(NetworkService.self) {
                    MockNetworkService() // 개발에서는 모킹 사용
                }
                container.register(AnalyticsService.self) {
                    ConsoleAnalyticsService() // 콘솔에만 로그
                }

            case .staging:
                // 스테이징 서비스
                container.register(NetworkService.self) {
                    URLSessionNetworkService(baseURL: environment.apiBaseURL)
                }
                container.register(AnalyticsService.self) {
                    TestAnalyticsService() // 테스트 애널리틱스
                }

            case .production:
                // 프로덕션 서비스
                container.register(NetworkService.self) {
                    URLSessionNetworkService(baseURL: environment.apiBaseURL)
                }
                container.register(AnalyticsService.self) {
                    FirebaseAnalyticsService() // 완전한 애널리틱스
                }
            }

            // 모든 환경에 공통인 서비스
            container.register(UserService.self) {
                UserServiceImpl()
            }
        }
    }
}
```

### 3. WeaveDI + TCA를 사용한 테스팅

#### 테스트용 모킹 서비스

```swift
import XCTest
import ComposableArchitecture
import WeaveDI
@testable import YourApp

// MARK: - 모킹 서비스
class MockUserService: UserService {
    var mockUsers: [String: User] = [:]
    var shouldThrowError = false
    var errorToThrow: Error = ServiceError.unknown

    func fetchUser(id: String) async throws -> User {
        if shouldThrowError {
            throw errorToThrow
        }

        return mockUsers[id] ?? User.mockUser(id: id)
    }

    func updateUser(_ user: User) async throws -> User {
        if shouldThrowError {
            throw errorToThrow
        }

        mockUsers[user.id] = user
        return user
    }
}

class MockAnalyticsService: AnalyticsService {
    var trackedEvents: [(event: String, parameters: [String: Any])] = []
    var currentUserId: String?

    func track(event: String, parameters: [String: Any]) {
        trackedEvents.append((event: event, parameters: parameters))
    }

    func setUserId(_ userId: String) {
        currentUserId = userId
    }
}

// MARK: - 테스트 케이스
class UserFeatureTests: XCTestCase {
    var mockUserService: MockUserService!
    var mockAnalytics: MockAnalyticsService!

    override func setUp() async throws {
        await super.setUp()

        // 각 테스트마다 WeaveDI 컨테이너 리셋
        WeaveDI.Container.live = WeaveDI.Container()

        // 모킹 서비스 생성 및 등록
        mockUserService = MockUserService()
        mockAnalytics = MockAnalyticsService()

        await WeaveDI.Container.bootstrap { container in
            container.register(UserService.self, instance: mockUserService)
            container.register(AnalyticsService.self, instance: mockAnalytics)
        }
    }

    @MainActor
    func testLoadUserSuccess() async {
        // Given
        let expectedUser = User(id: "test-123", name: "테스트 사용자", email: "test@example.com")
        mockUserService.mockUsers["test-123"] = expectedUser

        let store = TestStore(initialState: UserFeature.State()) {
            UserFeature()
        }

        // When
        await store.send(.loadUser("test-123")) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        // Then
        await store.receive(.userLoaded(expectedUser)) {
            $0.isLoading = false
            $0.user = expectedUser
        }

        // 애널리틱스 검증
        XCTAssertEqual(mockAnalytics.trackedEvents.count, 2) // fetch_started + loaded_in_view
        XCTAssertEqual(mockAnalytics.trackedEvents.last?.event, "user_loaded_in_view")
    }

    @MainActor
    func testLoadUserFailure() async {
        // Given
        mockUserService.shouldThrowError = true
        mockUserService.errorToThrow = ServiceError.networkError("연결 실패")

        let store = TestStore(initialState: UserFeature.State()) {
            UserFeature()
        }

        // When
        await store.send(.loadUser("test-123")) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        // Then
        await store.receive(.userLoadFailed("연결 실패")) {
            $0.isLoading = false
            $0.errorMessage = "연결 실패"
        }

        // 애널리틱스 검증
        XCTAssertEqual(mockAnalytics.trackedEvents.last?.event, "user_load_failed")
    }

    @MainActor
    func testUpdateUser() async {
        // Given
        let initialUser = User(id: "test-123", name: "테스트 사용자", email: "test@example.com")
        let updatedUser = User(id: "test-123", name: "업데이트된 사용자", email: "test@example.com")

        let store = TestStore(initialState: UserFeature.State(user: initialUser)) {
            UserFeature()
        }

        // When
        await store.send(.updateUser(updatedUser))

        // Then
        await store.receive(.userUpdated(updatedUser)) {
            $0.user = updatedUser
        }

        // 모킹 서비스에서 사용자가 실제로 업데이트되었는지 검증
        XCTAssertEqual(mockUserService.mockUsers["test-123"]?.name, "업데이트된 사용자")

        // 애널리틱스 검증
        let updateEvents = mockAnalytics.trackedEvents.filter { $0.event.contains("user_update") }
        XCTAssertEqual(updateEvents.count, 2) // started + completed
    }
}
```

### 4. 복잡한 상태 관리

복잡한 상태 요구사항을 가진 앱의 경우:

```swift
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var user: UserFeature.State = .init()
        var orders: OrderFeature.State = .init()
        var settings: SettingsFeature.State = .init()
        var isAuthenticated = false
    }

    enum Action {
        case user(UserFeature.Action)
        case orders(OrderFeature.Action)
        case settings(SettingsFeature.Action)
        case authenticate
        case logout
    }

    @Injected private var authService: AuthService?
    @Injected private var analytics: AnalyticsService?

    var body: some ReducerOf<Self> {
        Scope(state: \.user, action: \.user) {
            UserFeature()
        }

        Scope(state: \.orders, action: \.orders) {
            OrderFeature()
        }

        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }

        Reduce { state, action in
            switch action {
            case .authenticate:
                return .run { send in
                    // 인증 로직
                    guard let auth = authService else { return }

                    do {
                        let isAuthenticated = try await auth.authenticate()
                        if isAuthenticated {
                            analytics?.track(event: "user_authenticated", parameters: [:])
                        }
                    } catch {
                        analytics?.track(event: "authentication_failed", parameters: ["error": error.localizedDescription])
                    }
                }

            case .logout:
                state.isAuthenticated = false
                analytics?.track(event: "user_logged_out", parameters: [:])
                return .none

            case .user, .orders, .settings:
                return .none
            }
        }
    }
}
```

## 성능 최적화

### 1. 런타임 최적화

더 나은 성능을 위해 WeaveDI의 런타임 최적화를 활성화하세요:

```swift
// App.swift나 AppDelegate에서
@main
struct MyApp: App {
    init() {
        Task {
            // 의존성을 등록하기 전에 최적화 활성화
            UnifiedRegistry.shared.enableOptimization()

            // 모든 의존성 등록
            await WeaveDI.registerTCADependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. 지연 로딩 패턴

더 나은 성능을 위해 비용이 많이 드는 의존성에는 지연 로딩을 사용하세요:

```swift
@Reducer
struct DataProcessingFeature {
    // 지연 주입 - 처음 접근할 때만 생성됩니다
    @Factory private var dataProcessor: ExpensiveDataProcessor
    @Injected private var cache: CacheService?

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .processLargeDataSet(let data):
                return .run { send in
                    // dataProcessor는 필요할 때만 생성됩니다
                    let processor = dataProcessor
                    let result = await processor.process(data)
                    await send(.dataProcessed(result))
                }

            default:
                return .none
            }
        }
    }
}
```

## 모범 사례

### 1. 의존성 조직화

```swift
// 관련된 의존성을 그룹화
protocol UserDependencies {
    var userService: UserService { get }
    var userRepository: UserRepository { get }
    var userCache: UserCacheService { get }
}

class UserDependenciesImpl: UserDependencies {
    @Injected var userService: UserService
    @Injected var userRepository: UserRepository
    @Injected var userCache: UserCacheService
}

@Reducer
struct UserFeature {
    @Injected private var dependencies: UserDependencies?

    // 그룹화된 의존성 사용
    private var userService: UserService? {
        dependencies?.userService
    }
}
```

### 2. 에러 처리

```swift
enum ReducerError: LocalizedError {
    case dependencyNotFound(String)
    case serviceUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .dependencyNotFound(let dependency):
            return "필수 의존성 '\(dependency)'를 찾을 수 없습니다"
        case .serviceUnavailable(let service):
            return "서비스 '\(service)'를 현재 사용할 수 없습니다"
        }
    }
}

@Reducer
struct SafeUserFeature {
    @SafeInject private var userService: UserService?

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadUser(let id):
                return .run { send in
                    do {
                        let service = try userService.getValue() // nil이면 throw
                        let user = try await service.fetchUser(id: id)
                        await send(.userLoaded(user))
                    } catch {
                        await send(.userLoadFailed(error.localizedDescription))
                    }
                }
            }
        }
    }
}
```

### 3. 모듈식 테스팅

```swift
// 테스트 전용 모듈 생성
struct TestUserModule: FeatureModule {
    static func registerDependencies() async {
        await WeaveDI.Container.bootstrap { container in
            // 테스트용 모킹 서비스 등록
            container.register(UserService.self) {
                MockUserService()
            }

            container.register(NetworkService.self) {
                MockNetworkService()
            }
        }
    }
}

// 테스트에서 사용
class UserFeatureIntegrationTests: XCTestCase {
    override func setUp() async throws {
        await TestUserModule.registerDependencies()
    }
}
```

## 마이그레이션 가이드

### TCA Dependencies에서 WeaveDI로

현재 TCA의 의존성 시스템을 사용하고 있다면, 다음과 같이 마이그레이션할 수 있습니다:

#### 이전 (TCA Dependencies)

```swift
struct UserFeature: Reducer {
    @Dependency(\.userService) var userService
    @Dependency(\.analytics) var analytics

    // ... 리듀서 구현
}

extension DependencyValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}
```

#### 이후 (WeaveDI)

```swift
struct UserFeature: Reducer {
    @Injected private var userService: UserService?
    @Injected private var analytics: AnalyticsService?

    // ... 동일한 리듀서 구현
}

// 앱 시작 시 한 번만 등록
await WeaveDI.registerTCADependencies()
```

## 일반적인 문제와 해결책

### 문제 1: 서비스를 찾을 수 없음

**문제:** `@Injected`가 `nil`을 반환합니다

**해결책:** 스토어를 만들기 전에 의존성이 등록되었는지 확인하세요:

```swift
// ❌ 잘못됨 - 등록 전에 스토어 생성
let store = Store(initialState: UserFeature.State()) {
    UserFeature()
}
await WeaveDI.registerTCADependencies()

// ✅ 올바름 - 의존성을 먼저 등록
await WeaveDI.registerTCADependencies()
let store = Store(initialState: UserFeature.State()) {
    UserFeature()
}
```

### 문제 2: Swift 6 Sendable 에러

**문제:** 주입된 서비스와 관련된 Sendable 준수 오류

**해결책:** 모든 서비스가 `Sendable`을 준수하도록 하세요:

```swift
// ✅ 서비스를 Sendable로 만들기
protocol UserService: Sendable {
    func fetchUser(id: String) async throws -> User
}

class UserServiceImpl: UserService, Sendable {
    // 구현...
}
```

### 문제 3: Factory의 메모리 문제

**문제:** `@Factory`가 너무 많은 인스턴스를 생성합니다

**해결책:** 상태가 없는 서비스는 `@Injected`를 사용하고, `@Factory`는 필요할 때만 사용하세요:

```swift
// ✅ 싱글톤 서비스는 @Injected 사용
@Injected private var apiClient: APIClient?

// ✅ 상태가 있거나 임시 객체는 @Factory 사용
@Factory private var documentGenerator: DocumentGenerator
```

## 결론

WeaveDI와 TCA는 함께 매우 잘 작동하여, 유지보수 가능하고 테스트 가능하며 성능이 뛰어난 iOS 애플리케이션을 구축하기 위한 견고한 아키텍처를 제공합니다. 이 조합은 다음을 제공합니다:

- **깔끔한 아키텍처**: 비즈니스 로직과 의존성 관리 간의 명확한 분리
- **타입 안전성**: 의존성의 컴파일 타임 검증
- **쉬운 테스팅**: 자동 모킹 주입과 격리된 테스트 환경
- **성능**: 최소한의 오버헤드로 최적화된 의존성 해결
- **Swift 6 준비**: 현대적인 Swift 동시성 기능과의 완전한 호환성

이 가이드의 패턴과 모범 사례를 따르면, 강력한 의존성 주입 기능을 가진 확장 가능한 TCA 애플리케이션을 구축할 수 있습니다.

## 다음 단계

- [Property Wrapper 가이드](./propertyWrappers.md) - WeaveDI의 주입 패턴 깊이 알아보기
- [테스팅 가이드](../tutorial/testing.md) - WeaveDI를 사용한 고급 테스팅 전략
- [성능 최적화](./runtimeOptimization.md) - 프로덕션용 DI 컨테이너 최적화
- [마이그레이션 가이드](./migration-3.0.0.md) - 다른 DI 프레임워크에서 마이그레이션

## Swift-Dependencies 연동

WeaveDI는 Point-Free의 `swift-dependencies` 패키지와 완벽하게 통합되어, 두 시스템을 함께 사용하거나 점진적으로 마이그레이션할 수 있습니다.

### 설정 및 구성

`Package.swift`에 두 패키지 모두 추가:

```swift
dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.2.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "Dependencies", package: "swift-dependencies"),
            "WeaveDI"
        ]
    )
]
```

### 실제 사용 패턴

#### 1. 구체적 타입 직접 주입 (사용자 패턴)

```swift
import WeaveDI

class ExchangeFeature: Reducer {
    // 실제 사용 중인 패턴 - 구체적 타입 직접 주입
    @Injected(ExchangeUseCaseImpl.self) private var injectedExchangeUseCase
    @Injected(FavoriteCurrencyUseCaseImpl.self) private var injectedFavoriteUseCase
    @Injected(ExchangeRateCacheUseCaseImpl.self) private var injectedCacheUseCase

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadExchangeRates:
                return .run { send in
                    // 직접 타입 사용으로 타입 안전성 보장
                    guard let exchangeUseCase = injectedExchangeUseCase else { return }

                    let rates = try await exchangeUseCase.fetchRates()
                    await send(.exchangeRatesLoaded(rates))
                }
            }
        }
    }
}
```

#### 2. Protocol 기반 주입 (권장 패턴)

```swift
// 프로토콜 정의
protocol ExchangeUseCase: Sendable {
    func fetchRates() async throws -> [ExchangeRate]
}

protocol FavoriteCurrencyUseCase: Sendable {
    func getFavorites() async -> [Currency]
    func addFavorite(_ currency: Currency) async
}

// InjectedKey 정의
struct ExchangeUseCaseKey: InjectedKey {
    static let liveValue: ExchangeUseCase = ExchangeUseCaseImpl()
    static let testValue: ExchangeUseCase = MockExchangeUseCase()
}

struct FavoriteUseCaseKey: InjectedKey {
    static let liveValue: FavoriteCurrencyUseCase = FavoriteCurrencyUseCaseImpl()
    static let testValue: FavoriteCurrencyUseCase = MockFavoriteUseCase()
}

// 사용 방법
class CurrencyFeature: Reducer {
    @Injected(\.exchangeUseCase) var exchangeUseCase
    @Injected(\.favoriteUseCase) var favoriteUseCase

    // 또는 타입으로 직접 주입
    @Injected(ExchangeUseCaseKey.self) var directExchangeUseCase
}

// InjectedValues 확장
extension InjectedValues {
    var exchangeUseCase: ExchangeUseCase {
        get { self[ExchangeUseCaseKey.self] }
        set { self[ExchangeUseCaseKey.self] = newValue }
    }

    var favoriteUseCase: FavoriteCurrencyUseCase {
        get { self[FavoriteUseCaseKey.self] }
        set { self[FavoriteUseCaseKey.self] = newValue }
    }
}
```

### Swift-Dependencies와 함께 사용

#### Component 빠른 시작

```swift
import WeaveDI

@Component
struct UserComponent {
    @Provide var repository: UserRepository = UserRepositoryImpl()
    @Provide(scope: .singleton) var service: UserService = UserServiceImpl(repository: repository)
}

// 공유 컨테이너에 등록
UserComponent.registerAll()
```

`@Component` 매크로는 구조체 내부의 `@Provide` 속성을 분석해 의존성 순서를 정렬하고 `DIContainer` 등록 코드를 컴파일 타임에 생성합니다.

## 기본 통합 패턴

```swift
import Dependencies
import WeaveDI

// 1. 서비스 프로토콜 정의
protocol UserService: Sendable {
    func fetchUser(id: String) async throws -> User
}

// 2. WeaveDI 키 생성
struct UserServiceKey: InjectedKey {
    static let liveValue: UserService = UserServiceImpl()
    static let testValue: UserService = MockUserService()
}

// 3. DependencyValues 확장으로 브리지 생성
extension DependencyValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

// 4. 리듀서에서 두 시스템 모두 사용 가능
struct UserFeature: Reducer {
    // 옵션 A: swift-dependencies 사용 (새 프로젝트 권장)
    @Dependency(\.userService) var userService

    // 옵션 B: WeaveDI 직접 사용 (기존 코드와 같은 패턴)
    // @Injected(UserServiceImpl.self) private var injectedUserService

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadUser(let id):
                return .run { send in
                    let user = try await userService.fetchUser(id: id)
                    await send(.userLoaded(user))
                }
            }
        }
    }
}
```

### 실제 환전 앱 마이그레이션 예시

#### 현재 패턴에서 개선된 패턴으로

```swift
// MARK: - 현재 사용 중인 패턴
class CurrentExchangeFeature: Reducer {
    @Injected(ExchangeUseCaseImpl.self) private var injectedExchangeUseCase
    @Injected(FavoriteCurrencyUseCaseImpl.self) private var injectedFavoriteUseCase
    @Injected(ExchangeRateCacheUseCaseImpl.self) private var injectedCacheUseCase
}

// MARK: - 개선된 하이브리드 패턴
class ImprovedExchangeFeature: Reducer {
    // 기존 패턴 유지 (안전성을 위해)
    @Injected(ExchangeUseCaseImpl.self) private var exchangeUseCase
    @Injected(FavoriteCurrencyUseCaseImpl.self) private var favoriteUseCase
    @Injected(ExchangeRateCacheUseCaseImpl.self) private var cacheUseCase

    // 새로운 서비스들은 프로토콜 기반으로
    @Injected(\.analyticsService) var analytics
    @Injected(\.networkMonitor) var networkMonitor

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadExchangeRates(let baseCurrency):
                return .run { send in
                    // 기존 서비스 사용
                    guard let useCase = exchangeUseCase,
                          let cache = cacheUseCase else { return }

                    // 네트워크 상태 확인 (새 서비스)
                    guard networkMonitor?.isConnected == true else {
                        // 캐시에서 가져오기
                        let cachedRates = try await cache.getCachedRates(for: baseCurrency)
                        await send(.exchangeRatesLoaded(cachedRates))
                        return
                    }

                    // 실시간 환율 가져오기
                    let rates = try await useCase.fetchRates(baseCurrency: baseCurrency)

                    // 캐시에 저장
                    try await cache.cacheRates(rates, for: baseCurrency)

                    // 분석 이벤트 전송
                    analytics?.track(event: "exchange_rates_loaded",
                                   parameters: ["base_currency": baseCurrency.code])

                    await send(.exchangeRatesLoaded(rates))
                }
            }
        }
    }
}
```

### UseCase 등록 및 설정

```swift
// MARK: - UseCase 등록
extension WeaveDI {
    static func registerExchangeUseCases() async {
        await WeaveDI.Container.bootstrap { container in
            // 구체적 타입 등록 (현재 패턴)
            container.register(ExchangeUseCaseImpl.self) {
                ExchangeUseCaseImpl(
                    apiClient: container.resolve(APIClient.self)!,
                    database: container.resolve(Database.self)!
                )
            }

            container.register(FavoriteCurrencyUseCaseImpl.self) {
                FavoriteCurrencyUseCaseImpl(
                    userDefaults: UserDefaults.standard
                )
            }

            container.register(ExchangeRateCacheUseCaseImpl.self) {
                ExchangeRateCacheUseCaseImpl(
                    cache: container.resolve(CacheService.self)!
                )
            }

            // 프로토콜 기반 등록 (개선된 패턴)
            container.register(AnalyticsService.self) {
                FirebaseAnalyticsService()
            }

            container.register(NetworkMonitorProtocol.self) {
                SystemNetworkMonitor()
            }
        }
    }
}

// MARK: - 앱 시작 시 등록
@main
struct ExchangeApp: App {
    init() {
        Task {
            await WeaveDI.registerExchangeUseCases()
        }
    }

    var body: some Scene {
        WindowGroup {
            ExchangeRootView()
        }
    }
}
```

### 테스트에서의 활용

```swift
import XCTest
import Dependencies
import WeaveDI
@testable import ExchangeApp

class ExchangeFeatureTests: XCTestCase {

    override func setUp() async throws {
        await super.setUp()

        // WeaveDI 컨테이너 초기화
        WeaveDI.Container.live = WeaveDI.Container()

        // 모킹된 UseCase들 등록
        await WeaveDI.Container.bootstrap { container in
            container.register(ExchangeUseCaseImpl.self) {
                MockExchangeUseCaseImpl()
            }
            container.register(FavoriteCurrencyUseCaseImpl.self) {
                MockFavoriteCurrencyUseCaseImpl()
            }
            container.register(ExchangeRateCacheUseCaseImpl.self) {
                MockCacheUseCaseImpl()
            }
        }
    }

    @MainActor
    func testLoadExchangeRates() async {
        // Given
        let store = TestStore(initialState: ExchangeFeature.State()) {
            ExchangeFeature()
        } withDependencies: {
            // swift-dependencies 모킹
            $0.analyticsService = MockAnalyticsService()
            $0.networkMonitor = MockNetworkMonitor(isConnected: true)
        }

        // When
        await store.send(.loadExchangeRates(.usd))

        // Then
        await store.receive(.exchangeRatesLoaded(expectedRates)) {
            $0.exchangeRates = expectedRates
            $0.isLoading = false
        }
    }
}

// MARK: - Mock 구현들
class MockExchangeUseCaseImpl: ExchangeUseCaseImpl {
    override func fetchRates(baseCurrency: Currency) async throws -> [ExchangeRate] {
        return [
            ExchangeRate(from: .usd, to: .krw, rate: 1350.0),
            ExchangeRate(from: .usd, to: .jpy, rate: 149.0)
        ]
    }
}
```

### 성능 비교 및 최적화

| 측면 | 구체적 타입 주입 | 프로토콜 기반 | swift-dependencies |
|------|-----------------|-------------|-------------------|
| **타입 안전성** | **매우 강함** | 강함 | 강함 |
| **해결 속도** | **매우 빠름** | 빠름 | 빠름 |
| **테스트 용이성** | 보통 | **매우 좋음** | **매우 좋음** |
| **유연성** | 낮음 | **높음** | **높음** |
| **코드 결합도** | 높음 | **낮음** | **낮음** |

### 권장 사용 패턴

#### 1. 기존 코드 유지 + 점진적 개선

```swift
// 현재 안정적으로 동작하는 코드는 그대로 유지
@Injected(ExchangeUseCaseImpl.self) private var exchangeUseCase
@Injected(FavoriteCurrencyUseCaseImpl.self) private var favoriteUseCase

// 새로운 기능은 프로토콜 기반으로
@Injected(\.pushNotificationService) var pushService
@Injected(\.userPreferences) var preferences
```

#### 2. 새 프로젝트 권장 패턴

```swift
// 모든 의존성을 프로토콜 기반으로
@Injected(\.exchangeUseCase) var exchangeUseCase
@Injected(\.favoriteUseCase) var favoriteUseCase
@Injected(\.cacheUseCase) var cacheUseCase
```

### 자주 묻는 질문

**Q: 현재 사용 중인 구체적 타입 주입 방식이 잘못된 건가요?**

A: 아닙니다! 구체적 타입 주입은 완전히 유효한 패턴이며, 특히 타입 안전성이 중요한 상황에서 매우 효과적입니다. 다만 프로토콜 기반 접근법이 테스트와 유연성 면에서 더 유리할 수 있습니다.

**Q: 기존 코드를 바꿔야 하나요?**

A: 기존 코드가 잘 동작한다면 바꿀 필요가 없습니다. 새로운 기능을 추가할 때 점진적으로 프로토콜 기반 패턴을 도입하시면 됩니다.

**Q: 두 패턴을 함께 사용해도 되나요?**

A: 네! 완전히 안전하며 실제로 권장되는 접근법입니다.

### 결론

WeaveDI와 swift-dependencies의 통합을 통해:
- **점진적 마이그레이션**: 자신만의 속도로 이전
- **성능 최적화**: WeaveDI로 무거운 작업 처리
- **최대 호환성**: 기존 코드 유지
- **향상된 테스트**: 통합된 모킹 관리

이런 하이브리드 접근법은 특히 기존 코드가 안정적으로 동작하는 상황에서 위험을 최소화하면서 개선할 수 있는 방법입니다.
