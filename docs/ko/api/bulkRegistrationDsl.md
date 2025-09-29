# 대량 등록 & DSL

WeaveDI의 강력한 대량 등록 패턴과 도메인 전용 언어(DSL)를 활용해 여러 의존성을 효율적으로 구성하는 방법에 대한 종합 가이드입니다.

## 개요

WeaveDI는 여러 의존성을 효율적으로 등록할 수 있는 다양한 DSL 패턴을 제공합니다. 이는 보일러플레이트 코드를 줄이고 유지보수성을 향상시키며, 많은 서비스를 보유한 대규모 애플리케이션에서 특히 유용합니다.

### 핵심 이점

- **보일러플레이트 감소**: 관련된 여러 의존성을 최소한의 코드로 등록
- **타입 안전성**: 의존성 관계를 컴파일 타임에 검증
- **일관성**: 의존성 구성 전반에 일관된 패턴 적용
- **성능**: 일괄(배치) 등록 최적화로 더 빠른 시작 시간
- **유지보수성**: 명확하고 선언적인 의존성 정의

## 인터페이스 패턴 일괄 등록

인터페이스 패턴은 단일 선언으로 Repository, UseCase, 폴백 구현을 포함한 완전한 기능 모듈을 등록할 수 있게 해줍니다.

### 기본 인터페이스 패턴

```swift
// Repository + UseCase 를 포함한 완전한 기능 인터페이스 등록
let entries = registerModule.registerInterfacePattern(
    BookListInterface.self,
    repositoryFactory: { BookListRepositoryImpl() },
    useCaseFactory: { BookListUseCaseImpl(repository: $0) },
    repositoryFallback: { DefaultBookListRepositoryImpl() }
)
```

**동작 내용:**
1. **Repository 등록**: `BookListRepositoryImpl` 생성 및 등록
2. **UseCase 등록**: Repository를 자동 주입하여 `BookListUseCaseImpl` 생성
3. **폴백 처리**: 기본 구현 `DefaultBookListRepositoryImpl` 제공(주 구현 실패 시)
4. **반환**: 컨테이너 등록 준비가 완료된 `Module` 객체 배열

### 고급 인터페이스 패턴

```swift
// 더 복잡한 의존성을 가진 인터페이스
let userEntries = registerModule.registerInterfacePattern(
    UserInterface.self,
    repositoryFactory: {
        UserRepositoryImpl(
            networkService: WeaveDI.Container.live.resolve(NetworkService.self)!,
            cacheService: WeaveDI.Container.live.resolve(CacheService.self)!
        )
    },
    useCaseFactory: { repository in
        UserUseCaseImpl(
            repository: repository,
            authService: WeaveDI.Container.live.resolve(AuthService.self)!,
            validator: UserValidator()
        )
    },
    repositoryFallback: {
        MockUserRepository() // 테스트에 안전한 폴백
    }
)

// 인터페이스에서 생성된 모든 모듈 등록
for module in userEntries {
    await container.register(module)
}
```

### 구성(환경) 기반 인터페이스 패턴

```swift
// 환경별 인터페이스 등록
let networkEntries = registerModule.registerInterfacePattern(
    NetworkInterface.self,
    repositoryFactory: {
        if Configuration.isProduction {
            return ProductionNetworkRepository(timeout: 30.0)
        } else {
            return MockNetworkRepository(delay: 0.1)
        }
    },
    useCaseFactory: { repository in
        NetworkUseCaseImpl(
            repository: repository,
            retryCount: Configuration.isProduction ? 3 : 1,
            logger: WeaveDI.Container.live.resolve(LoggerProtocol.self)!
        )
    },
    repositoryFallback: {
        OfflineNetworkRepository() // 네트워크 없이도 동작
    }
)
```

## 대량 DSL 문법

Bulk DSL은 여러 인터페이스를 보다 표현력 있게 등록할 수 있는 도메인 전용 문법을 제공합니다.

### 기본 Bulk DSL

```swift
let modules = registerModule.bulkInterfaces {
    // User 기능
    UserInterface.self => (
        repository: { UserRepositoryImpl() },
        useCase: { UserUseCaseImpl(repository: $0) },
        fallback: { MockUserRepository() }
    )

    // Order 기능
    OrderInterface.self => (
        repository: { OrderRepositoryImpl() },
        useCase: { OrderUseCaseImpl(repository: $0) },
        fallback: { MockOrderRepository() }
    )

    // Payment 기능
    PaymentInterface.self => (
        repository: { PaymentRepositoryImpl() },
        useCase: { PaymentUseCaseImpl(repository: $0) },
        fallback: { MockPaymentRepository() }
    )
}

// 생성된 모든 모듈을 한 번에 등록
await modules.asyncForEach { module in
    await container.register(module)
}
```

