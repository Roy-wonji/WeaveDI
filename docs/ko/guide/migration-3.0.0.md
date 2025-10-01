# WeaveDI 3.0.0 마이그레이션 가이드

WeaveDI 2.x에서 3.0.0으로의 전체 마이그레이션 가이드입니다. 새로운 기능, 성능 개선 및 주요 변경 사항을 다룹니다.

## 개요

WeaveDI 3.0.0은 자동 최적화, 향상된 Swift 6 호환성 및 최대 80%의 성능 개선과 함께 큰 도약을 나타냅니다. 이 버전은 Auto DI Optimizer를 도입하고 actor hop 성능을 크게 개선했습니다.

## 3.0.0의 새로운 기능

### 🚀 주요 기능

- **Auto DI Optimizer**: 자동 의존성 그래프 생성 및 성능 최적화
- **Swift 6 완전 지원**: 엄격한 동시성과의 완전한 호환성
- **Actor Hop 최적화**: MainActor 시나리오에서 최대 81% 성능 개선
- **향상된 TypeID 시스템**: 락 프리 읽기로 O(1) 해결
- **모듈 팩토리 시스템**: 고급 의존성 구성

### 📊 성능 개선

| 시나리오 | 2.x 성능 | 3.0.0 성능 | 개선 |
|----------|-----------------|-------------------|-------------|
| 단일 의존성 해결 | 0.8ms | 0.2ms | **75%** |
| 복잡한 의존성 그래프 | 15.6ms | 3.1ms | **80%** |
| MainActor UI 업데이트 | 3.1ms | 0.6ms | **81%** |
| 멀티스레드 해결 | 락 경합 | 락 프리 | **300%** |

## 주요 변경 사항

### 1. 향상된 프로퍼티 래퍼

**이전 (2.x):**
```swift
@Inject var userService: UserService?
@RequiredInject var databaseService: DatabaseService
```

**이후 (3.0.0):**
```swift
@Inject var userService: UserService?           // 변경 없음
@SafeInject var databaseService: DatabaseService // 향상된 에러 처리
```

**마이그레이션 필요:**
- `@RequiredInject`를 `@SafeInject`로 교체
- 에러 처리 패턴 업데이트

### 2. 기본적으로 자동 최적화

**이전 (2.x):**
```swift
// 수동 최적화 필요
UnifiedDI.enableOptimization()
```

**이후 (3.0.0):**
```swift
// 자동 최적화 - 조치 불필요
// 모든 것이 자동으로 최적화됨
```

**마이그레이션 필요:**
- 수동 `enableOptimization()` 호출 제거
- 자동 최적화가 이제 기본적으로 활성화됨

### 3. 모듈 시스템 향상

**이전 (2.x):**
```swift
// 간단한 등록
UnifiedDI.register(UserService.self) { UserServiceImpl() }
```

**이후 (3.0.0):**
```swift
// 향상된 모듈 시스템
let module = Module(UserService.self) {
    UserServiceImpl()
}
await module.register()
```

**마이그레이션 필요:**
- 더 나은 구성을 위해 모듈 시스템으로 마이그레이션 고려
- 이전 등록 스타일도 작동하지만 모듈 사용 권장

## 단계별 마이그레이션

### 1단계: 패키지 의존성 업데이트

Package.swift를 업데이트하여 WeaveDI 3.0.0 사용:

```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.0.0")
]
```

### 2단계: 프로퍼티 래퍼 마이그레이션

**@RequiredInject 찾기 및 교체:**

```swift
// 이전 (2.x):
class CriticalService {
    @RequiredInject var database: DatabaseService

    func performOperation() {
        database.execute() // 직접 접근
    }
}

// 이후 (3.0.0):
class CriticalService {
    @SafeInject var database: DatabaseService

    func performOperation() throws {
        let db = try database.getValue() // 에러 처리 필요
        db.execute()
    }
}
```

### 3단계: 자동 최적화 활용

**이전 (2.x):**
```swift
// 수동 최적화 설정
await WeaveDI.Container.bootstrap { container in
    container.register(UserService.self) { UserServiceImpl() }
    container.register(OrderService.self) { OrderServiceImpl() }
}

// 수동 최적화 활성화
UnifiedDI.enableOptimization()
```

**이후 (3.0.0):**
```swift
// 자동 최적화 - 수동 설정 불필요
await WeaveDI.Container.bootstrap { container in
    container.register(UserService.self) { UserServiceImpl() }
    container.register(OrderService.self) { OrderServiceImpl() }
}

// 자동 최적화가 기본적으로 활성화됨
// 최적화 통계 보기:
print("자동 최적화된 타입: \(UnifiedDI.optimizedTypes)")
print("성능 통계: \(UnifiedDI.stats)")
```

