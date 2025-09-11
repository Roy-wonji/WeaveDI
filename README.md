# DiContainer

![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
[![License](https://img.shields.io/github/license/pelagornis/PLCommand)](https://github.com/pelagornis/PLCommand/blob/main/LICENSE)
![Platform](https://img.shields.io/badge/platforms-macOS%2010.5-red)
[![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2FMonsteel%2FAsyncMoya&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false)](https://hits.seeyoufarm.com)

💁🏻‍♂️ iOS15+ 를 지원합니다.

## 개요

DiContainer는 Swift 애플리케이션에서 의존성 주입(Dependency Injection)을 쉽고 안전하게 관리할 수 있도록 설계된 경량화된 DI 라이브러리입니다. 타입 안전성을 보장하면서도 선언적이고 직관적인 API를 제공하여, 코드의 재사용성, 테스트 용이성, 그리고 유지보수성을 크게 향상시킵니다.

### 주요 특징

✅ **타입 안전성**: Swift의 타입 시스템을 활용하여 컴파일 타임에 의존성 오류를 방지합니다.  
✅ **동시성 안전**: Swift Concurrency를 기반으로 한 스레드 안전한 의존성 관리를 제공합니다.  
✅ **선언적 API**: 직관적이고 간결한 코드 작성이 가능합니다.  
✅ **프로퍼티 래퍼**: `@ContainerRegister`를 통한 편리한 의존성 주입을 지원합니다.  
✅ **TCA 통합**: The Composable Architecture와 원활한 연동을 제공합니다.  
✅ **테스트 지원**: 의존성 모킹과 테스트를 위한 완벽한 지원을 제공합니다.  

## 설치

### Swift Package Manager(SPM)

```swift
let package = Package(
    name: "YourProject",
    dependencies: [
        .package(url: "https://github.com/Roy-wonji/DiContainer.git", from: "1.0.7")
    ],
    targets: [
        .target(
            name: "YourTarget",
            dependencies: ["DiContainer"]
        )
    ]
)
```

## 빠른 시작

### 1단계: 의존성 부트스트랩

앱 시작 시 의존성을 등록해야 합니다. 다양한 부트스트랩 방법을 제공합니다:

#### SwiftUI

```swift
import SwiftUI
import DiContainer

@main
struct MyApp: App {
    init() {
        Task {
            await DependencyContainer.bootstrap { container in
                // 동기 의존성 등록
                container.register(LoggerProtocol.self) { ConsoleLogger() }
                container.register(ConfigProtocol.self) { AppConfig() }
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

#### UIKit (AppDelegate)

```swift
import UIKit
import DiContainer

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        Task {
            await DependencyContainer.bootstrapAsync { container in
                // 동기 의존성
                container.register(UserRepositoryProtocol.self) { UserRepository() }
                
                // 비동기 의존성 (예: 데이터베이스 초기화)
                let database = await Database.initialize()
                container.register(Database.self, instance: database)
            }
        }
        return true
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
    @ContainerRegister(\.userRepository)
    private var userRepository: UserRepositoryProtocol
    
    @ContainerRegister(\.logger)
    private var logger: LoggerProtocol
    
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
        self.networkService = DependencyContainer.live.resolve(NetworkServiceProtocol.self)!
        self.logger = DependencyContainer.live.resolve(LoggerProtocol.self)!
    }
    
    func authenticate(credentials: Credentials) async throws -> AuthToken {
        logger.info("인증 시작")
        let token = try await networkService.authenticate(credentials)
        logger.info("인증 성공")
        return token
    }
}
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

### 기본 팩토리를 활용한 안전한 주입

```swift
final class WeatherService {
    // 기본 구현체를 제공하여 의존성 누락 시에도 안전하게 동작
    @ContainerRegister(\.locationService, defaultFactory: { MockLocationService() })
    private var locationService: LocationServiceProtocol
    
    @ContainerRegister(\.networkService, defaultFactory: { MockNetworkService() })
    private var networkService: NetworkServiceProtocol
    
    func getCurrentWeather() async throws -> Weather {
        let location = try await locationService.getCurrentLocation()
        return try await networkService.fetchWeather(for: location)
    }
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
        let repository = ContainerRegister(\.userRepository, defaultFactory: { 
            DefaultUserRepository() 
        }).wrappedValue
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

### ContainerRegister

타입 안전한 의존성 주입을 위한 프로퍼티 래퍼입니다.

#### 초기화자
- `init(_:)`: KeyPath로 의존성 주입
- `init(_:defaultFactory:)`: 기본 팩토리와 함께 의존성 주입

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
    
    @ContainerRegister(\.userUseCase)
    private var userUseCase: UserUseCaseProtocol
    
    @ContainerRegister(\.logger)
    private var logger: LoggerProtocol
    
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
    @ContainerRegister(\.userRepository)
    private var repository: UserRepositoryProtocol
    
    @ContainerRegister(\.logger)
    private var logger: LoggerProtocol
    
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
        DependencyContainer.live.register(ServiceProtocol.self) { Service() }
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
    @ContainerRegister(\.userRepository)
    private var repository: UserRepositoryProtocol
    
    func getUser(id: String) async throws -> User {
        return try await repository.findUser(by: id)
    }
}

// 등록 시에도 프로토콜 타입으로
container.register(UserServiceProtocol.self) { UserService() }

// ❌ 피해야 할 예시: 구체 타입에 의존
class BadUserService {
    @ContainerRegister(\.userRepository)
    private var repository: UserRepository // 구체 타입에 직접 의존
}
```

### 3. 기본 팩토리 활용

```swift
// ✅ 좋은 예시: 기본 구현체 제공으로 안전성 확보
final class WeatherService {
    @ContainerRegister(\.locationService, defaultFactory: { MockLocationService() })
    private var locationService: LocationServiceProtocol
    
    @ContainerRegister(\.networkService, defaultFactory: { MockNetworkService() })
    private var networkService: NetworkServiceProtocol
}

// ❌ 피해야 할 예시: 기본값 없이 사용
final class RiskyWeatherService {
    @ContainerRegister(\.locationService) // 등록되지 않았을 때 크래시
    private var locationService: LocationServiceProtocol
}
```

### 4. 계층별 의존성 분리

```swift
// ✅ 좋은 예시: 계층별로 명확히 분리
// Presentation Layer
class UserViewController {
    @ContainerRegister(\.userUseCase) // UseCase에만 의존
    private var userUseCase: UserUseCaseProtocol
}

// Domain Layer (UseCase)
class UserUseCase: UserUseCaseProtocol {
    @ContainerRegister(\.userRepository) // Repository에만 의존
    private var repository: UserRepositoryProtocol
}

// Data Layer (Repository)
class UserRepository: UserRepositoryProtocol {
    @ContainerRegister(\.networkService) // 인프라스트럭처 서비스에만 의존
    private var networkService: NetworkServiceProtocol
}

// ❌ 피해야 할 예시: 계층 건너뛰기
class BadUserViewController {
    @ContainerRegister(\.userRepository) // Repository에 직접 의존 (UseCase 건너뜀)
    private var repository: UserRepositoryProtocol
    
    @ContainerRegister(\.networkService) // 인프라 계층에 직접 의존
    private var networkService: NetworkServiceProtocol
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
DependencyContainer.live.register(AuthRepositoryProtocol.self) { AuthRepository() }

// 방법 2: 기본 팩토리 제공
@ContainerRegister(\.authRepository, defaultFactory: { MockAuthRepository() })
private var authRepository: AuthRepositoryProtocol
```

#### 3. 순환 의존성 오류

순환 의존성은 두 개 이상의 의존성이 서로를 참조할 때 발생합니다.

```swift
// ❌ 문제 상황: A → B → A 순환 참조
class ServiceA {
    @ContainerRegister(\.serviceB)
    private var serviceB: ServiceBProtocol // A가 B에 의존
}

class ServiceB {
    @ContainerRegister(\.serviceA) 
    private var serviceA: ServiceAProtocol // B가 A에 의존
}
```

**해결책**: 인터페이스 분리 또는 중간 계층 도입

```swift
// ✅ 해결책 1: 인터페이스 분리
protocol ServiceADelegate {
    func handleEvent(_ event: String)
}

class ServiceA: ServiceADelegate {
    @ContainerRegister(\.serviceB)
    private var serviceB: ServiceBProtocol
    
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
    @ContainerRegister(\.eventBus)
    private var eventBus: EventBus
}

class ServiceB {
    @ContainerRegister(\.eventBus)
    private var eventBus: EventBus
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
    
    @ContainerRegister(\.networkService)
    private var networkService: NetworkServiceProtocol
}
```

#### 2. 싱글톤 패턴 적용

```swift
// 상태를 공유해야 하는 서비스는 싱글톤으로 등록
container.register(CacheServiceProtocol.self) { 
    CacheService.shared  // 이미 생성된 싱글톤 인스턴스 사용
}

// 또는 컨테이너에서 인스턴스 관리
let cacheService = CacheService()
container.register(CacheServiceProtocol.self, instance: cacheService)
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