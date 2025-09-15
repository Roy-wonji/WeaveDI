# DiContainer

![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/Roy-wonji/DiContainer/blob/main/LICENSE)
![Platform](https://img.shields.io/badge/platforms-iOS%2015%2B%20%7C%20macOS%2014%2B%20%7C%20watchOS%208%2B%20%7C%20tvOS%2015%2B-lightgrey)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange.svg?style=flat)](https://swift.org/package-manager/)

**현대적인 Swift Concurrency와 Actor 모델을 위한 차세대 의존성 주입 프레임워크**

📖 **[공식 문서](https://roy-wonji.github.io/DiContainer/documentation/dicontainer)** | 🚀 **[빠른 시작](#빠른-시작)** | 🧪 **[API 레퍼런스](#api-레퍼런스)**

## 🎯 개요

DiContainer는 Swift의 최신 동시성 모델(async/await, Actor)과 완벽하게 통합된 현대적인 의존성 주입 프레임워크입니다. **Actor Hop 최적화**를 통해 의존성 해결 성능을 최대 **10배** 향상시키며, 직관적이고 강력한 API로 모든 규모의 프로젝트에서 활용할 수 있습니다.

## ⚡ 주요 특징

### 🎭 Actor Hop 최적화
서로 다른 Actor 컨텍스트 간 전환을 지능적으로 최적화하여 의존성 해결 성능을 **최대 10배** 향상시킵니다.

### 🚀 Swift Concurrency 네이티브
async/await와 Actor isolation을 완벽 지원하는 현대적인 아키텍처를 제공합니다.

### 🔒 타입 안전성
컴파일 타임 타입 검증과 런타임 안전성을 모두 보장합니다.

### 📝 직관적인 Property Wrapper
```swift
@Inject var userService: UserServiceProtocol
@Factory var serviceFactory: ServiceFactory
```

### 🔌 플러그인 시스템
로깅, 성능 모니터링, 검증 등을 위한 확장 가능한 아키텍처를 제공합니다.

### 🧪 테스트 친화적
의존성 모킹과 테스트 격리를 위한 완벽한 지원을 제공합니다.  

## 🌟 Actor Hop이란?

Actor Hop은 Swift Concurrency에서 서로 다른 Actor 컨텍스트 간에 실행이 전환되는 현상입니다.

```swift
// 기존 방식: 여러 번의 Actor Hop 발생 ❌
@MainActor
class ViewController {
    func loadData() {
        Task {
            let service: UserService = DI.resolve()        // Hop 1
            let data = await service.fetchUser()           // Hop 2
            await MainActor.run { self.updateUI(data) }    // Hop 3
        }
    }
}

// DiContainer: 최적화된 단일 Hop ✅
@MainActor
class OptimizedViewController {
    @Inject var userService: UserService

    func loadData() {
        Task {
            let data = await userService.fetchUser()  // 최적화된 단일 Hop
            updateUI(data)  // 이미 MainActor 컨텍스트
        }
    }
}
```

### 📊 성능 향상 결과

| 시나리오 | 기존 DI | DiContainer | 개선율 |
|---------|--------|----------------|--------|
| 단일 의존성 해결 | 0.8ms | 0.1ms | **87.5%** |
| 복잡한 의존성 그래프 | 15.6ms | 1.4ms | **91.0%** |
| MainActor UI 업데이트 | 3.1ms | 0.2ms | **93.5%** |

## 🆕 2.0.0 주요 변경사항

### ✨ 새로운 기능
- **Actor Hop 최적화**: 의존성 해결 성능 최대 10배 향상
- **통합된 DI API**: 더 직관적이고 일관된 API 구조
- **플러그인 시스템**: 로깅, 성능 모니터링, 검증 등 확장 가능
- **자동 의존성 해결**: 향상된 `@Inject` property wrapper

### 🔄 마이그레이션
자세한 마이그레이션 가이드는 [MIGRATION-2.0.0.md](Sources/DiContainer.docc/ko.lproj/MIGRATION-2.0.0.md)를 참조하세요.

## 📦 설치

### Swift Package Manager (권장)

#### Xcode에서 설치
1. File → Add Package Dependencies...
2. URL 입력: `https://github.com/Roy-wonji/DiContainer.git`
3. Version: `2.0.0` 이상 선택

#### Package.swift에서 설치
```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/DiContainer.git", from: "2.0.0")
]
```

### 최소 요구사항
- iOS 15.0+ / macOS 14.0+ / watchOS 8.0+ / tvOS 15.0+
- Swift 5.9+ (Swift 6.0 권장)
- Xcode 15.0+ (Xcode 16.0 권장)

## 🚀 빠른 시작

### 1단계: 의존성 부트스트랩

```swift
import DiContainer

// 앱 시작 시 의존성 부트스트랩
await DependencyContainer.bootstrap { container in
    // 기본 서비스 등록
    container.register(UserServiceProtocol.self) {
        UserService()
    }

    container.register(NetworkServiceProtocol.self) {
        NetworkService()
    }

    container.register(LoggerProtocol.self) {
        ConsoleLogger()
    }
}
```

### 2단계: 의존성 주입 사용

#### Property Wrapper 방식 (최고 권장)

```swift
class UserViewController: UIViewController {
    @Inject var userService: UserServiceProtocol?          // 옵셔널 주입
    @RequiredInject var logger: LoggerProtocol             // 필수 주입

    override func viewDidLoad() {
        super.viewDidLoad()

        logger.info("사용자 화면 로딩 시작")

        Task {
            guard let service = userService else {
                logger.error("UserService를 찾을 수 없습니다")
                return
            }

            let user = try await service.getCurrentUser()
            await updateUI(with: user)
            logger.info("사용자 데이터 로딩 완료")
        }
    }
}
```

#### KeyPath 기반 타입 안전 주입

```swift
// DependencyContainer 확장
extension DependencyContainer {
    var userService: UserServiceProtocol? {
        resolve(UserServiceProtocol.self)
    }

    var logger: LoggerProtocol? {
        resolve(LoggerProtocol.self)
    }
}

// KeyPath 기반 주입 사용
class UserViewModel {
    @Inject(\.userService) var userService: UserServiceProtocol?
    @RequiredInject(\.logger) var logger: LoggerProtocol
}
```

#### 수동 해결 방식

```swift
class AuthService {
    private let networkService: NetworkServiceProtocol
    private let logger: LoggerProtocol

    init() throws {
        // 안전한 해결 (throws)
        self.networkService = try UnifiedDI.resolveThrows(NetworkServiceProtocol.self)

        // 기본값과 함께 해결
        self.logger = UnifiedDI.resolve(
            LoggerProtocol.self,
            default: ConsoleLogger()
        )
    }

    func authenticate() async throws -> AuthToken {
        logger.info("인증 시작")
        let token = try await networkService.authenticate()
        logger.info("인증 성공")
        return token
    }
}
```

### 2단계: 의존성 컨테이너 확장

KeyPath 기반 접근을 위해 컨테이너를 확장합니다:

```swift
import DiContainer

extension DependencyContainer {
    /// 사용자 리포지토리 의존성
    var userRepository: UserRepositoryProtocol? {
        resolve(UserRepositoryProtocol.self)
    }
    
    /// 네트워크 서비스 의존성
    var networkService: NetworkServiceProtocol? {
        resolve(NetworkServiceProtocol.self)
    }
    
    /// 로거 의존성
    var logger: LoggerProtocol? {
        resolve(LoggerProtocol.self)
    }
}
```

### 3단계: 의존성 주입 사용

#### 프로퍼티 래퍼 방식

```swift
import DiContainer

final class UserService {
    @Inject(\.userRepository)
    var userRepository: UserRepositoryProtocol
    
    @Inject(\.logger)
    var logger: LoggerProtocol
    
    func getUser(id: String) async throws -> User {
        logger.debug("사용자 조회 시작: \(id)")
        let user = try await userRepository.findUser(by: id)
        logger.debug("사용자 조회 완료: \(user.name)")
        return user
    }
}
```

#### 직접 조회 방식

```swift
final class AuthenticationService {
    private let networkService: NetworkServiceProtocol
    private let logger: LoggerProtocol
    
    init() {
        self.networkService = UnifiedDI.requireResolve(NetworkServiceProtocol.self)
        self.logger = UnifiedDI.requireResolve(LoggerProtocol.self)
    }
    
    func authenticate(credentials: Credentials) async throws -> AuthToken {
        logger.info("인증 시작")
        let token = try await networkService.authenticate(credentials)
        logger.info("인증 성공")
        return token
    }
}
```

### 4단계: 등록 여부 확인 (Introspection)

등록 여부를 빠르게 확인할 수 있습니다.

```swift
// UnifiedDI를 통한 등록 여부 확인(존재 여부 검사)
let exists = (UnifiedDI.resolve(NetworkServiceProtocol.self) != nil)
let exists2 = (UnifiedDI.resolve(\.networkService) != nil)
```

## AutoResolver 옵션

- 메인 액터에서 자동 해석이 동작합니다(리플렉션/주입 안전성 우선).
- 토글/제외 설정

```swift
// 전체 활성/비활성
AutoDependencyResolver.enable()
AutoDependencyResolver.disable()

// 특정 타입 제외/해제
AutoDependencyResolver.excludeType(UserService.self)
AutoDependencyResolver.includeType(UserService.self)
```

- 문자열 기반 타입 매핑은 사용하지 않습니다. `@AutoResolve` 또는 명시적 등록을 사용하세요.

## 컨테이너 배치 빌드와 리포트

`Container`는 수집된 모듈을 병렬로 등록합니다. 비-throwing, 메트릭, 리포트 API를 제공합니다.

```swift
let container = Container()
// 모듈 수집 …

// 1) 기본 빌드(비-throwing)
await container.build()

// 2) 메트릭 수집
let metrics = await container.buildWithMetrics()
print(metrics.summary)

// 3) 상세 리포트(성공/실패 목록)
let result = await container.buildWithResults()
print(result.summary)

// 4) throwing 변형(향후 throwing 등록 지원 대비)
try await container.buildThrowing()
```

## 고급 사용법

### 부트스트랩 옵션

#### 혼합 부트스트랩 (동기 + 비동기)

```swift
@MainActor
func setupDependencies() async {
    await DependencyContainer.bootstrapMixed(
        sync: { container in
            // 즉시 필요한 의존성
            container.register(LoggerProtocol.self) { ConsoleLogger() }
            container.register(ConfigProtocol.self) { AppConfig() }
        },
        async: { container in
            // 비동기 초기화가 필요한 의존성
            let database = await DatabaseManager.initialize()
            container.register(DatabaseManager.self, instance: database)
            
            let remoteConfig = await RemoteConfigService.load()
            container.register(RemoteConfigService.self, instance: remoteConfig)
        }
    )
}
```

#### 조건부 부트스트랩

```swift
// 이미 부트스트랩되어 있지 않은 경우에만 실행
Task {
    let wasBootstrapped = await DependencyContainer.bootstrapIfNeeded { container in
        container.register(AnalyticsProtocol.self) { Analytics() }
    }
    print("부트스트랩 수행됨: \(wasBootstrapped)")
}
```

### 런타임 의존성 업데이트

```swift
// 앱 실행 중 의존성 교체
await DependencyContainer.update { container in
    container.register(LoggerProtocol.self) { FileLogger() } // 콘솔 → 파일 로거로 교체
}

// 비동기 업데이트
await DependencyContainer.updateAsync { container in
    let newDatabase = await Database.open(path: "production.db")
    container.register(Database.self, instance: newDatabase)
}
```

### Module 시스템 확장(설계 개요)

향후 모듈 시스템은 다음을 목표로 확장됩니다.

- 자동 의존성 해결(Reflection 기반)
  - 등록된 타입 그래프를 스캔하고, 생성자 시그니처를 반사(reflection)로 분석하여 자동 주입을 시도합니다.
  - 실패 시 `DI.resolveThrows`/`resolveResult`로 정밀한 피드백을 제공합니다.
- 플러그인 시스템(확장 가능한 아키텍처)
  - “Module 플러그인”이 특정 규칙(이름/어트리뷰트/애노테이션)을 기준으로 모듈을 자동 수집/등록합니다.
  - 예: `@AutoModule`가 붙은 타입 자동 등록, 특정 네임스페이스 스캔 등.

현재도 `RegisterModule` + `Factory` 조합으로 선언적 구성이 가능하며, 위 기능은 선택적으로 레이어를 더하는 형태로 제공될 예정입니다.

### Factory Property Wrapper

`@Factory`를 통해 `FactoryValues.current`에 저장된 팩토리를 간단히 주입할 수 있습니다.

```swift
final class MyVM {
  @Factory(\.repositoryFactory) var repositoryFactory: RepositoryModuleFactory
  @Factory(\.useCaseFactory)     var useCaseFactory: UseCaseModuleFactory
}
```

## Concurrency 메모: actor hop 최소화

actor hop은 서로 다른 actor 격리로 이동하면서 발생하는 스케줄링 비용을 의미합니다. 
`Container.build()`는 내부 상태 배열을 스냅샷한 뒤 TaskGroup에서 작업을 생성하여, 
작업 생성 중 불필요한 actor hop을 줄입니다(스냅샷 → 병렬 실행 → 정리 순서).

```swift
let snapshot = modules  // hop 최소화용 스냅샷
await withTaskGroup(of: Void.self) { group in
  for module in snapshot {
    group.addTask { await module.register() }
  }
  await group.waitForAll()
}
```

## 왜 부트스트랩을 쓰나요?

- 원자적 초기화: “컨테이너 교체 + 상태 플래그”를 한 번에 처리하여 반쪽 상태를 방지합니다.
- 초기 접근 보호: 앱 시작 전에 `resolve`가 호출되는 상황을 피하고, 필요한 비동기 준비(DB, 원격 설정 등)를 보장합니다.
- 동시성 안전: `BootstrapCoordinator`(actor)가 초기화 경합을 직렬화합니다.
- 테스트 용이성: `resetForTesting`으로 상태를 명확히 리셋하고, 각 테스트에서 독립적으로 등록/해결할 수 있습니다.

### 기본값(디폴트) 전략으로 안전한 주입

```swift
// 패턴 1) 옵셔널 주입 + 디폴트 구현
final class WeatherService {
    @Inject(\.locationService) var locationService: LocationServiceProtocol?
    @Inject(\.networkService) var networkService: NetworkServiceProtocol?
    
    func getCurrentWeather() async throws -> Weather {
        let locationSvc = locationService ?? MockLocationService()
        let network = networkService ?? MockNetworkService()
        
        let location = try await locationSvc.getCurrentLocation()
        return try await network.fetchWeather(for: location)
    }
}

// 패턴 2) UnifiedDI.resolve(default:) 사용
final class WeatherService2 {
    private let network: NetworkServiceProtocol =
        UnifiedDI.resolve(NetworkServiceProtocol.self, default: MockNetworkService())
}
```

### Factory 패턴을 활용한 모듈화

#### Repository Factory

```swift
import DiContainer

extension RepositoryModuleFactory {
    /// Repository 모듈들의 기본 정의를 등록합니다.
    public mutating func registerDefaultDefinitions() {
        let registerModuleCopy = registerModule
        repositoryDefinitions = {
            return [
                registerModuleCopy.makeDependency(UserRepositoryProtocol.self) { 
                    UserRepository() 
                },
                registerModuleCopy.makeDependency(AuthRepositoryProtocol.self) { 
                    AuthRepository() 
                },
                registerModuleCopy.makeDependency(SettingsRepositoryProtocol.self) { 
                    SettingsRepository() 
                }
            ]
        }()
    }
}
```

#### UseCase Factory

```swift
import DiContainer

extension UseCaseModuleFactory {
    public var useCaseDefinitions: [() -> Module] {
        return [
            registerModule.makeUseCaseWithRepository(
                UserUseCaseProtocol.self,
                repositoryProtocol: UserRepositoryProtocol.self,
                repositoryFallback: DefaultUserRepository()
            ) { repository in
                UserUseCase(repository: repository)
            },
            
            registerModule.makeUseCaseWithRepository(
                AuthUseCaseProtocol.self,
                repositoryProtocol: AuthRepositoryProtocol.self,
                repositoryFallback: DefaultAuthRepository()
            ) { repository in
                AuthUseCase(repository: repository)
            }
        ]
    }
}
```

#### AppDIContainer에서 Factory 사용

```swift
import DiContainer

extension AppDIContainer {
    /// 기본 의존성들을 등록합니다.
    /// Factory 패턴을 사용하여 Repository와 UseCase를 체계적으로 관리합니다.
    public func registerDefaultDependencies() async {
        var repositoryFactory = self.repositoryFactory
        let useCaseFactory = self.useCaseFactory
        
        await registerDependencies { container in
            // Repository 기본 정의 등록
            repositoryFactory.registerDefaultDefinitions()
            
            // Repository 모듈들을 비동기적으로 등록
            await repositoryFactory.makeAllModules().asyncForEach { module in
                await container.register(module)
            }
            
            // UseCase 모듈들을 비동기적으로 등록
            await useCaseFactory.makeAllModules().asyncForEach { module in
                await container.register(module)
            }
        }
    }
}
```

### TCA(The Composable Architecture) 통합

#### DependencyKey 구현

```swift
import ComposableArchitecture
import DiContainer

extension UserUseCase: DependencyKey {
    public static var liveValue: UserUseCaseProtocol = {
        // 등록되어 있으면 resolve, 없으면 기본 구현을 등록하며 사용
        let repository = ContainerRegister.register(\.userRepository) {
            DefaultUserRepository()
        }
        return UserUseCase(repository: repository)
    }()
}

extension DependencyValues {
    var userUseCase: UserUseCaseProtocol {
        get { self[UserUseCase.self] }
        set { self[UserUseCase.self] = newValue }
    }
}
```

#### Reducer에서 사용

```swift
import ComposableArchitecture

@Reducer
struct UserFeature {
    struct State: Equatable {
        var user: User?
        var isLoading = false
        var errorMessage: String?
    }
    
    enum Action: Equatable {
        case loadUser(String)
        case userLoaded(Result<User, UserError>)
    }
    
    @Dependency(\.userUseCase) var userUseCase
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .loadUser(let id):
            state.isLoading = true
            state.errorMessage = nil
            
            return .run { send in
                do {
                    let user = try await userUseCase.getUser(id: id)
                    await send(.userLoaded(.success(user)))
                } catch let error as UserError {
                    await send(.userLoaded(.failure(error)))
                }
            }
            
        case .userLoaded(.success(let user)):
            state.isLoading = false
            state.user = user
            return .none
            
        case .userLoaded(.failure(let error)):
            state.isLoading = false
            state.errorMessage = error.localizedDescription
            return .none
        }
    }
}
```

## API 레퍼런스

### UnifiedDI

- `register<T>(_:factory:)` 타입 기반 등록(지연 생성)
- `register<T>(_:factory:)` KeyPath 등록(생성과 동시에 인스턴스 등록)
- `registerIf<T>(_:condition:factory:fallback:)` 조건부 등록
- `resolve<T>(_: ) -> T?` 옵셔널 해결
- `requireResolve<T>(_: ) -> T` 필수 해결(fatalError)
- `resolveThrows<T>(_: ) throws -> T` 안전한 해결(throws)
- `resolve<T>(_:default:) -> T` 기본값 포함 해결
- `registerMany { … }` 일괄 등록 Result Builder
- `release<T>(_: )` 특정 타입 해제, `releaseAll()` 전체 해제(테스트 용)

### DependencyContainer

#### 등록 메서드
- `register<T>(_:build:)`: 팩토리 클로저로 의존성 등록
- `register<T>(_:instance:)`: 인스턴스 직접 등록

#### 조회 메서드
- `resolve<T>(_:)`: 의존성 조회 (옵셔널 반환)
- `resolveOrDefault<T>(_:default:)`: 의존성 조회 또는 기본값 반환

#### 부트스트랩 메서드
- `bootstrap(_:)`: 동기 부트스트랩
- `bootstrapAsync(_:)`: 비동기 부트스트랩
- `bootstrapMixed(sync:async:)`: 혼합 부트스트랩
- `bootstrapIfNeeded(_:)`: 조건부 부트스트랩

#### 업데이트 메서드
- `update(_:)`: 동기 의존성 업데이트
- `updateAsync(_:)`: 비동기 의존성 업데이트

#### 유틸리티 메서드
- `isBootstrapped`: 부트스트랩 상태 확인
- `ensureBootstrapped()`: 부트스트랩 보장
- `resetForTesting()`: 테스트용 초기화 (DEBUG 전용)

### Inject

타입 안전한 의존성 주입을 위한 프로퍼티 래퍼입니다. 변수의 옵셔널 여부에 따라 동작이 달라집니다.

- Optional 타입으로 선언: 미등록 시 `nil` 반환(크래시 없음)
- Non-Optional 타입으로 선언: 미등록 시 친화적인 메시지와 함께 `fatalError`

예시

```swift
@Inject(\.logger) var logger: LoggerProtocol         // 필수
@Inject(\.analytics) var analytics: AnalyticsProtocol? // 선택
```

필수 의존성만 허용하고 싶다면 `@RequiredDependency(\.keyPath)`를 사용하세요.

### RegisterModule

Repository와 UseCase 모듈 생성을 위한 헬퍼 구조체입니다.

#### 주요 메서드
- `makeModule<T>(_:factory:)`: 모듈 생성
- `makeDependency<T,U>(_:factory:)`: 의존성 모듈 생성
- `makeUseCaseWithRepository(_:repositoryProtocol:repositoryFallback:factory:)`: UseCase 모듈 생성
- `resolveOrDefault<T>(_:default:)`: 조회 또는 기본값 반환
- `defaultInstance<T>(for:fallback:)`: 기본 인스턴스 반환

## 실제 사용 사례

### 1. MVVM 아키텍처에서 활용

```swift
import DiContainer
import Combine

final class UserListViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Inject(\.userUseCase) var userUseCase: UserUseCaseProtocol
    @Inject(\.logger)     var logger: LoggerProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    func loadUsers() {
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                logger.info("사용자 목록 로딩 시작")
                let loadedUsers = try await userUseCase.getAllUsers()
                self.users = loadedUsers
                logger.info("사용자 목록 로딩 완료: \(loadedUsers.count)명")
            } catch {
                self.errorMessage = error.localizedDescription
                logger.error("사용자 목록 로딩 실패: \(error)")
            }
            self.isLoading = false
        }
    }
}
```

### 2. Clean Architecture 적용 예시

```swift
// Domain Layer
protocol UserUseCaseProtocol {
    func getUser(id: String) async throws -> User
    func createUser(_ user: CreateUserRequest) async throws -> User
    func updateUser(_ user: User) async throws -> User
    func deleteUser(id: String) async throws
}

// Data Layer
protocol UserRepositoryProtocol {
    func findUser(by id: String) async throws -> User
    func saveUser(_ user: User) async throws -> User
    func deleteUser(id: String) async throws
}

// Implementation
struct UserUseCase: UserUseCaseProtocol {
    @Inject(\.userRepository) var repository: UserRepositoryProtocol
    @Inject(\.logger)        var logger: LoggerProtocol
    
    func getUser(id: String) async throws -> User {
        logger.debug("사용자 조회: \(id)")
        return try await repository.findUser(by: id)
    }
    
    func createUser(_ request: CreateUserRequest) async throws -> User {
        logger.info("새 사용자 생성: \(request.email)")
        let user = User(
            id: UUID().uuidString,
            name: request.name,
            email: request.email,
            createdAt: Date()
        )
        return try await repository.saveUser(user)
    }
}
```

### 3. 테스트 환경 구성

```swift
import XCTest
import DiContainer

final class UserServiceTests: XCTestCase {
    
    override func setUp() async throws {
        await super.setUp()
        
        // 테스트용 컨테이너 초기화
        await DependencyContainer.resetForTesting()
        
        // 테스트 더블 등록
        await DependencyContainer.bootstrap { container in
            container.register(UserRepositoryProtocol.self) { MockUserRepository() }
            container.register(LoggerProtocol.self) { MockLogger() }
            container.register(NetworkServiceProtocol.self) { MockNetworkService() }
        }
    }
    
    func testUserCreation() async throws {
        // Given
        let userService = UserService()
        let request = CreateUserRequest(name: "테스트 사용자", email: "test@example.com")
        
        // When
        let createdUser = try await userService.createUser(request)
        
        // Then
        XCTAssertEqual(createdUser.name, "테스트 사용자")
        XCTAssertEqual(createdUser.email, "test@example.com")
        XCTAssertFalse(createdUser.id.isEmpty)
    }
}

// Mock 구현체
class MockUserRepository: UserRepositoryProtocol {
    private var users: [String: User] = [:]
    
    func findUser(by id: String) async throws -> User {
        guard let user = users[id] else {
            throw UserError.userNotFound
        }
        return user
    }
    
    func saveUser(_ user: User) async throws -> User {
        users[user.id] = user
        return user
    }
    
    func deleteUser(id: String) async throws {
        users.removeValue(forKey: id)
    }
}
```

### 4. 환경별 구성 관리

```swift
import DiContainer

enum AppEnvironment {
    case development
    case staging
    case production
}

extension DependencyContainer {
    static func bootstrapForEnvironment(_ environment: AppEnvironment) async {
        await bootstrap { container in
            // 공통 의존성
            container.register(LoggerProtocol.self) { 
                environment == .development ? ConsoleLogger() : FileLogger() 
            }
            
            // 환경별 구성
            switch environment {
            case .development:
                container.register(NetworkServiceProtocol.self) { 
                    NetworkService(baseURL: "https://dev-api.example.com") 
                }
                container.register(AnalyticsProtocol.self) { 
                    MockAnalytics() 
                }
                
            case .staging:
                container.register(NetworkServiceProtocol.self) { 
                    NetworkService(baseURL: "https://staging-api.example.com") 
                }
                container.register(AnalyticsProtocol.self) { 
                    FirebaseAnalytics() 
                }
                
            case .production:
                container.register(NetworkServiceProtocol.self) { 
                    NetworkService(baseURL: "https://api.example.com") 
                }
                container.register(AnalyticsProtocol.self) { 
                    MixpanelAnalytics() 
                }
            }
        }
    }
}

// AppDelegate에서 사용
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        #if DEBUG
        let environment: AppEnvironment = .development
        #elseif STAGING
        let environment: AppEnvironment = .staging
        #else
        let environment: AppEnvironment = .production
        #endif
        
        Task {
            await DependencyContainer.bootstrapForEnvironment(environment)
        }
        
        return true
    }
}
```

## 베스트 프랙티스

### 1. 의존성 등록 시점

```swift
// ✅ 좋은 예시: 앱 시작 시 모든 의존성을 등록
@main
struct MyApp: App {
    init() {
        Task {
            await DependencyContainer.bootstrapAsync { container in
                // 모든 핵심 의존성을 여기서 등록
                await self.registerAllDependencies(container)
            }
        }
    }
    
    private func registerAllDependencies(_ container: DependencyContainer) async {
        // Repository 등록
        container.register(UserRepositoryProtocol.self) { UserRepository() }
        container.register(AuthRepositoryProtocol.self) { AuthRepository() }
        
        // UseCase 등록
        container.register(UserUseCaseProtocol.self) {
            UserUseCase(repository: container.resolve(UserRepositoryProtocol.self)!)
        }
        
        // Service 등록
        container.register(NetworkServiceProtocol.self) { NetworkService() }
    }
}

// ❌ 피해야 할 예시: 늦은 시점에 등록
class SomeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // 뷰가 로드될 때 의존성을 등록하는 것은 좋지 않습니다
        UnifiedDI.register(ServiceProtocol.self) { Service() }
    }
}
```

### 2. 프로토콜 기반 의존성 정의

```swift
// ✅ 좋은 예시: 프로토콜 기반으로 추상화
protocol UserServiceProtocol {
    func getUser(id: String) async throws -> User
    func createUser(_ request: CreateUserRequest) async throws -> User
}

class UserService: UserServiceProtocol {
    @Inject(\.userRepository) var repository: UserRepositoryProtocol
    
    func getUser(id: String) async throws -> User {
        return try await repository.findUser(by: id)
    }
}

// 등록 시에도 프로토콜 타입으로
container.register(UserServiceProtocol.self) { UserService() }

// ❌ 피해야 할 예시: 구체 타입에 의존
class BadUserService {
    @Inject(\.userRepository) var repository: UserRepository // 구체 타입에 직접 의존
}
```

### 3. 기본값(디폴트) 전략

```swift
// ✅ 좋은 예시: 옵셔널 주입 + 기본값
final class WeatherService {
    @Inject(\.locationService) var locationService: LocationServiceProtocol?
    @Inject(\.networkService) var networkService: NetworkServiceProtocol?
}

// ❌ 피해야 할 예시: 기본값 없이 Non-Optional만 사용(등록 누락 시 크래시)
final class RiskyWeatherService {
    @Inject(\.locationService) var locationService: LocationServiceProtocol
}
```

### 4. 계층별 의존성 분리

```swift
// ✅ 좋은 예시: 계층별로 명확히 분리
// Presentation Layer
class UserViewController {
    @Inject(\.userUseCase) var userUseCase: UserUseCaseProtocol // UseCase에만 의존
}

// Domain Layer (UseCase)
class UserUseCase: UserUseCaseProtocol {
    @Inject(\.userRepository) var repository: UserRepositoryProtocol // Repository에만 의존
}

// Data Layer (Repository)
class UserRepository: UserRepositoryProtocol {
    @Inject(\.networkService) var networkService: NetworkServiceProtocol // 인프라스트럭처 서비스에만 의존
}

// ❌ 피해야 할 예시: 계층 건너뛰기
class BadUserViewController {
    @Inject(\.userRepository) var repository: UserRepositoryProtocol // Repository에 직접 의존 (UseCase 건너뜀)
    @Inject(\.networkService) var networkService: NetworkServiceProtocol // 인프라 계층에 직접 의존
}
```

### 5. 테스트를 위한 의존성 구성

```swift
// ✅ 좋은 예시: 테스트별 독립적인 구성
class UserServiceTests: XCTestCase {
    
    override func setUp() async throws {
        await super.setUp()
        await DependencyContainer.resetForTesting()
        
        // 각 테스트에 맞는 Mock 등록
        await DependencyContainer.bootstrap { container in
            container.register(UserRepositoryProtocol.self) { 
                MockUserRepository(shouldFail: false) 
            }
            container.register(LoggerProtocol.self) { 
                MockLogger() 
            }
        }
    }
    
    func testUserCreationFailure() async throws {
        // 특정 테스트를 위한 의존성 교체
        await DependencyContainer.update { container in
            container.register(UserRepositoryProtocol.self) { 
                MockUserRepository(shouldFail: true) 
            }
        }
        
        // 테스트 실행
        let service = UserService()
        
        do {
            _ = try await service.createUser(CreateUserRequest(name: "Test", email: "test@example.com"))
            XCTFail("예외가 발생해야 합니다")
        } catch {
            XCTAssertTrue(error is UserError)
        }
    }
}
```

## 문제 해결

### 자주 발생하는 오류

#### 1. 부트스트랩 미완료 오류

```
Precondition failed: DI not bootstrapped. Call DependencyContainer.bootstrap(...) first.
```

**해결책**: 앱 시작 시 부트스트랩을 완료했는지 확인하세요.

```swift
// 부트스트랩 상태 확인
let isReady = await DependencyContainer.isBootstrapped
if !isReady {
    await DependencyContainer.bootstrap { container in
        // 의존성 등록
    }
}
```

#### 2. 의존성 등록 누락 오류

```
Fatal error: AuthRepositoryProtocol 타입의 등록된 의존성을 찾을 수 없으며, 기본 팩토리도 제공되지 않았습니다.
```

**해결책**: 의존성을 등록하거나 기본 팩토리를 제공하세요.

```swift
// 방법 1: 의존성 등록
UnifiedDI.register(AuthRepositoryProtocol.self) { AuthRepository() }

// 방법 2: 기본값 사용 패턴
@Inject(\.authRepository) var authRepository: AuthRepositoryProtocol?
let repo = authRepository ?? MockAuthRepository()
```

#### 3. 순환 의존성 오류

순환 의존성은 두 개 이상의 의존성이 서로를 참조할 때 발생합니다.

```swift
// ❌ 문제 상황: A → B → A 순환 참조
class ServiceA {
    @Inject(\.serviceB) var serviceB: ServiceBProtocol // A가 B에 의존
}

class ServiceB {
    @Inject(\.serviceA) var serviceA: ServiceAProtocol // B가 A에 의존
}
```

**해결책**: 인터페이스 분리 또는 중간 계층 도입

```swift
// ✅ 해결책 1: 인터페이스 분리
protocol ServiceADelegate {
    func handleEvent(_ event: String)
}

class ServiceA: ServiceADelegate {
    @Inject(\.serviceB) var serviceB: ServiceBProtocol
    
    func handleEvent(_ event: String) {
        // 이벤트 처리
    }
}

class ServiceB {
    private weak var delegate: ServiceADelegate?
    
    func setDelegate(_ delegate: ServiceADelegate) {
        self.delegate = delegate
    }
}

// ✅ 해결책 2: 중간 계층 도입
class EventBus {
    // 이벤트 중개자 역할
}

class ServiceA {
    @Inject(\.eventBus) var eventBus: EventBus
}

class ServiceB {
    @Inject(\.eventBus) var eventBus: EventBus
}
```

### 성능 최적화

#### 1. 지연 초기화 활용

```swift
// 무거운 의존성은 지연 초기화 사용
class ExpensiveService {
    private lazy var heavyComponent: HeavyComponent = {
        return HeavyComponent()
    }()
    
    @Inject(\.networkService) var networkService: NetworkServiceProtocol
}
```

#### 2. 인스턴스 관리 패턴

```swift
// 상태를 공유해야 하는 서비스는 인스턴스로 등록
let cacheService = CacheService()
container.register(CacheServiceProtocol.self, instance: cacheService)

// 또는 팩토리 패턴으로 관리
container.register(CacheServiceProtocol.self) {
    CacheService()
}
```

## 기여하기

DiContainer는 오픈소스 프로젝트로, 모든 형태의 기여를 환영합니다.

### 기여 방법

1. **이슈 리포트**: 버그를 발견하거나 개선사항이 있으면 GitHub Issues에서 리포트해 주세요.
2. **기능 제안**: 새로운 기능이나 개선사항을 제안해 주세요.
3. **코드 기여**: Pull Request를 통해 코드 개선사항을 제출해 주세요.
4. **문서 개선**: 문서화 개선도 큰 도움이 됩니다.

### 개발 가이드라인

- Swift 코딩 컨벤션을 따라주세요.
- 새로운 기능에는 테스트 코드를 포함해 주세요.
- API 변경사항에는 문서 업데이트도 함께 진행해 주세요.
- 커밋 메시지는 명확하고 설명적으로 작성해 주세요.

## 라이선스

DiContainer는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 작성자

**서원지(Roy)**  
📧 [suhwj81@gmail.com](mailto:suhwj81@gmail.com)  
🐙 [GitHub](https://github.com/Roy-wonji)

## 감사의 글

이 프로젝트는 [Swinject](https://github.com/Swinject/Swinject)에서 영감을 받아 Swift의 현대적인 기능들과 더 간단한 API를 제공하도록 재설계되었습니다.

---

DiContainer를 사용해주셔서 감사합니다! 궁금한 점이나 개선사항이 있으시면 언제든지 연락해 주세요. 🙏
