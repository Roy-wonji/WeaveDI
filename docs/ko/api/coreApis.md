---
title: CoreAPIs
lang: ko-KR
---

# 코어 API 가이드

> Language: 한국어 | English: 

WeaveDI 2.0의 핵심 API들과 사용법을 자세히 알아보세요.

> 공지: 동기 API → async API 전환 (중요)
>
> - UnifiedRegistry의 동기 해석 API는 제거되었습니다. 모든 해석은 async API(`resolveAsync`, `resolveAnyAsync`, `resolveAnyAsyncBox`, `resolveAsync(keyPath:)`)를 사용하세요.
> - 의존성 그래프 시각화의 동기 API도 제거되었습니다. async API(`generateDOTGraphAsync`, `generateMermaidGraphAsync`, `generateASCIIGraphAsync`, `generateJSONGraphAsync`)를 사용하세요.
> - 기존 코드는 `await`를 붙여 async 버전으로 전환하시기 바랍니다.

## 개요

WeaveDI 2.0은 세 가지 핵심 패턴을 중심으로 설계되었습니다:
1. **등록 (Registration)** - 의존성을 컨테이너에 등록
2. **주입 (Injection)** - 프로퍼티 래퍼를 통한 자동 주입
3. **해결 (Resolution)** - 수동으로 의존성 해결

## 등록 API (Registration)

### UnifiedDI 빠른 레퍼런스

```swift
// 기본 등록
UnifiedDI.register(Service.self) { ServiceImpl() }

// 조건부 등록
UnifiedDI.registerIf(Analytics.self, condition: isProd,
                     factory: { FirebaseAnalytics() },
                     fallback: { NoOpAnalytics() })

// 스코프 등록 (동기/비동기)
UnifiedDI.registerScoped(UserService.self, scope: .session) { UserServiceImpl() }
UnifiedDI.registerAsyncScoped(ProfileCache.self, scope: .screen) { await ProfileCache.make() }

// 해제 (전체/스코프/특정 타입-스코프)
UnifiedDI.release(Service.self)
UnifiedDI.releaseScope(.session, id: userID)
UnifiedDI.releaseScoped(UserService.self, kind: .session, id: userID)
```

### DI(단순화) 빠른 레퍼런스

```swift
// 기본 등록
DI.register(Service.self) { ServiceImpl() }

// 조건부 등록
DI.registerIf(Service.self, condition: flag,
              factory: { RealService() },
              fallback: { MockService() })

// 스코프 등록 (동기/비동기)
DI.registerScoped(UserService.self, scope: .request) { UserServiceImpl() }
DI.registerAsyncScoped(RequestContext.self, scope: .request) { await RequestContext.create() }

// 해제 (전체/스코프/특정 타입-스코프)
DI.release(Service.self)
DI.releaseScope(.request, id: requestID)
DI.releaseScoped(UserService.self, kind: .request, id: requestID)
```

### WeaveDI.Container.bootstrap

가장 일반적인 등록 방법입니다:

```swift
await WeaveDI.Container.bootstrap { container in
    // 타입 등록
    container.register(UserService.self) {
        UserServiceImpl()
    }

    // KeyPath를 사용한 타입 안전 등록
    container.register(\.userService) {
        UserServiceImpl()
    }
}
```

### AppDIContainer를 통한 대규모 등록

복잡한 애플리케이션에서는 AppDIContainer를 사용하세요:

```swift
await AppDIContainer.shared.registerDependencies { container in
    // Repository 계층 등록
    var repositoryFactory = AppDIContainer.shared.repositoryFactory
    repositoryFactory.registerDefaultDefinitions()

    await repositoryFactory.makeAllModules().asyncForEach { module in
        await container.register(module)
    }

    // UseCase 계층 등록
    let useCaseFactory = AppDIContainer.shared.useCaseFactory
    await useCaseFactory.makeAllModules().asyncForEach { module in
        await container.register(module)
    }
}
```

### 모듈 기반 등록

모듈을 사용한 체계적인 등록:

```swift
// 모듈 정의
struct UserModule: Module {
    func registerDependencies() async {
        DI.register(UserRepository.self) {
            CoreDataUserRepository()
        }

        DI.register(UserService.self) {
            UserServiceImpl()
        }
    }
}

// 모듈 등록
await WeaveDI.Container.bootstrap { container in
    await container.register(UserModule())
}
```

## 주입 API (Injection)

### @Inject 프로퍼티 래퍼

가장 일반적인 의존성 주입 방법입니다:

```swift
class UserViewModel {
    // 옵셔널 주입 - 등록되지 않은 경우 nil
    @Inject var userService: UserService?

    // 필수 타입 - 등록되지 않은 경우 기본값 사용
    @Inject var userService: UserService = UserServiceImpl()

    func loadUser() async {
        guard let service = userService else { return }
        let user = try await service.getCurrentUser()
        // ...
    }
}
```

### @RequiredInject 프로퍼티 래퍼

반드시 등록되어야 하는 의존성에 사용:

