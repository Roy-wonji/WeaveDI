# DiContainer 2.0.0 마이그레이션 가이드

DiContainer 1.x에서 2.0.0으로 업그레이드하는 완전한 가이드

## 개요

DiContainer 2.0.0은 Swift Concurrency를 완전히 수용하고, Actor Hop 최적화를 도입한 메이저 업데이트입니다. 이 가이드는 기존 1.x 코드를 새 버전으로 안전하고 효율적으로 마이그레이션하는 방법을 제공합니다.

## 한눈에 보는 주요 변화

### ✅ 새로운 기능
- **통합 DI API**: `UnifiedDI`, `DI`, `DIAsync` 3가지 레벨의 API 제공
- **부트스트랩 시스템**: 안전한 앱 초기화를 위한 `DependencyContainer.bootstrap`
- **Actor Hop 최적화**: Swift Concurrency와 완벽 호환되는 성능 최적화
- **강화된 Property Wrapper**: `@Inject`, `@RequiredInject`, `@Factory` 지원
- **AppDIContainer**: 앱 수준의 의존성 관리를 위한 통합 컨테이너
- **ModuleFactory 시스템**: Repository, UseCase, Scope 팩토리 패턴

### 🔄 변경된 API
- `DependencyContainer.live.register` → `UnifiedDI.register` 또는 `DI.register`
- `RegisterAndReturn.register` → `UnifiedDI.register` 또는 KeyPath 기반 등록
- Property Wrapper 통합: `@Inject` 하나로 옵셔널/필수 모두 지원
- 부트스트랩 시스템: 앱 시작 시 반드시 `bootstrap` 호출 필요

## 빠른 치트시트(이전 → 이후)

| 1.x(이전) | 2.0.0(이후) |
| --- | --- |
| `DependencyContainer.live.register(T.self) { ... }` | `DI.register(T.self) { ... }` |
| `DependencyContainer.live.resolve(T.self)` | `DI.resolve(T.self)` 또는 `await DIAsync.resolve(T.self)` |
| `RegisterAndReturn.register(\.key) { ... }` | `DI.register(\.key) { ... }` 또는 `await DIAsync.register(\.key) { ... }` |
| 직접 싱글턴 캐시 관리 | `DI.registerSingleton(T.self, instance:)` 사용 |
| GCD 기반 일괄 등록 | `await DIAsync.registerMany { ... }` (TaskGroup 병렬) |
| 복합 락 + 임시 부트스트랩 | `DependencyContainer.bootstrap(…)`으로 단일 경로 고정 |

## 부트스트랩(bootstrap) 왜 필요한가, 어떻게 쓰는가

앱이 의존성을 사용하기 전, 안전하게 한 번에 초기화하기 위함입니다. 내부적으로는 actor를 통해 초기화 경합을 직렬화하고, live 컨테이너 교체를 원자적으로 수행합니다.

```swift
// 동기 초기 등록
await DependencyContainer.bootstrap { c in
  c.register(Logger.self) { ConsoleLogger() }
  c.register(Config.self) { AppConfig() }
}

// 비동기 초기 등록(예: DB 오픈, 원격 설정 로드)
await DependencyContainer.bootstrapAsync { c in
  let db = await Database.open()
  c.register(Database.self, instance: db)
}
```

부트스트랩 전에 `resolve`/`@Inject`가 호출되면 크래시 또는 실패가 발생할 수 있습니다. 앱 시작 진입점에서 반드시 부트스트랩을 호출하세요.

## KeyPath 기반 등록/해결

가독성과 타입 안전성을 동시에 제공합니다.

```swift
extension DependencyContainer {
  var bookListInterface: BookListInterface? { resolve(BookListInterface.self) }
}

// 동기: 생성과 동시에 싱글톤으로 등록하고 반환
let repo = DI.register(\.bookListInterface) { BookListRepositoryImpl() }

// 비동기: 생성과 동시에 싱글톤으로 등록하고 반환
let repo2 = await DIAsync.register(\.bookListInterface) { await BookListRepositoryImpl.make() }

// 이미 있으면 재생성하지 않음(idempotent)
let repo3 = await DIAsync.getOrCreate(\.bookListInterface) { await BookListRepositoryImpl.make() }
```

## 프로퍼티 래퍼 변화

- `@Inject(\.keyPath)` 하나로 옵셔널/필수 모두 지원됩니다.
  - 변수 타입이 Optional이면 미등록 시 `nil` 반환
  - 변수 타입이 Non-Optional이면 미등록 시 명확한 메시지로 `fatalError`
- 더 엄격한 필수 의존성에는 `@RequiredDependency(\.keyPath)`를 사용하세요.

기존 `@ContainerRegister` 같은 래퍼를 사용했다면 `@Inject` 또는 `@RequiredDependency`로 교체하는 것을 권장합니다.

## Module 과 Container

