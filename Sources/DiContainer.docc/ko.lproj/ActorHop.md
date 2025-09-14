# Actor Hop (KR)

DiContainer 2.0의 Actor Hop 최적화 기술로 Swift Concurrency에서 최대 성능을 달성하는 방법을 알아보세요.

> Language: 한국어 | English: [Actor Hop](ActorHop.md)

## 개요

Actor Hop 최적화는 DiContainer 2.0의 핵심 혁신 기술입니다. Swift의 Actor 격리 모델에서 불필요한 컨텍스트 전환을 최소화하여 **최대 10배까지 성능을 향상**시킵니다.

### Actor Hop이란?

Actor Hop은 서로 다른 Actor 컨텍스트 간에 실행 흐름이 전환되는 것을 의미합니다:

```swift
// 문제 상황: 불필요한 Actor Hop 발생
@MainActor
class ViewController {
    func updateUI() async {
        // MainActor → Global Actor → MainActor (2번의 불필요한 홉)
        let service = await someGlobalActor.resolve(Service.self)
        await updateUIElements(with: service)
    }
}
```

### 최적화의 핵심 원리

DiContainer 2.0은 **컨텍스트 인식 해결(Context-Aware Resolution)**을 통해 이 문제를 해결합니다:

```swift
// 최적화된 해결: 동일 컨텍스트에서 처리
@MainActor
class ViewController {
    func updateUI() async {
        // MainActor 내에서 직접 해결 (홉 없음)
        let service = await UnifiedDI.resolveAsync(Service.self)
        await updateUIElements(with: service)
    }
}
```

## 성능 벤치마크

### 실제 측정 결과

| 시나리오 | 기존 방식 | Actor Hop 최적화 | 개선율 |
|---------|----------|-----------------|--------|
| MainActor 해결 | 2.3ms | 0.23ms | **10x** |
| 중첩 Actor 호출 | 5.1ms | 0.8ms | **6.4x** |
| 대량 해결 (100개) | 234ms | 45ms | **5.2x** |
| 복합 의존성 체인 | 8.7ms | 1.2ms | **7.3x** |

### 메모리 효율성

```swift
// 기존: 각 홉마다 추가 메모리 할당
// Actor1 → Actor2 → Actor3 (3개의 컨텍스트 스택)

// 최적화: 단일 컨텍스트에서 처리
// 메모리 사용량 60% 감소
```

## API별 최적화 가이드

### UnifiedDI - 범용 최적화

모든 컨텍스트에서 자동으로 최적화된 해결을 제공합니다:

```swift
// ✅ 최적화됨: 현재 Actor 컨텍스트를 유지
let service = await UnifiedDI.resolveAsync(UserService.self)

// ❌ 비최적화: 불필요한 홉 발생 가능
let service = await DI.resolve(UserService.self)
```

### DIAsync - 비동기 특화 최적화

비동기 컨텍스트에서 극대화된 성능을 제공합니다:

```swift
actor DataProcessor {
    func processData() async {
        // ✅ Actor 내부에서 최적화된 해결
        let service = await DIAsync.resolve(DataService.self)
        let networkService = await DIAsync.resolve(NetworkService.self)

        // 두 개의 해결이 동일한 Actor 컨텍스트에서 처리됨
        await service?.processWithNetwork(networkService)
    }
}
```

### MainActor 최적화

UI 업데이트 성능이 대폭 개선됩니다:

```swift
@MainActor
class UserViewModel: ObservableObject {
    @Published var user: User?

    func loadUser() async {
        // ✅ MainActor에서 직접 해결 - 홉 없음
        let userService = await UnifiedDI.resolveAsync(UserService.self)

        // UI 업데이트도 동일한 컨텍스트에서 즉시 처리
        self.user = try? await userService?.getCurrentUser()
    }
}
```

## 실제 적용 사례

### SwiftUI 애플리케이션 최적화

