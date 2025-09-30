---
title: Bootstrap
lang: ko-KR
---

# 부트스트랩 가이드 (Bootstrap)

앱 시작 시 의존성을 안전하고 일관되게 준비하는 방법을 소개합니다. WeaveDI는 다양한 부트스트랩 패턴을 제공하여 동기/비동기 초기화, 테스트 격리, 조건부 초기화 등을 유연하게 구성할 수 있습니다.

## 개요

- 목표: 앱 시작 시점에 필요한 의존성을 한곳에서 명확하게 초기화
- 특징:
  - 동기/비동기/혼합 부트스트랩 지원
  - 전역 컨테이너의 원자적 교체(스레드 안전)
  - 테스트 격리/리셋 API 제공

## 사용 시점

- AppDelegate/SceneDelegate/앱 엔트리포인트에서 한 번만 호출
- SwiftUI App 구조에서는 `@main` 진입부 또는 초기 View-Model 구성 시점

## 동기 부트스트랩

```swift
import WeaveDI

await DIContainer.bootstrap { container in
    container.register(Logger.self) { ConsoleLogger() }
    container.register(Networking.self) { DefaultNetworking() }
    container.register(UserRepository.self) { UserRepositoryImpl() }
}

// 이후 어디서든 DIContainer.shared.resolve(...) 사용 가능
let logger = DIContainer.shared.resolve(Logger.self)
```

## 비동기 부트스트랩

비동기 초기화가 필요한 경우(예: 원격 설정, 데이터베이스 연결 등)에는 `bootstrapAsync`를 사용합니다.

```swift
let ok = await DIContainer.bootstrapAsync { container in
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
await DIContainer.bootstrapMixed(
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
DIContainer.bootstrapInTask { container in
    let featureFlags = try await FeatureFlags.fetch()
    container.register(FeatureFlags.self) { featureFlags }
}
```

## 조건부 부트스트랩

이미 초기화된 경우는 건너뛰고 싶을 때 사용합니다.

```swift
let didInit = await DIContainer.bootstrapIfNeeded { container in
    container.register(Logger.self) { ConsoleLogger() }
}

if !didInit {
    // 이미 준비됨
}
```

비동기 버전도 제공합니다.

```swift
let didInit = await DIContainer.bootstrapAsyncIfNeeded { container in
    let remote = try await RemoteConfig.load()
    container.register(RemoteConfig.self) { remote }
}
```

## 접근 보장(Assert)

부트스트랩 전에 DI에 접근하지 않도록 강제할 때 사용합니다.

```swift
DIContainer.ensureBootstrapped() // 미부트스트랩 시 precondition 실패
```

## 테스트 가이드

테스트마다 깨끗한 컨테이너를 원하면 리셋 API를 사용합니다.

```swift
@MainActor
override func setUp() async throws {
    try await super.setUp()
    await DIContainer.resetForTesting() // DEBUG 빌드에서만 허용

    // 테스트 전용 등록
    DIContainer.shared.register(MockService.self) { MockService() }
}
```

## 베스트 프랙티스

- 한 곳에서만 부트스트랩: 앱 진입점(또는 테스트 setUp)에서 단 한 번
- 실패 처리 분기: 비동기 부트스트랩은 실패 시 사용자 경험을 고려한 경로 준비
- 혼합 패턴 권장: 필수 의존성은 동기, 부가 의존성은 비동기 등록
- 접근 보장: 개발 단계에서는 `ensureBootstrapped()`로 실수 조기 발견
- 테스트 격리: 각 테스트 시작 전 `resetForTesting()` 호출

## 관련 문서

- <doc:QuickStart>
- <doc:CoreAPIs>
- <doc:UnifiedDI>
