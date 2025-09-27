# Unified DI System

WeaveDI의 통합 의존성 주입 시스템인 UnifiedDI와 기본 DIContainer의 차이점 및 선택 가이드

## Overview

WeaveDI는 두 가지 주요 API를 제공합니다:

1. **UnifiedDI** - 추천하는 고수준 API (High-Level API)
2. **DIContainer** - 저수준 컨테이너 API (Low-Level API)

각각의 특징과 적절한 사용 시나리오를 이해하여 프로젝트에 맞는 선택을 하세요.

## UnifiedDI vs DIContainer 비교

### 기능 비교표

| 기능 | UnifiedDI | DIContainer | 설명 |
|------|-----------|-------------|------|
| **사용 편의성** | ✅ 매우 간편 | ⚠️ 수동 관리 필요 | UnifiedDI는 자동화된 편의 기능 제공 |
| **타입 안전성** | ✅ 강화된 안전성 | ✅ 기본 안전성 | UnifiedDI는 KeyPath 지원으로 더 안전 |
| **성능 최적화** | ✅ 자동 최적화 | ⚠️ 수동 최적화 | UnifiedDI는 런타임 최적화 자동 적용 |
| **조건부 등록** | ✅ 내장 지원 | ❌ 수동 구현 | UnifiedDI.Conditional API 제공 |
| **에러 처리** | ✅ 풍부한 에러 정보 | ⚠️ 기본 에러 정보 | UnifiedDI는 상세한 디버깅 정보 |
| **KeyPath 지원** | ✅ 네이티브 지원 | ❌ 지원 없음 | 컴파일 타임 안전성 강화 |
| **대량 등록** | ✅ DSL 지원 | ⚠️ 반복 코드 | registerMany로 깔끔한 등록 |
| **메모리 관리** | ✅ 자동 최적화 | ⚠️ 수동 관리 | weak reference 자동 처리 |
| **비동기 지원** | ✅ 완벽한 async/await | ⚠️ 기본 지원 | Swift Concurrency 최적화 |
| **Actor 지원** | ✅ Actor-safe | ⚠️ 수동 관리 | Actor isolation 자동 처리 |

## UnifiedDI API

### 기본 등록 및 해결

가장 간단하고 권장되는 방식입니다.

```swift
import WeaveDI

// 기본 등록 - 가장 간단한 형태
let userService = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}

// 즉시 사용 가능 - 등록과 동시에 인스턴스 반환
let currentUser = userService.getCurrentUser()

// 다른 곳에서 같은 인스턴스 해결
let sameService = await UnifiedDI.resolve(UserService.self)
print(userService === sameService) // true - 같은 인스턴스
```

**UnifiedDI 등록의 장점:**
- **즉시 사용**: 등록과 동시에 첫 번째 인스턴스 반환받아 바로 사용 가능
- **자동 싱글톤**: 내부적으로 싱글톤 패턴 자동 적용하여 메모리 효율성 확보
- **타입 추론**: Swift 타입 시스템을 활용한 강력한 타입 추론으로 코딩 편의성 향상
- **스레드 안전**: 멀티스레드 환경에서도 안전한 인스턴스 생성 및 공유

### 비동기 해결 (Swift Concurrency 완벽 지원)

```swift
// 비동기 해결 - Swift Concurrency 완벽 지원
let service = await UnifiedDI.resolve(UserService.self)

// Actor 안전한 해결 - MainActor에서 안전하게 사용
@MainActor
class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        Task {
            // MainActor 컨텍스트에서 안전하게 의존성 해결
            let userService = await UnifiedDI.resolve(UserService.self)
            let user = await userService?.fetchCurrentUser()

            // UI 업데이트는 이미 MainActor에서 실행 중
            updateUI(with: user)
        }
    }
}

// 안전한 해결 - 에러 처리 포함
do {
    let service: UserService = try await UnifiedDI.resolveSafely(UserService.self)
    let userData = await service.fetchUserData()
    print("✅ 사용자 데이터 로드 성공")

} catch DIError.dependencyNotFound(let type) {
    print("❌ 의존성을 찾을 수 없습니다: \(type)")
    // 사용자에게 친화적인 에러 메시지 표시
    showErrorAlert("서비스를 사용할 수 없습니다. 앱을 재시작해 주세요.")

} catch DIError.circularDependency(let cycle) {
    print("❌ 순환 의존성 감지: \(cycle)")
    // 개발자 전용 에러 - 릴리스에서는 발생하지 않아야 함
    assertionFailure("순환 의존성 수정 필요: \(cycle)")

} catch {
    print("❌ 알 수 없는 오류: \(error)")
    // 일반적인 에러 처리
    handleUnknownError(error)
}
```

