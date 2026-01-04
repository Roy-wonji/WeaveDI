# WeaveDI Builder 패턴 가이드

WeaveDI v3.4.0에서 정식으로 도입된 새로운 Builder 패턴에 대한 완전한 가이드입니다. 이 패턴은 더욱 직관적이고 fluent한 API를 통해 의존성을 등록할 수 있게 해줍니다.

## 개요

WeaveDI.builder 패턴은 메서드 체이닝을 통해 여러 의존성을 한 번에 등록할 수 있는 새로운 방식입니다. 기존의 개별 등록 방식보다 더 읽기 쉽고 관리하기 쉬운 코드를 작성할 수 있습니다.

### 주요 장점

- 🔗 **메서드 체이닝**: 여러 의존성을 한 번에 fluent하게 등록
- 📖 **가독성 향상**: 선언적이고 직관적인 코드 스타일
- 🎯 **타입 안전성**: 컴파일 타임 타입 검증
- 🔄 **일관성**: 모든 의존성 등록을 일관된 패턴으로 처리

## 기본 사용법

### 단순 등록 (타입 추론 자동)

```swift
import WeaveDI

// 기본 빌더 패턴 - 타입이 자동 추론됩니다
WeaveDI.builder
    .register { UserServiceImpl() }    // UserService로 자동 등록
    .register { ConsoleLogger() }      // Logger로 자동 등록
    .register { NetworkClientImpl() }  // NetworkClient로 자동 등록
    .configure()
```

### 개별 등록

```swift
// 한 줄로 간단하게 등록
WeaveDI.register { UserServiceImpl() }
WeaveDI.register { ConsoleLogger() }
WeaveDI.register { NetworkClientImpl() }

// 프로토콜 타입으로 명시적 등록
WeaveDI.register { UserRepository() as UserRepositoryProtocol }
WeaveDI.register { AuthService() as AuthServiceProtocol }
```

## 기존 방식과 비교

### 기존 방식

```swift
// 기존의 개별 등록 방식
UnifiedDI.register(UserService.self) { UserServiceImpl() }
UnifiedDI.register(Logger.self) { ConsoleLogger() }
UnifiedDI.register(NetworkClient.self) { NetworkClientImpl() }
UnifiedDI.register(CacheService.self) { CacheServiceImpl() }
```

### Builder 패턴 (새로운 방식)

```swift
// 새로운 빌더 패턴 - 타입 추론 자동
WeaveDI.builder
    .register { UserServiceImpl() }    // UserService로 자동 등록
    .register { ConsoleLogger() }      // Logger로 자동 등록
    .register { NetworkClientImpl() }  // NetworkClient로 자동 등록
    .register { CacheServiceImpl() }   // CacheService로 자동 등록
    .configure()
```

## 고급 사용법

### 조건부 등록

```swift
WeaveDI.builder
    .register { UserServiceImpl() }
    .register {
        #if DEBUG
        return DebugLogger() as Logger
        #else
        return ProductionLogger() as Logger
        #endif
    }
    .register {
        if FeatureFlags.analyticsEnabled {
            return FirebaseAnalyticsService() as AnalyticsService
        } else {
            return NoOpAnalyticsService() as AnalyticsService
        }
    }
    .configure()

// 또는 환경별 등록 API 사용
WeaveDI.registerForEnvironment { env in
    env.register { UserServiceImpl() }

    if env.isDebug {
        env.register { DebugLogger() as Logger }
        env.register { MockAnalyticsService() as AnalyticsService }
    } else {
        env.register { ProductionLogger() as Logger }
        env.register { FirebaseAnalyticsService() as AnalyticsService }
    }
}
```

### 의존성 체인

```swift
// 의존성 간의 관계를 명확하게 표현
WeaveDI.builder
    .register(NetworkConfig.self) {
        NetworkConfig(baseURL: "https://api.example.com")
    }
    .register(NetworkClient.self) {
        let config = WeaveDI.Container.live.resolve(NetworkConfig.self)!
        return NetworkClient(config: config)
    }
    .register(APIService.self) {
        let client = WeaveDI.Container.live.resolve(NetworkClient.self)!
        return APIService(client: client)
    }
    .configure()
```

