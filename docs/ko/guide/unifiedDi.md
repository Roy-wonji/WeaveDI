# UnifiedDI vs WeaveDI.Container: 종합 비교

WeaveDI의 두 가지 주요 API인 현대적인 UnifiedDI 접근 방식과 고급 WeaveDI.Container 시스템 중에서 선택하기 위한 완전한 가이드입니다.

## 개요

WeaveDI는 서로 다른 사용 사례와 아키텍처 요구사항을 위해 설계된 두 가지 별개의 의존성 주입 API를 제공합니다.

### 빠른 결정 가이드

| 사용 사례 | 권장 API | 이유 |
|----------|---------|------|
| **간단한 애플리케이션** | `UnifiedDI` | 최소한의 학습 곡선, 한 줄 등록 |
| **복잡한 엔터프라이즈 앱** | `WeaveDI.Container` | 고급 기능, 모듈식 아키텍처 |
| **빠른 프로토타이핑** | `UnifiedDI` | 즉시 등록 및 사용 |
| **프로덕션 시스템** | `WeaveDI.Container` | 부트스트랩 안정성, 비동기 초기화 |
| **테스팅** | 둘 다 지원 | UnifiedDI가 더 간단, WeaveDI.Container가 더 격리됨 |
| **라이브러리 개발** | `WeaveDI.Container` | 더 나은 캡슐화 및 스코핑 |

## UnifiedDI: 현대적인 간단한 API

### 설계 철학

UnifiedDI는 **"단순함 우선"** 원칙을 따릅니다 - 복잡성을 제거하면서 강력함을 유지합니다.

```swift
// ✅ UnifiedDI: 즉시 등록하고 사용
let userService = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}
// userService는 즉시 사용 가능

// ✅ 간단한 해결
if let analytics = UnifiedDI.resolve(AnalyticsService.self) {
    analytics.track("user_action")
}

// ✅ 기본값으로 안전한 해결
let logger = UnifiedDI.resolve(Logger.self, default: ConsoleLogger())
```

### 핵심 기능

#### 1. 즉시 등록 및 사용

```swift
// 한 줄로 등록하고 인스턴스 가져오기
let repository = UnifiedDI.register(UserRepository.self) {
    UserRepositoryImpl(
        network: UnifiedDI.requireResolve(NetworkService.self),
        cache: UnifiedDI.resolve(CacheService.self, default: MemoryCache())
    )
}

// 즉시 사용
let users = await repository.fetchUsers()
```

#### 2. 타입 안전한 해결

```swift
// ✅ 안전한 옵셔널 해결
let optionalService = UnifiedDI.resolve(OptionalService.self)

// ✅ 필수 해결 (누락 시 명확한 오류와 함께 크래시)
let criticalService = UnifiedDI.requireResolve(DatabaseService.self)

// ✅ 대체값이 있는 해결
let configService = UnifiedDI.resolve(ConfigService.self, default: DefaultConfig())
```

#### 3. KeyPath 지원

```swift
// 추가 타입 안정성을 위해 KeyPath로 등록
let emailService = UnifiedDI.register(\.emailInterface) {
    EmailServiceImpl()
}

// KeyPath로 해결
let notificationService = UnifiedDI.resolve(\.notificationInterface)
```

#### 4. Auto DI Optimizer 통합

UnifiedDI는 WeaveDI의 Auto DI Optimizer의 이점을 자동으로 받습니다:

```swift
// ✅ 자동 성능 최적화
print("최적화된 타입: \(UnifiedDI.optimizedTypes())")
print("사용 통계: \(UnifiedDI.stats())")
print("순환 의존성: \(UnifiedDI.circularDependencies())")

// ✅ 실시간 모니터링
UnifiedDI.setLogLevel(.optimization)
print("자동 그래프: \(UnifiedDI.autoGraph())")
```

#### 5. 조건부 등록

```swift
// 환경별 등록
let apiService = UnifiedDI.Conditional.registerIf(
    APIService.self,
    condition: isProduction,
    factory: { ProductionAPIService() },
    fallback: { MockAPIService() }
)
```

### UnifiedDI를 선택해야 하는 경우

**✅ 완벽한 경우:**
- **빠른 개발**: 즉시 시작 가능
- **간단한 애플리케이션**: 직관적인 의존성 관계
- **DI 패턴 학습**: 최소한의 인지적 부담
- **프로토타이핑**: 빠른 등록 및 테스팅
- **소규모 팀**: 아키텍처 조율이 덜 필요함