- `Module`은 더 가벼운 구조로, 내부 등록 클로저는 `@Sendable`로 정의됩니다.
- `Container`는 다음 빌드 API를 제공합니다.
  - `await build()` — 비-throwing 기본 빌드
  - `await buildWithMetrics()` — 수행 시간/처리량 메트릭 수집
  - `await buildWithResults()` — 성공/실패 상세 리포트
  - `try await buildThrowing()` — throwing 등록을 위한 확장 포인트

## DI vs DIAsync — 언제 무엇을 쓰나

- 동기 팩토리라면 `DI`를, 비동기 팩토리/병렬 일괄 등록이 필요하면 `DIAsync`를 사용하세요.

```swift
// DI (sync)
DI.register(Service.self) { ServiceImpl() }
let s = DI.resolve(Service.self)

// DIAsync (async)
await DIAsync.register(Service.self) { await ServiceImpl.make() }
let s2 = await DIAsync.resolve(Service.self)

// 등록 여부 확인
let ok = DI.isRegistered(Service.self)
let ok2 = await DIAsync.isRegistered(Service.self)
```

## UnifiedDI로 단일 진입점 사용하기

팀이 `DI`/`DIAsync` 대신 하나의 API로 통일하고 싶다면 `UnifiedDI`를 권장합니다. 내부적으로는 `DependencyContainer.live`를 사용하여 타입 안전한 등록/해결을 제공합니다.

치트시트(이전 → UnifiedDI)

- `DI.register(T.self) { ... }` → `UnifiedDI.register(T.self) { ... }`
- `DI.resolve(T.self)` → `UnifiedDI.resolve(T.self)`
- `DI.requireResolve(T.self)` → `UnifiedDI.requireResolve(T.self)`
- `DI.resolve(T.self, default: …)` → `UnifiedDI.resolve(T.self, default: …)`
- `DI.registerMany { … }` → `UnifiedDI.registerMany { … }`
- `DIAsync.registerMany { … }` → 비동기 초기화가 필요하면 `DependencyContainer.bootstrapAsync` 안에서 인스턴스를 만든 뒤 `container.register(_:instance:)`로 등록하거나, 생성 이후 `UnifiedDI.register`/`DependencyContainer.live.register`로 등록하세요.

예시

```swift
// 등록
UnifiedDI.register(ServiceProtocol.self) { ServiceImpl() }

// KeyPath 등록
let repo = UnifiedDI.register(\.userRepository) { UserRepositoryImpl() }

// 해결
let s1 = UnifiedDI.resolve(ServiceProtocol.self)
let s2 = UnifiedDI.requireResolve(ServiceProtocol.self)
let logger = UnifiedDI.resolve(LoggerProtocol.self, default: ConsoleLogger())

// 배치 등록
UnifiedDI.registerMany {
  UnifiedRegistration(NetworkService.self) { DefaultNetworkService() }
  UnifiedRegistration(UserRepository.self, singleton: UserRepositoryImpl())
}
```

## 동시성 주의사항(Swift 6)

- `@Sendable` 클로저 안에서 non-Sendable 상태를 캡처하지 마세요. 필요 시 값 스냅샷/`Sendable` 채택을 고려하세요.
- `Container.build`는 작업 생성 전에 스냅샷을 만들어 actor hop 비용을 줄입니다.

## 주요 변경점(브레이킹)과 대체 방법

1) 수동 등록/해결 진입점 변경

```swift
// 이전(1.x)
DependencyContainer.live.register(ServiceProtocol.self) { Service() }
let s = DependencyContainer.live.resolve(ServiceProtocol.self)

// 이후(2.0.0)
DI.register(ServiceProtocol.self) { Service() }
let s = DI.resolve(ServiceProtocol.self)
```

2) KeyPath 기반 등록 방식 정리

```swift
// 이전(1.x)
RegisterAndReturn.register(\.userRepository) { UserRepository() }

// 이후(2.0.0)
DI.register(\.userRepository) { UserRepository() }
// 또는 비동기 초기화 필요 시
await DIAsync.register(\.userRepository) { await UserRepository.make() }
```

3) 프로퍼티 래퍼 마이그레이션

```swift
// 이전(예: @ContainerRegister 사용)
final class UserService {
  @ContainerRegister(\.userRepository)
  private var repo: UserRepositoryProtocol
}

// 이후(2.0.0)
final class UserService {
  // Non-Optional: 미등록 시 명확한 크래시로 빠르게 발견
  @Inject(\.userRepository) var repo: UserRepositoryProtocol
  
  // Optional로 선언하면 미등록 시 nil 반환(선택적 의존성에 적합)
  // @Inject(\.userRepository) var repo: UserRepositoryProtocol?
}

// 더 엄격한 필수 의존성
final class AuthService {
  @RequiredDependency(\.authRepository) var authRepo: AuthRepositoryProtocol
}
```