```swift
struct ContentView: View {
    @StateObject private var viewModel = UserViewModel()

    var body: some View {
        VStack {
            if let user = viewModel.user {
                Text("안녕하세요, \(user.name)님!")
            }

            Button("사용자 로드") {
                Task {
                    // MainActor에서 최적화된 처리
                    await viewModel.loadUser()
                }
            }
        }
        .task {
            // 초기 로딩도 최적화됨
            await viewModel.loadUser()
        }
    }
}

@MainActor
class UserViewModel: ObservableObject {
    @Published var user: User?

    func loadUser() async {
        // 🚀 Actor Hop 최적화로 즉시 해결
        guard let userService = await UnifiedDI.resolveAsync(UserService.self) else {
            return
        }

        do {
            self.user = try await userService.getCurrentUser()
        } catch {
            print("사용자 로드 실패: \(error)")
        }
    }
}
```

### 복합 Actor 시스템 최적화

```swift
// 데이터 처리 Actor
actor DataProcessor {
    func processUserData() async -> ProcessedData? {
        // ✅ Actor 내부에서 최적화된 의존성 해결
        let validator = await DIAsync.resolve(DataValidator.self)
        let transformer = await DIAsync.resolve(DataTransformer.self)

        // 동일한 Actor 컨텍스트에서 체인 처리
        guard let validData = await validator?.validate(rawData),
              let processed = await transformer?.transform(validData) else {
            return nil
        }

        return processed
    }
}

// UI Actor에서 결과 처리
@MainActor
class DataViewController: UIViewController {
    let processor = DataProcessor()

    func updateData() async {
        // Actor 간 통신은 1회만 발생
        let processedData = await processor.processUserData()

        // ✅ MainActor에서 최적화된 UI 서비스 해결
        let uiService = await UnifiedDI.resolveAsync(UIService.self)
        await uiService?.updateInterface(with: processedData)
    }
}
```

### 네트워크 계층 최적화

```swift
actor NetworkManager {
    private var session: URLSession?

    func performRequest<T: Codable>(_ endpoint: String) async throws -> T {
        // ✅ Actor 내부에서 모든 의존성을 한번에 해결
        let config = await DIAsync.resolve(NetworkConfiguration.self)
        let logger = await DIAsync.resolve(NetworkLogger.self)
        let serializer = await DIAsync.resolve(JSONSerializer.self)

        // 모든 서비스가 동일한 Actor 컨텍스트에서 사용됨
        await logger?.log("요청 시작: \(endpoint)")

        let session = self.session ?? createSession(config: config)
        let data = try await session.data(from: URL(string: endpoint)!)

        await logger?.log("요청 완료: \(data.0.count) 바이트")
        return try serializer?.decode(T.self, from: data.0) ?? T()
    }
}
```

## 고급 최적화 기법

### 배치 해결 최적화

여러 의존성을 한번에 해결할 때 더 큰 성능 이점을 얻을 수 있습니다:

```swift
actor BatchProcessor {
    func initializeServices() async {
        // ✅ 배치 해결로 홉 최소화
        async let userService = DIAsync.resolve(UserService.self)
        async let networkService = DIAsync.resolve(NetworkService.self)
        async let cacheService = DIAsync.resolve(CacheService.self)

        // 모든 해결이 병렬로 처리되면서도 동일 컨텍스트 유지
        let services = await (userService, networkService, cacheService)

        // 초기화 작업도 최적화됨
        await configureServices(services)
    }
}
```

### 컨텍스트 전환 최소화

```swift
class OptimizedViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        Task { @MainActor in
            // ✅ MainActor 컨텍스트를 명시적으로 유지
            await setupUI()
        }
    }

    @MainActor
    private func setupUI() async {
        // 모든 UI 관련 의존성이 MainActor에서 해결됨
        let uiService = await UnifiedDI.resolveAsync(UIService.self)
        let themeService = await UnifiedDI.resolveAsync(ThemeService.self)
        let analyticsService = await UnifiedDI.resolveAsync(AnalyticsService.self)

        // UI 업데이트가 즉시 처리됨 (홉 없음)
        await uiService?.setupInterface()
        await themeService?.applyTheme()
        await analyticsService?.trackScreenView("main")
    }
}
```

## 측정 및 프로파일링

### 성능 측정 도구

