# WeaveDI 모범 사례

프로덕션 애플리케이션에서 WeaveDI를 효과적으로 사용하기 위한 권장 패턴과 사례입니다.

## Property Wrapper 선택

### 대부분의 경우 @Injected 사용 (v3.2.0+)

```swift
// ✅ 권장: 타입 안전, TCA 스타일
@Injected(\.userService) var userService
@Injected(\.apiClient) var apiClient
```

**이유:**
- KeyPath를 통한 컴파일 타임 타입 안전성
- 기본적으로 non-optional (liveValue/testValue 폴백)
- `withInjectedValues`를 통한 향상된 테스트 지원
- TCA 호환 API

### 새 인스턴스가 필요한 경우 @Factory 사용

```swift
// ✅ 좋음: 무상태 작업
@Factory var pdfGenerator: PDFGenerator
@Factory var reportBuilder: ReportBuilder
@Factory var dateFormatter: DateFormatter
```

**사용 시기:**
- 무상태 서비스 (PDF 생성기, 포맷터, 파서)
- 각 작업마다 독립적인 상태가 필요한 경우
- 독립적인 인스턴스로 동시 처리
- 새로운 인스턴스가 필요한 빌더 패턴

**예제:**
```swift
class DocumentService {
    @Factory var pdfGenerator: PDFGenerator

    func generateReports(data: [ReportData]) async {
        await withTaskGroup(of: PDF.self) { group in
            for item in data {
                group.addTask {
                    // 각 작업마다 새 생성기 획득 - 상태 충돌 없음
                    let generator = self.pdfGenerator
                    return generator.generate(item)
                }
            }
        }
    }
}
```

### @Injected/@SafeInject 사용 피하기 (v3.2.0부터 Deprecated)

```swift
// ❌ 피하기: Deprecated
@Injected var service: UserService?
@SafeInject var api: APIClient?

// ✅ 대신 사용:
@Injected(\.service) var service
@Injected(\.api) var api
```

## 의존성 구성

### 기능별로 의존성 그룹화

```swift
// ✅ 좋음: 기능 기반 구성
// File: DI/UserFeatureDependencies.swift
extension InjectedValues {
    // 사용자 기능 의존성
    var userService: UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }

    var userRepository: UserRepository {
        get { self[UserRepositoryKey.self] }
        set { self[UserRepositoryKey.self] = newValue }
    }
}

// File: DI/AuthFeatureDependencies.swift
extension InjectedValues {
    // 인증 기능 의존성
    var authService: AuthService {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }

    var tokenManager: TokenManager {
        get { self[TokenManagerKey.self] }
        set { self[TokenManagerKey.self] = newValue }
    }
}
```

**장점:**
- 명확한 기능 경계
- 관련 의존성을 쉽게 찾을 수 있음
- 기능 제거가 쉬움
- 더 나은 코드 구성

### InjectedKey 정의 중앙 집중화

```swift
// ✅ 좋음: 한 곳에 모든 키
// File: DI/InjectedKeys.swift
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()
}

struct APIClientKey: InjectedKey {
    static var liveValue: APIClient = URLSessionAPIClient()
    static var testValue: APIClient = MockAPIClient()
}

// 그런 다음 기능 파일에서 InjectedValues 확장
```

## 스코프 관리

### 적절한 스코프 사용

```swift
// ✅ 앱 전체 서비스에 싱글톤
struct LoggerKey: InjectedKey {
    static var liveValue: Logger = ConsoleLogger()  // 공유 인스턴스
}

// ✅ 기능별 서비스에 스코프 지정
await WeaveDI.Container.bootstrap { container in
    container.register(SessionService.self, scope: .session) {
        SessionServiceImpl()
    }
}
```