```swift
class UserViewController: UIViewController {
    // 등록되지 않은 경우 fatalError 발생
    @RequiredInject var userService: UserService

    override func viewDidLoad() {
        super.viewDidLoad()
        // userService는 항상 사용 가능
        loadUserData()
    }
}
```

### @Factory 프로퍼티 래퍼

팩토리 패턴을 통한 복잡한 의존성 관리:

```swift
extension FactoryValues {
    var userServiceFactory: Factory<UserService> {
        Factory(this) {
            UserServiceImpl()
        }
    }
}

class UserManager {
    @Factory(\.userServiceFactory)
    var userService: UserService
}
```

## 해결 API (Resolution)

### DI 글로벌 해결자

간단한 의존성 해결:

```swift
// 옵셔널 해결
let userService: UserService? = DI.resolve(UserService.self)

// 기본값과 함께 해결
let userService = DI.resolve(UserService.self) ?? UserServiceImpl()

// 필수 해결 (등록되지 않은 경우 fatalError)
let userService: UserService = DI.requireResolve(UserService.self)

// Result 타입으로 에러 처리
let result = DI.resolveResult(UserService.self)
switch result {
case .success(let service):
    // 사용
case .failure(let error):
    Log.error("해결 실패: \(error)")
}
```

### UnifiedDI 통합 해결자

성능 최적화된 해결 방법:

```swift
// 동기 해결
let userService: UserService? = UnifiedDI.resolve(UserService.self)

// 비동기 해결 (Actor Hop 최적화)
let userService: UserService? = await UnifiedDI.resolveAsync(UserService.self)

// KeyPath를 통한 타입 안전 해결
extension WeaveDI.Container {
    var userService: UserService? {
        resolve(UserService.self)
    }
}

let service = UnifiedDI.resolve(\.userService)
```

### DIAsync 비동기 특화 해결자

비동기 컨텍스트에 최적화:

```swift
// 비동기 해결
let userService: UserService? = await DIAsync.resolve(UserService.self)

// 필수 비동기 해결
let userService: UserService = await DIAsync.requireResolve(UserService.self)

// 비동기 Result 해결
let result = await DIAsync.resolveResult(UserService.self)
```

## 고급 API 패턴

### 스코프 등록과 사용 (.screen / .session / .request)

의존성을 화면/세션/요청 단위로 격리하고 캐시하려면 스코프 API를 사용하세요.

```swift
// 현재 스코프 설정 (예: 세션 시작 시)
ScopeContext.shared.setCurrent(.session, id: "user-123")

// 스코프 기반 등록 (동기)
await WeaveDI.Container.bootstrap { _ in
    await GlobalUnifiedRegistry.registerScoped(UserService.self, scope: .session) {
        UserServiceImpl()
    }
}

// 스코프 기반 등록 (비동기)
await GlobalUnifiedRegistry.registerAsyncScoped(ProfileCache.self, scope: .screen) {
    await ProfileCache.make()
}

// 해결은 기존과 동일 (현재 스코프 id가 있으면 스코프 캐시 사용)
let userService: UserService? = UnifiedDI.resolve(UserService.self)

// 스코프 해제 (예: 화면 종료, 세션 만료 시)
ScopeContext.shared.clear(.session)
```

> 팁: View/Screen 진입/이탈 시점에 `.screen` 스코프를 set/clear 하고, 로그인/로그아웃 등 세션 이벤트에 `.session` 스코프를 set/clear 하세요.

### 비동기 싱글톤 등록 (최초 1회 생성 후 재사용)

네트워크/디스크 의존성을 비동기로 안전하게 1회만 초기화하고 이후 재사용합니다.

```swift
// 최초 1회만 생성, 동시 호출도 1회 생성으로 병합
await GlobalUnifiedRegistry.registerAsyncSingleton(RemoteConfig.self) {
    await RemoteConfig.fetch()
}

// 어디서든 사용
let config: RemoteConfig? = await UnifiedDI.resolveAsync(RemoteConfig.self)
```

내부적으로 in-flight Task 캐시를 사용하여 동시 초기화를 방지합니다.

### 조건부 등록 및 해결

```swift
await WeaveDI.Container.bootstrap { container in
    // 환경에 따른 조건부 등록
    #if DEBUG
    container.register(LoggerService.self) {
        ConsoleLogger()
    }
    #else
    container.register(LoggerService.self) {
        FileLogger()
    }
    #endif

    // 런타임 조건부 등록
    if ProcessInfo.processInfo.environment["USE_MOCK"] == "true" {
        container.register(NetworkService.self) {
            MockNetworkService()
        }
    } else {
        container.register(NetworkService.self) {
            URLSessionNetworkService()
        }
    }
}
```

### 생명주기 관리

```swift
// 싱글턴 등록
let sharedCache = CacheManager()
await WeaveDI.Container.bootstrap { container in
    container.register(CacheManager.self) { sharedCache }
}

// 매번 새 인스턴스 생성
await WeaveDI.Container.bootstrap { container in
    container.register(RequestHandler.self) {
        RequestHandler() // 매번 새로 생성
    }
}
```

### 순환 의존성 탐지와 문서화

