---
title: ModuleFactory
lang: en-US
---

# ModuleFactory

모든 모듈 팩토리의 공통 인터페이스입니다.
Repository, UseCase, Scope 모듈을 통합하여 중복을 제거합니다.

```swift
public protocol ModuleFactory {
  /// 모듈 생성 시 필요한 의존성 등록 헬퍼
  var registerModule: RegisterModule { get }
}
```

  /// 모듈을 생성하는 클로저들의 배열 (Sendable)
  /// 모든 모듈 인스턴스를 생성합니다

```swift
public extension ModuleFactory {
  func makeAllModules() -> [Module] {
    return definitions.map { $0() }
  }
}
```

Repository 계층 모듈 팩토리

```swift
public struct RepositoryModuleFactory: ModuleFactory, Sendable {
  public let registerModule = RegisterModule()
  public var definitions: [@Sendable () -> Module] = []
}
```

  /// Repository 의존성을 쉽게 추가하는 헬퍼
UseCase 계층 모듈 팩토리

```swift
public struct UseCaseModuleFactory: ModuleFactory, Sendable {
  public let registerModule = RegisterModule()
  public var definitions: [@Sendable () -> Module] = []
}
```

  /// UseCase와 Repository 의존성을 함께 등록하는 헬퍼
Scope 계층 모듈 팩토리

```swift
public struct ScopeModuleFactory: ModuleFactory, Sendable {
  public let registerModule = RegisterModule()
  public var definitions: [@Sendable () -> Module] = []
}
```

  /// Scoped 의존성을 추가하는 헬퍼
여러 팩토리를 한 번에 관리하는 매니저

```swift
public struct ModuleFactoryManager: Sendable {
  public var repositoryFactory = RepositoryModuleFactory()
  public var useCaseFactory = UseCaseModuleFactory()
  public var scopeFactory = ScopeModuleFactory()
}
```

  /// 모든 팩토리의 모듈을 한 번에 생성
  /// 모든 모듈을 DI 컨테이너에 등록
  /// WeaveDI.Container에 정의된 registerAllDependencies()를 자동으로 호출합니다.
  /// ### 사용법:
  /// ```swift
  /// // 1. WeaveDI.Container에 의존성 정의
  /// extension WeaveDI.Container {
  ///     static func registerAllDependencies() {
  ///         _ = UnifiedDI.register(MyType.self) { MyImpl() }
  ///     }
  /// }
  /// // 2. Factory가 자동으로 호출
  /// let factory = ModuleFactoryManager()
  /// await factory.registerAll(to: container)
  /// ```
  /// 기존 방식 (컨테이너 없이 직접 등록)

```swift
public extension ModuleFactoryManager {
}
```

  /// DSL 스타일로 의존성 정의
  /// 🚀 간편 설정: 한 번에 생성하고 등록
  /// ### 사용법:
  /// ```swift
  /// await ModuleFactoryManager.createAndRegisterAll(to: container)
  /// ```
모듈 정의를 위한 Result Builder

```swift
public struct ModuleDefinitionBuilder {
  public static func buildBlock(_ components: (inout ModuleFactoryManager) -> Void...) -> (inout ModuleFactoryManager) -> Void {
    return { manager in
      for component in components {
        component(&manager)
      }
    }
  }
}
```