### KeyPath 기반 등록 (타입 안전성 강화)

컴파일 타임에 타입 안전성을 보장하는 방법입니다.

```swift
// 먼저 DependencyContainer 확장에서 KeyPath 정의
extension DependencyContainer {
    // 사용자 관련 서비스들
    var userRepository: UserRepository? {
        resolve(UserRepository.self)
    }

    var userService: UserService? {
        resolve(UserService.self)
    }

    // 네트워크 관련 서비스들
    var networkManager: NetworkManager? {
        resolve(NetworkManager.self)
    }

    var apiClient: APIClient? {
        resolve(APIClient.self)
    }

    // 캐시 관련 서비스들
    var cacheService: CacheService? {
        resolve(CacheService.self)
    }

    var imageCache: ImageCache? {
        resolve(ImageCache.self)
    }

    // 분석 및 로깅 서비스들
    var analyticsService: AnalyticsService? {
        resolve(AnalyticsService.self)
    }

    var logger: LoggerProtocol? {
        resolve(LoggerProtocol.self)
    }
}

// KeyPath를 사용한 타입 안전한 등록
let repository = UnifiedDI.register(\.userRepository) {
    UserRepositoryImpl()
}

let networkManager = UnifiedDI.register(\.networkManager) {
    NetworkManagerImpl(timeout: 30.0)
}

// KeyPath를 사용한 해결
let repo = await UnifiedDI.resolve(\.userRepository)
let network = await UnifiedDI.resolve(\.networkManager)
```

**KeyPath 등록의 장점:**
- **컴파일 타임 검증**: 오타나 잘못된 타입 사용 시 컴파일 에러로 조기 발견
- **IDE 지원**: 자동완성, go-to-definition, 리팩토링 완벽 지원
- **타입 추론 강화**: Swift 컴파일러가 타입을 자동으로 추론하여 코드 간소화
- **리팩토링 안전성**: 타입 이름 변경 시 모든 사용처가 자동으로 업데이트

### 조건부 등록 (환경별 구현체)

다양한 환경과 조건에 따라 다른 구현체를 등록하는 방법입니다.

```swift
// 환경에 따른 조건부 등록
let analytics = UnifiedDI.Conditional.registerIf(
    AnalyticsService.self,
    condition: Configuration.isProduction, // 프로덕션 환경인지 확인
    factory: {
        print("🔥 Firebase Analytics 서비스 등록")
        let service = FirebaseAnalyticsService()
        service.configure(apiKey: Configuration.firebaseAPIKey)
        return service
    },
    fallback: {
        print("🧪 Mock Analytics 서비스 등록")
        return MockAnalyticsService()
    }
)

// A/B 테스트를 위한 조건부 등록
let recommendationEngine = UnifiedDI.Conditional.registerIf(
    RecommendationService.self,
    condition: FeatureFlags.useMLRecommendation,
    factory: {
        print("🤖 ML 기반 추천 엔진 사용")
        return MLRecommendationService(modelPath: "recommendation_model.mlmodel")
    },
    fallback: {
        print("📏 규칙 기반 추천 엔진 사용")
        return RuleBasedRecommendationService()
    }
)

// 디바이스 능력에 따른 조건부 등록
let imageProcessor = UnifiedDI.Conditional.registerIf(
    ImageProcessor.self,
    condition: ProcessInfo.processInfo.processorCount > 4, // 쿼드코어 이상
    factory: {
        print("⚡ 고성능 이미지 프로세서 사용")
        return HighPerformanceImageProcessor(threadCount: 8)
    },
    fallback: {
        print("🔋 절전형 이미지 프로세서 사용")
        return BasicImageProcessor()
    }
)

// 메모리 용량에 따른 조건부 등록
let memoryInfo = ProcessInfo.processInfo.physicalMemory
let cacheService = UnifiedDI.Conditional.registerIf(
    CacheService.self,
    condition: memoryInfo > 4_000_000_000, // 4GB 이상
    factory: {
        print("💾 대용량 메모리 캐시 사용")
        return LargeCacheService(maxSize: 200_000_000) // 200MB 캐시
    },
    fallback: {
        print("📱 절약형 메모리 캐시 사용")
        return CompactCacheService(maxSize: 50_000_000) // 50MB 캐시
    }
)
```