### 의존성이 포함된 복합 Bulk DSL

```swift
let modules = registerModule.bulkInterfaces {
    // 코어 인프라
    NetworkInterface.self => (
        repository: {
            NetworkRepositoryImpl(
                session: URLSession.shared,
                timeout: 30.0
            )
        },
        useCase: { repository in
            NetworkUseCaseImpl(
                repository: repository,
                reachability: WeaveDI.Container.live.resolve(ReachabilityService.self)!
            )
        },
        fallback: { OfflineNetworkRepository() }
    )

    // 네트워크 의존성을 가지는 사용자 관리
    UserInterface.self => (
        repository: {
            UserRepositoryImpl(
                networkService: WeaveDI.Container.live.resolve(NetworkInterface.self)!,
                cacheService: WeaveDI.Container.live.resolve(CacheService.self)!
            )
        },
        useCase: { repository in
            UserUseCaseImpl(
                repository: repository,
                authValidator: AuthValidator(),
                profileValidator: ProfileValidator()
            )
        },
        fallback: { CachedUserRepository() }
    )

    // 사용자 의존성을 가지는 주문 관리
    OrderInterface.self => (
        repository: {
            OrderRepositoryImpl(
                database: WeaveDI.Container.live.resolve(DatabaseService.self)!,
                networkService: WeaveDI.Container.live.resolve(NetworkInterface.self)!
            )
        },
        useCase: { repository in
            OrderUseCaseImpl(
                repository: repository,
                userUseCase: WeaveDI.Container.live.resolve(UserInterface.self)!,
                paymentValidator: PaymentValidator()
            )
        },
        fallback: { LocalOrderRepository() }
    )
}
```

### 조건부 대량 등록

```swift
let modules = registerModule.bulkInterfaces {
    // 개발 환경 전용 구현
    if Configuration.isDevelopment {
        AnalyticsInterface.self => (
            repository: { MockAnalyticsRepository() },
            useCase: { DebugAnalyticsUseCase(repository: $0) },
            fallback: { NoOpAnalyticsRepository() }
        )
    } else {
        AnalyticsInterface.self => (
            repository: {
                FirebaseAnalyticsRepository(
                    apiKey: Configuration.firebaseAPIKey
                )
            },
            useCase: { ProductionAnalyticsUseCase(repository: $0) },
            fallback: { LocalAnalyticsRepository() }
        )
    }

    // 기능 플래그 기반 등록
    if FeatureFlags.pushNotificationsEnabled {
        NotificationInterface.self => (
            repository: { APNSNotificationRepository() },
            useCase: { NotificationUseCaseImpl(repository: $0) },
            fallback: { LocalNotificationRepository() }
        )
    }
}
```

## Easy Scope 등록

Easy Scope는 동일한 스코프 내에서 여러 서비스를 간단한 DSL로 등록할 수 있게 해줍니다.

### 기본 Easy Scope

```swift
let modules = registerModule.easyScopes {
    // 코어 서비스
    register(LoggerProtocol.self) { OSLogLogger(category: "WeaveDI") }
    register(ConfigService.self) { ConfigServiceImpl() }
    register(NetworkService.self) { NetworkServiceImpl() }

    // 데이터 서비스
    register(DatabaseService.self) { SQLiteDatabaseService() }
    register(CacheService.self) { NSCacheService() }

    // 비즈니스 서비스
    register(UserService.self) { UserServiceImpl() }
    register(OrderService.self) { OrderServiceImpl() }
    register(PaymentService.self) { PaymentServiceImpl() }
}
```

### 의존성이 포함된 스코프 등록

```swift
let modules = registerModule.easyScopes {
    // 인프라 레이어
    register(LoggerProtocol.self) {
        if Configuration.isDebug {
            return DetailedLogger(level: .debug)
        } else {
            return ProductionLogger(level: .error)
        }
    }

    register(NetworkService.self) {
        NetworkServiceImpl(
            session: URLSession.shared,
            logger: WeaveDI.Container.live.resolve(LoggerProtocol.self)!
        )
    }

    register(DatabaseService.self) {
        SQLiteDatabaseService(
            path: Configuration.databasePath,
            logger: WeaveDI.Container.live.resolve(LoggerProtocol.self)!
        )
    }

    // 의존성이 있는 애플리케이션 레이어
    register(UserService.self) {
        UserServiceImpl(
            networkService: WeaveDI.Container.live.resolve(NetworkService.self)!,
            databaseService: WeaveDI.Container.live.resolve(DatabaseService.self)!,
            logger: WeaveDI.Container.live.resolve(LoggerProtocol.self)!
        )
    }

    register(OrderService.self) {
        OrderServiceImpl(
            userService: WeaveDI.Container.live.resolve(UserService.self)!,
            databaseService: WeaveDI.Container.live.resolve(DatabaseService.self)!,
            paymentService: WeaveDI.Container.live.resolve(PaymentService.self)!
        )
    }
}

// 모든 모듈 등록
await modules.asyncForEach { module in
    await container.register(module)
}
```

