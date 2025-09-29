# DIActor & @DIContainerActor

Swift Concurrency를 활용한 안전하고 고성능의 의존성 주입 시스템입니다. Thread safety와 Actor 모델을 통해 동시성 문제를 해결합니다.

## Actor Hop 이해하기

### Actor Hop이란 무엇인가요?

**Actor hop**은 Swift의 액터 모델에서 실행이 한 액터 컨텍스트에서 다른 액터 컨텍스트로 전환될 때 발생하는 핵심 개념입니다. Actor hop을 이해하고 최적화하는 것은 WeaveDI로 고성능 애플리케이션을 구축하는 데 중요합니다.

```swift
// Actor hop 개념을 보여주는 예제
@MainActor
class UIViewController {
    @Inject var userService: UserService?

    func updateUI() async {
        // 1. 현재 MainActor (UI 스레드)에 있음
        print("📱 MainActor에 있음: \(Thread.isMainThread)")

        // 2. 여기서 actor hop 발생 - DIActor 컨텍스트로 전환
        let service = await DIActor.shared.resolve(UserService.self)
        // ⚡ ACTOR HOP: MainActor → DIActor

        // 3. 이제 DIActor 컨텍스트에 있음
        guard let userService = service else { return }

        // 4. 또 다른 actor hop - DIActor에서 MainActor로 UI 업데이트를 위해 복귀
        await MainActor.run {
            // ⚡ ACTOR HOP: DIActor → MainActor
            self.displayUsers(users)
        }
    }
}
```

### Actor Hop 성능 영향

각 actor hop은 다음을 포함합니다:
- **컨텍스트 스위칭**: CPU가 액터 간 실행 컨텍스트를 전환
- **메모리 동기화**: 액터 경계 간 메모리 일관성 보장
- **작업 일시정지**: 현재 작업이 일시정지되고 나중에 재개될 수 있음
- **큐 조정**: 내부 큐를 통한 액터 메시지 전달

**성능 특성:**
- **일반적인 지연 시간**: hop당 50-200 마이크로초
- **메모리 오버헤드**: 일시정지된 작업당 16-64바이트
- **CPU 영향**: 빈번한 hopping 시 ~2-5% 오버헤드
- **배터리 영향**: 모바일 기기에서 전력 소모 증가

### WeaveDI의 Actor Hop 최적화

WeaveDI는 actor hop 오버헤드를 최소화하기 위한 여러 전략을 구현합니다:

#### 1. Hot Path 캐싱
```swift
// 첫 번째 해결은 actor hop이 필요함
let service1 = await DIActor.shared.resolve(UserService.self)
// ⚡ ACTOR HOP: 현재 컨텍스트 → DIActor

// 후속 해결은 캐시되고 최적화됨
let service2 = await DIActor.shared.resolve(UserService.self)
// ✨ 최적화됨: 캐시된 해결, 최소한의 actor hop 오버헤드
```

#### 2. 배치 해결 최적화
```swift
// ❌ 비효율적: 여러 actor hop
@DIActor
func inefficientSetup() async {
    let userService = await DIActor.shared.resolve(UserService.self)     // Hop 1
    let networkService = await DIActor.shared.resolve(NetworkService.self) // Hop 2
    let cacheService = await DIActor.shared.resolve(CacheService.self)   // Hop 3
}

// ✅ 최적화됨: 단일 액터 컨텍스트, 여러 작업
@DIActor
func optimizedSetup() async {
    // 모든 작업이 DIActor 컨텍스트 내에서 발생 - 추가 hop 없음
    let userService = await DIActor.shared.resolve(UserService.self)
    let networkService = await DIActor.shared.resolve(NetworkService.self)
    let cacheService = await DIActor.shared.resolve(CacheService.self)
}
```

#### 3. 컨텍스트 해결 전략
```swift
actor BusinessLogicActor {
    @Inject var userService: UserService?

    func processUserData() async {
        // 프로퍼티 래퍼 주입이 actor hop을 최소화
        // 서비스는 한 번 해결되고 액터 인스턴스 내에 캐시됨
        guard let service = userService else { return }

        // 모든 후속 호출은 캐시된 인스턴스 사용 - actor hop 없음
        let users = await service.fetchUsers()
        let processed = await service.processUsers(users)
        await service.saveProcessedUsers(processed)
    }
}
```

### Actor Hop 감지 및 모니터링

WeaveDI는 포괄적인 actor hop 모니터링 기능을 제공합니다:

```swift
// Actor hop 모니터링 활성화
@DIActor
func enableMonitoring() async {
    await DIActor.shared.enableActorHopMonitoring()

    // 작업 수행
    let service = await DIActor.shared.resolve(UserService.self)

    // Actor hop 통계 확인
    let stats = await DIActor.shared.getActorHopStats()
    print("🔍 Actor Hop 분석:")
    print("  총 hop 수: \(stats.totalHops)")
    print("  평균 지연 시간: \(stats.averageLatency)ms")
    print("  최대 지연 시간: \(stats.peakLatency)ms")
    print("  최적화 기회: \(stats.optimizationSuggestions)")
}

// 실시간 actor hop 로깅
@DIActor
func demonstrateHopLogging() async {
    // 상세 로깅 활성화
    await DIActor.shared.setActorHopLoggingLevel(.detailed)

    let service = await DIActor.shared.resolve(UserService.self)
    // 콘솔 출력:
    // 🎭 [ActorHop] MainActor → DIActor (85μs)
    // 🎭 [ActorHop] DIActor → MainActor (92μs)
    // ⚡ [최적화] hop을 줄이기 위해 작업을 배치하는 것을 고려하세요
}
```

### Actor Hop 최적화를 위한 모범 사례

#### 1. 액터 간 통신 최소화
```swift
// ❌ 피해야 할 패턴: 빈번한 액터 간 통신
@MainActor
class BadViewController {
    func loadData() async {
        for i in 1...10 {
            // 10개의 actor hop - 매우 비효율적!
            let user = await DIActor.shared.resolve(UserService.self)
            await updateUI(with: user)
        }
    }
}

// ✅ 좋은 패턴: 단일 액터 컨텍스트 내에서 작업 배치
@MainActor
class GoodViewController {
    func loadData() async {
        // 모든 서비스를 배치 해결하기 위한 단일 actor hop
        let services = await DIActor.shared.batchResolve([
            UserService.self,
            NetworkService.self,
            CacheService.self
        ])

        // MainActor 컨텍스트 내에서 모든 데이터 처리
        await processServices(services)
    }
}
```

#### 2. 액터별 패턴 사용
```swift
// ✅ 좋은 패턴: 액터를 고려한 서비스 설계
actor DataProcessingActor {
    private var cachedServices: [String: Any] = [:]

    func processWithOptimizedHops() async {
        // 액터 내에서 서비스를 한 번 해결하고 캐시
        if cachedServices.isEmpty {
            // 모든 서비스 해결을 위한 단일 actor hop
            await resolveDependencies()
        }

        // 모든 처리가 액터 내에서 발생 - 추가 hop 없음
        await performDataProcessing()
    }

    @DIActor
    private func resolveDependencies() async {
        let userService = await DIActor.shared.resolve(UserService.self)
        let networkService = await DIActor.shared.resolve(NetworkService.self)

        await MainActor.run {
            // 메인 액터 컨텍스트에서 서비스 캐시
            self.cachedServices["user"] = userService
            self.cachedServices["network"] = networkService
        }
    }
}
```

#### 3. 전략적 프로퍼티 래퍼 사용
```swift
// ✅ 최적: 프로퍼티 래퍼가 actor hop을 최소화
class OptimizedService {
    @Inject var userService: UserService?
    @Factory var logger: Logger  // 각 접근마다 새 인스턴스이지만 최적화됨
    @SafeInject var database: Database?

    func performOperations() async {
        // 프로퍼티 래퍼가 actor hop 최적화를 자동으로 처리
        // 서비스는 한 번 해결되고 인스턴스별로 캐시됨

        guard let user = userService,
              let db = database else { return }

        // 모든 후속 작업은 캐시된 인스턴스 사용
        let data = await user.fetchData()
        await db.save(data)

        // 팩토리 인스턴스는 생성 패턴에 최적화됨
        logger.info("작업 완료")
    }
}
```

## 🎯 이 문서에서 배우는 것

- **@DIActor**: WeaveDI의 글로벌 액터 시스템
- **@DIContainerActor**: 컨테이너 수준의 액터 격리
- **Thread Safety**: 여러 스레드에서 안전한 의존성 관리
- **Performance**: 고성능 캐싱과 최적화 기법

## 📚 Swift Concurrency 기초 지식

Swift Concurrency를 처음 접하는 분들을 위한 간단한 설명:

- **Actor**: 데이터를 안전하게 관리하는 Swift의 동시성 모델
- **async/await**: 비동기 코드를 동기 코드처럼 작성할 수 있게 해주는 키워드
- **@MainActor**: UI 업데이트를 위한 메인 스레드 액터
- **Thread Safety**: 여러 스레드가 동시에 접근해도 안전한 상태