### 4단계: 모듈 시스템으로 마이그레이션 (선택 사항이지만 권장)

**모듈을 사용한 향상된 구성:**

```swift
// 구성된 모듈 생성
struct UserModule: ModuleFactory {
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

// 모듈 팩토리 매니저 사용
let manager = ModuleFactoryManager(
    repositoryFactory: RepositoryModuleFactory(),
    useCaseFactory: UseCaseModuleFactory(),
    scopeFactory: ScopeModuleFactory()
)

await manager.registerAll()
```

### 5단계: Swift 6 호환성 업데이트

**Sendable 준수 보장:**

```swift
// 이전 (2.x):
class UserService {
    var cache: [String: User] = [:]

    func getUser(id: String) -> User? {
        return cache[id]
    }
}

// 이후 (3.0.0) - Swift 6 호환:
actor UserService: Sendable {
    private var cache: [String: User] = [:]

    func getUser(id: String) -> User? {
        return cache[id]
    }

    func setUser(_ user: User) {
        cache[user.id] = user
    }
}
```

## 도입할 새로운 기능

### 1. Auto DI Optimizer 모니터링

```swift
// 실시간으로 자동 최적화 모니터링
print("🔄 의존성 그래프: \(UnifiedDI.autoGraph)")
print("⚡ 최적화된 타입: \(UnifiedDI.optimizedTypes)")
print("📊 사용 통계: \(UnifiedDI.stats)")
print("🎯 Actor 최적화 제안: \(UnifiedDI.actorOptimizations)")
print("🔒 타입 안전성 문제: \(UnifiedDI.typeSafetyIssues)")

// 로깅 레벨 설정
UnifiedDI.setLogLevel(.optimization) // 최적화 로그만 보기
UnifiedDI.setLogLevel(.errors)       // 에러만 보기
UnifiedDI.setLogLevel(.off)          // 프로덕션용 끄기
```

### 2. 향상된 에러 처리

```swift
// SafeInject를 사용한 포괄적인 에러 처리
class DataManager {
    @SafeInject var database: DatabaseService
    @SafeInject var networkService: NetworkService

    func synchronizeData() async throws {
        // SafeInject는 상세한 에러 정보 제공
        do {
            let db = try database.getValue()
            let network = try networkService.getValue()

            let remoteData = try await network.fetchLatestData()
            try await db.save(remoteData)

        } catch SafeInjectError.notRegistered(let type) {
            throw DataError.serviceUnavailable("필수 서비스 \(type)가 등록되지 않음")
        } catch SafeInjectError.resolutionFailed(let type, let reason) {
            throw DataError.resolutionFailed("\(type) 해결 실패: \(reason)")
        }
    }
}
```

### 3. 고급 모듈 패턴

```swift
// 환경별 모듈 구성
struct EnvironmentModuleFactory {
    let environment: Environment

    func createNetworkModule() -> Module {
        switch environment {
        case .development:
            return Module(NetworkService.self) {
                MockNetworkService(delay: 0.1)
            }
        case .staging:
            return Module(NetworkService.self) {
                NetworkService(baseURL: "https://staging-api.example.com")
            }
        case .production:
            return Module(NetworkService.self) {
                NetworkService(
                    baseURL: "https://api.example.com",
                    certificatePinner: SSLCertificatePinner()
                )
            }
        }
    }
}
```

### 4. Actor Hop 최적화

```swift
// WeaveDI 3.0.0은 자동으로 actor hop 최적화
@MainActor
class UIController {
    @Inject var dataService: DataService? // MainActor 접근용 자동 최적화

    func updateUI() async {
        // 이 해결은 actor hop을 최소화하도록 자동 최적화됨
        guard let service = dataService else { return }

        let data = await service.fetchData()
        // UI 업데이트는 불필요한 hop 없이 MainActor에서 발생
        updateView(with: data)
    }
}

// actor hop 최적화 모니터링
print("🎯 Actor hop 통계: \(UnifiedDI.actorHopStats)")
```

## 성능 최적화 가이드

### 1. 자동 최적화 활용

```swift
// WeaveDI 3.0.0은 자주 사용되는 의존성을 자동으로 최적화
// 수동 개입 불필요, 하지만 모니터링 가능:

func monitorOptimization() {
    let stats = UnifiedDI.asyncPerformanceStats
    print("평균 해결 시간: \(stats.averageTime)ms")
    print("최적화된 의존성: \(stats.optimizedCount)")
    print("캐시 히트율: \(stats.cacheHitRatio)%")
}
```

