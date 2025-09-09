# DiContainer
DiContainer

![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
[![License](https://img.shields.io/github/license/pelagornis/PLCommand)](https://github.com/pelagornis/PLCommand/blob/main/LICENSE)
![Platform](https://img.shields.io/badge/platforms-macOS%2010.5-red)
[![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2FMonsteel%2FAsyncMoya&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false)](https://hits.seeyoufarm.com)

💁🏻‍♂️ iOS15+ 를 지원합니다.<br>

## 개요
- Swift 의존성 주입 컨테이너는 Swift 애플리케이션에서 의존성 관리를 용이하게 하기 위해 설계된 경량화되고 유연한 라이브러리입니다. 이 라이브러리는 코드베이스 전반에 걸쳐 의존성을 해결하는 구조화되고 타입 안전한 접근 방식을 제공하여 코드 재사용성, 테스트 용이성 및 유지 관리성을 향상시킵니다.


## 기능 
- 동적 모듈 등록 및 관리.
- 선언적 모듈 등록을 위한 결과 빌더 구문.
- 모듈 및 주입 키 스캐닝을 위한 디버그 유틸리티.
- 추후에 편리하게 사용할수있는 프로퍼티 레퍼 추가 예정


## 장점
✅ DiContainer을 사용하면, 의존성 코드를 좀더 간결하게 사용 할수 있어요!

## 기반
이 프로젝트는 [Swinject](https://github.com/Swinject/Swinject)을 기반으로 좀더 쉽게 사용할수 있게 구현되었습니다.<br>
보다 자세한 내용은 해당 라이브러리의 문서를 참고해 주세요

## Swift Package Manager(SPM) 을 통해 사용할 수 있어요
```swift
let package = Package(
    ...
    dependencies: [
        .package(url: "git@github.com:Roy-wonji/DiContainer.git", from: "1.0.7")
    ],
    ...
)
```
```swift
import DiContainer
```

## 사용 방법  
### AppDIContainer 등록  
먼저, UseCase와 Repository 의존성을 등록합니다.  
아래 예시는 AppDIContainer의 확장을 통해 기본 의존성(Repository, UseCase)을 DI 컨테이너에 등록하는 방법을 보여줍니다.

```swift
import DiContainer

extension AppDIContainer {
  /// 기본 의존성(Repository, UseCase)을 DI 컨테이너에 등록합니다.
  ///
  /// 이 메서드는 다음 단계를 수행합니다:
  /// 1. `RepositoryModuleFactory`와 `UseCaseModuleFactory` 인스턴스를 생성하여,
  ///    각각 Repository와 UseCase 관련 모듈들을 관리합니다.
  /// 2. Repository 모듈 팩토리에서 기본 의존성 정의를 등록합니다.
  ///    (앱 측에서는 이 기본 정의를 extension을 통해 커스터마이징할 수 있습니다.)
  /// 3. 두 팩토리의 `makeAllModules()` 메서드를 호출하여 생성된 모듈들을 DI 컨테이너(Container)에 등록합니다.
  /// 4. Factory 프로퍼티 사용해  각각 인스턴스를 생성 할수 있습니다  
  
  Factory 사용 안한 예제 
   public func registerDefaultDependencies() async {
    await registerDependencies { container in
      var repositoryFactory = RepositoryModuleFactory()
      let useCaseFactory = UseCaseModuleFactory()
      
      repositoryFactory.registerDefaultDefinitions()
      
      // asyncForEach를 사용하여 각 모듈을 비동기적으로 등록합니다.
      await repositoryFactory.makeAllModules().asyncForEach { module in
        await container.register(module)
      }
      await useCaseFactory.makeAllModules().asyncForEach { module in
        await container.register(module)
      }
    }
  }

  Factory 사용 한 예제
  
  public func registerDefaultDependencies() async {
    var repositoryFactoryCopy = self.repositoryFactory
    let useCaseFactoryCopy = self.repositoryFactory
    
    await registerDependencies {  container in
      
      // Repository 기본 의존성 정의 등록
      repositoryFactoryCopy.registerDefaultDefinitions()
      
      // Repository 모듈들을 컨테이너에 등록
      await repositoryFactory.makeAllModules().asyncForEach { module in
        await container.register(module)
      }
      
      // UseCase 모듈들을 컨테이너에 등록
      await useCaseFactory.makeAllModules().asyncForEach { module in
        await container.register(module)
      }
    }
  } 
```

### UseCaseModuleFactory 등록  
#### Factory로 등록할 수 있게 편리하게 등록  

이 확장은 `UseCaseModuleFactory`에 기본 UseCase 의존성을 등록하기 위한 computed property를 추가합니다.  
- **목적:**  
  - UseCase 관련 의존성을 Factory 방식으로 등록하여 DI 컨테이너에 주입할 준비를 합니다.
- **동작 방식:**  
  - `registerModule.makeUseCaseWithRepository`를 호출하여,  
    `AuthUseCaseProtocol` 타입의 의존성을 생성하는 클로저를 반환합니다.
  - 이 클로저는 내부적으로 `AuthRepositoryProtocol`에 대한 의존성을 주입받고,  
    생성된 Repository를 사용해 `AuthUseCase` 인스턴스를 생성합니다.
  
```swift
import DiContainer

extension UseCaseModuleFactory {
  public var useCaseDefinitions: [() -> Module] {
    return [
      registerModule.makeUseCaseWithRepository(
        AuthUseCaseProtocol.self,
        repositoryProtocol: AuthRepositoryProtocol.self,
        repositoryFallback: DefaultAuthRepository()
      ) { repo in
        AuthUseCase(repository: repo)
      }
    ]
  }
}
 ```
 
### RepositoryModuleFactory 등록  
#### Factory로 등록할 수 있게 편리하게 등록

이 확장(extension)은 `RepositoryModuleFactory`에 기본 의존성 정의를 설정하는 `registerDefaultDefinitions()` 메서드를 추가합니다.  
이를 통해, 앱에서 별도의 추가 설정 없이 기본 Repository 의존성(예: AuthRepositoryProtocol)을 DI 컨테이너에 등록할 수 있습니다.

**주요 동작:**

- **로컬 변수에 복사:**  
  `registerModule` 프로퍼티를 `registerModuleCopy`라는 로컬 변수에 복사합니다.  
  이렇게 하면 클로저 내부에서 `self`를 직접 캡처하지 않아, 값 타입인 `RepositoryModuleFactory`에서 발생할 수 있는 캡처 문제를 방지할 수 있습니다.

- **즉시 실행 클로저 사용:**  
  클로저를 즉시 실행하여 반환된 배열을 `repositoryDefinitions`에 할당합니다.  
  이 배열은 기본 의존성 정의들을 포함하며, 여기서는 `AuthRepositoryProtocol` 타입에 대해 `AuthRepository` 인스턴스를 생성하는 정의가 등록됩니다.

**코드 예시:**

```swift
import DiContainer

extension RepositoryModuleFactory {
  /// 기본 의존성 정의를 설정하는 함수입니다.
  ///
  /// 이 메서드는 RepositoryModuleFactory의 기본 의존성 정의(repositoryDefinitions)를 업데이트합니다.
  /// - 먼저, `registerModule` 프로퍼티를 로컬 변수 `registerModuleCopy`에 복사하여 self를 직접 캡처하지 않고 사용합니다.
  /// - 그 후, 클로저를 즉시 실행하여, 반환값(여기서는 AuthRepositoryProtocol에 대한 의존성 정의 배열)을
  ///   `repositoryDefinitions`에 할당합니다.
  ///
  /// 이 예제에서는 AuthRepositoryProtocol 타입의 의존성을 등록하고, 이 의존성은 AuthRepository 인스턴스를 생성합니다.
  public mutating func registerDefaultDefinitions() {
    let registerModuleCopy = registerModule  // self를 직접 캡처하지 않고 복사합니다.
    repositoryDefinitions = {
      return [
        registerModuleCopy.makeDependency(AuthRepositoryProtocol.self) { AuthRepository() },
      ]
    }()
  }
}
```

### 앱 실행 부분 호출  
#### AppDelegate에서 의존성 등록 호출

아래 코드는 AppDelegate에서 앱 실행 시 DI(의존성 주입) 컨테이너에 필요한 의존성을 등록하는 예시입니다.

**주요 동작:**

- **앱 시작 시 등록:**  
  AppDelegate의 `application(_:didFinishLaunchingWithOptions:)` 메서드에서 `registerDependencies()`를 호출하여,  
  앱이 실행될 때 DI 컨테이너에 의존성이 등록되도록 합니다.

- **비동기 작업:**  
  의존성 등록 작업은 비동기적으로 수행되므로, `Task { ... }`를 사용하여 async/await 패턴으로 실행합니다.  
  이를 통해, 앱 초기화 시점에 DI 컨테이너의 의존성이 비동기적으로 등록되고, 등록이 완료될 때까지 기다릴 수 있습니다.

**코드 예시:**

```swift
import Foundation

class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 앱 실행 시 DI 컨테이너에 의존성을 등록합니다.
    registerDependencies()
    return true
  }
  
  /// 의존성 등록 작업을 비동기적으로 수행하는 함수입니다.
  /// 이 함수는 AppDIContainer의 전역 인스턴스를 사용하여 의존성 등록을 시작합니다.
  fileprivate func registerDependencies() {
    Task {
      await AppDIContainer.shared.registerDependencies()
    }
  }
}
```

### UseCase 등록 

아래 코드는 UseCase 에서 DI(의존성 주입) 을 하는 부분입니다.(with TCA)

```swift
extension AuthUseCase: DependencyKey {
  static public var liveValue: AuthUseCase = {
    let authRepository = ContainerResgister(\.authUseCase).wrappedValue
    return AuthUseCase(repository:  authRepository)
  }()
}
```

### ContainerResgister 를 프로 퍼티를 사용 하는 방법

```swift
extension DependencyContainer {
  var authUseCase: AuthUseCaseProtocol? {
    resolve(AuthRepositoryProtocol.self)
  }
}
```

#### SwiftUI App 파일에서 의존성 등록 호출

아래 코드는 SwiftUI 앱의 진입점(`@main`)에서 DI(의존성 주입) 컨테이너에 필요한 의존성을 등록하는 예시입니다.

**주요 동작:**

- **앱 초기화 시 의존성 등록:**  
  `init()`에서 `registerDependencies()`를 호출하여 앱 실행 전에 DI 컨테이너에 의존성이 등록되도록 합니다.

- **비동기 등록:**  
  `registerDependencies()` 함수는 `Task { ... }`를 사용하여 비동기적으로 의존성을 등록합니다.  
  이를 통해, 의존성 등록 작업이 앱 초기화 중에 안전하게 실행됩니다.

- **AppDelegate 연동:**  
  `@UIApplicationDelegateAdaptor`를 사용하여 기존 AppDelegate의 기능을 SwiftUI 앱과 연동합니다.  
  이 방식으로 UIKit 기반 초기화 코드와 SwiftUI 기반 코드를 함께 사용할 수 있습니다.

**코드 예시:**

```swift
import SwiftUI
import ComposableArchitecture

@main
struct TestApp: App {
  // 기존 UIKit 기반의 AppDelegate와 연동
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  
  init() {
    // 앱 초기화 시 DI 컨테이너에 의존성을 등록합니다.
    registerDependencies()
  }
  
  var body: some Scene {
    WindowGroup {
      // Composable Architecture의 Store 생성 및 주입
      let store = Store(initialState: AppReducer.State()) {
        AppReducer()
          ._printChanges()
          ._printChanges(.actionLabels)
      }
      
      // 최상위 뷰에 Store를 주입합니다.
      AppView(store: store)
    }
  }
  
  /// 비동기적으로 DI 컨테이너에 의존성을 등록하는 함수입니다.
  /// AppDIContainer의 전역 인스턴스를 사용하여 의존성 등록을 수행합니다.
  private func registerDependencies() {
    Task {
      await AppDIContainer.shared.registerDependencies()
    }
  }
}
```

###  모듈 등록 패턴 (KeyPath + TCA `DependencyKey` + `RegisterModule`)

#### 1) `DependencyContainer` 확장 — KeyPath용 접근자
```swift
extension DependencyContainer {
  var bookListInterface: BookListInterface? {
    resolve(BookListInterface.self)
  }
}
```
- **역할:** 타입 기반 `resolve(BookListInterface.self)`를 **KeyPath 프로퍼티**로 노출.  
- **이유:** `ContainerRegister(\.bookListInterface, ...)` 같은 **키패스 래퍼**가 가리킬 수 있도록 하기 위함.

---

#### 2) `DependencyKey` 채택 — TCA 의존성 브리징
```swift
extension BookListUseCaseImpl: DependencyKey {
  public static var liveValue: BookListInterface = {
    let repository = ContainerRegister(\.bookListInterface, defaultFactory: { BookListRepositoryImpl() }).wrappedValue
    return BookListUseCaseImpl(repository: repository)
  }()
}
```
- **역할:** TCA의 `DependencyValues`에서 사용할 **기본(live) 의존성**을 제공.  
- **동작:**  
  1) `ContainerRegister`로 레포지토리(`bookListInterface`) 획득  
  2) 미등록이면 `defaultFactory`로 **한 번만 생성/등록** 후 사용  
  3) 해당 레포로 `BookListUseCaseImpl` 생성해 반환  
- **전제:** `BookListUseCaseImpl`이 **`BookListInterface`를 준수**해야 반환 타입과 일치.

---

#### 3) `DependencyValues` 확장 — TCA에서 쓰는 키
```swift
public extension DependencyValues {
  var bookListUseCase: BookListInterface {
    get { self[BookListUseCaseImpl.self] }
    set { self[BookListUseCaseImpl.self] = newValue }
  }
}
```
- **역할:** `@Dependency(\.bookListUseCase)`로 **UseCase**를 주입할 수 있게 함.  
- **연결:** 위의 `DependencyKey`(`BookListUseCaseImpl.self`)와 매핑.

---

#### 4) `RegisterModule` 확장 — 선언적 모듈 정의
```swift
public extension RegisterModule {
  var bookListUseCaseImplModule: () -> Module {
    makeUseCaseWithRepository(
      BookListInterface.self,
      repositoryProtocol: BookListInterface.self,
      repositoryFallback: DefaultBookListRepositoryImpl()
    ) { repo in
      BookListUseCaseImpl(repository: repo)
    }
  }

  var bookListRepositoryImplModule: () -> Module {
    makeDependency(BookListInterface.self) {
      BookListRepositoryImpl()
    }
  }
}
```
- **역할:** DI 컨테이너에 등록할 **UseCase/Repository 모듈**을 선언적으로 제공.  
- `bookListRepositoryImplModule` → `BookListInterface` 키에 `BookListRepositoryImpl` 등록(팩토리).  
- `bookListUseCaseImplModule` → “레포 → 유스케이스” **연쇄 등록**을 헬퍼로 간결하게 작성.  
  `repositoryFallback` 제공으로 레포 미등록 시 기본 구현 사용.

---

### ✅ 어떻게 쓰나

**부트스트랩에서 모듈 등록**
```swift
await DependencyContainer.bootstrapAsync { c in
  let reg = RegisterModule()
  await c.register(reg.bookListRepositoryImplModule())
  await c.register(reg.bookListUseCaseImplModule())
}
```

**TCA 피처에서 의존성 사용**
```swift
@Reducer
struct BookListFeature {
  struct State: Equatable {}
  enum Action: Equatable { case load }

  @Dependency(\.bookListUseCase) var useCase

  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .load:
      return .run { _ in
        _ = try await useCase.getBookList()
      }
    }
  }
}
```

**컨테이너에서 직접 사용(서비스/테스트)**
```swift
let repo: BookListInterface? = DependencyContainer.live.resolve(BookListInterface.self)
let books = try await repo?.getBookList()
```

---

### ⚠️ 주의사항 / 팁
- **타입 정합성:**  
  - `liveValue`의 반환 타입(`BookListInterface`) ↔︎ `BookListUseCaseImpl`의 프로토콜 준수 관계 확인.  
  - `makeUseCaseWithRepository`의 `repositoryProtocol:`은 **레포지토리 프로토콜**을 넣는 컨벤션이 일반적.  
    현재 예시는 UseCase/Repo가 같은 프로토콜을 공유한다는 가정이므로, **설계에 따라 분리**(`…RepositoryProtocol`, `…UseCaseProtocol`)하는 게 명확할 수 있음.
- **fallback 통일:**  
  - `ContainerRegister`에선 `BookListRepositoryImpl()`, 모듈에선 `DefaultBookListRepositoryImpl()`을 쓰고 있음.  
    실제 프로젝트에선 **하나로 통일**하는 걸 권장.
- **스레드 안전:**  
  - `defaultFactory`가 **한 번만 등록**되도록 내부에서 락/배리어로 보호돼야 함(현재 컨테이너 구조면 OK).


## 부트스트랩(필수)

앱 시작 시 필요한 의존성을 한 번에 등록합니다.  
`bootstrap(_:)`, `bootstrapAsync(_:)`, `bootstrapMixed(sync:async:)`, `bootstrapIfNeeded(_:)` 중 선택하세요.  
> Swift 6 동시성 경고를 피하려면 클로저에 `@Sendable`을 붙이는 걸 권장합니다.

먼저 등록 함수들을 정의합니다:

```swift
// 동기 등록 (필수/가벼운 의존성)
private func registerSyncDependencies(_ c: DependencyContainer) {
  c.register(AuthRepositoryProtocol.self) { DefaultAuthRepository() }
  c.register(AuthUseCaseProtocol.self) {
    let repo = c.resolve(AuthRepositoryProtocol.self)!
    return AuthUseCase(repository: repo)
  }
}

// 비동기 등록 (DB, 원격설정 등 I/O)
private func registerAsyncDependencies(_ c: DependencyContainer) async {
  let db = await Database.open()
  c.register(Database.self, instance: db)

  let remote = await RemoteConfigService.load()
  c.register(RemoteConfigService.self, instance: remote)
}
```

### 동기 부트스트랩
```swift
@main
struct MyApp: App {
  init() {
    Task {
      await DependencyContainer.bootstrap { c in
        registerSyncDependencies(c)
      }
    }
  }
  var body: some Scene { WindowGroup { RootView() } }
}
```

### 비동기 부트스트랩
```swift
@main
struct MyApp: App {
  init() {
    Task {
      _ = await DependencyContainer.bootstrapAsync { c in
        registerSyncDependencies(c)
        await registerAsyncDependencies(c)
      }
    }
  }
  var body: some Scene { WindowGroup { RootView() } }
}
```

### 혼합 부트스트랩 (Sync → Async)
```swift
@main
struct MyApp: App {
  init() {
    Task { @MainActor in
      await DependencyContainer.bootstrapMixed(
        sync: { c in
          registerSyncDependencies(c)
        },
        async: { c in
          await registerAsyncDependencies(c)
        }
      )
    }
  }
  var body: some Scene { WindowGroup { RootView() } }
}
```

### 이미 되어 있으면 스킵
```swift
Task {
  _ = await DependencyContainer.bootstrapIfNeeded { c in
    registerSyncDependencies(c)
    await registerAsyncDependencies(c)
  }
}
```

### AppDelegate에서 부트스트랩
```swift
final class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ app: UIApplication,
    didFinishLaunchingWithOptions opts: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    Task {
      _ = await DependencyContainer.bootstrapAsync { c in
        registerSyncDependencies(c)
        await registerAsyncDependencies(c)
      }
    }
    return true
  }
}
```

---

## 의존성 사용(Resolve)

```swift
let auth: AuthUseCaseProtocol = DependencyContainer.live
  .resolve(AuthUseCaseProtocol.self)!

let user = try await auth.signIn(id: "roy", pw: "•••")
```

> 기본값이 필요하면:
```swift
let logger = DependencyContainer.live.resolveOrDefault(
  LoggerProtocol.self,
  default: ConsoleLogger()
)
```

---

## 런타임 업데이트

앱 실행 중 특정 의존성을 교체해야 할 때 사용합니다.

```swift
// 동기
await DependencyContainer.update { c in
  c.register(LoggerProtocol.self) { FileLogger() }
}

// 비동기
await DependencyContainer.updateAsync { c in
  let newDB = await Database.open(path: "test.sqlite")
  c.register(Database.self, instance: newDB)
}
```

---

## 부트스트랩 보장 & 상태 확인

```swift
// 접근 전 보장(개발 빌드에서 precondition)
await DependencyContainer.ensureBootstrapped()

// 상태 확인
let ok = await DependencyContainer.isBootstrapped
```

---

## 테스트 초기화

```swift
#if DEBUG
await DependencyContainer.resetForTesting()

// 더블/스텁 등록
DependencyContainer.live.register(AuthRepositoryProtocol.self) {
  StubAuthRepository()
}
#endif
```

---

## 선택: KeyPath 스타일 접근

타입 기반 레지스트리를 쓰더라도, KeyPath 형태를 선호하면 아래처럼 매핑할 수 있습니다.

```swift
// 컨테이너 확장: 키패스에서 resolve로 위임
extension DependencyContainer {
  var authRepository: AuthRepositoryProtocol? { resolve(AuthRepositoryProtocol.self) }
  var authUseCase:   AuthUseCaseProtocol?    { resolve(AuthUseCaseProtocol.self) }
}

// 사용 예
let useCase: AuthUseCaseProtocol? = DependencyContainer.live[\.authUseCase]
```

> 반환 타입과 `resolve` 타입을 반드시 일치시켜 주세요.

---

## TCA/SwiftUI 예시

```swift
import ComposableArchitecture
import DiContainer

@Reducer
struct LoginFeature {
  @Dependency(\.continuousClock) var clock

  struct State: Equatable { var id = "" ; var pw = "" }
  enum Action: Equatable { case signInTapped ; case signedIn(Result<User, Error>) }

  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .signInTapped:
      return .run { send in
        // DiContainer에서 직접 resolve
        let auth = DependencyContainer.live.resolve(AuthUseCaseProtocol.self)!
        do {
          let user = try await auth.signIn(id: state.id, pw: state.pw)
          await send(.signedIn(.success(user)))
        } catch {
          await send(.signedIn(.failure(error)))
        }
      }
    case .signedIn:
      return .none
    }
  }
}
```


### Log Use
로그 관련 사용은 [LogMacro](https://github.com/Roy-wonji/LogMacro) 해당 라이브러리에 문서를 참고 해주세요. <br>


## Auther
서원지(Roy) [suhwj81@gmail.com](suhwj81@gmail.com)


## 함께 만들어 나가요

개선의 여지가 있는 모든 것들에 대해 열려있습니다.<br>
PullRequest를 통해 기여해주세요. 🙏


## 기여
Swift 의존성 주입 컨테이너에 대한 기여는 언제나 환영합니다. 다음과 같은 방식으로 기여할 수 있습니다.
- 이슈 보고
- 기능 개선 제안
- 버그 수정 또는 새로운 기능을 위한 풀 요청 제출
- 새로운 기능을 추가할 때는 코딩 표준을 따르고 테스트를 작성해 주시기 바랍니다.
## License

DiContainer 는 MIT 라이선스로 이용할 수 있습니다. 자세한 내용은 [라이선스](LICENSE) 파일을 참조해 주세요.<br>
DiContainer is available under the MIT license. See the  [LICENSE](LICENSE) file for more info.

