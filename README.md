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

