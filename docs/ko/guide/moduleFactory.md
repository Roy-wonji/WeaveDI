# 모듈 팩토리

WeaveDI의 모듈 팩토리는 대규모 애플리케이션에서 의존성을 체계적으로 관리하고 모듈화할 수 있는 강력한 도구입니다.

## 개요

모듈 팩토리는 관련된 의존성들을 논리적으로 그룹화하고, 이를 체계적으로 컨테이너에 등록할 수 있게 해주는 패턴입니다. 이를 통해 대규모 프로젝트에서도 깔끔하고 유지보수 가능한 DI 구조를 만들 수 있습니다.

## 기본 사용법

### 단순한 모듈 팩토리

```swift
protocol ModuleFactory {
  func makeModule() -> Module
}

struct RepositoryModuleFactory: ModuleFactory {
  func makeModule() -> Module {
    Module { container in
      container.register(UserRepositoryProtocol.self) {
        UserRepositoryImpl()
      }

      container.register(BookRepositoryProtocol.self) {
        BookRepositoryImpl()
      }
    }
  }
}
```

### 팩토리 등록 및 사용

```swift
// 앱 초기화 시점
await DependencyContainer.bootstrap { container in
  let repositoryFactory = RepositoryModuleFactory()
  let repositoryModule = repositoryFactory.makeModule()

  await container.register(repositoryModule)
  await container.build()
}
```

## 고급 패턴

### 1. 다중 모듈 팩토리

여러 모듈을 한 번에 생성하고 등록하는 패턴입니다.

```swift
struct ApplicationModuleFactory {
  func makeAllModules() -> [Module] {
    [
      makeRepositoryModule(),
      makeUseCaseModule(),
      makeViewModelModule(),
      makeServiceModule()
    ]
  }

  private func makeRepositoryModule() -> Module {
    Module { container in
      container.register(\.userRepository) { UserRepositoryImpl() }
      container.register(\.bookRepository) { BookRepositoryImpl() }
      container.register(\.authRepository) { AuthRepositoryImpl() }
    }
  }

  private func makeUseCaseModule() -> Module {
    Module { container in
      container.register(\.loginUseCase) {
        LoginUseCaseImpl(repository: container.resolve(\.authRepository))
      }

      container.register(\.userListUseCase) {
        UserListUseCaseImpl(repository: container.resolve(\.userRepository))
      }
    }
  }

  private func makeViewModelModule() -> Module {
    Module { container in
      container.register(LoginViewModelProtocol.self) {
        LoginViewModel(useCase: container.resolve(\.loginUseCase))
      }
    }
  }

  private func makeServiceModule() -> Module {
    Module { container in
      container.register(\.networkService) { NetworkServiceImpl() }
      container.register(\.cacheService) { CacheServiceImpl() }
    }
  }
}
```

### 2. 조건부 모듈 팩토리

환경이나 설정에 따라 다른 모듈을 생성하는 패턴입니다.

```swift
struct ConditionalModuleFactory {
  let environment: Environment

  func makeNetworkModule() -> Module {
    switch environment {
    case .development:
      return makeDevelopmentNetworkModule()
    case .staging:
      return makeStagingNetworkModule()
    case .production:
      return makeProductionNetworkModule()
    }
  }

  private func makeDevelopmentNetworkModule() -> Module {
    Module { container in
      container.register(\.apiClient) {
        MockAPIClient(baseURL: "https://dev-api.example.com")
      }

      container.register(\.networkLogger) {
        VerboseNetworkLogger()
      }
    }
  }

  private func makeProductionNetworkModule() -> Module {
    Module { container in
      container.register(\.apiClient) {
        ProductionAPIClient(
          baseURL: "https://api.example.com",
          certificatePinner: SSLCertificatePinner()
        )
      }

      container.register(\.networkLogger) {
        ProductionNetworkLogger()
      }
    }
  }
}
```

### 3. 비동기 모듈 팩토리

네트워크나 파일 시스템 접근이 필요한 의존성을 다루는 팩토리입니다.

```swift
struct AsyncModuleFactory {
  func makeConfigurationModule() async -> Module {
    // 원격 설정 로드
    let remoteConfig = await RemoteConfigService.fetchConfiguration()

    return Module { container in
      container.register(\.configuration) { remoteConfig }

      container.register(\.featureFlags) {
        FeatureFlagService(configuration: remoteConfig)
      }
    }
  }

  func makeDatabaseModule() async -> Module {
    // 데이터베이스 초기화
    let database = await DatabaseManager.initialize()

    return Module { container in
      container.register(\.database) { database }

      container.register(\.userDAO) {
        UserDAO(database: database)
      }

      container.register(\.bookDAO) {
        BookDAO(database: database)
      }
    }
  }
}
```

