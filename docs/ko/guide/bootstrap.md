# 부트스트랩 가이드 (Bootstrap)

앱 시작 시 의존성 주입 컨테이너를 안전하고 효율적으로 초기화하는 포괄적인 가이드입니다. WeaveDI는 Swift 5/6 동시성, 테스트 격리, 조건부 초기화, 프로덕션 준비 구성 패턴을 지원하는 강력한 부트스트랩 패턴을 제공합니다.

## 개요

### 핵심 목표
- **🎧 중앙화된 설정**: 앱 시작 시 모든 의존성을 한 곳에서 초기화
- **🔒 타입 안전성**: 컴파일 타임 의존성 검증
- **⚡ 성능**: 최적화된 컨테이너 초기화
- **🧪 테스팅**: 격리된 테스트 환경

### 주요 기능
- **🔄 동시성 지원**: 완전한 async/await와 Swift 6 엄격한 동시성
- **🎯 원자적 연산**: 스레드 안전 컨테이너 교체
- **🔍 환경 인식**: 개발/스테이징/프로덕션을 위한 다른 설정
- **🧬 테스트 격리**: 각 테스트를 위한 깨끗한 환경

### Swift 버전 호환성

| 기능 | Swift 5.8+ | Swift 5.9+ | Swift 6.0+ |
|------|----------|----------|----------|
| 기본 부트스트랩 | ✅ | ✅ | ✅ |
| 비동기 부트스트랩 | ✅ | ✅ | ✅ |
| 혼합 부트스트랩 | ✅ | ✅ | ✅ |
| 액터 격리 | ⚠️ | ✅ | ✅ |
| 엄격한 Sendable | ❌ | ⚠️ | ✅ |

## 부트스트랩 사용 시점

### 필수 시나리오
- **🚀 앱 시작**: 앱 시작 시 항상 부트스트랩 수행
- **🧪 단위 테스트**: 각 테스트 스위트 이전에 부트스트랩 수행
- **🔄 통합 테스트**: 테스트 전용 구성으로 부트스트랩 수행
- **🛠️ 환경 변경**: 환경 전환 시 재부트스트랩 수행

### 애플리케이션 진입점

#### SwiftUI 앱 (권장)
```swift
@main
struct MyApp: App {
    init() {
        Task {
            await bootstrapDependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

#### UIKit 앱
```swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Task {
            await bootstrapDependencies()
        }
        return true
    }
}
```

## 동기 부트스트랩

```swift
import WeaveDI

await WeaveDI.Container.bootstrap { container in
    container.register(Logger.self) { ConsoleLogger() }
    container.register(Networking.self) { DefaultNetworking() }
    container.register(UserRepository.self) { UserRepositoryImpl() }
}

// 이후 어디서든 WeaveDI.Container.shared.resolve(...) 사용 가능
let logger = WeaveDI.Container.shared.resolve(Logger.self)
```

## 비동기 부트스트랩

비동기 초기화가 필요한 경우(예: 원격 설정, 데이터베이스 연결 등)에는 `bootstrapAsync`를 사용합니다.

```swift
let ok = await WeaveDI.Container.bootstrapAsync { container in
    // 예: 원격 설정 로드
    let config = try await RemoteConfig.load()
    container.register(AppConfig.self) { config }

    // 예: 비동기 리소스 초기화
    let db = try await Database.open()
    container.register(Database.self) { db }
}

guard ok else { /* 실패 처리 (스플래시/알림/재시도) */ return }
```

> 참고: `bootstrapAsync`는 실패 시 DEBUG 빌드에선 `fatalError`, RELEASE에선 `false`를 반환하도록 구성할 수 있습니다. 현재 구현은 내부 로깅과 함께 Bool 반환을 제공합니다.

## 혼합 부트스트랩 (sync + async)

핵심 의존성은 즉시, 부가 의존성은 비동기로 준비하고 싶을 때 유용합니다.

```swift
@MainActor
await WeaveDI.Container.bootstrapMixed(
    sync: { container in
        container.register(Logger.self) { ConsoleLogger() }
        container.register(Networking.self) { DefaultNetworking() }
    },
    async: { container in
        // 비동기 확장 의존성
        let analytics = await AnalyticsClient.make()
        container.register(AnalyticsClient.self) { analytics }
    }
)
```

## 백그라운드 Task에서 부트스트랩

앱 시작 지연을 최소화하고 싶을 때 백그라운드에서 비동기 부트스트랩을 수행할 수 있습니다.

```swift
WeaveDI.Container.bootstrapInTask { container in
    let featureFlags = try await FeatureFlags.fetch()
    container.register(FeatureFlags.self) { featureFlags }
}
```

## 조건부 부트스트랩

이미 초기화된 경우는 건너뛰고 싶을 때 사용합니다.

```swift
let didInit = await WeaveDI.Container.bootstrapIfNeeded { container in
    container.register(Logger.self) { ConsoleLogger() }
}

if !didInit {
    // 이미 준비됨
}
```

비동기 버전도 제공합니다.

```swift
let didInit = await WeaveDI.Container.bootstrapAsyncIfNeeded { container in
    let remote = try await RemoteConfig.load()
    container.register(RemoteConfig.self) { remote }
}
```

## 접근 보장(Assert)

부트스트랩 전에 DI에 접근하지 않도록 강제할 때 사용합니다.

```swift
WeaveDI.Container.ensureBootstrapped() // 미부트스트랩 시 precondition 실패
```

## 테스트 가이드

테스트마다 깨끗한 컨테이너를 원하면 리셋 API를 사용합니다.

```swift
@MainActor
override func setUp() async throws {
    try await super.setUp()
    await WeaveDI.Container.resetForTesting() // DEBUG 빌드에서만 허용

    // 테스트 전용 등록
    WeaveDI.Container.shared.register(MockService.self) { MockService() }
}
```

## 베스트 프랙티스

- 한 곳에서만 부트스트랩: 앱 진입점(또는 테스트 setUp)에서 단 한 번
- 실패 처리 분기: 비동기 부트스트랩은 실패 시 사용자 경험을 고려한 경로 준비
- 혼합 패턴 권장: 필수 의존성은 동기, 부가 의존성은 비동기 등록
- 접근 보장: 개발 단계에서는 `ensureBootstrapped()`로 실수 조기 발견
- 테스트 격리: 각 테스트 시작 전 `resetForTesting()` 호출