### 라이프사이클을 고려한 스코프 등록

```swift
let coreModules = registerModule.easyScopes {
    // 싱글톤 서비스
    register(ConfigService.self, scope: .singleton) {
        ConfigServiceImpl(configPath: Bundle.main.path(forResource: "Config", ofType: "plist")!)
    }

    register(LoggerProtocol.self, scope: .singleton) {
        OSLogLogger(category: "App")
    }

    // 트랜지언트 서비스(호출 시마다 새 인스턴스)
    register(RequestIDGenerator.self, scope: .transient) {
        UUIDRequestIDGenerator()
    }

    register(TimestampProvider.self, scope: .transient) {
        SystemTimestampProvider()
    }

    // 약한 싱글톤(참조가 없으면 해제)
    register(ImageCache.self, scope: .weakSingleton) {
        NSCacheImageCache(maxSize: 100_000_000) // 100MB
    }
}
```

## 고급 DSL 패턴

### 여러 DSL 접근 결합하기

```swift
class AppDependencyConfiguration {
    static func configure() async {
        await AppWeaveDI.Container.shared.registerDependencies { container in
            // Easy Scope로 코어 인프라 구성
            let coreModules = registerModule.easyScopes {
                register(LoggerProtocol.self) { OSLogLogger(category: "WeaveDI") }
                register(ConfigService.self) { ConfigServiceImpl() }
                register(NetworkService.self) { NetworkServiceImpl() }
                register(DatabaseService.self) { SQLiteDatabaseService() }
            }

            // Bulk DSL로 기능 모듈 구성
            let featureModules = registerModule.bulkInterfaces {
                UserInterface.self => (
                    repository: { UserRepositoryImpl() },
                    useCase: { UserUseCaseImpl(repository: $0) },
                    fallback: { MockUserRepository() }
                )

                OrderInterface.self => (
                    repository: { OrderRepositoryImpl() },
                    useCase: { OrderUseCaseImpl(repository: $0) },
                    fallback: { MockOrderRepository() }
                )
            }

            // 인터페이스 패턴으로 특화 모듈 구성
            let paymentModules = registerModule.registerInterfacePattern(
                PaymentInterface.self,
                repositoryFactory: {
                    StripePaymentRepository(
                        apiKey: Configuration.stripeAPIKey,
                        networkService: WeaveDI.Container.live.resolve(NetworkService.self)!
                    )
                },
                useCaseFactory: { repository in
                    PaymentUseCaseImpl(
                        repository: repository,
                        fraudDetection: WeaveDI.Container.live.resolve(FraudDetectionService.self)!,
                        validator: PaymentValidator()
                    )
                },
                repositoryFallback: {
                    MockPaymentRepository()
                }
            )

            // 모든 모듈 등록
            let allModules = coreModules + featureModules + paymentModules
            await allModules.asyncForEach { module in
                await container.register(module)
            }
        }
    }
}
```

### 환경별 DSL 구성

