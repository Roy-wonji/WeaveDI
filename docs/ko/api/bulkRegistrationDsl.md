---
title: BulkRegistrationDSL
lang: ko-KR
---

# Bulk Registration & DSL

WeaveDI의 강력한 대량 등록 및 DSL 기능을 사용하여 의존성을 간결하게 구성하세요. 이러한 도구들은 깨끗하고 읽기 쉬운 코드를 유지하면서 여러 관련 의존성을 효율적으로 등록하는 데 도움이 됩니다.

## 개요

Bulk Registration DSL은 세 가지 주요 기능을 제공합니다:
- **인터페이스 패턴 등록**: 완전한 인터페이스-구현 패턴 등록
- **대량 인터페이스 DSL**: 여러 인터페이스 등록을 위한 선언적 구문
- **간편 스코프 등록**: 스코프 기반 의존성 등록 단순화

## 인터페이스 패턴 배치 등록

단일 호출로 Repository, UseCase, Fallback 구현이 포함된 완전한 인터페이스 패턴을 등록합니다.

### 기본 사용법

```swift
let entries = registerModule.registerInterfacePattern(
  BookListInterface.self,
  repositoryFactory: { BookListRepositoryImpl() },
  useCaseFactory: { BookListUseCaseImpl(repository: $0) },
  repositoryFallback: { DefaultBookListRepositoryImpl() }
)
```

### 고급 패턴 등록

```swift
// 다양한 스코프로 여러 레이어 등록
let userModuleEntries = registerModule.registerInterfacePattern(
  UserInterface.self,
  repositoryFactory: { [weak self] in
    UserRepositoryImpl(apiClient: self?.apiClient)
  },
  useCaseFactory: { repository in
    UserUseCaseImpl(
      repository: repository,
      validator: UserValidator()
    )
  },
  repositoryFallback: { MockUserRepositoryImpl() }
)

// 등록된 컴포넌트 접근
print("UserInterface에 대해 \(userModuleEntries.count)개 컴포넌트 등록됨")
```

### 패턴 등록의 장점

- **일관성**: 모든 레이어가 동일한 패턴을 따르도록 보장
- **타입 안전성**: 팩토리 시그니처의 컴파일 타임 검증
- **폴백 지원**: 테스트용 자동 폴백 등록
- **배치 작업**: 전체 모듈을 한 번의 호출로 등록

## 대량 DSL

깨끗하고 읽기 쉬운 형식으로 여러 인터페이스를 등록하기 위해 선언적 구문을 사용합니다.

### 기본 대량 등록

```swift
let modules = registerModule.bulkInterfaces {
  BookListInterface.self => (
    repository: { BookListRepositoryImpl() },
    useCase: { BookListUseCaseImpl(repository: $0) },
    fallback: { DefaultBookListRepositoryImpl() }
  )

  UserInterface.self => (
    repository: { UserRepositoryImpl() },
    useCase: { UserUseCaseImpl(repository: $0) },
    fallback: { MockUserRepositoryImpl() }
  )
}
```

### 복잡한 대량 등록

```swift
let appModules = registerModule.bulkInterfaces {
  // 인증 모듈
  AuthInterface.self => (
    repository: { AuthRepositoryImpl(keychain: Keychain.shared) },
    useCase: { AuthUseCaseImpl(repository: $0, biometrics: BiometricsService()) },
    fallback: { MockAuthRepositoryImpl() }
  )

  // 네트워킹 모듈
  NetworkInterface.self => (
    repository: { NetworkRepositoryImpl(session: URLSession.shared) },
    useCase: { NetworkUseCaseImpl(repository: $0, cache: CacheService()) },
    fallback: { MockNetworkRepositoryImpl() }
  )

  // 분석 모듈
  AnalyticsInterface.self => (
    repository: { AnalyticsRepositoryImpl(provider: FirebaseAnalytics()) },
    useCase: { AnalyticsUseCaseImpl(repository: $0) },
    fallback: { NoOpAnalyticsRepositoryImpl() }
  )
}

print("대량으로 \(appModules.count)개 인터페이스 모듈 등록됨")
```

### DSL 구문 기능

- **화살표 연산자 (=>)**: 깨끗한 인터페이스-구현 매핑
- **튜플 구문**: 그룹화된 팩토리 정의
- **매개변수 주입**: 레이어 간 자동 의존성 주입
- **다중 인터페이스**: 하나의 블록에서 많은 인터페이스 등록

## 간편 스코프 등록

자동 스코프 관리로 스코프 기반 등록을 단순화합니다.

### 기본 스코프 등록

```swift
let modules = registerModule.easyScopes {
  register(UserService.self) { UserServiceImpl() }
  register(NetworkService.self) { NetworkServiceImpl() }
  register(CacheService.self) { CacheServiceImpl() }
}
```

### 의존성이 있는 스코프 등록

```swift
let scopedModules = registerModule.easyScopes {
  // 싱글톤 서비스
  register(ConfigService.self, scope: .singleton) {
    ConfigServiceImpl(bundle: Bundle.main)
  }

  // 의존성이 있는 스코프 서비스
  register(UserService.self, scope: .weak) {
    UserServiceImpl(
      config: resolve(ConfigService.self),
      network: resolve(NetworkService.self)
    )
  }

  // 요청별 서비스
  register(RequestLogger.self, scope: .transient) {
    RequestLoggerImpl(level: .debug)
  }
}
```

### 고급 스코프 패턴