### 대량 등록 DSL

여러 의존성을 한 번에 깔끔하게 등록하는 방법입니다.

```swift
// 여러 의존성을 한 번에 깔끔하게 등록
UnifiedDI.registerMany {
    // 네트워크 계층 서비스들
    Registration(APIService.self) {
        URLSessionAPIService(
            configuration: .default,
            timeout: 30.0
        )
    }

    Registration(NetworkManager.self) {
        NetworkManagerImpl(
            session: URLSession.shared,
            retryCount: 3
        )
    }

    Registration(\.networkReachability) {
        NetworkReachabilityImpl()
    }

    // 데이터 계층 서비스들
    Registration(UserRepository.self) {
        UserRepositoryImpl()
    }

    Registration(OrderRepository.self) {
        OrderRepositoryImpl()
    }

    Registration(ProductRepository.self) {
        ProductRepositoryImpl()
    }

    // 비즈니스 로직 계층 서비스들
    Registration(UserService.self) {
        UserServiceImpl()
    }

    Registration(OrderService.self) {
        OrderServiceImpl()
    }

    Registration(PaymentService.self) {
        PaymentServiceImpl()
    }

    // 캐시 및 저장소 서비스들
    Registration(CacheService.self) {
        NSCacheService(
            countLimit: 1000,
            totalCostLimit: 100_000_000
        )
    }

    Registration(PersistenceService.self) {
        CoreDataService(
            modelName: "DataModel",
            storeType: .sqlite
        )
    }

    Registration(\.imageCache) {
        ImageCacheService(maxMemorySize: 50_000_000)
    }

    // 횡단 관심사 서비스들
    Registration(LoggerProtocol.self) {
        OSLogLogger(category: "WeaveDI")
    }

    // 환경별 조건부 등록
    Registration(AnalyticsService.self,
                condition: Configuration.isProduction,
                factory: {
                    FirebaseAnalyticsService()
                },
                fallback: {
                    NoOpAnalyticsService()
                })

    Registration(CrashReportingService.self,
                condition: !Configuration.isDebug,
                factory: {
                    CrashlyticsService()
                },
                fallback: {
                    LocalCrashLogger()
                })

    // 피처 플래그 기반 등록
    Registration(NotificationService.self,
                condition: FeatureFlags.pushNotificationsEnabled,
                factory: {
                    APNSNotificationService()
                },
                fallback: {
                    LocalNotificationService()
                })
}

print("✅ 총 \(registrationCount)개의 의존성 등록 완료")
```

## DIContainer API

### 기본 사용법

더 세밀한 제어가 필요한 경우 사용하는 저수준 API입니다.

```swift
import WeaveDI

// 기본 등록 - 수동 관리
DIContainer.shared.register(UserService.self) {
    UserServiceImpl()
}

// 해결
let service = DIContainer.shared.resolve(UserService.self)

// 명시적 메모리 관리
DIContainer.shared.unregister(UserService.self)
```

**DIContainer 사용 시나리오:**
- **세밀한 제어**가 필요한 경우 (스코프, 라이프사이클 등)
- **메모리 관리**를 직접 해야 하는 경우
- **레거시 코드**와의 호환성이 필요한 경우
- **멀티 컨테이너** 아키텍처가 필요한 경우

### 고급 DIContainer 사용법

