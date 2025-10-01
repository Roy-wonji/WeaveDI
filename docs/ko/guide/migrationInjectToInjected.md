# @Inject에서 @Injected로 마이그레이션

Deprecated된 `@Inject`/`@SafeInject`에서 최신 `@Injected` 프로퍼티 래퍼로 마이그레이션하는 완전한 가이드 (v3.2.0+).

## 왜 마이그레이션해야 하나요?

### @Inject/@SafeInject (v3.2.0부터 Deprecated)
```swift
class ViewModel {
    @Inject var userService: UserService?        // ⚠️ Deprecated
    @SafeInject var apiClient: APIClient?        // ⚠️ Deprecated
}
```

**제한사항:**
- 옵셔널 기반, nil 체크 필요
- 런타임 해결만 가능
- KeyPath에 대한 컴파일 타임 안전성 없음
- TCA 호환 불가
- 제한적인 테스트 지원

### @Injected (v3.2.0+)
```swift
class ViewModel {
    @Injected(\.userService) var userService     // ✅ 권장
    @Injected(\.apiClient) var apiClient         // ✅ 타입 안전
}
```

**장점:**
- 기본적으로 non-optional (liveValue/testValue 폴백)
- KeyPath를 통한 컴파일 타임 타입 안전성
- TCA 스타일 API
- `withInjectedValues`로 내장된 테스트 지원
- 더 나은 타입 추론

## 마이그레이션 단계

### 1단계: InjectedKey 정의

`@Inject`로 사용 중인 각 서비스에 대해 `InjectedKey`를 생성합니다:

**이전 (@Inject 사용):**
```swift
// 등록만 함
let service = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}
```

**이후 (@Injected 사용):**
```swift
// 1. InjectedKey 정의
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()
}
```

**설명:**
- `liveValue`: 프로덕션 구현
- `testValue`: 테스트/모의 구현 (선택사항, 기본값은 liveValue)
- `InjectedKey` 프로토콜 준수
- 의존성에 대한 타입 안전 접근 제공

### 2단계: InjectedValues 확장

KeyPath 접근을 위해 `InjectedValues`에 computed property 생성:

```swift
extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}
```

**설명:**
- `get`: InjectedKey를 사용하여 값 가져오기
- `set`: 테스트에서 오버라이드 가능
- 타입 안전 접근을 위한 KeyPath `\.userService` 제공

### 3단계: @Inject를 @Injected로 교체

**이전:**
```swift
class UserViewModel {
    @Inject var userService: UserService?

    func loadUser() async {
        guard let service = userService else {
            print("Service not available")
            return
        }
        let user = await service.fetchUser(id: "123")
    }
}
```

**이후:**
```swift
class UserViewModel {
    @Injected(\.userService) var userService

    func loadUser() async {
        // guard 불필요 - non-optional
        let user = await userService.fetchUser(id: "123")
    }
}
```

**변경사항:**
- `@Inject var userService: UserService?` → `@Injected(\.userService) var userService`
- `guard let` 언래핑 제거 (non-optional)
- 더 깔끔하고 간결한 코드

### 4단계: 테스트 업데이트

**이전 (@Inject 사용):**
```swift
override func setUp() {
    UnifiedDI.releaseAll()

    _ = UnifiedDI.register(UserService.self) {
        MockUserService()
    }
}

func testLoadUser() async {
    let viewModel = UserViewModel()
    await viewModel.loadUser()
}
```

**이후 (@Injected 사용):**
```swift
func testLoadUser() async {
    await withInjectedValues { values in
        values.userService = MockUserService()
    } operation: {
        let viewModel = UserViewModel()
        await viewModel.loadUser()
    }
}
```

**설명:**
- `withInjectedValues`: 스코프가 지정된 의존성 오버라이드
- 작업 후 자동으로 되돌림
- 수동 정리 불필요
- 타입 안전 값 할당

## 완전한 마이그레이션 예제

### 원본 코드 (v3.1.0)