**스코프 가이드라인:**
| 스코프 | 사용 사례 | 예제 |
|-------|----------|------|
| Singleton | 앱 전체 서비스 | Logger, Analytics, Config |
| Session | 사용자 세션 서비스 | Auth token, User preferences |
| Request | 요청당 서비스 | 네트워크 호출당 API 클라이언트 |
| Transient | 새 인스턴스 | Formatters, Builders |

### 예제: 다중 스코프 아키텍처

```swift
// 앱 전체 싱글톤
struct AnalyticsKey: InjectedKey {
    static var liveValue: Analytics = FirebaseAnalytics()
}

// 세션 스코프 서비스
class SessionManager {
    @Injected(\.authToken) var authToken  // 세션마다 변경
    @Injected(\.analytics) var analytics  // 공유 싱글톤

    func login(credentials: Credentials) async {
        // authToken은 세션 특정
        // analytics는 앱 전체
    }
}
```

## 성능 최적화

### 의존성 수 최소화

```swift
// ❌ 나쁨: 너무 많은 의존성
class ViewModel {
    @Injected(\.service1) var service1
    @Injected(\.service2) var service2
    @Injected(\.service3) var service3
    @Injected(\.service4) var service4
    @Injected(\.service5) var service5  // 너무 많음!
}

// ✅ 좋음: 서비스 조합
class ViewModel {
    @Injected(\.userFacade) var userFacade  // Facade 패턴
}

// Facade가 관련 서비스 결합
class UserFacade {
    @Injected(\.userService) var userService
    @Injected(\.authService) var authService
    @Injected(\.profileService) var profileService

    func performUserAction() {
        // 여러 서비스 조정
    }
}
```

### 무거운 의존성의 지연 로딩

```swift
// ✅ 좋음: 지연 초기화
struct DatabaseKey: InjectedKey {
    static var liveValue: Database {
        // 비용이 많이 드는 초기화 지연
        Database.shared
    }
}

// 필요할 때만 접근
class DataService {
    @Injected(\.database) var database

    func saveData() {
        // Database는 처음 접근할 때만 초기화됨
        database.save()
    }
}
```

### 동시 작업에 @Factory 사용

```swift
// ✅ 좋음: @Factory로 병렬 처리
class ImageProcessor {
    @Factory var imageFilter: ImageFilter

    func processImages(_ images: [UIImage]) async -> [UIImage] {
        await withTaskGroup(of: UIImage.self) { group in
            for image in images {
                group.addTask {
                    // 각 이미지마다 새 필터 - 스레드 충돌 없음
                    let filter = self.imageFilter
                    return filter.apply(to: image)
                }
            }

            var results: [UIImage] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
}
```

## 테스트 전략

### 테스트에 withInjectedValues 사용

```swift
// ✅ 좋음: 스코프 지정된 의존성 오버라이드
func testUserLogin() async {
    await withInjectedValues { values in
        values.authService = MockAuthService()
        values.userService = MockUserService()
    } operation: {
        let viewModel = LoginViewModel()
        await viewModel.login(credentials: testCredentials)

        XCTAssertTrue(viewModel.isLoggedIn)
    }
}
```

**장점:**
- 테스트 후 자동 정리
- 전역 상태 오염 없음
- 타입 안전 값 할당
- async/await와 호환

### InjectedKey에서 테스트 값 정의

```swift
// ✅ 좋음: 내장 테스트 값
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = UserServiceImpl()
    static var testValue: UserService = MockUserService()  // 사전 정의된 모의 객체
}

// 테스트 컨텍스트에서 자동으로 testValue 사용
func testWithDefaults() async {
    await withInjectedValues { values in
        // testValue 자동 사용
    } operation: {
        // 테스트 코드
    }
}
```

### 테스트 헬퍼 생성

```swift
// ✅ 좋음: 재사용 가능한 테스트 설정
extension XCTestCase {
    func withTestDependencies(
        userService: UserService = MockUserService(),
        apiClient: APIClient = MockAPIClient(),
        operation: () async throws -> Void
    ) async rethrows {
        await withInjectedValues { values in
            values.userService = userService
            values.apiClient = apiClient
        } operation: {
            try await operation()
        }
    }
}

// 테스트에서 사용
func testExample() async throws {
    await withTestDependencies {
        // 표준 모의 객체로 테스트
    }
}
```