```swift
// 커스텀 컨테이너 생성
let userModuleContainer = DIContainer()
let orderModuleContainer = DIContainer()

// 스코프별 관리
userModuleContainer.register(RequestScopedService.self, scope: .transient) {
    RequestScopedService()
}

userModuleContainer.register(DatabaseService.self, scope: .singleton) {
    DatabaseServiceImpl()
}

// 라이프사이클 관리
userModuleContainer.register(TempService.self, scope: .weakSingleton) {
    TempServiceImpl()
}

// 모듈별 메모리 정리
userModuleContainer.removeAll()
orderModuleContainer.removeAll()

// 특정 타입만 제거
userModuleContainer.unregister(TempService.self)
```

## 어떤 API를 선택할까?

### UnifiedDI 추천 상황

#### ✅ 새로운 프로젝트

```swift
// 새 프로젝트에서는 UnifiedDI 사용 권장
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // 간단하고 강력한 의존성 설정
        setupDependencies()

        // 런타임 최적화 자동 활성화
        UnifiedRegistry.shared.enableOptimization()

        return true
    }

    private func setupDependencies() {
        UnifiedDI.registerMany {
            // 핵심 서비스들
            Registration(UserService.self) { UserServiceImpl() }
            Registration(\.networkManager) { NetworkManagerImpl() }

            // 환경별 서비스
            Registration(AnalyticsService.self,
                        condition: !Configuration.isDebugMode,
                        factory: { FirebaseAnalytics() },
                        fallback: { MockAnalytics() })

            // 디바이스별 최적화
            Registration(ImageProcessor.self,
                        condition: DeviceInfo.isHighEndDevice,
                        factory: { HighPerformanceImageProcessor() },
                        fallback: { StandardImageProcessor() })
        }

        print("✅ 의존성 등록 완료")
    }
}
```

#### ✅ 타입 안전성이 중요한 프로젝트

```swift
// KeyPath를 활용한 컴파일 타임 안전성
extension DependencyContainer {
    // 결제 관련 서비스들 - 타입 안전성이 매우 중요
    var paymentProcessor: PaymentProcessor? {
        resolve(PaymentProcessor.self)
    }

    var fraudDetection: FraudDetectionService? {
        resolve(FraudDetectionService.self)
    }

    var securityValidator: SecurityValidator? {
        resolve(SecurityValidator.self)
    }
}

class PaymentService {
    func processPayment(_ payment: Payment) async throws {
        // 컴파일 타임에 타입 검증 - 실수 방지
        let processor = await UnifiedDI.resolve(\.paymentProcessor)
        let fraud = await UnifiedDI.resolve(\.fraudDetection)
        let security = await UnifiedDI.resolve(\.securityValidator)

        // 모든 보안 서비스가 있는지 확인
        guard let processor = processor,
              let fraud = fraud,
              let security = security else {
            throw PaymentError.securityServicesUnavailable
        }

        // 보안 검증
        try await security.validatePaymentRequest(payment)

        // 사기 감지
        try await fraud.validate(payment)

        // 결제 처리
        try await processor.process(payment)

        print("✅ 결제 처리 완료: \(payment.amount)")
    }
}
```

#### ✅ 성능이 중요한 앱

```swift
// UnifiedDI는 자동으로 성능 최적화 적용
class HighPerformanceService {
    @Inject var dataProcessor: DataProcessor?
    @Factory var taskExecutor: TaskExecutor // 매번 새 인스턴스

    func processLargeDataset(_ data: [DataItem]) async {
        // UnifiedDI의 런타임 최적화가 자동으로 적용됨:
        // - TypeID 매핑으로 O(1) 접근
        // - Lock-free 읽기로 스레드 경합 제거
        // - 인라인 최적화로 함수 호출 오버헤드 감소

        guard let processor = dataProcessor else {
            print("❌ 데이터 프로세서를 사용할 수 없습니다")
            return
        }

        // 대량 데이터를 청크 단위로 병렬 처리
        await withTaskGroup(of: Void.self) { group in
            for chunk in data.chunked(into: 1000) {
                group.addTask { [weak self] in
                    // 각 태스크마다 새로운 executor 인스턴스 사용
                    let executor = self?.taskExecutor
                    await executor?.execute {
                        await processor.process(chunk)
                    }
                }
            }
        }

        print("✅ \(data.count)개 항목 처리 완료")
    }
}

// 성능 모니터링
extension HighPerformanceService {
    func benchmarkPerformance() async {
        let startTime = CFAbsoluteTimeGetCurrent()

        // 성능 측정을 위한 더미 데이터 생성
        let testData = (0..<100_000).map { DataItem(id: $0) }

        await processLargeDataset(testData)

        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        print("⏱️ 실행 시간: \(executionTime)초")
    }
}
```