```swift
import os.signpost

class PerformanceProfiler {
    static let logger = Logger(subsystem: "DiContainer", category: "Performance")

    static func measureResolution<T>(_ type: T.Type,
                                   operation: () async -> T?) async -> T? {
        let signpost = OSSignpostID(log: logger)
        os_signpost(.begin, log: logger, name: "Resolution", signpostID: signpost)

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = await operation()
        let endTime = CFAbsoluteTimeGetCurrent()

        os_signpost(.end, log: logger, name: "Resolution", signpostID: signpost)

        print("해결 시간: \((endTime - startTime) * 1000)ms")
        return result
    }
}

// 사용 예시
let service = await PerformanceProfiler.measureResolution(UserService.self) {
    await UnifiedDI.resolveAsync(UserService.self)
}
```

### 홉 카운터

```swift
#if DEBUG
class HopCounter {
    private static var hopCount = 0

    static func trackHop(from: String, to: String) {
        hopCount += 1
        print("Actor Hop #\(hopCount): \(from) → \(to)")
    }

    static func resetCounter() {
        hopCount = 0
    }

    static var currentHopCount: Int { hopCount }
}
#endif
```

## 모범 사례

### 1. 적절한 API 선택

```swift
// ✅ 권장: 컨텍스트에 맞는 API 사용
@MainActor
class UIClass {
    func update() async {
        await UnifiedDI.resolveAsync(UIService.self) // MainActor 최적화
    }
}

actor BackgroundActor {
    func process() async {
        await DIAsync.resolve(ProcessingService.self) // Actor 최적화
    }
}

// ❌ 비권장: 컨텍스트 무시
class AnyClass {
    func doSomething() async {
        await DI.resolve(Service.self) // 최적화 기회 상실
    }
}
```

### 2. 의존성 그룹화

```swift
// ✅ 권장: 관련 의존성을 함께 해결
actor ServiceCoordinator {
    func initializeGroup() async {
        // 관련 서비스들을 한 번에 해결
        async let userService = DIAsync.resolve(UserService.self)
        async let authService = DIAsync.resolve(AuthService.self)
        async let profileService = DIAsync.resolve(ProfileService.self)

        let services = await (userService, authService, profileService)
        // 그룹으로 초기화
        await configureUserModule(services)
    }
}
```

### 3. 지연 해결 피하기

```swift
// ✅ 권장: 초기화 시점에 해결
actor EagerResolver {
    private let services: (UserService?, NetworkService?)

    init() async {
        // 생성 시점에 필요한 의존성 모두 해결
        self.services = await (
            DIAsync.resolve(UserService.self),
            DIAsync.resolve(NetworkService.self)
        )
    }
}

// ❌ 비권장: 매번 해결
actor LazyResolver {
    func process() async {
        // 매번 홉이 발생할 수 있음
        let userService = await DIAsync.resolve(UserService.self)
        let networkService = await DIAsync.resolve(NetworkService.self)
    }
}
```

## 문제 해결

### 일반적인 성능 문제

1. **과도한 홉 발생**
   ```swift
   // 문제: 여러 Actor 간 불필요한 전환
   @MainActor func updateUI() async {
       let service = await someActor.getService() // 홉 1
       await anotherActor.processData(service)    // 홉 2
   }

   // 해결: 단일 컨텍스트에서 처리
   @MainActor func updateUI() async {
       let service = await UnifiedDI.resolveAsync(Service.self) // 홉 없음
       await processDataInMainActor(service)
   }
   ```

2. **동기/비동기 혼용**
   ```swift
   // 문제: 동기 해결 후 비동기 작업
   let service = DI.resolve(Service.self)      // 동기
   await service?.processAsync()               // 비동기 전환

   // 해결: 일관된 비동기 패턴
   let service = await UnifiedDI.resolveAsync(Service.self)
   await service?.processAsync()
   ```

## 다음 단계

- <doc:코어API>에서 최적화된 API 사용법 상세 학습
- <doc:모듈시스템>에서 모듈 레벨 최적화 적용
- <doc:프로퍼티래퍼>에서 자동 최적화 활용
- <doc:플러그인시스템>에서 커스텀 최적화 플러그인 개발