### 스코프 지정

```swift
WeaveDI.builder
    .register(UserService.self, scope: .singleton) { UserServiceImpl() }
    .register(RequestHandler.self, scope: .transient) { RequestHandlerImpl() }
    .register(SessionManager.self, scope: .session) { SessionManagerImpl() }
    .configure()
```

## 환경별 설정

### 개발 환경

```swift
#if DEBUG
WeaveDI.builder
    .register(Logger.self) { DebugLogger(level: .verbose) }
    .register(NetworkClient.self) { MockNetworkClient() }
    .register(UserService.self) { MockUserService() }
    .configure()
#endif
```

### 프로덕션 환경

```swift
#if !DEBUG
WeaveDI.builder
    .register(Logger.self) { ProductionLogger(level: .warning) }
    .register(NetworkClient.self) { NetworkClientImpl() }
    .register(AnalyticsService.self) { FirebaseAnalyticsService() }
    .configure()
#endif
```

### 환경 팩토리 패턴

```swift
enum BuilderEnvironment {
    case development
    case staging
    case production

    func configure() {
        switch self {
        case .development:
            WeaveDI.builder
                .register(Logger.self) { DebugLogger() }
                .register(APIClient.self) { MockAPIClient() }
                .configure()

        case .staging:
            WeaveDI.builder
                .register(Logger.self) { StagingLogger() }
                .register(APIClient.self) { StagingAPIClient() }
                .configure()

        case .production:
            WeaveDI.builder
                .register(Logger.self) { ProductionLogger() }
                .register(APIClient.self) { ProductionAPIClient() }
                .configure()
        }
    }
}

// 사용법
BuilderEnvironment.current.configure()
```

## 모듈화된 등록

### 기능별 빌더

```swift
extension WeaveDI {
    static func configureNetworking() {
        builder
            .register(NetworkConfig.self) { NetworkConfig.default }
            .register(NetworkClient.self) { NetworkClientImpl() }
            .register(APIService.self) { APIServiceImpl() }
            .configure()
    }

    static func configureAuth() {
        builder
            .register(AuthConfig.self) { AuthConfig.load() }
            .register(AuthService.self) { AuthServiceImpl() }
            .register(TokenManager.self) { TokenManagerImpl() }
            .configure()
    }

    static func configureCore() {
        builder
            .register(Logger.self) { AppLogger.shared }
            .register(UserDefaults.self) { UserDefaults.standard }
            .configure()
    }
}

// 앱 초기화에서
WeaveDI.configureCore()
WeaveDI.configureNetworking()
WeaveDI.configureAuth()
```

### 모듈 조합

```swift
struct AppDependencyBuilder {
    static func configureAll() {
        // 코어 의존성
        WeaveDI.builder
            .register(AppConfig.self) { AppConfig.load() }
            .register(Logger.self) { AppLogger.shared }
            .configure()

        // 네트워킹 의존성
        WeaveDI.builder
            .register(NetworkClient.self) { NetworkClientImpl() }
            .register(APIService.self) { APIServiceImpl() }
            .configure()

        // 비즈니스 로직 의존성
        WeaveDI.builder
            .register(UserRepository.self) { UserRepositoryImpl() }
            .register(AuthUseCase.self) { AuthUseCaseImpl() }
            .configure()
    }
}
```

## 테스트에서의 활용

### 테스트용 빌더

```swift
#if DEBUG
extension WeaveDI {
    static func configureMocks() {
        builder
            .register(UserService.self) { MockUserService() }
            .register(NetworkClient.self) { MockNetworkClient() }
            .register(Logger.self) { MockLogger() }
            .configure()
    }

    static func configureTestData() {
        builder
            .register(TestDataManager.self) { TestDataManagerImpl() }
            .register(MockServer.self) { MockServerImpl() }
            .configure()
    }
}

// 테스트 케이스에서
class SomeTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        WeaveDI.configureMocks()
        WeaveDI.configureTestData()
    }
}
#endif
```

### 부분적 목 등록