### DIContainer 추천 상황

#### ✅ 레거시 코드 통합

```swift
// 기존 Swinject 코드를 점진적으로 마이그레이션
class LegacyServiceManager {
    private let container = DIContainer()

    init() {
        setupLegacyServices()
    }

    private func setupLegacyServices() {
        // 기존 등록 방식 유지하면서 점진적 전환
        container.register(LegacyService.self) {
            LegacyServiceImpl()
        }

        container.register(OldNetworkService.self) {
            OldNetworkServiceImpl()
        }

        // 새로운 서비스는 UnifiedDI로 등록
        _ = UnifiedDI.register(NewService.self) {
            NewServiceImpl()
        }
    }

    func getLegacyService() -> LegacyService? {
        return container.resolve(LegacyService.self)
    }

    // 점진적 마이그레이션 메서드
    func migrateToUnifiedDI() {
        // 기존 서비스를 UnifiedDI로 이전
        if let legacyService = container.resolve(LegacyService.self) {
            _ = UnifiedDI.register(LegacyService.self) { legacyService }
            container.unregister(LegacyService.self)
        }
    }
}
```

#### ✅ 세밀한 컨테이너 제어

```swift
class ModularContainer {
    private let userContainer = DIContainer()
    private let orderContainer = DIContainer()
    private let paymentContainer = DIContainer()

    func setupUserModule() {
        userContainer.register(UserService.self) { UserServiceImpl() }
        userContainer.register(UserRepository.self) { UserRepositoryImpl() }
        userContainer.register(UserValidator.self) { UserValidatorImpl() }

        print("✅ 사용자 모듈 설정 완료")
    }

    func setupOrderModule() {
        orderContainer.register(OrderService.self) { OrderServiceImpl() }
        orderContainer.register(OrderRepository.self) { OrderRepositoryImpl() }
        orderContainer.register(InventoryService.self) { InventoryServiceImpl() }

        print("✅ 주문 모듈 설정 완료")
    }

    func setupPaymentModule() {
        paymentContainer.register(PaymentService.self) { PaymentServiceImpl() }
        paymentContainer.register(PaymentValidator.self) { PaymentValidatorImpl() }
        paymentContainer.register(FraudDetection.self) { FraudDetectionImpl() }

        print("✅ 결제 모듈 설정 완료")
    }

    // 모듈별 메모리 정리
    func clearUserModule() {
        userContainer.removeAll()
        print("🗑️ 사용자 모듈 정리 완료")
    }

    func clearOrderModule() {
        orderContainer.removeAll()
        print("🗑️ 주문 모듈 정리 완료")
    }

    // 모듈별 서비스 해결
    func getUserService() -> UserService? {
        return userContainer.resolve(UserService.self)
    }

    func getOrderService() -> OrderService? {
        return orderContainer.resolve(OrderService.self)
    }
}
```

## 마이그레이션 가이드

### Swinject에서 UnifiedDI로

```swift
// Before: Swinject (복잡하고 번거로운 방식)
let container = Container()
container.register(UserRepository.self) { _ in
    UserRepositoryImpl()
}
container.register(Logger.self) { _ in
    OSLogLogger()
}
container.register(UserService.self) { resolver in
    UserServiceImpl(
        repository: resolver.resolve(UserRepository.self)!,
        logger: resolver.resolve(Logger.self)!
    )
}

// 사용 시
let userService = container.resolve(UserService.self)!

// After: UnifiedDI (간단하고 직관적인 방식)
UnifiedDI.registerMany {
    Registration(UserRepository.self) { UserRepositoryImpl() }
    Registration(Logger.self) { OSLogLogger() }
    Registration(UserService.self) {
        UserServiceImpl() // 의존성 자동 주입 (@Inject 사용)
    }
}

// 사용 시
let userService = await UnifiedDI.resolve(UserService.self)
```

