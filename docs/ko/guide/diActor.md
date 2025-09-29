# DIActor & @WeaveDI.ContainerActor

Swift Concurrency를 활용한 안전하고 고성능의 의존성 주입 시스템입니다. Thread safety와 Actor 모델을 통해 동시성 문제를 해결합니다.

## 🎯 이 문서에서 배우는 것

- **@DIActor**: WeaveDI의 글로벌 액터 시스템
- **@WeaveDI.ContainerActor**: 컨테이너 수준의 액터 격리
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

## @WeaveDI.ContainerActor

컨테이너 레벨 Actor 격리를 위해:

```swift
@WeaveDI.ContainerActor
public final class AppWeaveDI.Container {
    public static let shared: AppWeaveDI.Container = .init()

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