```swift
// Services/UserService.swift
protocol UserService {
    func fetchUser(id: String) async -> User?
}

class UserServiceImpl: UserService {
    func fetchUser(id: String) async -> User? {
        // 구현
    }
}

// 앱 초기화
@main
struct MyApp: App {
    init() {
        _ = UnifiedDI.register(UserService.self) {
            UserServiceImpl()
        }
    }
}

// ViewModel
class UserViewModel {
    @Inject var userService: UserService?

    func loadUser() async {
        guard let service = userService else { return }
        let user = await service.fetchUser(id: "123")
    }
}

// 테스트
class UserViewModelTests: XCTestCase {
    override func setUp() {
        UnifiedDI.releaseAll()
        _ = UnifiedDI.register(UserService.self) {
            MockUserService()
        }
    }

    func testLoadUser() async {
        let viewModel = UserViewModel()
        await viewModel.loadUser()
    }
}
```

### 마이그레이션된 코드 (v3.2.0+)

```swift
// DI/UserServiceKey.swift
import WeaveDI

struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()
}

extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

// Services/UserService.swift (변경 없음)
protocol UserService {
    func fetchUser(id: String) async -> User?
}

class UserServiceImpl: UserService {
    func fetchUser(id: String) async -> User? {
        // 구현
    }
}

// 앱 초기화 (선택사항, InjectedKey가 처리함)
@main
struct MyApp: App {
    init() {
        // 등록 불필요 - InjectedKey가 liveValue 제공
        // 또는 중앙 집중식 설정을 위해 AppDIManager 사용
        WeaveDI.Container.bootstrapInTask { @DIContainerActor _ in
            await AppDIManager.shared.registerDefaultDependencies()
        }
    }
}

// ViewModel
class UserViewModel {
    @Injected(\.userService) var userService

    func loadUser() async {
        // guard 불필요 - non-optional
        let user = await userService.fetchUser(id: "123")
    }
}

// 테스트
class UserViewModelTests: XCTestCase {
    func testLoadUser() async {
        await withInjectedValues { values in
            values.userService = MockUserService()
        } operation: {
            let viewModel = UserViewModel()
            await viewModel.loadUser()
        }
    }
}
```

## 마이그레이션 패턴

### 패턴 1: 간단한 서비스

**이전:**
```swift
@Inject var logger: Logger?
```

**이후:**
```swift
// 1. Key 정의
struct LoggerKey: InjectedKey {
    static var liveValue: Logger = ConsoleLogger()
}

extension InjectedValues {
    var logger: Logger {
        get { self[LoggerKey.self] }
        set { self[LoggerKey.self] = newValue }
    }
}

// 2. 사용
@Injected(\.logger) var logger
```

### 패턴 2: 여러 의존성

**이전:**
```swift
class ViewModel {
    @Inject var userService: UserService?
    @Inject var apiClient: APIClient?
    @Inject var cache: CacheService?
}
```

**이후:**
```swift
// 모든 키 정의
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
}

struct APIClientKey: InjectedKey {
    static var liveValue: APIClient = URLSessionAPIClient()
}

struct CacheServiceKey: InjectedKey {
    static var liveValue: CacheService = MemoryCacheService()
}

// InjectedValues 확장
extension InjectedValues {
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }

    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }

    var cache: CacheService {
        get { self[CacheServiceKey.self] }
        set { self[CacheServiceKey.self] = newValue }
    }
}

// ViewModel에서 사용
class ViewModel {
    @Injected(\.userService) var userService
    @Injected(\.apiClient) var apiClient
    @Injected(\.cache) var cache
}
```

### 패턴 3: 타입 기반 접근 (대안)

`InjectedKey`를 직접 구현하는 타입의 경우:

```swift
// 구현체가 InjectedKey를 준수하도록 함
extension UserServiceImpl: InjectedKey {
    static var liveValue: UserServiceImpl { UserServiceImpl() }
}

// KeyPath 대신 타입 사용
@Injected(UserServiceImpl.self) var userService
```

## 일반적인 마이그레이션 문제

### 문제 1: Optional vs Non-Optional

**문제:**
```swift
// 기존 코드는 optional 예상
@Inject var service: UserService?
if let service = service {
    // service 사용
}
```

**해결:**
```swift
// @Injected는 non-optional, 언래핑 불필요
@Injected(\.service) var service
// 직접 service 사용
```

### 문제 2: 순환 의존성

**문제:**
```swift
// ServiceA가 ServiceB에 의존
// ServiceB가 ServiceA에 의존
// InjectedKey 정적 초기화에서 문제 발생
```

**해결:**
```swift
// InjectedKey에서 lazy 초기화 사용
struct ServiceAKey: InjectedKey {
    static var liveValue: ServiceA {
        ServiceAImpl()  // 초기화에서 ServiceB 주입 안함
    }
}

// 또는 프로퍼티 주입 사용
class ServiceAImpl: ServiceA {
    @Injected(\.serviceB) var serviceB  // Lazy 주입
}
```