```swift
extension AppDependencyConfiguration {
    static func configureForEnvironment(_ environment: AppEnvironment) async {
        await AppWeaveDI.Container.shared.registerDependencies { container in
            let modules: [Module]

            switch environment {
            case .development:
                modules = developmentModules()
            case .staging:
                modules = stagingModules()
            case .production:
                modules = productionModules()
            }

            await modules.asyncForEach { module in
                await container.register(module)
            }
        }
    }

    private static func developmentModules() -> [Module] {
        return registerModule.bulkInterfaces {
            // 디버그 기능이 포함된 개발용 구현
            NetworkInterface.self => (
                repository: { MockNetworkRepository(delay: 1.0) }, // 네트워크 지연 시뮬레이션
                useCase: { DebugNetworkUseCase(repository: $0) },
                fallback: { OfflineNetworkRepository() }
            )

            AnalyticsInterface.self => (
                repository: { ConsoleAnalyticsRepository() }, // 콘솔 로깅
                useCase: { DebugAnalyticsUseCase(repository: $0) },
                fallback: { NoOpAnalyticsRepository() }
            )
        }
    }

    private static func productionModules() -> [Module] {
        return registerModule.bulkInterfaces {
            // 최적화된 운영 환경 구현
            NetworkInterface.self => (
                repository: {
                    CachedNetworkRepository(
                        underlying: HTTPNetworkRepository(),
                        cache: WeaveDI.Container.live.resolve(CacheService.self)!
                    )
                },
                useCase: { OptimizedNetworkUseCase(repository: $0) },
                fallback: { OfflineNetworkRepository() }
            )

            AnalyticsInterface.self => (
                repository: {
                    FirebaseAnalyticsRepository(
                        apiKey: Configuration.firebaseAPIKey,
                        batchSize: 50
                    )
                },
                useCase: { ProductionAnalyticsUseCase(repository: $0) },
                fallback: { LocalAnalyticsRepository() }
            )
        }
    }
}
```

## 성능 고려사항

### DSL로 지연 등록(Lazy Registration)

```swift
// 비용이 큰 서비스는 지연 등록
let modules = registerModule.easyScopes {
    // 비용이 큰 서비스 - 최초 접근 시에만 생성
    register(MLModelService.self, lazy: true) {
        print("Creating expensive ML model service...")
        return CoreMLModelService(
            modelPath: Bundle.main.path(forResource: "model", ofType: "mlmodel")!
        )
    }

    // 경량 서비스 - 즉시 생성
    register(LoggerProtocol.self) { OSLogLogger(category: "ML") }
    register(ConfigService.self) { ConfigServiceImpl() }
}
```

### 배치 최적화

```swift
// 성능을 위한 배치 등록 최적화
let optimizedModules = registerModule.bulkInterfaces(optimized: true) {
    // 많은 수의 인터페이스
    Interface1.self => (repository: { Repo1() }, useCase: { UseCase1(repository: $0) }, fallback: { Mock1() })
    Interface2.self => (repository: { Repo2() }, useCase: { UseCase2(repository: $0) }, fallback: { Mock2() })
    // ... 더 많은 인터페이스
}

// 병렬 등록으로 성능 향상
await withTaskGroup(of: Void.self) { group in
    for module in optimizedModules {
        group.addTask {
            await container.register(module)
        }
    }
    await group.waitForAll()
}
```

## 오류 처리 및 검증

### 오류 처리를 포함한 DSL

```swift
let modules = registerModule.easyScopes {
    // 검증이 포함된 서비스
    register(DatabaseService.self) {
        guard let dbPath = Configuration.databasePath else {
            fatalError("Database path not configured")
        }

        do {
            return try SQLiteDatabaseService(path: dbPath)
        } catch {
            print("Failed to initialize database: \(error)")
            return InMemoryDatabaseService() // 폴백
        }
    }

    // 사전 조건을 갖는 서비스
    register(EncryptionService.self) {
        precondition(!Configuration.encryptionKey.isEmpty, "Encryption key required")
        return AESEncryptionService(key: Configuration.encryptionKey)
    }
}
```

### 검증 DSL

```swift
extension RegisterModule {
    func validateAndRegister<T>(_ type: T.Type, factory: @escaping () -> T) -> Module {
        return Module(type) {
            let instance = factory()

            // 인스턴스가 기대하는 프로토콜을 준수하는지 검증
            if let validatable = instance as? Validatable {
                guard validatable.isValid else {
                    fatalError("Invalid instance of \(type)")
                }
            }

            return instance
        }
    }
}

// 사용 예
let validatedModules = registerModule.easyScopes {
    validateAndRegister(UserService.self) { UserServiceImpl() }
    validateAndRegister(OrderService.self) { OrderServiceImpl() }
}
```

## 모범 사례

### 1. 관련 의존성을 묶어서 구성

```swift
// 기능/도메인별 그룹핑
let userFeatureModules = registerModule.bulkInterfaces {
    UserInterface.self => (/* 사용자 구현 */)
    UserPreferencesInterface.self => (/* 사용자 환경설정 구현 */)
    UserNotificationInterface.self => (/* 사용자 알림 구현 */)
}

let orderFeatureModules = registerModule.bulkInterfaces {
    OrderInterface.self => (/* 주문 구현 */)
    OrderHistoryInterface.self => (/* 주문 이력 구현 */)
    OrderTrackingInterface.self => (/* 주문 추적 구현 */)
}
```

### 2. 의미 있는 팩토리 이름 사용