### DIContainer에서 UnifiedDI로

```swift
// Before: DIContainer (기본 방식)
DIContainer.shared.register(UserService.self) {
    UserServiceImpl()
}

// 여러 단계로 해결
let service = DIContainer.shared.resolve(UserService.self)
guard let service = service else {
    // 에러 처리
    return
}

// After: UnifiedDI (통합 방식)
// 등록과 동시에 인스턴스 받기
let service = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}

// 또는 나중에 해결
let resolvedService = await UnifiedDI.resolve(UserService.self)
```

## 성능 비교

### 의존성 해결 성능

| 시나리오 | DIContainer | UnifiedDI | 개선율 | 설명 |
|----------|-------------|-----------|--------|------|
| 단일 의존성 해결 | 1.0ms | 0.2ms | **80%** | TypeID 매핑으로 빠른 접근 |
| 복잡한 의존성 그래프 | 15.6ms | 3.1ms | **80%** | 체인 플래튼닝 최적화 |
| 멀티스레드 해결 | 경합 발생 | 락프리 | **300%** | 스냅샷 기반 읽기 |
| 메모리 사용량 | 기본 | 최적화됨 | **40%** | 효율적인 메모리 레이아웃 |

### 실제 앱에서의 성능 측정

```swift
class PerformanceBenchmark {
    func benchmarkDependencyResolution() async {
        let iterations = 10000

        // DIContainer 성능 측정
        let diStartTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = DIContainer.shared.resolve(TestService.self)
        }
        let diTime = CFAbsoluteTimeGetCurrent() - diStartTime

        // UnifiedDI 성능 측정
        let unifiedStartTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = await UnifiedDI.resolve(TestService.self)
        }
        let unifiedTime = CFAbsoluteTimeGetCurrent() - unifiedStartTime

        print("📊 성능 비교 결과:")
        print("   DIContainer: \(diTime * 1000)ms")
        print("   UnifiedDI: \(unifiedTime * 1000)ms")
        print("   개선율: \((1 - unifiedTime/diTime) * 100)%")
    }
}
```

### 메모리 사용량 비교

| 항목 | DIContainer | UnifiedDI | 설명 |
|------|-------------|-----------|------|
| 메모리 오버헤드 | 기본 | 최적화됨 | TypeID 매핑으로 메모리 효율성 향상 |
| 약한 참조 관리 | 수동 | 자동 | 순환 참조 자동 방지 |
| 캐시 효율성 | 기본 | 향상됨 | 스냅샷 기반 캐시로 메모리 접근 최적화 |

## Best Practices

### ✅ 권장사항

1. **새 프로젝트는 UnifiedDI 사용**
   ```swift
   // 새로운 프로젝트에서는 항상 UnifiedDI 권장
   UnifiedDI.registerMany {
       Registration(UserService.self) { UserServiceImpl() }
       Registration(\.networkManager) { NetworkManagerImpl() }
       Registration(\.analyticsService) { AnalyticsServiceImpl() }
   }
   ```

2. **KeyPath 적극 활용으로 타입 안전성 확보**
   ```swift
   extension DependencyContainer {
       var criticalService: CriticalService? {
           resolve(CriticalService.self)
       }
   }

   // 컴파일 타임 안전성 보장
   let service = await UnifiedDI.resolve(\.criticalService)
   ```

3. **조건부 등록으로 환경별 최적화**
   ```swift
   UnifiedDI.Conditional.registerIf(
       AnalyticsService.self,
       condition: Configuration.isProduction,
       factory: { FirebaseAnalytics() },
       fallback: { MockAnalytics() }
   )
   ```

4. **성능 최적화 활성화**
   ```swift
   // 앱 시작 시 성능 최적화 활성화
   UnifiedRegistry.shared.enableOptimization()
   ```