4) 일괄 등록(배치) — GCD → Concurrency

```swift
await DIAsync.registerMany {
  DIAsyncRegistration(ServiceA.self) { await ServiceA.make() }
  DIAsyncRegistration(ServiceB.self) { ServiceB() }
  DIAsyncRegistration(\.userRepository) { await UserRepository.make() }
}
```

## 마이그레이션 단계별 가이드

### 1단계: API 선택 및 통일

팀의 선호에 따라 다음 중 하나를 선택하세요:

#### 옵션 A: UnifiedDI (최신 및 추천)
```swift
// 모든 의존성 작업을 UnifiedDI로 통일
UnifiedDI.register(ServiceProtocol.self) { ServiceImpl() }
let service = UnifiedDI.resolve(ServiceProtocol.self)
```

#### 옵션 B: DI/DIAsync 분리 사용
```swift
// 동기 작업은 DI
DI.register(ServiceProtocol.self) { ServiceImpl() }

// 비동기 작업은 DIAsync
await DIAsync.register(ServiceProtocol.self) { await ServiceImpl.make() }
```

### 2단계: 등록 방식 업데이트

```swift
// 이전
DependencyContainer.live.register(ServiceProtocol.self) { ServiceImpl() }
RegisterAndReturn.register(\.userRepository) { UserRepository() }

// 이후
UnifiedDI.register(ServiceProtocol.self) { ServiceImpl() }
UnifiedDI.register(\.userRepository) { UserRepository() }
```

### 3단계: 부트스트랩 시스템 도입

```swift
// 앱 시작점에서 반드시 호출
@main
struct MyApp: App {
    init() {
        Task {
            await DependencyContainer.bootstrap { container in
                // 모든 의존성 등록
                container.register(LoggerProtocol.self) { Logger() }
                container.register(NetworkProtocol.self) { NetworkService() }
            }
        }
    }
}
```

### 4단계: Property Wrapper 업데이트

```swift
// 이전
@ContainerRegister(\.userRepository) var repo: UserRepositoryProtocol

// 이후 - 옵션 1: 옵셔널 주입 (안전)
@Inject(\.userRepository) var repo: UserRepositoryProtocol?

// 이후 - 옵션 2: 필수 주입 (빠른 실패 발견)
@RequiredInject(\.userRepository) var repo: UserRepositoryProtocol
```

### 5단계: 테스트 코드 업데이트

```swift
class MyTests: XCTestCase {
    override func setUp() async throws {
        await super.setUp()

        // 테스트 컨테이너 리셋
        await DependencyContainer.resetForTesting()

        // 테스트용 의존성 등록
        await DependencyContainer.bootstrap { container in
            container.register(ServiceProtocol.self) { MockService() }
        }
    }

    override func tearDown() async throws {
        UnifiedDI.releaseAll()
        await super.tearDown()
    }
}
```

### 6단계: 고급 기능 활용 (AppDIContainer)

대규모 프로젝트에서는 AppDIContainer를 활용하세요:

```swift
// AppDIContainer 활용
await AppDIContainer.shared.registerDefaultDependencies()

// 또는 커스텀 등록
await AppDIContainer.shared.registerDependencies { container in
    var repositoryFactory = AppDIContainer.shared.repositoryFactory
    repositoryFactory.registerDefaultDefinitions()

    await repositoryFactory.makeAllModules().asyncForEach { module in
        await container.register(module)
    }
}
```

## AutoResolver 메모와 옵션

- 2.0.0에서는 AutoResolver가 메인 액터에서 동작하여 UI/주입 안전성을 높였습니다.
- 자동 해석을 전체 끄거나, 특정 타입만 제외할 수 있습니다.

```swift
// 전체 토글
AutoDependencyResolver.enable()
AutoDependencyResolver.disable()

// 타입별 제외/해제
AutoDependencyResolver.excludeType(UserService.self)
AutoDependencyResolver.includeType(UserService.self)
```

- 문자열 기반 공통 타입 매핑은 제거되었습니다. `@AutoResolve` 또는 명시적 등록을 사용해 타입을 알려주세요.

## TCA 통합 코드 예(업데이트)

```swift
import ComposableArchitecture
import DiContainer

extension UserUseCase: DependencyKey {
  public static var liveValue: UserUseCaseProtocol = {
    // 등록되어 있으면 resolve, 없으면 기본 구현을 등록하며 사용
    let repository = ContainerRegister.register(\.userRepository) { DefaultUserRepository() }
    return UserUseCase(repository: repository)
  }()
}

extension DependencyValues {
  var userUseCase: UserUseCaseProtocol {
    get { self[UserUseCase.self] }
    set { self[UserUseCase.self] = newValue }
  }
}
```

---

특정 코드 조각의 변환이 필요하다면, 스니펫을 공유해 주세요. 2.0.0 스타일로 정확히 바꿔드립니다.