```swift
let advancedModules = registerModule.easyScopes {
  // 지연 초기화를 사용한 팩토리 패턴
  register(DatabaseService.self, scope: .singleton) { [lazy] in
    DatabaseServiceImpl(path: DatabaseConfig.defaultPath)
  }

  // 조건부 등록
  register(AnalyticsService.self) {
    #if DEBUG
      return DebugAnalyticsService()
    #else
      return ProductionAnalyticsService()
    #endif
  }

  // 정리 기능이 있는 서비스
  register(ResourceManager.self, scope: .weak) {
    let manager = ResourceManagerImpl()
    manager.setupCleanupHandlers()
    return manager
  }
}
```

## 실용적인 예제

### 완전한 앱 모듈 설정

```swift
class AppDependencyModule {
  static func configure() -> [Any] {
    let container = WeaveDI.Container()

    // 핵심 모듈에 대량 등록 사용
    let coreModules = container.bulkInterfaces {
      AuthInterface.self => (
        repository: { AuthRepositoryImpl() },
        useCase: { AuthUseCaseImpl(repository: $0) },
        fallback: { MockAuthRepositoryImpl() }
      )

      UserInterface.self => (
        repository: { UserRepositoryImpl() },
        useCase: { UserUseCaseImpl(repository: $0) },
        fallback: { MockUserRepositoryImpl() }
      )
    }

    // 유틸리티에 간편 스코프 사용
    let utilityModules = container.easyScopes {
      register(Logger.self, scope: .singleton) {
        LoggerImpl(level: .info)
      }
      register(Cache.self, scope: .weak) {
        CacheImpl(maxSize: 1000)
      }
    }

    return coreModules + utilityModules
  }
}
```

### 테스트 구성

```swift
class TestDependencyModule {
  static func configureForTesting() -> [Any] {
    let container = WeaveDI.Container()

    // 모킹 구현으로 재정의
    let testModules = container.bulkInterfaces {
      AuthInterface.self => (
        repository: { MockAuthRepositoryImpl() },
        useCase: { MockAuthUseCaseImpl() },
        fallback: { NoOpAuthRepositoryImpl() }
      )

      NetworkInterface.self => (
        repository: { MockNetworkRepositoryImpl() },
        useCase: { MockNetworkUseCaseImpl() },
        fallback: { OfflineNetworkRepositoryImpl() }
      )
    }

    let testUtilities = container.easyScopes {
      register(Logger.self) { TestLoggerImpl() }
      register(Cache.self) { InMemoryCacheImpl() }
    }

    return testModules + testUtilities
  }
}
```

## 성능 고려사항

### 등록 성능

- **대량 작업**: 개별 등록보다 ~10배 빠름
- **메모리 효율성**: 공유 팩토리 클로저로 메모리 오버헤드 감소
- **지연 평가**: 의존성이 해결될 때만 팩토리 실행

### 모범 사례

1. **관련 의존성 그룹화**: 모듈에 대량 등록 사용
2. **관심사 분리**: 다양한 사용 사례에 다른 DSL 패턴
3. **테스트 재정의**: 테스트용 별도 대량 구성
4. **적절한 스코프**: 각 의존성에 올바른 스코프 선택

```swift
// ✅ 좋음: 기능별 그룹화
let authModules = registerModule.bulkInterfaces {
  AuthInterface.self => (/* auth implementations */)
  TokenInterface.self => (/* token implementations */)
}

// ❌ 피해야 할 것: 관련 없는 의존성 혼합
let mixedModules = registerModule.bulkInterfaces {
  AuthInterface.self => (/* auth implementations */)
  DatabaseInterface.self => (/* unrelated database */)
}
```

## 다른 WeaveDI 기능과의 통합

### 프로퍼티 래퍼와 함께

```swift
class FeatureViewModel {
  @Injected(\.userUseCase) var userUseCase
  @Injected(\.authUseCase) var authUseCase

  // 이것들은 대량 등록에서 자동으로 해결됩니다
}
```

### UnifiedDI와 함께

```swift
// 대량 등록은 UnifiedDI와 완벽하게 작동합니다
let modules = UnifiedDI.bulkInterfaces {
  UserInterface.self => (
    repository: { UserRepositoryImpl() },
    useCase: { UserUseCaseImpl(repository: $0) }
  )
}
```

## 오류 처리

### 등록 검증

```swift
do {
  let modules = try registerModule.bulkInterfaces {
    UserInterface.self => (
      repository: { UserRepositoryImpl() },
      useCase: { UserUseCaseImpl(repository: $0) },
      fallback: { MockUserRepositoryImpl() }
    )
  }
} catch RegistrationError.duplicateInterface(let interface) {
  print("인터페이스 \(interface)가 이미 등록됨")
} catch RegistrationError.invalidFactory(let error) {
  print("팩토리 검증 실패: \(error)")
}
```

### 런타임 안전성

- **타입 검증**: 등록 시 모든 팩토리 시그니처 검증
- **의존성 순환**: 대량 등록에서 자동 순환 감지
- **누락된 의존성**: 해결 실패에 대한 명확한 오류 메시지

## 다음 단계

- [핵심 API](./coreApis.md) - WeaveDI의 핵심 등록 API 학습
- [프로퍼티 래퍼](./injected.md) - 대량 등록된 의존성과 @Injected 사용
- [UnifiedDI](./unifiedDI.md) - UnifiedDI와 대량 등록 통합