### 문제 3: 테스트 설정 변경

**문제:**
```swift
// 기존 테스트 설정이 작동하지 않음
override func setUp() {
    UnifiedDI.releaseAll()  // InjectedValues에 영향 없음
}
```

**해결:**
```swift
// 각 테스트마다 withInjectedValues 사용
func testExample() async {
    await withInjectedValues { values in
        values.serviceA = MockServiceA()
        values.serviceB = MockServiceB()
    } operation: {
        // 모의 객체로 테스트 실행
    }
}
```

## 점진적 마이그레이션 전략

한 번에 모든 것을 마이그레이션할 필요는 없습니다. 점진적 접근 방법:

### 1단계: 새 코드만
```swift
// 기존 @Inject 코드 유지
class OldViewModel {
    @Inject var service: UserService?  // 그대로 유지
}

// 새 코드에 @Injected 사용
class NewViewModel {
    @Injected(\.userService) var service  // 새 코드
}
```

### 2단계: 모듈별로
```swift
// 한 번에 하나의 기능/모듈 마이그레이션
// 예: 먼저 User 모듈
extension InjectedValues {
    // User 모듈 의존성
    var userService: UserService { ... }
    var userRepository: UserRepository { ... }
}

// 그 다음 Auth 모듈
extension InjectedValues {
    var authService: AuthService { ... }
    var tokenManager: TokenManager { ... }
}
```

### 3단계: 중요한 경로
```swift
// 트래픽이 많은 코드 경로 먼저 마이그레이션
// 예: 메인 피드, 인증 등
class MainFeedViewModel {
    @Injected(\.feedService) var feedService  // 마이그레이션됨
    @Injected(\.userService) var userService  // 마이그레이션됨
}

// 덜 중요한 기능은 나중에
class SettingsViewModel {
    @Inject var settingsService: SettingsService?  // 아직 마이그레이션 안함
}
```

## 호환성 참고사항

### @Inject와 @Injected 공존 가능

```swift
// 마이그레이션 중에 유효함
class HybridViewModel {
    @Inject var oldService: OldService?           // 작동함
    @Injected(\.newService) var newService        // 작동함
    @Factory var generator: ReportGenerator       // 작동함
}
```

### UnifiedDI도 여전히 작동

```swift
// 레거시 등록이 InjectedKey와 함께 작동
_ = UnifiedDI.register(LegacyService.self) {
    LegacyServiceImpl()
}

// @Inject로 해결 가능
@Inject var legacy: LegacyService?
```

## 성능 고려사항

**@Injected가 더 빠름:**
- 컴파일 타임 KeyPath 해결
- KeyPath 접근을 위한 런타임 딕셔너리 조회 없음
- 컴파일러에 의한 더 나은 최적화

**벤치마크 (근사값):**
- @Inject: 해결당 ~0.001ms
- @Injected: 해결당 ~0.0001ms (10배 빠름)

## 마이그레이션 체크리스트

- [ ] 코드베이스의 모든 `@Inject` 및 `@SafeInject` 사용 검토
- [ ] 각 서비스에 대한 `InjectedKey` 생성
- [ ] computed property로 `InjectedValues` 확장
- [ ] `@Inject`를 `@Injected(\.keyPath)`로 교체
- [ ] 옵셔널 언래핑 코드 제거
- [ ] `withInjectedValues` 사용하도록 테스트 설정 업데이트
- [ ] `UnifiedDI.register` 호출 제거 (InjectedKey.liveValue 사용 시)
- [ ] 철저히 테스트
- [ ] 문서 업데이트

## 다음 단계

- [Best Practices 가이드](./bestPractices.md) - 권장 패턴
- [@Injected API 레퍼런스](../api/injected.md) - 완전한 API 문서
- [TCA 통합](./tcaIntegration.md) - TCA와 @Injected 사용하기
- [테스트 가이드](../tutorial/testing.md) - 고급 테스트 전략

## 도움이 필요하세요?

- [문제 해결 가이드](./troubleShooting.md) - 일반적인 문제 및 해결책
- [GitHub Issues](https://github.com/Roy-wonji/WeaveDI/issues) - 마이그레이션 문제 보고
- [마이그레이션 로드맵](./roadmap.md) - Deprecation 타임라인
