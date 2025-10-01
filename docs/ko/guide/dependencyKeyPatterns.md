# 의존성 키 패턴

WeaveDI의 실제 구현을 사용하여 안전한 의존성 해결을 위한 DependencyKey 패턴을 정리합니다.

## 개요

WeaveDI의 의존성 시스템은 KeyPath 기반 등록과 타입 안전한 해결을 중심으로 구축되었습니다. 이 가이드는 실제 소스 코드 구현을 기반으로 프레임워크에서 사용 가능한 실제 API 패턴을 다룹니다.

## 핵심 API 패턴

### 1. UnifiedDI 등록 패턴

의존성 등록 및 해결을 위한 주요 API:

```swift
import WeaveDI

// 즉시 반환과 함께 기본 등록
let userService = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}

// KeyPath 기반 등록
let repository = UnifiedDI.register(\.userRepository) {
    UserRepositoryImpl()
}

// 비동기 등록
let asyncService = await UnifiedDI.registerAsync(AsyncService.self) {
    await AsyncServiceImpl()
}
```

### 2. 안전한 해결 패턴

```swift
// 안전한 해결 (옵셔널 반환)
let service = UnifiedDI.resolve(UserService.self)

// 필수 해결 (실패 시 fatalError)
let requiredService = UnifiedDI.requireResolve(UserService.self)

// 기본값 폴백과 함께 해결
let serviceWithDefault = UnifiedDI.resolve(UserService.self, default: DefaultUserService())

// 비동기 해결
let asyncResult = await UnifiedDI.resolveAsync(AsyncService.self)
```

## 고급 패턴

### 3. WeaveDI.Container Bootstrap 패턴

소스 코드의 실제 bootstrap API:

```swift
// 동기 bootstrap
await WeaveDI.Container.bootstrap { container in
    _ = container.register(UserService.self) { UserServiceImpl() }
    _ = container.register(DataRepository.self) { DataRepositoryImpl() }
}

// 비동기 bootstrap
let success = await WeaveDI.Container.bootstrapAsync { container in
    let config = await RemoteConfig.fetch()
    _ = container.register(Configuration.self) { config }
}

// 혼합 bootstrap (동기 + 비동기)
await WeaveDI.Container.bootstrapMixed(
    sync: { container in
        _ = container.register(Logger.self) { LoggerImpl() }
    },
    async: { container in
        let database = await Database.initialize()
        _ = container.register(Database.self) { database }
    }
)

// 조건부 bootstrap
let wasNeeded = await WeaveDI.Container.bootstrapIfNeeded { container in
    _ = container.register(DevService.self) { DevServiceImpl() }
}
```

### 4. Property Wrapper 패턴

실제 PropertyWrapper 구현을 기반으로:

```swift
class ViewController {
    // 옵셔널 주입 (안전)
    @Inject var userService: UserService?

    // 필수 주입 (미등록 시 크래시)
    @Inject var logger: Logger

    // KeyPath 기반 주입
    @Inject(\.dataRepository) var repository: DataRepository?

    // Factory 패턴 (매번 새 인스턴스)
    @Factory var temporaryCache: TemporaryCache

    // 에러 처리가 있는 안전한 주입
    @SafeInject var riskService: RiskService

    func handleSafeInjection() {
        switch riskService {
        case .success(let service):
            service.doWork()
        case .failure(let error):
            print("주입 실패: \(error)")
        }

        // 또는 throwing 사용
        do {
            let service = try riskService.getValue()
            service.doWork()
        } catch {
            print("서비스 획득 실패: \(error)")
        }
    }
}
```

### 5. SimpleKeyPathRegistry 패턴

등록을 더 세밀하게 제어:

```swift
// 기본 KeyPath 등록
SimpleKeyPathRegistry.register(\.userService) {
    UserServiceImpl()
}

// 조건부 등록
SimpleKeyPathRegistry.registerIf(\.debugService, condition: isDebugMode) {
    DebugServiceImpl()
}

// 환경별 등록
#if DEBUG
SimpleKeyPathRegistry.registerIfDebug(\.mockService) {
    MockServiceImpl()
}
#else
SimpleKeyPathRegistry.registerIfRelease(\.productionService) {
    ProductionServiceImpl()
}
#endif
```

### 6. SafeDependencyRegister 헬퍼

```swift
// 폴백과 함께 안전한 해결
let service = SafeDependencyRegister.resolveWithFallback(\.userService) {
    DefaultUserService()
}

// 옵셔널 안전한 해결
let optionalService = SafeDependencyRegister.safeResolve(\.optionalService)
```