## @DIActor Global Actor

### 기본 사용법 (초보자용)

`@DIActor`는 의존성 주입을 안전하게 처리하는 글로벌 액터입니다:

```swift
import WeaveDI

// 🔧 Step 1: 의존성 등록 (앱 시작시 한 번만 실행)
@DIActor
func setupDependencies() async {
    print("🚀 의존성 등록 시작...")

    // UserService 등록 - 사용자 관련 비즈니스 로직 처리
    let service = await DIActor.shared.register(UserService.self) {
        print("📦 UserService 인스턴스 생성")
        return UserServiceImpl()
    }

    // UserRepository 등록 - 데이터 저장/조회 처리
    let repository = await DIActor.shared.register(UserRepository.self) {
        print("📦 UserRepository 인스턴스 생성")
        return UserRepositoryImpl()
    }

    print("✅ 모든 의존성 등록 완료")
}

// 🎯 Step 2: 의존성 사용 (필요할 때마다 호출)
@DIActor
func useServices() async {
    print("🔍 의존성 해결 중...")

    // 등록된 UserService 인스턴스 가져오기
    let userService = await DIActor.shared.resolve(UserService.self)

    if let service = userService {
        print("✅ UserService 해결 성공")
        let users = await service.fetchUsers()
        print("📊 \(users.count)명의 사용자 가져옴")
    } else {
        print("❌ UserService를 찾을 수 없음 - 등록했나요?")
    }
}

// 🏃‍♂️ Step 3: 실제 앱에서 사용하는 방법
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // 앱 시작시 의존성 설정
                    await setupDependencies()
                }
        }
    }
}
```

### 왜 @DIActor를 사용하나요?

1. **Thread Safety**: 여러 스레드에서 동시에 접근해도 안전
2. **Performance**: 자동으로 최적화된 캐싱 시스템
3. **Swift 6 Ready**: 최신 Swift Concurrency 모델 지원
4. **Error Prevention**: 컴파일 타임에 동시성 오류 방지

### 공유 Actor 패턴

```swift
// 공유 (싱글톤) 인스턴스 등록
@DIActor
func registerSharedServices() async {
    await DIActor.shared.registerSharedActor(DatabaseService.self) {
        DatabaseServiceImpl() // 한 번만 생성됨
    }

    await DIActor.shared.registerSharedActor(NetworkService.self) {
        NetworkServiceImpl() // 앱 전체에서 공유
    }
}

// 공유 인스턴스 접근
@DIActor
func accessSharedServices() async {
    let database = await DIActor.shared.resolve(DatabaseService.self)
    let network = await DIActor.shared.resolve(NetworkService.self)
    // 둘 다 동일한 공유 인스턴스를 반환
}
```

## Global API 브리지

편리한 통합을 위해:

```swift
// DIActorGlobalAPI를 사용한 편의성
func setupApp() async {
    // 등록
    await DIActorGlobalAPI.register(UserService.self) {
        UserServiceImpl()
    }

    // 해결
    let service = await DIActorGlobalAPI.resolve(UserService.self)

    // 에러 처리를 포함한 해결
    let result = await DIActorGlobalAPI.resolveResult(UserService.self)
    switch result {
    case .success(let service):
        await service.performOperation()
    case .failure(let error):
        print("해결 실패: \(error)")
    }
}
```

## 성능 기능

### Hot Cache 최적화

```swift
// 자주 사용되는 타입은 자동으로 캐시됨
for _ in 1...15 {
    let service = await DIActor.shared.resolve(UserService.self)
    // 10회 이상 사용 후 자동으로 hot cache로 이동
}
```

### 자동 캐시 정리

```swift
// DIActor는 100회 해결마다 그리고 5분마다 자동으로 캐시 정리를 수행하여
// 메모리 효율성을 유지합니다
```

### 사용 통계

```swift
@DIActor
func checkStatistics() async {
    let actor = DIActor.shared

    print("등록된 타입: \(actor.registeredCount)")
    print("타입 이름들: \(actor.registeredTypeNames)")

    await actor.printRegistrationStatus()
    // 📊 [DIActor] Registration Status:
    //    Total registrations: 5
    //    [1] DatabaseService (registered: 2025-09-14...)
}
```

## 에러 처리

### Result 패턴