```swift
// 일부만 목으로 교체
WeaveDI.builder
    .register(UserService.self) { MockUserService() }  // Mock
    .register(Logger.self) { AppLogger.shared }        // 실제
    .register(NetworkClient.self) { MockNetworkClient() }  // Mock
    .configure()
```

## 성능 고려사항

### 배치 등록

빌더 패턴은 내부적으로 배치 등록을 수행하여 성능을 최적화합니다:

```swift
// 내부적으로 최적화된 배치 등록
WeaveDI.builder
    .register(Service1.self) { Service1Impl() }
    .register(Service2.self) { Service2Impl() }
    .register(Service3.self) { Service3Impl() }
    .configure()  // 여기서 한 번에 등록
```

### 지연 등록

```swift
// 필요할 때만 빌더 실행
lazy var dependencyBuilder = WeaveDI.builder
    .register(ExpensiveService.self) { ExpensiveServiceImpl() }

// 실제 필요한 시점에 등록
func setupDependencies() {
    dependencyBuilder.configure()
}
```

## 오류 처리

### 등록 실패 처리

```swift
do {
    try WeaveDI.builder
        .register(RiskyService.self) {
            try RiskyServiceImpl()
        }
        .register(SafeService.self) { SafeServiceImpl() }
        .configure()
} catch {
    print("의존성 등록 실패: \(error)")
    // 폴백 설정
    WeaveDI.builder
        .register(RiskyService.self) { FallbackService() }
        .configure()
}
```

### 검증

```swift
WeaveDI.builder
    .register(UserService.self) { UserServiceImpl() }
    .register(Logger.self) { ConsoleLogger() }
    .validate()  // 등록 전 검증
    .configure()
```

## 마이그레이션 가이드

### 기존 코드에서 빌더 패턴으로

**Before:**
```swift
UnifiedDI.register(UserService.self) { UserServiceImpl() }
UnifiedDI.register(Logger.self) { ConsoleLogger() }
UnifiedDI.register(NetworkClient.self) { NetworkClientImpl() }
```

**After:**
```swift
WeaveDI.builder
    .register(UserService.self) { UserServiceImpl() }
    .register(Logger.self) { ConsoleLogger() }
    .register(NetworkClient.self) { NetworkClientImpl() }
    .configure()
```

### 점진적 마이그레이션

기존 코드와 새로운 빌더 패턴을 함께 사용할 수 있습니다:

```swift
// 기존 등록 유지
UnifiedDI.register(LegacyService.self) { LegacyServiceImpl() }

// 새로운 빌더 패턴 추가
WeaveDI.builder
    .register(NewService.self) { NewServiceImpl() }
    .register(ModernService.self) { ModernServiceImpl() }
    .configure()
```

## 모범 사례

### 1. 의존성 그룹화

관련된 의존성들을 함께 등록:

```swift
// Good: 관련된 의존성들을 그룹화
WeaveDI.builder
    .register(UserRepository.self) { UserRepositoryImpl() }
    .register(UserService.self) { UserServiceImpl() }
    .register(UserValidator.self) { UserValidatorImpl() }
    .configure()
```

### 2. 명확한 의존성 순서

의존성 간의 관계를 고려한 순서로 등록:

```swift
WeaveDI.builder
    .register(DatabaseConfig.self) { DatabaseConfig.load() }    // 1. 설정
    .register(Database.self) { DatabaseImpl() }                 // 2. 인프라
    .register(UserRepository.self) { UserRepositoryImpl() }     // 3. 데이터 레이어
    .register(UserService.self) { UserServiceImpl() }           // 4. 비즈니스 로직
    .configure()
```

### 3. 환경별 분리

```swift
// Good: 환경별로 명확하게 분리
#if DEBUG
WeaveDI.builder
    .register(Logger.self) { DebugLogger() }
    .configure()
#else
WeaveDI.builder
    .register(Logger.self) { ProductionLogger() }
    .configure()
#endif
```

WeaveDI Builder 패턴을 통해 더 깔끔하고 유지보수하기 쉬운 의존성 등록 코드를 작성할 수 있습니다. 기존 API와 완벽히 호환되므로 점진적으로 마이그레이션할 수 있습니다.