## 실제 사용 예제

### 대규모 앱의 모듈 구성

```swift
@main
struct WeaveDIApp: App {
  init() {
    Task {
      await setupDependencies()
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }

  private func setupDependencies() async {
    let factory = ApplicationModuleFactory()

    await DependencyContainer.bootstrap { container in
      // 모든 모듈을 순차적으로 등록
      for module in factory.makeAllModules() {
        await container.register(module)
      }

      // 특별한 설정이 필요한 모듈들
      let asyncFactory = AsyncModuleFactory()
      let configModule = await asyncFactory.makeConfigurationModule()
      let dbModule = await asyncFactory.makeDatabaseModule()

      await container.register(configModule)
      await container.register(dbModule)

      await container.build()
    }
  }
}
```

### UseCase Factory 통합

UseCase 레이어를 전담하는 팩토리 패턴입니다.

```swift
struct UseCaseModuleFactory {
  func makeAllModules() -> [Module] {
    [
      makeAuthUseCases(),
      makeUserUseCases(),
      makeBookUseCases(),
      makeNotificationUseCases()
    ]
  }

  private func makeAuthUseCases() -> Module {
    Module { container in
      container.register(\.loginUseCase) {
        LoginUseCaseImpl(
          authRepository: container.resolve(\.authRepository),
          userRepository: container.resolve(\.userRepository),
          analyticsService: container.resolve(\.analyticsService)
        )
      }

      container.register(\.logoutUseCase) {
        LogoutUseCaseImpl(
          authRepository: container.resolve(\.authRepository),
          cacheService: container.resolve(\.cacheService)
        )
      }

      container.register(\.refreshTokenUseCase) {
        RefreshTokenUseCaseImpl(
          authRepository: container.resolve(\.authRepository)
        )
      }
    }
  }

  private func makeUserUseCases() -> Module {
    Module { container in
      container.register(\.fetchUserProfileUseCase) {
        FetchUserProfileUseCaseImpl(
          userRepository: container.resolve(\.userRepository),
          cacheService: container.resolve(\.cacheService)
        )
      }

      container.register(\.updateUserProfileUseCase) {
        UpdateUserProfileUseCaseImpl(
          userRepository: container.resolve(\.userRepository)
        )
      }
    }
  }
}
```

## 베스트 프랙티스

### 1. 모듈 간 의존성 관리

```swift
struct OrderedModuleFactory {
  func registerModulesInOrder() async {
    await DependencyContainer.bootstrap { container in
      // 1. 기반 서비스부터 등록
      await container.register(makeInfrastructureModule())

      // 2. 데이터 레이어
      await container.register(makeRepositoryModule())

      // 3. 비즈니스 로직 레이어
      await container.register(makeUseCaseModule())

      // 4. 프레젠테이션 레이어
      await container.register(makeViewModelModule())

      await container.build()
    }
  }
}
```

### 2. 테스트용 모듈 팩토리

```swift
#if DEBUG
struct TestModuleFactory {
  func makeMockModules() -> [Module] {
    [
      makeMockRepositoryModule(),
      makeMockServiceModule()
    ]
  }

  private func makeMockRepositoryModule() -> Module {
    Module { container in
      container.register(\.userRepository) { MockUserRepository() }
      container.register(\.bookRepository) { MockBookRepository() }
    }
  }
}
#endif
```

### 3. 에러 처리

```swift
struct SafeModuleFactory {
  func makeModuleWithErrorHandling() -> Module {
    Module { container in
      do {
        let expensiveService = try ExpensiveService()
        container.register(\.expensiveService) { expensiveService }
      } catch {
        // Fallback 구현체 제공
        container.register(\.expensiveService) { FallbackService() }
        print("Failed to initialize ExpensiveService: \\(error)")
      }
    }
  }
}
```

## 성능 최적화

### 지연 로딩 팩토리

```swift
struct LazyModuleFactory {
  func makeLazyModule() -> Module {
    Module { container in
      // 실제 사용 시점에 초기화
      container.register(\.heavyService) {
        HeavyServiceImpl()
      }
      .scope(.singleton) // 한 번만 생성
      .lazy() // 첫 요청 시에 생성
    }
  }
}
```

모듈 팩토리를 활용하면 복잡한 의존성 구조도 체계적으로 관리할 수 있으며, 코드의 가독성과 유지보수성을 크게 향상시킬 수 있습니다.