# 자주 묻는 질문 (FAQ)

WeaveDI에 대해 자주 묻는 질문과 답변입니다.

## 일반 질문

### WeaveDI란 무엇인가요?

WeaveDI는 Swift 네이티브 의존성 주입 프레임워크로 다음을 제공합니다:
- **타입 안전 의존성 주입** - 컴파일 타임 보장
- **다양한 주입 패턴**: `@Injected`, `@Factory`, 레거시 `@Injected`
- **TCA 호환 API** - KeyPath 기반 접근
- **Swift Concurrency 지원** - Actor 격리
- **성능 최적화** - 내장 캐싱 및 지연 로딩

**사용 시기:**
```swift
// ✅ 완벽한 경우:
// - 복잡한 의존성 그래프를 가진 iOS/macOS 앱
// - The Composable Architecture (TCA) 사용 앱
// - 엄격한 타입 안전성이 필요한 프로젝트
// - 테스트 가능한 아키텍처가 필요한 앱

// 예제: 깔끔하고 테스트 가능한 뷰 모델
class UserViewModel {
    @Injected(\.userService) var userService
    @Injected(\.analytics) var analytics

    func loadUser() async {
        let user = await userService.fetchCurrentUser()
        analytics.track("user_loaded")
    }
}
```

### WeaveDI와 다른 DI 프레임워크 비교

| 기능 | WeaveDI | Swinject | Needle | Factory |
|------|---------|----------|--------|---------|
| **타입 안전성** | ✅ 컴파일 타임 | ⚠️ 런타임 | ✅ 컴파일 타임 | ✅ 컴파일 타임 |
| **TCA 호환** | ✅ Yes | ❌ No | ❌ No | ⚠️ 제한적 |
| **Property Wrappers** | ✅ @Injected, @Factory | ✅ @Injected | ❌ No | ✅ @Injected |
| **Swift Concurrency** | ✅ 완전 지원 | ⚠️ 부분 지원 | ⚠️ 제한적 | ✅ 완전 지원 |
| **성능** | ✅ 최적화됨 | ⚠️ 보통 | ✅ 빠름 | ✅ 빠름 |
| **학습 곡선** | ⚠️ 보통 | ⚠️ 보통 | ❌ 가파름 | ✅ 쉬움 |

자세한 분석은 [프레임워크 비교](./frameworkComparison.md)를 참조하세요.

## 설치 및 설정

### 어떤 Swift 버전이 필요한가요?

**버전 요구사항:**
- **Swift 6.0+**: 완전한 동시성, strict Sendable (권장)
- **Swift 5.9+**: 완전한 async/await 지원
- **Swift 5.8+**: 핵심 DI 기능
- **Swift 5.7+**: 제한적 지원 (폴백 구현)

**SPM 설정 예제:**
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.2.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["WeaveDI"],
        swiftSettings: [
            // Swift 6 strict concurrency (선택사항)
            .enableExperimentalFeature("StrictConcurrency")
        ]
    )
]
```

### 프로젝트에 WeaveDI를 어떻게 설정하나요?

**빠른 설정 (3단계):**

```swift
// 1. InjectedKey 정의
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()
}

// 2. InjectedValues 확장
extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

// 3. @Injected 사용
class ViewModel {
    @Injected(\.userService) var userService