## 모듈 시스템 패턴

### 7. 모듈 등록

실제 Module 구조체 기반:

```swift
// 모듈 생성 및 등록
let userModule = Module(UserService.self) {
    UserServiceImpl()
}

await WeaveDI.Container.shared.register(userModule)

// 에러 처리와 함께 등록
do {
    await userModule.registerThrowing()
} catch {
    print("모듈 등록 실패: \(error)")
}
```

### 8. ModuleFactory 패턴

실제 ModuleFactory 프로토콜 사용:

```swift
struct UserModuleFactory: ModuleFactory {
    var registerModule = RegisterModule()
    var definitions: [@Sendable () -> Module] = []

    mutating func setup() {
        definitions.append {
            registerModule.makeModule(UserService.self) {
                UserServiceImpl()
            }
        }

        definitions.append {
            registerModule.makeUseCaseWithRepository(
                UserUseCase.self,
                repositoryProtocol: UserRepository.self,
                repositoryFallback: DefaultUserRepository(),
                factory: { repository in
                    UserUseCaseImpl(repository: repository)
                }
            )()
        }
    }

    func makeAllModules() -> [Module] {
        definitions.map { $0() }
    }
}

// 사용법
var factory = UserModuleFactory()
factory.setup()

let modules = factory.makeAllModules()
for module in modules {
    await module.register()
}
```

### 9. ModuleFactoryManager 패턴

```swift
let manager = ModuleFactoryManager(
    repositoryFactory: RepositoryModuleFactory(),
    useCaseFactory: UseCaseModuleFactory(),
    scopeFactory: ScopeModuleFactory()
)

await manager.registerAll()
```

## 스코프 관리 패턴

### 10. ScopeContext 사용

```swift
// 현재 스코프 설정
ScopeContext.shared.setCurrent(.screen, id: "userProfile")

// 현재 스코프 ID 가져오기
let currentScreenID = ScopeContext.shared.currentID(for: .screen)

// 사용 가능한 스코프 종류
let scopes: [ScopeKind] = [.singleton, .screen, .session, .request]
```

## 베스트 프랙티스

### 타입 안전성

```swift
// ✅ 좋음: 타입 안전성을 위해 KeyPath 사용
UnifiedDI.register(\.userService) { UserServiceImpl() }

// ✅ 좋음: 옵셔널 결과 처리
if let service = UnifiedDI.resolve(UserService.self) {
    service.performAction()
}

// ❌ 피할 것: 강제 언래핑
let service = UnifiedDI.resolve(UserService.self)! // 위험!
```

### 에러 처리

```swift
// ✅ 좋음: 에러가 발생할 수 있는 의존성에 SafeInject 사용
@SafeInject var networkService: NetworkService

func handleNetworkOperation() {
    do {
        let service = try networkService.getValue()
        await service.fetchData()
    } catch SafeInjectError.notRegistered {
        // 누락된 의존성 처리
        showOfflineMode()
    } catch {
        // 기타 에러 처리
        showError(error)
    }
}
```

### 성능 최적화

```swift
// 비용이 높은 서비스를 싱글톤으로 등록
UnifiedDI.register(ExpensiveService.self) {
    ExpensiveServiceImpl() // 한 번만 생성
}

// 가벼운 상태 없는 서비스에 Factory 사용
@Factory var dateFormatter: DateFormatter // 매번 새 인스턴스
```

### 테스트 지원

```swift
#if DEBUG
extension WeaveDI.Container {
    static func setupForTesting() async {
        await WeaveDI.Container.releaseAll() // 모든 의존성 제거

        await WeaveDI.Container.bootstrap { container in
            _ = container.register(UserService.self) { MockUserService() }
            _ = container.register(NetworkService.self) { MockNetworkService() }
        }
    }
}
#endif
```

## 다른 DI 프레임워크에서 마이그레이션

### Swinject에서

```swift
// 이전 (Swinject)
container.register(UserServiceProtocol.self) { _ in
    UserServiceImpl()
}

// 이후 (WeaveDI)
UnifiedDI.register(UserServiceProtocol.self) {
    UserServiceImpl()
}
```

### Factory에서

```swift
// 이전 (Factory)
@Injected(\.userService) var userService: UserService

// 이후 (WeaveDI)
@Inject(\.userService) var userService: UserService?
```

이 포괄적인 가이드는 실제 소스 코드 구현을 기반으로 WeaveDI에서 사용 가능한 모든 실제 패턴을 다루며, 정확성과 실용적 적용 가능성을 보장합니다.