```swift
let modules = registerModule.easyScopes {
    register(NetworkService.self, factory: createProductionNetworkService)
    register(DatabaseService.self, factory: createOptimizedDatabaseService)
    register(CacheService.self, factory: createInMemoryCacheService)
}

private func createProductionNetworkService() -> NetworkService {
    return NetworkServiceImpl(
        configuration: .production,
        timeout: 30.0,
        retryCount: 3
    )
}
```

### 3. 구성(설정)과 등록을 분리

```swift
struct DependencyConfiguration {
    let environment: AppEnvironment
    let features: FeatureFlags

    func createModules() -> [Module] {
        return registerModule.bulkInterfaces {
            if features.userManagementEnabled {
                UserInterface.self => userInterfaceConfiguration()
            }

            if features.orderProcessingEnabled {
                OrderInterface.self => orderInterfaceConfiguration()
            }
        }
    }

    private func userInterfaceConfiguration() -> (
        repository: () -> UserRepository,
        useCase: (UserRepository) -> UserUseCase,
        fallback: () -> UserRepository
    ) {
        return (
            repository: { environment.isProduction ? ProductionUserRepo() : MockUserRepo() },
            useCase: { UserUseCaseImpl(repository: $0) },
            fallback: { CachedUserRepository() }
        )
    }
}
```

## 공통 패턴과 예시

### 마이크로서비스 아키텍처 패턴

```swift
let microserviceModules = registerModule.bulkInterfaces {
    // 사용자 마이크로서비스
    UserServiceInterface.self => (
        repository: {
            RestUserRepository(baseURL: "https://users.api.company.com")
        },
        useCase: { UserServiceUseCaseImpl(repository: $0) },
        fallback: { CachedUserRepository() }
    )

    // 주문 마이크로서비스
    OrderServiceInterface.self => (
        repository: {
            RestOrderRepository(baseURL: "https://orders.api.company.com")
        },
        useCase: { OrderServiceUseCaseImpl(repository: $0) },
        fallback: { LocalOrderRepository() }
    )

    // 결제 마이크로서비스
    PaymentServiceInterface.self => (
        repository: {
            RestPaymentRepository(baseURL: "https://payments.api.company.com")
        },
        useCase: { PaymentServiceUseCaseImpl(repository: $0) },
        fallback: { MockPaymentRepository() }
    )
}
```

### 플러그인 아키텍처 패턴

```swift
let pluginModules = registerModule.easyScopes {
    // 코어 플러그인 시스템
    register(PluginManager.self) { PluginManagerImpl() }
    register(PluginRegistry.self) { PluginRegistryImpl() }

    // 사용 가능한 플러그인 등록
    register(AnalyticsPlugin.self) { FirebaseAnalyticsPlugin() }
    register(CrashReportingPlugin.self) { CrashlyticsPlugin() }
    register(FeatureFlagPlugin.self) { LaunchDarklyPlugin() }
    register(LoggingPlugin.self) { DatadogLoggingPlugin() }
}
```

## 수동 등록에서의 마이그레이션

### 이전: 수동 등록

```swift
// 수동 등록(장황하고 오류 발생 가능성 큼)
container.register(UserRepository.self) { UserRepositoryImpl() }
container.register(UserUseCase.self) {
    UserUseCaseImpl(repository: container.resolve(UserRepository.self)!)
}
container.register(OrderRepository.self) { OrderRepositoryImpl() }
container.register(OrderUseCase.self) {
    OrderUseCaseImpl(repository: container.resolve(OrderRepository.self)!)
}
// ... 많은 수동 등록 코드
```

### 이후: DSL 등록

```swift
// DSL 등록(간결하고 유지보수 용이)
let modules = registerModule.bulkInterfaces {
    UserInterface.self => (
        repository: { UserRepositoryImpl() },
        useCase: { UserUseCaseImpl(repository: $0) },
        fallback: { MockUserRepository() }
    )

    OrderInterface.self => (
        repository: { OrderRepositoryImpl() },
        useCase: { OrderUseCaseImpl(repository: $0) },
        fallback: { MockOrderRepository() }
    )
}

await modules.asyncForEach { await container.register($0) }
```

## 함께 보기

- [모듈 시스템](/guide/moduleSystem) - WeaveDI의 모듈 아키텍처 이해
- [App DI 통합](/guide/appDiintegration) - 엔터프라이즈급 의존성 관리
- [프로퍼티 래퍼](/guide/propertyWrappers) - @Inject, @Factory, @SafeInject 사용법
- [핵심 API](/api/coreApis) - WeaveDI 핵심 API 레퍼런스