## 에러 처리

### 누락된 의존성을 우아하게 처리

```swift
// ✅ 좋음: 폴백 값
struct LoggerKey: InjectedKey {
    static var liveValue: Logger = ConsoleLogger()
    static var testValue: Logger = NoOpLogger()  // 테스트에서 조용함
}

// 서비스는 구성되지 않아도 항상 로거를 가짐
class Service {
    @Injected(\.logger) var logger  // nil이 아님

    func performAction() {
        logger.log("Action performed")  // 안전하게 호출
    }
}
```

### 시작 시 중요한 의존성 검증

```swift
// ✅ 좋음: 조기 검증
@main
struct MyApp: App {
    init() {
        validateDependencies()
        setupDependencies()
    }

    func validateDependencies() {
        // 중요한 의존성 존재 확인
        precondition(
            type(of: InjectedValues.current.apiClient) != Never.self,
            "API Client must be configured"
        )
    }

    func setupDependencies() {
        // 의존성 구성
    }
}
```

### 의미 있는 에러 메시지 제공

```swift
// ✅ 좋음: 설명적 에러
struct APIClientKey: InjectedKey {
    static var liveValue: APIClient {
        guard let baseURL = ProcessInfo.processInfo.environment["API_BASE_URL"] else {
            fatalError("""
                ❌ API_BASE_URL 환경 변수가 설정되지 않았습니다

                스킴의 환경 변수에서 API_BASE_URL을 구성하십시오:
                1. Edit Scheme → Run → Arguments → Environment Variables
                2. 추가: API_BASE_URL = https://api.example.com
                """)
        }
        return URLSessionAPIClient(baseURL: baseURL)
    }
}
```

## 아키텍처 패턴

### 프로토콜 기반 설계 사용

```swift
// ✅ 좋음: 추상화를 위한 프로토콜
protocol UserService {
    func fetchUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws
}

// 여러 구현 가능
class ProductionUserService: UserService { /* ... */ }
class MockUserService: UserService { /* ... */ }
class CachedUserService: UserService { /* ... */ }

// 한 번 정의하고 구현 교체
struct UserServiceKey: InjectedKey {
    static var liveValue: UserService = ProductionUserService()
    static var testValue: UserService = MockUserService()
}
```

### 의존성 계층화

```swift
// ✅ 좋음: 명확한 계층
// 레이어 1: 인프라 (하단)
extension InjectedValues {
    var networkClient: NetworkClient { /* ... */ }
    var database: Database { /* ... */ }
    var logger: Logger { /* ... */ }
}

// 레이어 2: 데이터/Repository
extension InjectedValues {
    var userRepository: UserRepository { /* ... */ }
    var productRepository: ProductRepository { /* ... */ }
}

// 레이어 3: 도메인/비즈니스 로직
extension InjectedValues {
    var userService: UserService { /* ... */ }
    var orderService: OrderService { /* ... */ }
}

// 레이어 4: 프레젠테이션
// ViewModel은 레이어 3의 서비스를 주입
```

### 순환 의존성 피하기

```swift
// ❌ 나쁨: 순환 의존성
class ServiceA {
    @Injected(\.serviceB) var serviceB
}

class ServiceB {
    @Injected(\.serviceA) var serviceA  // 순환!
}

// ✅ 좋음: 추상화 도입
protocol EventBus {
    func publish(_ event: Event)
}

class ServiceA {
    @Injected(\.eventBus) var eventBus  // 둘 다 추상화에 의존
}

class ServiceB {
    @Injected(\.eventBus) var eventBus  // 순환 의존성 없음
}
```

### 상속보다 조합 사용

