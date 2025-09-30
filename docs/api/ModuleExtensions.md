---
title: ModuleExtensions
lang: en-US
---

# ModuleExtensions

확장된 Module 시스템을 위한 고급 인터페이스
## 개요
기존의 단순한 `Module` 구조체를 확장하여 다음과 같은 고급 기능을 제공합니다:
- 모듈 간 의존성 관리
- 라이프사이클 훅 (등록 전후 처리)
- 조건부 모듈 로딩
- 모듈 그룹화 및 합성
- 검증 및 헬스 체크

```swift
public protocol AdvancedModule: Sendable {
  /// 모듈의 고유 식별자
  var identifier: String { get }
}
```

  /// 이 모듈이 의존하는 다른 모듈들의 식별자
  /// 모듈 등록 조건 (true일 때만 등록됨)
  /// 등록 전 실행되는 훅
  /// 실제 등록 작업
  /// 등록 후 실행되는 훅
  /// 모듈 검증 (등록 후 정상 동작 확인)
조건부 모듈 등록을 위한 구조체
## 사용 예시
```swift
let analyticsModule = ConditionalModule(
    identifier: "analytics",
    condition: { ProcessInfo.processInfo.environment["ANALYTICS_ENABLED"] == "true" },
    module: Module(AnalyticsService.self) { GoogleAnalytics() }
)
```

```swift
public struct ConditionalModule: AdvancedModule {
  public let identifier: String
  public let dependencies: [String]
  public let shouldRegister: @Sendable () -> Bool
}
```

여러 모듈을 그룹으로 관리하는 구조체
## 사용 예시
```swift
let networkModules = ModuleGroup(
    identifier: "network-stack",
    modules: [
        httpClientModule,
        authServiceModule,
        apiServiceModule
    ]
)
```

```swift
public struct ModuleGroup: AdvancedModule {
  public let identifier: String
  public let dependencies: [String]
  public let shouldRegister: @Sendable () -> Bool
}
```

  /// 모듈들을 의존성 순서에 따라 위상정렬
DSL 스타일로 모듈을 구성하기 위한 Result Builder

```swift
public struct ModuleBuilder {
  public static func buildBlock(_ components: AdvancedModule...) -> [AdvancedModule] {
    return components
  }
}
```

모듈 등록 및 관리를 위한 레지스트리

```swift
public final class ModuleRegistry: ObservableObject {
  @Published public private(set) var registeredModules: [String: AdvancedModule] = [:]
  @Published public private(set) var registrationStatus: [String: ModuleRegistrationStatus] = [:]
}
```

  /// 모듈 등록 (DSL 스타일 지원)
  /// 모듈 배열 등록
  /// 특정 모듈의 등록 상태 확인
  /// 모든 모듈 제거 (테스트 용도)

```swift
public enum ModuleRegistrationStatus: Sendable {
  case registering
  case registered
  case failed(Error)
}
```

기존 Module을 AdvancedModule로 래핑하는 확장

```swift
public extension Module {
  func asAdvanced(
    identifier: String,
    dependencies: [String] = [],
    condition: @Sendable @escaping () -> Bool = { true }
  ) -> ConditionalModule {
    return ConditionalModule(
      identifier: identifier,
      dependencies: dependencies,
      condition: condition,
      module: self
    )
  }
}
```

편의 생성자들

```swift
public extension ConditionalModule {
  /// 환경 변수 기반 조건부 모듈
  static func fromEnvironment(
    identifier: String,
    dependencies: [String] = [],
    envKey: String,
    expectedValue: String,
    module: Module
  ) -> ConditionalModule {
    return ConditionalModule(
      identifier: identifier,
      dependencies: dependencies,
      condition: {
        ProcessInfo.processInfo.environment[envKey] == expectedValue
      },
      module: module
    )
  }
}
```

  /// UserDefaults 기반 조건부 모듈
  /// 빌드 구성 기반 조건부 모듈
