# 코어 API 가이드

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

## 베스트 프랙티스

1. **UnifiedDI 사용**: 대부분의 시나리오에 권장
2. **최적화 활성화**: 성능이 중요한 앱에서 최적화 모드 사용
3. **프로퍼티 래퍼 활용**: 깔끔한 코드를 위해 프로퍼티 래퍼 사용
4. **에러 처리**: SafeInject로 우아한 에러 처리

## 관련 문서

- [Property Wrappers](/ko/guide/propertyWrappers) - 프로퍼티 래퍼 상세 가이드
- [Runtime Optimization](/ko/guide/runtimeOptimization) - 성능 최적화
- [UnifiedDI](/ko/guide/unifiedDi) - 고급 UnifiedDI 기능
