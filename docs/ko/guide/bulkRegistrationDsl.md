# 대량 등록 & DSL

WeaveDI의 대량 등록 시스템과 도메인 특화 언어(DSL) 패턴을 사용하여 여러 의존성을 효율적으로 구성합니다. 이 접근 방식은 보일러플레이트 코드를 줄이고 의존성 등록을 더 읽기 쉽고 유지보수하기 쉽게 만듭니다.

## 개요

대량 등록을 사용하면 Repository-UseCase 아키텍처와 같은 일반적인 패턴을 따라 여러 관련 의존성을 단일 작업으로 등록할 수 있습니다. DSL은 의존성 구성을 더 직관적으로 만드는 유창하고 표현적인 구문을 제공합니다.

**장점**:
- **보일러플레이트 감소**: 최소한의 코드로 여러 관련 서비스 등록
- **패턴 일관성**: 일반적인 아키텍처 패턴 강제
- **타입 안전성**: 의존성 관계의 컴파일 타임 검사
- **가독성**: 의존성을 문서화하는 명확하고 표현적인 구문

## 인터페이스 패턴 배치 등록

인터페이스 패턴은 함께 등록해야 하는 일반적인 의존성 패턴이 있는 Repository-UseCase 아키텍처에 완벽합니다.

**목적**: 주어진 인터페이스에 대한 Repository, UseCase 및 fallback 구현을 한 번의 작업으로 자동 등록합니다.

**작동 방식**:
- **Repository Factory**: 기본 데이터 접근 구현을 생성합니다
- **UseCase Factory**: 비즈니스 로직 계층을 생성하고 repository를 자동으로 주입합니다
- **Fallback**: 기본 repository가 실패할 때 기본 구현을 제공합니다

```swift
let entries = registerModule.registerInterfacePattern(
  BookListInterface.self,
  repositoryFactory: { BookListRepositoryImpl() },
  useCaseFactory: { BookListUseCaseImpl(repository: $0) }, // $0은 repository 인스턴스
  repositoryFallback: { DefaultBookListRepositoryImpl() }
)
```

**생성되는 것**:
- `BookListRepository` → `BookListRepositoryImpl` (기본)
- `BookListRepository` → `DefaultBookListRepositoryImpl` (fallback)
- `BookListUseCase` → `BookListUseCaseImpl` (repository 주입됨)
- `BookListInterface` → 완전히 구성된 서비스

**사용 사례**:
- **MVVM 아키텍처**: Repository-ViewModel 패턴
- **클린 아키텍처**: Repository-UseCase-Presenter 계층
- **서비스 계층**: API-Service-Cache 조합

## 대량 DSL

대량 DSL은 연산자 오버로딩과 클로저 구문을 사용하여 여러 인터페이스 패턴을 구성하는 더 표현적이고 읽기 쉬운 방법을 제공합니다.

**목적**: 유창한 DSL 구문을 사용하여 여러 인터페이스와 해당 의존성을 하나의 읽기 쉬운 블록으로 구성합니다.

**DSL의 장점**:
- **표현적 구문**: `=>` 연산자가 관계를 명확히 보여줍니다
- **그룹화된 구성**: 관련 의존성이 시각적으로 그룹화됩니다
- **타입 추론**: Swift의 타입 시스템이 안전성을 제공합니다
- **오류 감소**: 잘못된 구성의 가능성이 줄어듭니다

```swift
let modules = registerModule.bulkInterfaces {
  // 인터페이스와 구현 간의 관계를 보여주는 깔끔하고 읽기 쉬운 구문
  BookListInterface.self => (
    repository: { BookListRepositoryImpl() },      // 기본 repository
    useCase: { BookListUseCaseImpl(repository: $0) }, // 자동 주입된 repo를 가진 UseCase
    fallback: { DefaultBookListRepositoryImpl() }   // 기본이 실패할 때의 fallback
  )

  // 동일한 블록에서 여러 인터페이스를 등록할 수 있습니다
  UserInterface.self => (
    repository: { UserRepositoryImpl() },
    useCase: { UserUseCaseImpl(repository: $0) },
    fallback: { OfflineUserRepositoryImpl() }
  )
}
```

**고급 DSL 패턴**:

```swift
let modules = registerModule.bulkInterfaces {
  // 추가 의존성과 함께
  WeatherInterface.self => (
    repository: { WeatherRepositoryImpl() },
    useCase: {
      WeatherUseCaseImpl(
        repository: $0,
        logger: UnifiedDI.resolve(LoggerProtocol.self)!
      )
    },
    fallback: { CachedWeatherRepositoryImpl() }
  )

  // 조건부 등록과 함께
  AnalyticsInterface.self => (
    repository: {
      #if DEBUG
      MockAnalyticsRepositoryImpl()
      #else
      FirebaseAnalyticsRepositoryImpl()
      #endif
    },
    useCase: { AnalyticsUseCaseImpl(repository: $0) },
    fallback: { NoOpAnalyticsRepositoryImpl() }
  )
}
```

## 간편한 스코프 등록

