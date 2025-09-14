# 빠른 시작 가이드

> Language: 한국어 | English: [Quick Start](QuickStart.md)

DiContainer 2.0을 사용하여 Swift 프로젝트에서 의존성 주입을 시작하는 방법을 단계별로 알아보세요.

## 개요

DiContainer 2.0은 Swift Concurrency와 Actor Hop 최적화를 활용한 현대적인 의존성 주입 프레임워크입니다.
Clean Architecture 패턴을 완벽하게 지원하며, 타입 안전성과 성능을 모두 갖춘 DI 솔루션을 제공합니다.

## 설치 방법

### Swift Package Manager

`Package.swift` 파일에 DiContainer를 추가하세요:

```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/DiContainer", from: "2.0.0")
]
```

### Xcode에서 설치

1. File → Add Package Dependencies
2. URL 입력: `https://github.com/Roy-wonji/DiContainer`
3. 버전 선택: `2.0.0` 이상

## 기본 설정

### 1. 서비스 정의하기

```swift
// 서비스 프로토콜 정의
protocol UserService {
    func getCurrentUser() async throws -> User
    func updateUser(_ user: User) async throws
}

protocol NetworkService {
    func request<T: Codable>(_ endpoint: String) async throws -> T
}

// 서비스 구현
class UserServiceImpl: UserService {
    @Inject var networkService: NetworkService?
    @RequiredInject var logger: LoggerProtocol

    func getCurrentUser() async throws -> User {
        logger.info("사용자 정보 조회 시작")

        guard let network = networkService else {
            throw ServiceError.networkUnavailable
        }

        let user: User = try await network.request("/user/current")
        logger.info("사용자 정보 조회 완료: \(user.name)")
        return user
    }

    func updateUser(_ user: User) async throws {
        try await networkService?.request("/user/update")
    }
}

class URLSessionNetworkService: NetworkService {
    func request<T: Codable>(_ endpoint: String) async throws -> T {
        // URLSession을 사용한 네트워크 구현
        // ...
    }
}
```

### 2. 의존성 부트스트랩

`App` 또는 `AppDelegate`에서 설정:

```swift
@main
struct MyApp: App {
    init() {
        Task {
            await setupDependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupDependencies() async {
        await DependencyContainer.bootstrap { container in
            // 서비스 등록
            container.register(NetworkService.self) {
                URLSessionNetworkService()
            }

            container.register(UserService.self) {
                UserServiceImpl()
            }

            #if DEBUG
            // 디버그 빌드에서는 Mock 사용
            container.register(NetworkService.self) {
                MockNetworkService()
            }
            #endif
        }
    }
}
```

### 3. 의존성 주입 사용하기

#### 프로퍼티 래퍼 사용 (권장)

```swift
class UserViewController: UIViewController {
    // 자동 주입 - 접근 시점에 자동으로 해결됨
    @Inject var userService: UserService

    // 선택적 주입 - 등록되지 않은 경우 nil 반환
    @Inject var analyticsService: AnalyticsService?

    // 필수 주입 - 등록되지 않은 경우 크래시 (신중하게 사용!)
    @RequiredInject var coreService: CoreService

    override func viewDidLoad() {
        super.viewDidLoad()
        loadUserData()
    }

    private func loadUserData() {
        Task {
            do {
                let user = try await userService.getCurrentUser()
                updateUI(with: user)
            } catch {
                showError(error)
            }
        }
    }
}
```

#### 직접 해결 방식

```swift
class UserManager {
    private let userService: UserService

    init() {
        // 필요할 때 수동으로 의존성 해결
        self.userService = DI.resolve(UserService.self) ?? UserServiceImpl()
    }

    func processUser() async {
        // 에러 처리와 함께 사용
        let result = DI.resolveResult(UserService.self)
        switch result {
        case .success(let service):
            try await service.getCurrentUser()
        case .failure(let error):
            print("UserService 해결 실패: \(error)")
        }
    }
}
```

## 고급 등록 패턴

### 환경별 등록