```swift
// ❌ 나쁨: 상속 기반
class BaseService {
    @Injected(\.logger) var logger
}

class UserService: BaseService {
    // logger 상속
}

// ✅ 좋음: 조합 기반
class UserService {
    @Injected(\.logger) var logger  // 명시적
    @Injected(\.database) var database

    // 명확하고 자체 포함
}
```

## 코드 구성 체크리스트

- [ ] 새 코드에 `@Injected` 사용 (v3.2.0+)
- [ ] 기능/모듈별로 의존성 그룹화
- [ ] 명확한 의존성 계층 정의
- [ ] 클래스당 의존성 최소화 (< 5개)
- [ ] 추상화를 위한 프로토콜 사용
- [ ] InjectedKey에서 liveValue와 testValue 모두 제공
- [ ] 시작 시 중요한 의존성 검증
- [ ] 의존성 관계 문서화
- [ ] 순환 의존성 피하기
- [ ] 서비스에 적절한 스코프 사용

## 피해야 할 안티패턴

### ❌ 서비스 로케이터 패턴

```swift
// ❌ 나쁨: 수동 서비스 위치
class ViewModel {
    func loadData() {
        let service = InjectedValues.current.userService  // 나쁨!
        // 서비스 사용
    }
}

// ✅ 좋음: 의존성 주입
class ViewModel {
    @Injected(\.userService) var userService

    func loadData() {
        // userService 사용
    }
}
```

### ❌ 전역 싱글톤

```swift
// ❌ 나쁨: 전역 싱글톤
class APIClient {
    static let shared = APIClient()
}

// ✅ 좋음: DI 관리
struct APIClientKey: InjectedKey {
    static var liveValue: APIClient = APIClient()
}

// 필요한 곳에 주입
@Injected(\.apiClient) var apiClient
```

### ❌ 기본값이 있는 생성자 주입

```swift
// ❌ 나쁨: 숨겨진 의존성
class UserService {
    init(
        apiClient: APIClient = InjectedValues.current.apiClient,  // 나쁨!
        database: Database = InjectedValues.current.database
    ) { }
}

// ✅ 좋음: 명시적 의존성 주입
class UserService {
    @Injected(\.apiClient) var apiClient
    @Injected(\.database) var database

    init() { }  // 깔끔한 초기화
}
```

## 다음 단계

- [마이그레이션 가이드](./migrationInjectToInjected) - @Injected에서 업그레이드
- [TCA 통합](./tcaIntegration) - The Composable Architecture와 함께 사용
- [성능 가이드](./runtimeOptimization) - 최적화 기법
- [테스트 가이드](../tutorial/testing) - 고급 테스트 패턴

## CI 진단 자동화

### 컴포넌트 중복/스코프 헬스 체크
`WeaveDITools diagnose-components --json` 명령을 CI 파이프라인에 추가해 빌드 전에 중복 제공자나 스코프 충돌을 차단하세요. `deploy.yml` 예시는 다음과 같습니다.

```yaml
- name: 🧩 Component diagnostics
  run: |
    swift run --configuration release WeaveDITools diagnose-components --json > component-report.json
    python3 - <<'PY'
    import json, sys
    data = json.load(open('component-report.json'))
    issues = data.get('issues', [])
    if issues:
        for item in issues:
            print(f"- {item['type']}: {', '.join(item['providers'])} -> {item.get('detail')}")
        sys.exit(1)
    PY
```

### 메타데이터 기반 사이클 검증
새로운 `check-cycles` 서브커맨드는 컴파일 타임에 등록된 컴포넌트 메타데이터를 통해 간단한 사이클을 탐지합니다.

```bash
swift run WeaveDITools check-cycles --json
```

CI에서 간단히 활용하려면 제공된 `Scripts/check-component-cycles.sh` 스크립트를 호출하세요. 사이클이 발견되면 로그를 출력하고 종료 코드 1로 실패하므로, “compile-time hint channel”을 한층 강화할 수 있습니다.