**❌ 대안을 고려해야 하는 경우:**
- 복잡한 초기화 순서가 필요한 경우
- 부모-자식 컨테이너 관계가 필요한 경우
- 대규모 모듈식 애플리케이션 구축 시
- 고급 부트스트랩 패턴이 필요한 경우

## WeaveDI.Container: 고급 엔터프라이즈 시스템

### 설계 철학

WeaveDI.Container는 **"강력함과 제어"** 를 따릅니다 - 복잡한 애플리케이션을 위한 엔터프라이즈급 기능을 제공합니다.

```swift
// ✅ WeaveDI.Container: 안전한 초기화를 위한 부트스트랩 패턴
await WeaveDI.Container.bootstrap { container in
    // 먼저 핵심 인프라
    container.register(DatabaseService.self) { DatabaseImpl() }
    container.register(NetworkService.self) { NetworkServiceImpl() }

    // 두 번째로 비즈니스 로직
    container.register(UserRepository.self) {
        UserRepositoryImpl(
            database: container.resolve(DatabaseService.self)!,
            network: container.resolve(NetworkService.self)!
        )
    }
}
```

### 핵심 기능

#### 1. 안전한 초기화를 위한 부트스트랩 시스템

```swift
// ✅ 동기 부트스트랩
await WeaveDI.Container.bootstrap { container in
    container.register(Logger.self) { ConsoleLogger() }
    container.register(ConfigService.self) { ConfigServiceImpl() }
}

// ✅ 복잡한 초기화를 위한 비동기 부트스트랩
let success = await WeaveDI.Container.bootstrapAsync { container in
    // 데이터베이스 연결 초기화
    let database = try await DatabaseConnection.establish()
    container.register(DatabaseService.self, instance: database)

    // 원격 설정 로드
    let config = try await RemoteConfig.load()
    container.register(ConfigService.self, instance: config)
}

// ✅ 혼합 부트스트랩 (동기 + 비동기)
await WeaveDI.Container.bootstrapMixed(
    sync: { container in
        // 즉시 필요한 의존성
        container.register(Logger.self) { ConsoleLogger() }
    },
    async: { container in
        // 복잡한 초기화
        let remoteService = try await RemoteService.initialize()
        container.register(RemoteService.self, instance: remoteService)
    }
)
```

#### 2. 부모-자식 컨테이너 아키텍처

```swift
// ✅ 계층적 컨테이너 생성
let appContainer = WeaveDI.Container()
appContainer.register(DatabaseService.self) { DatabaseImpl() }

// 자식 컨테이너는 부모 의존성을 상속
let userModule = appContainer.createChild()
userModule.register(UserRepository.self) {
    // 부모에서 DatabaseService를 해결할 수 있음
    UserRepositoryImpl(database: userModule.resolve(DatabaseService.self)!)
}

let orderModule = appContainer.createChild()
orderModule.register(OrderRepository.self) {
    // 마찬가지로 부모에서 DatabaseService를 상속
    OrderRepositoryImpl(database: orderModule.resolve(DatabaseService.self)!)
}
```

#### 3. 병렬 빌드를 지원하는 모듈 시스템

```swift
// ✅ 체계적인 등록을 위한 모듈 정의
struct UserModule: Module {
    func register() async {
        await WeaveDI.Container.shared.register(UserService.self) {
            UserServiceImpl()
        }
        await WeaveDI.Container.shared.register(UserRepository.self) {
            UserRepositoryImpl()
        }
    }
}

struct NetworkModule: Module {
    func register() async {
        await WeaveDI.Container.shared.register(NetworkService.self) {
            NetworkServiceImpl()
        }
        await WeaveDI.Container.shared.register(APIClient.self) {
            APIClientImpl()
        }
    }
}

// ✅ 성능을 위한 병렬 모듈 빌드
await WeaveDI.Container.bootstrap { container in
    container.addModule(UserModule())
    container.addModule(NetworkModule())
    container.addModule(AnalyticsModule())

    // 모든 모듈이 병렬로 등록됨
    await container.buildModules()
}
```

#### 4. 지연 해결을 지원하는 팩토리 패턴

```swift
// ✅ 팩토리 등록 (지연 평가)
let releaseHandler = WeaveDI.Container.shared.register(ExpensiveService.self, build: {
    // 처음 해결될 때만 생성됨
    ExpensiveServiceImpl()
})

// ✅ 인스턴스 등록 (즉시)
let logger = ConsoleLogger()
WeaveDI.Container.shared.register(Logger.self, instance: logger)

// ✅ 즉시 인스턴스와 함께 팩토리 등록
let networkService = WeaveDI.Container.shared.register(NetworkService.self) {
    NetworkServiceImpl()
}
```