### 2. 모듈 기반 아키텍처

```swift
// 더 나은 성능을 위해 모듈별로 의존성 구성
await WeaveDI.Container.bootstrap { container in
    // 핵심 인프라 먼저
    let infrastructureModules = InfrastructureModuleFactory().makeAllModules()
    for module in infrastructureModules {
        await container.register(module)
    }

    // 비즈니스 로직 두 번째
    let businessModules = BusinessModuleFactory().makeAllModules()
    for module in businessModules {
        await container.register(module)
    }

    // UI 컴포넌트 마지막
    let uiModules = UIModuleFactory().makeAllModules()
    for module in uiModules {
        await container.register(module)
    }
}
```

## 테스팅 개선

### 향상된 테스트 지원

```swift
class UserServiceTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()

        // 3.0.0은 더 나은 테스트 격리 제공
        await UnifiedDI.releaseAll()

        // 깨끗한 테스트를 위해 최적화 통계 재설정
        UnifiedDI.resetStats()

        await WeaveDI.Container.bootstrap { container in
            container.register(UserService.self) { MockUserService() }
        }
    }

    func testServiceOptimization() async {
        // 서비스가 올바르게 최적화되었는지 테스트
        let service = UnifiedDI.resolve(UserService.self)
        XCTAssertNotNil(service)

        // 최적화 상태 확인
        XCTAssertTrue(UnifiedDI.isOptimized(UserService.self))
    }
}
```

## 문제 해결

### 일반적인 마이그레이션 문제

#### 문제 1: SafeInject 컴파일 에러

**에러:**
```
Value of type 'SafeInjectResult<DatabaseService>' has no member 'performOperation'
```

**해결:**
```swift
// 이전 (잘못됨):
@SafeInject var database: DatabaseService
database.performOperation() // 에러!

// 이후 (올바름):
@SafeInject var database: DatabaseService
let db = try database.getValue()
db.performOperation()
```

#### 문제 2: Actor 격리 경고

**에러:**
```
Call to actor-isolated method 'resolve' in a synchronous nonisolated context
```

**해결:**
```swift
// actor 컨텍스트에서 async 해결 사용
@MainActor
func updateData() async {
    let service = await UnifiedDI.resolveAsync(DataService.self)
    // 데이터 처리...
}
```

#### 문제 3: 모듈 등록 충돌

**에러:**
```
Multiple registrations for the same type
```

**해결:**
```swift
// 조건부 등록 사용
if !UnifiedDI.isRegistered(NetworkService.self) {
    let service = UnifiedDI.register(NetworkService.self) {
        NetworkServiceImpl()
    }
}

// 또는 충돌을 피하기 위해 모듈 팩토리 사용
let factory = ModuleFactoryManager(...)
await factory.registerAll() // 자동으로 충돌 처리
```

## 마이그레이션 체크리스트

- [ ] Package.swift에서 WeaveDI 3.0.0으로 업데이트
- [ ] `@RequiredInject`를 `@SafeInject`로 교체
- [ ] SafeInject에 대한 에러 처리 업데이트
- [ ] 수동 `enableOptimization()` 호출 제거
- [ ] Swift 6 호환성 테스트 (Sendable 준수)
- [ ] 모듈 시스템으로 마이그레이션 고려
- [ ] 더 나은 격리를 위한 테스트 설정 업데이트
- [ ] 자동 최적화 통계 모니터링
- [ ] actor hop 성능 개선 검증
- [ ] 문서 및 팀 지식 업데이트

## 마이그레이션 후 이점

WeaveDI 3.0.0으로 마이그레이션을 완료하면 다음을 얻을 수 있습니다:

- **자동 성능 최적화**: 수동 튜닝 불필요
- **더 나은 에러 진단**: 상세한 에러 메시지 및 제안
- **Swift 6 미래 대비**: 엄격한 동시성 준비 완료
- **향상된 개발자 경험**: 자동 완성 및 더 나은 디버깅
- **향상된 테스팅**: 더 나은 격리 및 테스트 유틸리티
- **프로덕션 모니터링**: 실시간 성능 인사이트

## 지원

- **이슈**: [GitHub Issues](https://github.com/Roy-wonji/WeaveDI/issues)
- **토론**: [GitHub Discussions](https://github.com/Roy-wonji/WeaveDI/discussions)
- **문서**: [전체 API 레퍼런스](/api/core-apis)

WeaveDI 3.0.0은 자동 최적화와 향상된 개발자 경험을 갖춘 Swift의 의존성 주입의 미래를 나타냅니다.