```swift
@DIActor
func resolveWithResult() async {
    let result = await DIActor.shared.resolveResult(UserService.self)

    switch result {
    case .success(let service):
        await service.processData()
    case .failure(let error):
        switch error {
        case .dependencyNotFound(let type):
            print("서비스 \(type)이 등록되지 않음")
        default:
            print("해결 에러: \(error)")
        }
    }
}
```

### Throwing API

```swift
@DIActor
func resolveWithThrows() async throws {
    let service = try await DIActor.shared.resolveThrows(UserService.self)
    await service.processData()
}
```

## @DIContainerActor

컨테이너 레벨 Actor 격리를 위해:

```swift
@DIContainerActor
public final class AppDIContainer {
    public static let shared: AppDIContainer = .init()

    public func setupDependencies() async {
        // 모든 연산이 Actor로 격리됨
        await registerRepositories()
        await registerUseCases()
        await registerServices()
    }

    private func registerRepositories() async {
        // Actor 안전성을 보장하는 Repository 등록
    }
}
```

## 동기식 DI에서의 마이그레이션

### 이전 (동기식)

```swift
// 기존 동기식 방식
class OldDI {
    func setup() {
        UnifiedDI.register(UserService.self) { UserServiceImpl() }
        let service = UnifiedDI.resolve(UserService.self)
    }
}
```

### 이후 (Actor 기반)

```swift
// 새로운 Actor 기반 방식
@DIActor
class NewDI {
    func setup() async {
        await DIActor.shared.register(UserService.self) { UserServiceImpl() }
        let service = await DIActor.shared.resolve(UserService.self)
    }
}
```

### 마이그레이션 브리지 (과도기)

```swift
// 점진적 마이그레이션을 위한 DIActorBridge 사용
@MainActor
class LegacySupport {
    func setupLegacyCode() {
        // 동기적으로 등록 (과도기)
        DIActorBridge.registerSync(UserService.self) {
            UserServiceImpl()
        }

        // 점진적으로 async로 마이그레이션
        Task {
            await DIActorBridge.migrateToActor()
        }
    }
}
```

## 모범 사례

### 1. 싱글톤에는 공유 Actor 사용

```swift
// ✅ 좋음: 싱글톤 서비스에 공유 Actor 사용
await DIActor.shared.registerSharedActor(DatabaseService.self) {
    DatabaseServiceImpl()
}

// ❌ 피하기: 수동 싱글톤 관리
```

### 2. Actor 격리 활용

```swift
// ✅ 좋음: 함수 레벨 Actor 격리
@DIActor
func configureServices() async {
    // 모든 DI 연산이 자동으로 스레드 안전함
}

// ✅ 좋음: 클래스 레벨 Actor 격리
@DIActor
class ServiceConfigurator {
    func configure() async {
        // 전체 클래스 연산이 Actor로 격리됨
    }
}
```

### 3. 적절한 에러 처리

```swift
// ✅ 좋음: 선택적 의존성에는 Result 사용
let analyticsResult = await DIActor.shared.resolveResult(AnalyticsService.self)
let analytics = try? analyticsResult.get()

// ✅ 좋음: 필수 의존성에는 throws 사용
let database = try await DIActor.shared.resolveThrows(DatabaseService.self)
```

## SwiftUI 통합

```swift
@main
struct MyApp: App {
    init() {
        Task {
            await setupDIActor()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    @DIActor
    private func setupDIActor() async {
        await DIActor.shared.register(UserService.self) {
            UserServiceImpl()
        }
    }
}

struct ContentView: View {
    @State private var userService: UserService?

    var body: some View {
        VStack {
            if let service = userService {
                Text("서비스 로드됨")
            } else {
                Text("로딩 중...")
            }
        }
        .task {
            await loadService()
        }
    }

    @DIActor
    private func loadService() async {
        userService = await DIActor.shared.resolve(UserService.self)
    }
}
```

## 성능 모니터링

```swift
@DIActor
func monitorPerformance() async {
    let actor = DIActor.shared

    // 등록 개수 확인
    print("등록된 서비스: \(actor.registeredCount)")

    // 모든 등록된 타입 나열
    for typeName in actor.registeredTypeNames {
        print("등록됨: \(typeName)")
    }

    // 상세 상태 출력
    await actor.printRegistrationStatus()
}
```

## 관련 문서

- [자동 DI 최적화](/ko/guide/autoDiOptimizer) - 자동 성능 최적화
- [동시성 가이드](/ko/guide/concurrency) - Swift Concurrency 패턴
- [UnifiedDI vs WeaveDI.Container](/ko/guide/unifiedDi) - 올바른 API 선택