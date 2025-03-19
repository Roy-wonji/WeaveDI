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
        .package(url: "git@github.com:Roy-wonji/DiContainer.git", from: "1.0.0")
    ],
    ...
)
```
```swift
import DiContainer
```

## 사용 방법</br>
### AppDIContainer 등록
먼저, UseCase 랑  Repository를  먼저 등록 합니다

```swift
import DiContainer

public final class AppDIContainer {
  public static let shared: AppDIContainer = .init()
  
  private init() {}
  
  public func registerDependencies() async {
    let container = Container() // Container 초기화
    let useCaseModuleFactory = UseCaseModuleFactory() // 팩토리 인스턴스 생성
    let repositoryModuleFactory = RepositoryModuleFactory()
    
    await container {
      repositoryModuleFactory.makeAllModules().forEach { module in
        container.register(module)
      }
      useCaseModuleFactory.makeAllModules().forEach { module in
        container.register(module)
      }
    }.build() // 등록된 모든 의존성을 처리
  }
}
```

### UseCaseModuleFactory 등록
####  Factory로 등록 할수 있게 편리하게 등록 

 ```swift
 import DiContainer
 
 struct UseCaseModuleFactory {
  let registerModule = RegisterModule()
  
  private var useCaseDefinitions: [() -> Module] {
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
  
  func makeAllModules() -> [Module] {
    useCaseDefinitions.map { $0() }
  }
}
```
 
### RepositoryModuleFactory 등록
####  Factory로 등록 할수 있게 편리하게 등록 

 ```swift
 import DiContainer
 
 struct RepositoryModuleFactory {
  private  let registerModule = RegisterModule()
  
  private var repositoryDefinitions: [() -> Module] {
    return [
      registerModule.makeDependency(
        AuthRepositoryProtocol.self) { AuthRepository() },
      registerModule.makeDependency(FireStoreRepositoryProtocol.self) { FireStoreRepository() },
      registerModule.makeDependency(QrCodeRepositoryProtcol.self) { QrCodeRepository() },
      registerModule.makeDependency(SignUpRepositoryProtcol.self) { SignUpRepository() }
    ]
  }
  
  func makeAllModules() -> [Module] {
    repositoryDefinitions.map { $0() }
  }
}
```

### 앱 실행 부분 호출 
#### AppDelegate 에서 호출 

``` swift
  
  import Foundation
  
  class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    registerDependencies()
    return true
  }
  
 
  
 fileprivate func registerDependencies() {
    Task {
      await AppDIContainer.shared.registerDependencies()
    }
  }
}
```

#### SwiftUI App 파일 에서 호출
 
``` swift
  
import SwiftUI

import ComposableArchitecture

@main
struct TestApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  
  init() {
    registerDependencies()
  }
  
  var body: some Scene {
    WindowGroup {
      let store = Store(initialState: AppReducer.State()) {
        AppReducer()
          ._printChanges()
          ._printChanges(.actionLabels)
      }
      
      AppView(store: store)
    }
  }
  
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

AsyncMoya 는 MIT 라이선스로 이용할 수 있습니다. 자세한 내용은 [라이선스](LICENSE) 파일을 참조해 주세요.<br>
AsyncMoya is available under the MIT license. See the  [LICENSE](LICENSE) file for more info.