#### 5. Actor 안전 작업

```swift
// ✅ Swift 6 actor 격리 작업
@DIContainerActor
func registerServices() async {
    let container = WeaveDI.Container.actorShared

    await container.actorRegister(UserService.self, instance: UserServiceImpl())

    let resolvedService = await WeaveDI.Container.resolveAsync(UserService.self)
}
```

#### 6. 성능 메트릭 및 모니터링

```swift
// ✅ 모듈 빌드 메트릭
let metrics = await WeaveDI.Container.shared.buildModulesWithMetrics()
print("""
성능 보고서:
- 빌드된 모듈: \(metrics.moduleCount)
- 소요 시간: \(metrics.duration)초
- 속도: \(metrics.modulesPerSecond) 모듈/초
""")

// ✅ 컨테이너 상태 모니터링
print("컨테이너 부트스트랩 완료: \(WeaveDI.Container.isBootstrapped)")
print("모듈 수: \(WeaveDI.Container.shared.moduleCount)")
print("비어있음: \(WeaveDI.Container.shared.isEmpty)")
```

### WeaveDI.Container를 선택해야 하는 경우

**✅ 완벽한 경우:**
- **엔터프라이즈 애플리케이션**: 복잡한 초기화 순서
- **모듈식 아키텍처**: 부모-자식 컨테이너 관계
- **성능이 중요한 앱**: 병렬 모듈 빌드
- **대규모 팀**: 체계적인 모듈 기반 등록
- **프로덕션 시스템**: 부트스트랩 안정성 및 오류 처리
- **테스트 격리**: 테스트별 별도 컨테이너

**❌ 과도할 수 있는 경우:**
- 간단한 애플리케이션 구축 시
- 설정 없이 즉시 등록이 필요한 경우
- 빠른 프로토타이핑
- 의존성 주입 개념 학습 시

## 성능 비교

### 등록 성능

```swift
// UnifiedDI: 즉시 등록
let start1 = CFAbsoluteTimeGetCurrent()
let service1 = UnifiedDI.register(TestService.self) { TestServiceImpl() }
let duration1 = CFAbsoluteTimeGetCurrent() - start1
// ~0.01ms per registration

// WeaveDI.Container: 부트스트랩과 함께 지연 등록
let start2 = CFAbsoluteTimeGetCurrent()
await WeaveDI.Container.bootstrap { container in
    container.register(TestService.self) { TestServiceImpl() }
}
let duration2 = CFAbsoluteTimeGetCurrent() - start2
// ~0.1ms per bootstrap (오버헤드가 더 크지만 더 안전함)
```

### 해결 성능

```swift
// 두 API 모두 유사한 해결 성능
let start = CFAbsoluteTimeGetCurrent()

// UnifiedDI 해결
let service1 = UnifiedDI.resolve(TestService.self)

// WeaveDI.Container 해결
let service2 = WeaveDI.Container.shared.resolve(TestService.self)

let duration = CFAbsoluteTimeGetCurrent() - start
// 둘 다: ~0.001ms per resolution (무시할 수 있는 차이)
```

### 모듈 빌드 성능

```swift
// WeaveDI.Container: 병렬 모듈 빌드의 장점
let modules = [UserModule(), NetworkModule(), AnalyticsModule(), PaymentModule()]

let start = CFAbsoluteTimeGetCurrent()
await WeaveDI.Container.bootstrap { container in
    for module in modules {
        container.addModule(module)
    }
    await container.buildModules() // 병렬 실행
}
let parallelDuration = CFAbsoluteTimeGetCurrent() - start

// UnifiedDI: 순차 등록
let start2 = CFAbsoluteTimeGetCurrent()
modules.forEach { module in
    // 순차 등록 (시뮬레이션)
    // module.registerInUnifiedDI()
}
let sequentialDuration = CFAbsoluteTimeGetCurrent() - start2

// WeaveDI.Container는 대규모 모듈 세트에 대해 3-5배 더 빠를 수 있음
```

## Auto DI Optimizer 통합

두 API 모두 WeaveDI의 Auto DI Optimizer의 이점을 받지만, 접근 패턴이 다릅니다:

### UnifiedDI 통합

```swift
// ✅ 직접 옵티마이저 접근
UnifiedDI.setLogLevel(.optimization)
print("자주 사용됨: \(UnifiedDI.stats())")
print("최적화 팁: \(UnifiedDI.getOptimizationTips())")

// ✅ 자동 최적화 구성
UnifiedDI.configureOptimization(
    debounceMs: 100,
    threshold: 10,
    realTimeUpdate: true
)

// ✅ 성능 인사이트
let asyncStats = await UnifiedDI.asyncPerformanceStats
let actorHops = await UnifiedDI.actorHopStats
```