간편한 스코프는 인터페이스 패턴의 복잡성 없이 특정 스코프 내에서 여러 서비스를 등록하는 단순한 방법을 제공합니다.

**목적**: 여러 독립적인 서비스를 일관된 스코프로 빠르고 효율적으로 등록합니다.

**언제 사용하는가**:
- **단순한 서비스**: Repository-UseCase 패턴을 따르지 않는 서비스
- **유틸리티 서비스**: 로거, 포맷터, 검증기
- **서드파티 통합**: 외부 SDK 래퍼
- **구성 서비스**: 설정, 환경 설정, 상수

```swift
let modules = registerModule.easyScopes {
  // 하나의 블록에서 여러 서비스 등록
  register(UserService.self) { UserServiceImpl() }
  register(NetworkService.self) { NetworkServiceImpl() }
  register(LoggerProtocol.self) { ConsoleLogger() }
  register(CacheService.self) { MemoryCacheService() }
}
```

**고급 간편한 스코프 예제**:

```swift
let modules = registerModule.easyScopes {
  // 서비스 간 의존성과 함께
  register(LoggerProtocol.self) { ConsoleLogger() }

  register(NetworkService.self) {
    NetworkServiceImpl(
      logger: UnifiedDI.resolve(LoggerProtocol.self)!
    )
  }

  register(UserService.self) {
    UserServiceImpl(
      network: UnifiedDI.resolve(NetworkService.self)!,
      logger: UnifiedDI.resolve(LoggerProtocol.self)!
    )
  }

  // 스코프 등록과 함께
  registerScoped(SessionService.self, scope: .session) {
    SessionServiceImpl()
  }
}
```

## 패턴 결합

최대한의 유연성을 위해 다양한 대량 등록 패턴을 결합할 수 있습니다:

```swift
await WeaveDI.Container.bootstrap { container in
  // 먼저 Easy Scope로 핵심 서비스 등록
  let coreServices = registerModule.easyScopes {
    register(LoggerProtocol.self) { ConsoleLogger() }
    register(ConfigService.self) { AppConfigService() }
  }

  // 그다음 Bulk DSL로 비즈니스 인터페이스 등록
  let businessServices = registerModule.bulkInterfaces {
    UserInterface.self => (
      repository: { UserRepositoryImpl() },
      useCase: { UserUseCaseImpl(repository: $0) },
      fallback: { OfflineUserRepositoryImpl() }
    )

    BookInterface.self => (
      repository: { BookRepositoryImpl() },
      useCase: { BookUseCaseImpl(repository: $0) },
      fallback: { CachedBookRepositoryImpl() }
    )
  }

  // 마지막으로 필요한 경우 복잡한 패턴을 개별적으로 등록
  let complexEntries = registerModule.registerInterfacePattern(
    ComplexInterface.self,
    repositoryFactory: { ComplexRepositoryImpl() },
    useCaseFactory: { ComplexUseCaseImpl(repository: $0) },
    repositoryFallback: { SimpleComplexRepositoryImpl() }
  )
}
```

## 모범 사례

### 1. 올바른 패턴 선택

```swift
// ✅ Repository-UseCase 아키텍처에 인터페이스 패턴 사용
let userEntries = registerModule.registerInterfacePattern(
  UserInterface.self,
  repositoryFactory: { UserRepositoryImpl() },
  useCaseFactory: { UserUseCaseImpl(repository: $0) },
  repositoryFallback: { OfflineUserRepositoryImpl() }
)

// ✅ 여러 인터페이스 패턴에 Bulk DSL 사용
let modules = registerModule.bulkInterfaces {
  UserInterface.self => (repository: ..., useCase: ..., fallback: ...)
  BookInterface.self => (repository: ..., useCase: ..., fallback: ...)
}

// ✅ 단순한 서비스에 Easy Scope 사용
let utilities = registerModule.easyScopes {
  register(LoggerProtocol.self) { ConsoleLogger() }
  register(DateFormatter.self) { ISO8601DateFormatter() }
}
```

### 2. 일관성 유지

```swift
// ✅ 관련 서비스를 함께 그룹화
let dataServices = registerModule.bulkInterfaces {
  UserInterface.self => (/* 구성 */),
  ProfileInterface.self => (/* 구성 */),
  SettingsInterface.self => (/* 구성 */)
}

let networkServices = registerModule.easyScopes {
  register(HTTPClient.self) { URLSessionHTTPClient() }
  register(APIService.self) { RestAPIService() }
}
```

### 3. 의미 있는 이름 사용

```swift
// ✅ 명확하고 설명적인 변수 이름
let coreBusinessLogic = registerModule.bulkInterfaces { /* ... */ }
let infrastructureServices = registerModule.easyScopes { /* ... */ }
let externalIntegrations = registerModule.registerInterfacePattern(/* ... */)
```

## 참고

- [모듈 시스템](./moduleSystem.md) - 대량 등록을 모듈로 구성하기
- [부트스트랩 가이드](./bootstrap.md) - 앱 시작시 대량 등록 사용하기
- [코어 API](../api/coreApis.md) - 개별 등록 방법