```swift
await DependencyContainer.bootstrap { container in
    #if DEBUG
    container.register(NetworkService.self) { MockNetworkService() }
    container.register(UserService.self) { MockUserService() }
    #elseif STAGING
    container.register(NetworkService.self) { StagingNetworkService() }
    container.register(UserService.self) { UserServiceImpl() }
    #else
    container.register(NetworkService.self) { ProductionNetworkService() }
    container.register(UserService.self) { UserServiceImpl() }
    #endif
}
```

### 팩토리 기반 등록

```swift
struct ServiceFactory {
    static func createNetworkService() -> NetworkService {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSessionNetworkService(configuration: config)
    }

    static func createUserService() -> UserService {
        return UserServiceImpl()
    }
}

// 팩토리를 사용한 등록
await DependencyContainer.bootstrap { container in
    container.register(NetworkService.self) {
        ServiceFactory.createNetworkService()
    }

    container.register(UserService.self) {
        ServiceFactory.createUserService()
    }
}
```

### KeyPath 기반 등록

```swift
extension DependencyContainer {
    var userService: UserService? { resolve(UserService.self) }
    var networkService: NetworkService? { resolve(NetworkService.self) }
}

// 타입 안전성을 위한 KeyPath 사용
await DependencyContainer.bootstrap { container in
    let userService = container.register(\.userService) {
        UserServiceImpl()
    }

    let networkService = container.register(\.networkService) {
        URLSessionNetworkService()
    }

    // 등록 직후 서비스를 바로 사용할 수 있음
    print("등록된 서비스: \(userService), \(networkService)")
}
```

## 테스트 설정

```swift
class UserServiceTests: XCTestCase {
    override func setUp() async throws {
        await super.setUp()

        // 깨끗한 테스트를 위해 DI 상태 리셋
        await DependencyContainer.releaseAll()

        // 테스트 의존성 설정
        await DependencyContainer.bootstrap { container in
            container.register(NetworkService.self) {
                MockNetworkService()
            }

            container.register(UserService.self) {
                UserServiceImpl()
            }
        }
    }

    func testGetCurrentUser() async throws {
        let userService: UserService = DI.requireResolve(UserService.self)
        let user = try await userService.getCurrentUser()

        XCTAssertEqual(user.id, "test-user")
    }
}
```

## 일반적인 패턴들

### 싱글턴 서비스

```swift
// 싱글턴 인스턴스 생성
let sharedAnalytics = AnalyticsManager()
let sharedCache = CacheManager()

await DependencyContainer.bootstrap { container in
    // 동일한 인스턴스 등록 - 싱글턴으로 동작
    container.register(AnalyticsManager.self) { sharedAnalytics }
    container.register(CacheManager.self) { sharedCache }
}
```

### 조건부 등록

```swift
await DependencyContainer.bootstrap { container in
    // 런타임 조건에 따른 등록
    if UserDefaults.standard.bool(forKey: "useAnalytics") {
        container.register(AnalyticsService.self) {
            GoogleAnalyticsService()
        }
    } else {
        container.register(AnalyticsService.self) {
            NoOpAnalyticsService()
        }
    }
}
```

## AppDIContainer 활용

AppDIContainer는 대규모 애플리케이션을 위한 체계적인 DI 관리 시스템입니다:

```swift
@main
struct MyApp: App {
    init() {
        Task {
            await AppDIContainer.shared.registerDependencies { container in
                // Repository 모듈 등록
                var repoFactory = AppDIContainer.shared.repositoryFactory
                repoFactory.registerDefaultDefinitions()

                await repoFactory.makeAllModules().asyncForEach { module in
                    await container.register(module)
                }

                // UseCase 모듈 등록
                let useCaseFactory = AppDIContainer.shared.useCaseFactory
                await useCaseFactory.makeAllModules().asyncForEach { module in
                    await container.register(module)
                }
            }
        }
    }
}
```

## 다음 단계

- <doc:모듈시스템>에서 대규모 의존성 그래프 구성 방법 학습
- <doc:액터홉최적화>에서 최대 성능을 위한 최적화 기법 탐구
- <doc:프로퍼티래퍼>에서 @Inject, @Factory 등의 활용법 이해
- <doc:플러그인시스템>에서 확장 가능한 아키텍처 구축 방법 학습