### WeaveDI.Container 통합

```swift
// ✅ 컨테이너 특정 모니터링
let container = WeaveDI.Container.shared
print("자동 그래프: \(container.getAutoGeneratedGraph())")
print("최적화된 타입: \(container.getOptimizedTypes())")
print("순환 의존성: \(container.getDetectedCircularDependencies())")

// ✅ 컨테이너 수준 최적화 제어
container.setAutoOptimization(true)
container.resetAutoStats()
```

## 테스팅 전략

### UnifiedDI 테스팅

```swift
class UserServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // 간단한 정리
        UnifiedDI.releaseAll()
    }

    func testUserCreation() async {
        // ✅ 직접 목 등록
        let mockRepo = UnifiedDI.register(UserRepository.self) {
            MockUserRepository()
        }

        let userService = UnifiedDI.register(UserService.self) {
            UserServiceImpl(repository: mockRepo)
        }

        let user = await userService.createUser(name: "Test")
        XCTAssertNotNil(user)
    }
}
```

### WeaveDI.Container 테스팅

```swift
class UserServiceTests: XCTestCase {
    var testContainer: WeaveDI.Container!

    override func setUp() async throws {
        try await super.setUp()

        // ✅ 격리된 테스트 컨테이너
        testContainer = WeaveDI.Container()

        // ✅ 테스트 특정 부트스트랩
        await WeaveDI.Container.bootstrap { container in
            container.register(UserRepository.self) { MockUserRepository() }
            container.register(UserService.self) {
                UserServiceImpl(repository: container.resolve(UserRepository.self)!)
            }
        }
    }

    override func tearDown() async throws {
        // ✅ 컨테이너 정리
        await WeaveDI.Container.resetForTesting()
        try await super.tearDown()
    }

    func testUserCreation() async {
        let userService = testContainer.resolve(UserService.self)
        let user = await userService?.createUser(name: "Test")
        XCTAssertNotNil(user)
    }
}
```

## 마이그레이션 전략

### UnifiedDI에서 WeaveDI.Container로

```swift
// 이전: UnifiedDI 간단한 등록
let userService = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}

// 이후: 부트스트랩이 있는 WeaveDI.Container
await WeaveDI.Container.bootstrap { container in
    container.register(UserService.self) {
        UserServiceImpl()
    }
}
```

### WeaveDI.Container에서 UnifiedDI로

```swift
// 이전: WeaveDI.Container 부트스트랩
await WeaveDI.Container.bootstrap { container in
    container.register(Logger.self) { ConsoleLogger() }
    container.register(NetworkService.self) { NetworkServiceImpl() }
}

// 이후: UnifiedDI 즉시 등록
let logger = UnifiedDI.register(Logger.self) { ConsoleLogger() }
let networkService = UnifiedDI.register(NetworkService.self) { NetworkServiceImpl() }
```

## 모범 사례

### UnifiedDI 모범 사례

```swift
// ✅ 핵심 서비스에 즉시 등록 사용
let logger = UnifiedDI.register(Logger.self) { ConsoleLogger() }

// ✅ 선택적 의존성에 기본값 활용
let analytics = UnifiedDI.resolve(AnalyticsService.self, default: NoOpAnalytics())

// ✅ 중요한 의존성에 requireResolve 사용
let database = UnifiedDI.requireResolve(DatabaseService.self)

// ✅ 성능을 자동으로 모니터링
if UnifiedDI.logLevel == .optimization {
    print("팁: \(UnifiedDI.getOptimizationTips())")
}
```

### WeaveDI.Container 모범 사례

```swift
// ✅ 초기화에 항상 부트스트랩 사용
await WeaveDI.Container.bootstrap { container in
    // 의존성 순서대로 의존성 등록
    container.register(Logger.self) { ConsoleLogger() }
    container.register(ConfigService.self) {
        ConfigServiceImpl(logger: container.resolve(Logger.self)!)
    }
}

// ✅ 조직화를 위해 모듈 사용
struct CoreModule: Module {
    func register() async {
        let container = WeaveDI.Container.shared
        await container.register(Logger.self) { ConsoleLogger() }
        await container.register(ConfigService.self) { ConfigServiceImpl() }
    }
}

// ✅ 부트스트랩 상태 확인
WeaveDI.Container.ensureBootstrapped()
let service = WeaveDI.Container.shared.resolve(MyService.self)

// ✅ 격리를 위해 자식 컨테이너 사용
let testContainer = WeaveDI.Container.shared.createChild()
testContainer.register(TestService.self) { MockTestService() }
```