### ❌ 피해야 할 것

1. **API 혼재 사용 금지**
   ```swift
   // 같은 앱에서 두 API 동시 사용 금지
   UnifiedDI.register(UserService.self) { UserServiceImpl() } // ❌
   DIContainer.shared.register(OrderService.self) { OrderServiceImpl() } // ❌

   // 하나의 API만 일관되게 사용
   UnifiedDI.registerMany {
       Registration(UserService.self) { UserServiceImpl() } // ✅
       Registration(OrderService.self) { OrderServiceImpl() } // ✅
   }
   ```

2. **불필요한 DIContainer 사용**
   ```swift
   // 단순한 경우 DIContainer 대신 UnifiedDI 사용
   DIContainer.shared.register(SimpleService.self) { SimpleServiceImpl() } // ❌

   let service = UnifiedDI.register(SimpleService.self) { SimpleServiceImpl() } // ✅
   ```

3. **런타임 중 빈번한 등록/해제**
   ```swift
   // 앱 실행 중 자주 등록/해제하지 말 것
   for user in users {
       UnifiedDI.register(UserSpecificService.self) { /* ... */ } // ❌
   }

   // 대신 팩토리 패턴이나 매개변수 사용
   UnifiedDI.register(UserServiceFactory.self) { UserServiceFactoryImpl() } // ✅
   ```

## 실전 적용 예제

### 전체 앱 아키텍처 예제

```swift
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        setupDependencyInjection()
        configureOptimizations()

        return true
    }

    private func setupDependencyInjection() {
        UnifiedDI.registerMany {
            // 네트워크 계층
            Registration(\.networkManager) { NetworkManagerImpl() }
            Registration(\.apiClient) { APIClientImpl() }
            Registration(\.reachabilityService) { ReachabilityServiceImpl() }

            // 데이터 계층
            Registration(\.userRepository) { UserRepositoryImpl() }
            Registration(\.orderRepository) { OrderRepositoryImpl() }
            Registration(\.cacheService) { CacheServiceImpl() }

            // 비즈니스 로직 계층
            Registration(UserService.self) { UserServiceImpl() }
            Registration(OrderService.self) { OrderServiceImpl() }
            Registration(PaymentService.self) { PaymentServiceImpl() }

            // 환경별 서비스
            Registration(AnalyticsService.self,
                        condition: Configuration.isProduction,
                        factory: { FirebaseAnalyticsService() },
                        fallback: { MockAnalyticsService() })

            Registration(LoggerProtocol.self,
                        condition: Configuration.isDebug,
                        factory: { DetailedLogger() },
                        fallback: { ProductionLogger() })
        }
    }

    private func configureOptimizations() {
        // 성능 최적화 활성화
        UnifiedRegistry.shared.enableOptimization()

        // 메모리 최적화 설정
        UnifiedRegistry.shared.configureMemoryOptimization(
            weakReferenceThreshold: 100,
            snapshotUpdateInterval: 0.1
        )
    }
}
```

## 결론

### 선택 가이드라인

- **새 프로젝트**: UnifiedDI 사용 권장 (간편성 + 성능)
- **레거시 통합**: DIContainer로 점진적 마이그레이션
- **성능 중시**: UnifiedDI의 자동 최적화 활용
- **타입 안전성**: KeyPath 기반 등록 적극 활용
- **복잡한 아키텍처**: UnifiedDI + 조건부 등록 조합

UnifiedDI는 WeaveDI의 미래 지향적 API로, 더 나은 개발자 경험과 성능을 제공합니다. 새로운 프로젝트에서는 UnifiedDI를 사용하고, 기존 프로젝트는 점진적으로 마이그레이션하는 것을 권장합니다.

## See Also

- [Core APIs](/api/core-apis) - 전체 API 참조
- [Property Wrappers](/guide/property-wrappers) - 프로퍼티 래퍼 가이드
- [Runtime Optimization](/guide/runtime-optimization) - 성능 최적화
- [Practical Guide](/api/practical-guide) - 실전 활용 가이드