    func loadData() async {
        await userService.fetchUser()
    }
}
```

**앱 전체 설정:**
```swift
@main
struct MyApp: App {
    init() {
        // 선택사항: 복잡한 의존성을 위한 Bootstrap
        Task {
            await WeaveDI.Container.bootstrap { container in
                container.register(DatabaseService.self) {
                    CoreDataService()
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

전체 설정은 [빠른 시작 가이드](./quickStart.md)를 참조하세요.

## Property Wrappers

### @Injected와 @Factory는 언제 사용하나요?

**@Injected 사용 (기본):**
```swift
// ✅ 공유 서비스 (싱글톤 같은)
@Injected(\.userService) var userService
@Injected(\.apiClient) var apiClient
@Injected(\.database) var database

// 이유: 같은 인스턴스 재사용, 더 나은 성능
```

**@Factory 사용:**
```swift
// ✅ 새 인스턴스 필요
@Factory var pdfGenerator: PDFGenerator
@Factory var dateFormatter: DateFormatter
@Factory var reportBuilder: ReportBuilder

// 이유: 매번 접근할 때마다 새 인스턴스 생성
// 완벽한 경우: 무상태 작업, 동시 처리

// 예제: 병렬 PDF 생성
class DocumentService {
    @Factory var pdfGenerator: PDFGenerator

    func generateReports(_ data: [Report]) async -> [PDF] {
        await withTaskGroup(of: PDF.self) { group in
            for report in data {
                group.addTask {
                    let gen = self.pdfGenerator  // 작업마다 새 인스턴스
                    return gen.generate(report)
                }
            }

            var results: [PDF] = []
            for await pdf in group {
                results.append(pdf)
            }
            return results
        }
    }
}
```

**의사결정 트리:**
```
매번 새 인스턴스가 필요한가?
├─ Yes → @Factory 사용
│   └─ 예: Formatters, Builders, Parsers
└─ No → @Injected 사용
    └─ 예: Services, Repositories, Managers
```

### @Injected와 @SafeInject는 어떻게 되었나요?

**v3.2.0부터 Deprecated:**
```swift
// ❌ Deprecated (여전히 작동하지만 권장하지 않음)
@Injected var service: UserService?
@SafeInject var api: APIClient?

// ✅ @Injected로 마이그레이션
@Injected(\.userService) var service
@Injected(\.apiClient) var api
```

**Deprecated 이유:**
- Optional 기반 (nil 체크 필요)
- 컴파일 타임 KeyPath 안전성 없음
- TCA 호환 불가
- 제한적인 테스트 지원

**마이그레이션 가이드:**
[마이그레이션: @Injected → @Injected](./migrationInjectToInjected.md) 참조

### 생성자 주입을 대신 사용할 수 있나요?

**예! 두 패턴 모두 지원됩니다:**

```swift
// 패턴 1: Property 주입 (권장)
class UserViewModel {
    @Injected(\.userService) var userService
    @Injected(\.analytics) var analytics
}

// 패턴 2: 생성자 주입
class UserViewModel {
    private let userService: UserService
    private let analytics: Analytics

    init(
        userService: UserService,
        analytics: Analytics
    ) {
        self.userService = userService
        self.analytics = analytics
    }
}

// 생성자 주입으로 등록
container.register(UserViewModel.self) {
    UserViewModel(
        userService: container.resolve(UserService.self),
        analytics: container.resolve(Analytics.self)
    )
}
```

**생성자 주입 사용 시기:**
- 의존성이 필수인 경우 (선택사항 아님)
- 불변 의존성 선호
- 다양한 구현으로 테스트
- 명시적 의존성 선언

**Property wrapper 사용 시기:**
- 더 간단하고 boilerplate 적음
- TCA 통합
- 동적 의존성 교체
- 대부분의 일반적인 사용 사례

## 테스트

### 테스트에서 의존성을 어떻게 모킹하나요?

**권장: `withInjectedValues` 사용:**

```swift
func testUserLogin() async {
    // 모의 객체 생성
    let mockAuth = MockAuthService()
    let mockUser = MockUserService()

    // 테스트에 의존성 오버라이드 범위 지정
    await withInjectedValues { values in
        values.authService = mockAuth
        values.userService = mockUser
    } operation: {
        // 모킹된 의존성으로 테스트
        let viewModel = LoginViewModel()
        await viewModel.login(username: "test", password: "pass")

        // 모의 객체 상호작용 검증
        XCTAssertTrue(mockAuth.loginCalled)
        XCTAssertEqual(mockAuth.lastUsername, "test")
    }
    // 테스트 후 의존성 자동 되돌림
}
```

**이 접근 방식의 이유:**
- ✅ 자동 정리 (전역 상태 오염 없음)
- ✅ 타입 안전
- ✅ async/await와 호환
- ✅ 테스트 실행 범위 지정

**대안: InjectedKey에서 testValue 정의:**
```swift
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()  // 테스트에서 자동 사용
}

// 테스트는 자동으로 testValue 사용
func testWithDefaults() async {
    let viewModel = UserViewModel()
    await viewModel.loadUser()
    // MockUserService 자동 사용
}
```

자세한 패턴은 [테스트 가이드](../tutorial/testing.md)를 참조하세요.

### @Injected를 사용하는 코드를 어떻게 테스트하나요?

**패턴 1: 의존성 오버라이드:**
```swift
class UserViewModel {
    @Injected(\.userService) var userService

    func loadUser() async -> User? {
        await userService.fetchUser(id: "123")
    }
}

// 테스트
func testLoadUser() async {
    let mockService = MockUserService()
    mockService.stubbedUser = User(id: "123", name: "Test")

    await withInjectedValues { values in
        values.userService = mockService
    } operation: {
        let viewModel = UserViewModel()
        let user = await viewModel.loadUser()

        XCTAssertEqual(user?.name, "Test")
        XCTAssertTrue(mockService.fetchUserCalled)
    }
}
```

### 테스트 간에 의존성을 정리해야 하나요?

**`withInjectedValues` 사용 시: 정리 불필요**
```swift
func testA() async {
    await withInjectedValues { values in
        values.service = MockA()
    } operation: {
        // 테스트 A
    }
    // 자동 정리
}

func testB() async {
    await withInjectedValues { values in
        values.service = MockB()
    } operation: {
        // 테스트 B - 깨끗한 상태
    }
}
```

**`withInjectedValues` 없이: 수동 정리**
```swift
class MyTests: XCTestCase {
    override func tearDown() async throws {
        await WeaveDI.Container.releaseAll()
    }
}
```

## 성능

### WeaveDI가 앱 성능에 영향을 주나요?

**성능 특성:**

| 작업 | 시간 | 영향 |
|------|------|------|
| @Injected 해결 | ~0.0001ms | ✅ 무시할 수 있음 |
| @Factory 생성 | ~0.001ms | ✅ 최소 |
| Container bootstrap | ~1-5ms | ✅ 일회성 비용 |

**벤치마크 예제:**
```swift
// 해결 성능 (1000회 반복)
let start = CFAbsoluteTimeGetCurrent()

for _ in 0..<1000 {
    let service = InjectedValues.current.userService
    _ = service.fetchUser()
}

let duration = CFAbsoluteTimeGetCurrent() - start
print("전체: \(duration * 1000)ms, 평균: \(duration)ms per resolution")
// 일반적: ~0.1ms 전체 = 해결당 0.0001ms
```

**최적화 팁:**
```swift
// 1. 런타임 최적화 활성화
UnifiedRegistry.shared.enableOptimization()

// 2. 자주 접근하는 의존성에 @Injected 사용
@Injected(\.logger) var logger  // 캐시됨

// 3. 새 인스턴스가 필요할 때만 @Factory 사용
@Factory var tempService: TempService  // 새 인스턴스 생성

// 4. 클래스당 의존성 수 최소화 (< 5개)
class ViewModel {
    @Injected(\.facade) var facade  // Facade가 여러 서비스 결합
}
```

최적화 기법은 [성능 가이드](./runtimeOptimization.md)를 참조하세요.

## 아키텍처

### SwiftUI와 WeaveDI를 함께 사용할 수 있나요?

**예! 완벽한 통합:**

```swift
// 1. 의존성 정의
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
}

extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

// 2. ViewModel에서 사용
@MainActor
class UserViewModel: ObservableObject {
    @Injected(\.userService) var userService
    @Published var user: User?

    func loadUser() async {
        user = await userService.fetchCurrentUser()
    }
}

// 3. SwiftUI View에서 사용
struct UserView: View {
    @StateObject private var viewModel = UserViewModel()

    var body: some View {
        VStack {
            if let user = viewModel.user {
                Text("안녕하세요, \(user.name)")
            }
        }
        .task {
            await viewModel.loadUser()
        }
    }
}
```

**SwiftUI Previews:**
```swift
struct UserView_Previews: PreviewProvider {
    static var previews: some View {
        UserView()
            .withInjectedValues { values in
                values.userService = MockUserService()
            }
    }
}
```

### The Composable Architecture (TCA)와 함께 사용할 수 있나요?

**예! WeaveDI는 TCA에서 영감을 받았습니다:**

```swift
// Dependencies (TCA 스타일)
extension InjectedValues {
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

// Reducer
struct UserFeature: Reducer {
    @Injected(\.apiClient) var apiClient

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .loadUser:
            return .run { send in
                let user = await apiClient.fetchUser()
                await send(.userLoaded(user))
            }
        }
    }
}

// 테스트
func testLoadUser() async {
    await withInjectedValues { values in
        values.apiClient = MockAPIClient()
    } operation: {
        let store = TestStore(initialState: UserFeature.State()) {
            UserFeature()
        }

        await store.send(.loadUser)
        await store.receive(.userLoaded)
    }
}
```

완전한 패턴은 [TCA 통합 가이드](./tcaIntegration.md)를 참조하세요.

## 일반적인 문제

### 의존성이 nil인 이유는?

**일반적인 원인:**

1. **의존성이 등록되지 않음:**
```swift
// ❌ 문제: 등록 안함
@Injected(\.userService) var service  // 기본값/nil 사용 가능

// ✅ 해결: InjectedKey 정의
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
}
```

2. **잘못된 타입:**
```swift
// ❌ 문제: 타입 불일치
container.register(Animal.self) { Dog() }
@Injected var cat: Cat?  // 잘못된 타입!

// ✅ 해결: 올바른 타입 사용
container.register(Dog.self) { Dog() }
@Injected var dog: Dog?
```

3. **너무 일찍 접근:**
```swift
// ❌ 문제: init에서 접근
class ViewModel {
    @Injected(\.service) var service

    init() {
        service.doWork()  // 준비되지 않을 수 있음
    }
}

// ✅ 해결: init 후 접근
class ViewModel {
    @Injected(\.service) var service

    func start() {
        service.doWork()  // ✅ 작동함
    }
}
```

해결책은 [문제 해결 가이드](./troubleShooting.md)를 참조하세요.

### 순환 의존성을 어떻게 피하나요?

**문제:**
```swift
class ServiceA {
    @Injected(\.serviceB) var serviceB  // ServiceA → ServiceB
}

class ServiceB {
    @Injected(\.serviceA) var serviceA  // ServiceB → ServiceA (순환!)
}
```

**해결 1: 추상화 도입**
```swift
protocol EventBus {
    func publish(_ event: Event)
}

class ServiceA {
    @Injected(\.eventBus) var eventBus  // 둘 다 추상화에 의존

    func doWork() {
        eventBus.publish(WorkEvent())
    }
}

class ServiceB {
    @Injected(\.eventBus) var eventBus

    init() {
        eventBus.subscribe(WorkEvent.self) { event in
            // 이벤트 처리
        }
    }
}
```

**해결 2: Weak 참조**
```swift
class ServiceA {
    weak var serviceB: ServiceB?  // Weak가 순환 끊음
}

class ServiceB {
    @Injected(\.serviceA) var serviceA
}
```

**해결 3: 공유 로직 리팩토링**
```swift
class SharedDependency {
    func performSharedWork() {
        // 두 서비스 모두 필요한 로직
    }
}

class ServiceA {
    @Injected(\.shared) var shared
}

class ServiceB {
    @Injected(\.shared) var shared
}
```

## 마이그레이션

### Swinject/Resolver에서 어떻게 마이그레이션하나요?

**Swinject → WeaveDI:**

```swift
// 이전 (Swinject)
let container = Container()
container.register(UserService.self) { _ in
    UserServiceImpl()
}

class ViewModel {
    let service = container.resolve(UserService.self)!
}

// 새로운 (WeaveDI)
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
}

extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

class ViewModel {
    @Injected(\.userService) var service
}
```

### @Injected에서 @Injected로 어떻게 마이그레이션하나요?

완전한 [마이그레이션 가이드](./migrationInjectToInjected.md)를 참조하세요.

**빠른 마이그레이션:**
```swift
// 단계 1: 이전 코드
@Injected var service: UserService?

// 단계 2: InjectedKey 정의
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
}

extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

// 단계 3: 새 코드
@Injected(\.userService) var service  // Non-optional!
```

## 고급 주제

### UIKit과 함께 WeaveDI를 사용할 수 있나요?

**예:**

```swift
class UserViewController: UIViewController {
    @Injected(\.userService) var userService
    @Injected(\.analytics) var analytics

    override func viewDidLoad() {
        super.viewDidLoad()

        Task {
            await loadUser()
        }
    }

    func loadUser() async {
        let user = await userService.fetchCurrentUser()
        updateUI(with: user)
        analytics.track("user_view_loaded")
    }
}
```

### 환경별 의존성을 어떻게 처리하나요?

```swift
struct APIClientKey: InjectedKey {
    static var liveValue: APIClient {
        #if DEBUG
        return MockAPIClient()  // 개발
        #else
        return URLSessionAPIClient()  // 프로덕션
        #endif
    }
}

// 또는 빌드 설정으로
struct ConfigurableAPIKey: InjectedKey {
    static var liveValue: APIClient {
        if ProcessInfo.processInfo.environment["USE_MOCK"] == "1" {
            return MockAPIClient()
        }
        return URLSessionAPIClient()
    }
}
```

### Swift Package에서 WeaveDI를 사용할 수 있나요?

**예:**

```swift
// Package.swift
let package = Package(
    name: "MyFeature",
    dependencies: [
        .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.2.0")
    ],
    targets: [
        .target(
            name: "MyFeature",
            dependencies: ["WeaveDI"]
        )
    ]
)

// MyFeature/Sources/DI.swift
import WeaveDI

public extension InjectedValues {
    var myFeatureService: MyFeatureService {
        get { self[MyFeatureServiceKey.self] }
        set { self[MyFeatureServiceKey.self] = newValue }
    }
}
```

## 도움 받기

### 더 많은 예제는 어디에서 찾을 수 있나요?

- [빠른 시작 가이드](./quickStart.md)
- [튜토리얼: 첫 번째 앱](../tutorial/firstApp.md)
- [GitHub 예제](https://github.com/Roy-wonji/WeaveDI/tree/main/Examples)
- [모범 사례](./bestPractices.md)

### 버그를 보고하거나 기능을 요청하려면?

- [GitHub Issues](https://github.com/Roy-wonji/WeaveDI/issues)
- [GitHub Discussions](https://github.com/Roy-wonji/WeaveDI/discussions)

### 커뮤니티가 있나요?

- [GitHub Issues](https://github.com/Roy-wonji/WeaveDI/issues) - 이슈 추적
- [Stack Overflow](https://stackoverflow.com/questions/tagged/weave-di) (태그: `weave-di`)

## 다음 단계

- [빠른 시작 가이드](./quickStart.md) - 5분 안에 시작하기
- [모범 사례](./bestPractices.md) - 권장 패턴
- [문제 해결](./troubleShooting.md) - 일반적인 문제
- [API 참조](../api/coreApis.md) - 완전한 API 문서