## 호환성 및 상호 운용성

두 API는 동일한 애플리케이션에서 함께 사용할 수 있습니다:

```swift
// ✅ 두 API 혼합
await WeaveDI.Container.bootstrap { container in
    // WeaveDI.Container로 핵심 서비스 부트스트랩
    container.register(DatabaseService.self) { DatabaseImpl() }
}

// UnifiedDI로 추가 서비스 등록
let analyticsService = UnifiedDI.register(AnalyticsService.self) {
    AnalyticsServiceImpl(
        database: WeaveDI.Container.shared.resolve(DatabaseService.self)!
    )
}

// 둘 다 동일한 기본 컨테이너에서 해결
let database1 = UnifiedDI.resolve(DatabaseService.self)
let database2 = WeaveDI.Container.shared.resolve(DatabaseService.self)
// database1과 database2는 동일한 인스턴스
```

## 결론

### 다음의 경우 UnifiedDI를 선택하세요:
- 간단하거나 중간 규모의 애플리케이션 구축
- 즉시 등록 및 사용이 필요한 경우
- 빠른 프로토타이핑 또는 DI 패턴 학습
- 최소한의 설정 오버헤드가 중요한 경우
- 자동 최적화 인사이트가 중요한 경우

### 다음의 경우 WeaveDI.Container를 선택하세요:
- 엔터프라이즈 또는 복잡한 애플리케이션 구축
- 고급 부트스트랩 패턴이 필요한 경우
- 부모-자식 컨테이너 관계가 필요한 경우
- 모듈식 아키텍처 구축
- 성능 모니터링이 중요한 경우
- 테스트 격리가 중요한 경우

두 API 모두 우수한 성능을 제공하며 Swift 6 동시성과 완전히 호환됩니다. 선택은 애플리케이션의 복잡성과 아키텍처 요구사항에 따라 달라집니다.

## UnifiedRegistry 통합 (v3.2.0+)

WeaveDI v3.2.0에서는 두 API 모두에 **UnifiedRegistry 통합**을 도입하여 별도 설정 없이 상당한 성능 향상을 제공합니다.

### 주요 이점

- **10배 해결 성능**: 최적화된 메모리 접근 패턴으로 O(1) 조회
- **제로 락 경합**: 스냅샷 기술을 사용한 락-프리 읽기 연산
- **QoS 우선순위 보존**: 비동기 연산 중 스레드 서비스 품질 유지
- **자동 최적화**: 수동 설정 불필요 - 즉시 작동
- **완전 API 호환성**: 기존 코드가 변경 없이 혜택 제공

### 성능 영향

```swift
// v3.2.0 이전: 락을 사용한 딕셔너리 기반 조회
// 해결 시간: ~0.001ms (경합 위험 있음)

// v3.2.0 이후: O(1) 접근의 UnifiedRegistry
// 해결 시간: ~0.0001ms (락-프리, 더 빠름)

// 두 API 모두 자동으로 혜택 제공:
let service1 = UnifiedDI.resolve(UserService.self)     // ✅ 10배 빨라짐
let service2 = container.resolve(UserService.self)     // ✅ 10배 빨라짐
```

### 기술 아키텍처

UnifiedRegistry 통합은 다음을 제공합니다:

1. **TypeID 기반 인덱싱**: 해시 조회 대신 직접 배열 접근
2. **불변 스냅샷**: 경합 없는 읽기를 위한 copy-on-write 스토리지
3. **우선순위 인식 태스크**: 비동기 경계에서 QoS 보존
4. **Sendable 우선 설계**: 완전한 Swift 6 동시성 준수

### 마이그레이션 참고사항

**마이그레이션 불필요!** 기존 애플리케이션이 자동으로 UnifiedRegistry 최적화 혜택을 받습니다:

- ✅ 모든 기존 `UnifiedDI.register()` 호출이 변경 없이 작동
- ✅ 모든 기존 `container.resolve()` 호출이 변경 없이 작동
- ✅ 모든 프로퍼티 래퍼(`@Injected`, `@Factory`)가 변경 없이 작동
- ✅ 코드 변경 없이 성능이 자동으로 향상

## 관련 항목

- [프로퍼티 래퍼](./propertyWrappers.md) - 주입 가능한 프로퍼티 패턴
- [부트스트랩 가이드](./bootstrap.md) - 고급 초기화 패턴
- [모듈 시스템](./moduleSystem.md) - 대규모 애플리케이션 구성
- [Auto DI Optimizer](./autoDiOptimizer.md) - 자동 성능 최적화