```swift
// 탐지 활성화
CircularDependencyDetector.shared.setDetectionEnabled(true)

// 그래프 산출 (개발/CI에서)
let dot = await DependencyGraphVisualizer.generateDOTGraphAsync(title: "Dependencies")
let mermaid = await DependencyGraphVisualizer.generateMermaidGraphAsync(title: "Dependencies")
```

### 실시간 그래프 업데이트 토글

의존성 그래프는 기본적으로 “실시간(diff + 디바운스)”으로 업데이트됩니다. 필요 시 토글로 끄고/켜세요.

```swift
// 실시간 업데이트 끄기 (그래프 반영 지연/미반영)
AutoDIOptimizer.shared.setRealtimeGraphEnabled(false)

// 다시 켜기 (즉시 1회 동기화 후, 디바운스 100ms로 실시간 반영)
AutoDIOptimizer.shared.setRealtimeGraphEnabled(true)
```

설명:
- 기본값은 true (자동 실시간 업데이트)
- 내부적으로 변경된 엣지만 반영하는 diff 방식 + 100ms 디바운스 적용
- 대규모 그래프/빈번한 등록 환경에서 성능 최적화를 위해 false로 두고, 필요 시 수동 시각화만 수행할 수 있습니다

### 의존성 체인 관리

```swift
await WeaveDI.Container.bootstrap { container in
    // 하위 의존성 먼저 등록
    container.register(NetworkService.self) {
        URLSessionNetworkService()
    }

    container.register(CacheService.self) {
        CacheServiceImpl()
    }

    // 상위 의존성은 하위 의존성을 자동 주입받음
    container.register(UserService.self) {
        UserServiceImpl() // @Inject로 자동 주입
    }
}
```

### 타입 별칭과 추상화

```swift
// 추상 타입으로 등록
protocol DatabaseService {
    func save(_ data: Data) async throws
    func load() async throws -> Data
}

await WeaveDI.Container.bootstrap { container in
    // 구체 타입을 추상 타입으로 등록
    container.register(DatabaseService.self) {
        CoreDataService() // DatabaseService 구현체
    }
}

class DataManager {
    @Inject var database: DatabaseService? // 추상 타입으로 주입
}
```

## 에러 처리 및 디버깅

### 해결 실패 처리

```swift
// Result 타입으로 안전하게 처리
let result = DI.resolveResult(UserService.self)
switch result {
case .success(let service):
    // 정상적으로 해결됨
    try await service.getCurrentUser()
case .failure(let error):
    // 해결 실패 - 로깅하고 기본값 사용
    logger.error("UserService 해결 실패: \(error)")
    let fallbackService = UserServiceImpl()
    try await fallbackService.getCurrentUser()
}
```

### 런타임 검증

```swift
#if DEBUG
// 개발 중에는 필수 의존성 검증
class AppValidator {
    static func validateDependencies() async {
        let requiredServices: [Any.Type] = [
            UserService.self,
            NetworkService.self,
            CacheService.self
        ]

        for serviceType in requiredServices {
            let result = DI.resolveResult(serviceType)
            switch result {
            case .success:
                Log.debug("✅ \(serviceType) 등록됨")
            case .failure(let error):
                Log.error("❌ \(serviceType) 등록 실패: \(error)")
                assertionFailure("필수 의존성 누락")
            }
        }
    }
}

// 앱 시작 시 검증
await AppValidator.validateDependencies()
#endif
```

## 성능 최적화

### Actor Hop 최적화 활용

```swift
// 비동기 컨텍스트에서는 Async API 사용
actor UserActor {
    func processUser() async {
        // Actor 내부에서는 DIAsync 사용으로 홉 최적화
        let userService = await DIAsync.resolve(UserService.self)
        await userService?.processUserData()
    }
}

// MainActor에서는 UnifiedDI 사용
@MainActor
class UserViewController: UIViewController {
    func updateUI() async {
        // MainActor에서 최적화된 해결
        let userService = await UnifiedDI.resolveAsync(UserService.self)
        // UI 업데이트
    }
}
```

### 지연 해결 패턴

```swift
class LazyServiceConsumer {
    // 처음 접근할 때까지 해결을 지연
    private lazy var userService: UserService? = {
        DI.resolve(UserService.self)
    }()

    func processWhenNeeded() async {
        guard let service = userService else { return }
        try await service.processData()
    }
}
```

## 다음 단계

- <doc:ModuleSystem>
- <doc:PropertyWrappers>
- <doc:AutoDIOptimizer>
- <doc:ModuleFactory>
### UnifiedDI/DI 사용 요약

```swift
// UnifiedDI
let svc1: Service? = UnifiedDI.resolve(Service.self)
let svc2: Service = UnifiedDI.requireResolve(Service.self)
let svc3: Service = try UnifiedDI.resolveThrows(Service.self)
let svc4: Service = UnifiedDI.resolve(Service.self, default: MockService())

// DI(단순화)
let s1: Service? = DI.resolve(Service.self)
let s2: Result<Service, DIError> = DI.resolveResult(Service.self)
let s3: Service = try DI.resolveThrows(Service.self)
```
