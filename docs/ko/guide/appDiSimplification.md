# AppDI 간소화 가이드

## 개요

WeaveDI 3.2.0은 자동 의존성 등록을 도입하여, 수동으로 `registerRepositories()`와 `registerUseCases()`를 호출할 필요가 없어졌습니다. 프레임워크가 개선된 `registerAllDependencies()` 시스템을 통해 이러한 메서드를 자동으로 호출합니다.

## 변경 사항

### 이전 (수동 등록)

```swift
// ❌ 이전 방식 - 수동 호출 필요
@main
struct MyApp: App {
    init() {
        Task {
            await WeaveDI.Container.bootstrap { container in
                // 수동 등록
                await WeaveDI.Container.registerRepositories()
                await WeaveDI.Container.registerUseCases()
            }
        }
    }
}
```

### 이후 (자동 등록)

```swift
// ✅ 새로운 방식 - 자동 등록
@main
struct MyApp: App {
    init() {
        WeaveDI.Container.bootstrapInTask { @DIContainerActor _ in
            await AppDIManager.shared.registerDefaultDependencies()
        }
    }
}
```

## 작동 방식

`AppDIManager.shared.registerDefaultDependencies()` 메서드가 `registerRepositories()`와 `registerUseCases()`를 자동으로 호출합니다:

```swift
// AppDIManager가 자동으로 모든 의존성을 등록
public actor AppDIManager {
    public static let shared = AppDIManager()

    public func registerDefaultDependencies() async {
        // 이 메서드들을 자동으로 호출
        await WeaveDI.Container.registerRepositories()
        await WeaveDI.Container.registerUseCases()

        #if DEBUG
        print("✅ AppDIManager.registerDefaultDependencies() 완료")
        #endif
    }
}
```

## 모듈 기반 등록 패턴

### 모듈 정의

```swift
extension WeaveDI.Container {
    private static let helper = RegisterModule()

    /// 📦 Repository 등록
    static func registerRepositories() async {
        let repositories = [
            helper.exchangeRepositoryModule(),
            helper.userRepositoryModule(),
            // 추가 repository 모듈...
        ]

        await repositories.asyncForEach { module in
            await module.register()
        }
    }

    /// 🔧 UseCase 등록
    static func registerUseCases() async {
        let useCases = [
            helper.exchangeUseCaseModule(),
            helper.userUseCaseModule(),
            // 추가 useCase 모듈...
        ]

        await useCases.asyncForEach { module in
            await module.register()
        }
    }
}
```

### 모듈 Extension 생성

```swift
extension RegisterModule {
    var exchangeUseCaseModule: @Sendable () -> Module {
        makeUseCaseWithRepository(
            ExchangeRateInterface.self,
            repositoryProtocol: ExchangeRateInterface.self,
            repositoryFallback: MockExchangeRepositoryImpl(),
            factory: { repo in
                ExchangeUseCaseImpl(repository: repo)
            }
        )
    }

    var exchangeRepositoryModule: @Sendable () -> Module {
        makeDependency(ExchangeRateInterface.self) {
            ExchangeRepositoryImpl()
        }
    }
}
```

## 이점

### 1. 보일러플레이트 감소

- **이전**: 모든 앱에서 수동 등록 호출 필요
- **이후**: 프레임워크가 자동으로 등록 처리

### 2. 더 깔끔한 앱 초기화

```swift
// 깔끔하고 간단한 앱 초기화
@main
struct CurrencyConverterApp: App {
    init() {
        WeaveDI.Container.bootstrapInTask { @DIContainerActor _ in
            await AppDIManager.shared.registerDefaultDependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 3. 더 나은 구조화

모듈 extension을 사용하여 기능별로 의존성 구성:

```swift
// 인증 모듈
extension RegisterModule {
    var authRepositoryModule: @Sendable () -> Module { ... }
    var authUseCaseModule: @Sendable () -> Module { ... }
}

// 사용자 모듈
extension RegisterModule {
    var userRepositoryModule: @Sendable () -> Module { ... }
    var userUseCaseModule: @Sendable () -> Module { ... }
}

// 환율 모듈
extension RegisterModule {
    var exchangeRepositoryModule: @Sendable () -> Module { ... }
    var exchangeUseCaseModule: @Sendable () -> Module { ... }
}
```

## 마이그레이션 가이드

### 1단계: 수동 호출 제거

앱 초기화에서 명시적인 `registerRepositories()`와 `registerUseCases()` 호출 제거:

```swift
// ❌ 이 라인들을 제거하세요
await WeaveDI.Container.registerRepositories()
await WeaveDI.Container.registerUseCases()
```

### 2단계: Extension 존재 확인

`WeaveDI.Container` extension이 기본 구현을 오버라이드하는지 확인:

```swift
extension WeaveDI.Container {
    static func registerRepositories() async {
        // Repository 등록 로직
    }

    static func registerUseCases() async {
        // UseCase 등록 로직
    }
}
```

### 3단계: 앱 테스트

`bootstrapInTask`와 `AppDIManager`를 사용하여 의존성 등록:

```swift
@main
struct MyApp: App {
    init() {
        WeaveDI.Container.bootstrapInTask { @DIContainerActor _ in
            await AppDIManager.shared.registerDefaultDependencies()
        }
    }
}
```

## 고급: asyncForEach

병렬 모듈 등록을 위해 `asyncForEach` 사용:

```swift
static func registerRepositories() async {
    let repositories = [
        helper.exchangeRepositoryModule(),
        helper.userRepositoryModule(),
        helper.authRepositoryModule(),
    ]

    // 모든 모듈을 병렬로 등록
    await repositories.asyncForEach { module in
        await module.register()
    }
}
```

## 실전 예제

```swift
// AutoDIRegistry.swift
import WeaveDI

extension WeaveDI.Container {
    private static let helper = RegisterModule()

    static func registerRepositories() async {
        let repositories = [
            helper.exchangeRepositoryModule(),
        ]

        await repositories.asyncForEach { module in
            await module.register()
        }
    }

    static func registerUseCases() async {
        let useCases = [
            helper.exchangeUseCaseModule(),
        ]

        await useCases.asyncForEach { module in
            await module.register()
        }
    }
}

extension RegisterModule {
    var exchangeUseCaseModule: @Sendable () -> Module {
        makeUseCaseWithRepository(
            ExchangeRateInterface.self,
            repositoryProtocol: ExchangeRateInterface.self,
            repositoryFallback: MockExchangeRepositoryImpl(),
            factory: { repo in
                ExchangeUseCaseImpl(repository: repo)
            }
        )
    }

    var exchangeRepositoryModule: @Sendable () -> Module {
        makeDependency(ExchangeRateInterface.self) {
            ExchangeRepositoryImpl()
        }
    }
}

// App.swift
@main
struct CurrencyConverterApp: App {
    init() {
        WeaveDI.Container.bootstrapInTask { @DIContainerActor _ in
            await AppDIManager.shared.registerDefaultDependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## 모범 사례

### 1. 기능별 구조화

관련 의존성을 기능 기반 모듈로 그룹화:

```swift
// 기능: 인증
extension RegisterModule {
    var authModule: @Sendable () -> [Module] {
        [
            authRepositoryModule(),
            authUseCaseModule(),
        ]
    }
}
```

### 2. 명확한 이름 사용

```swift
// ✅ 좋음 - 명확하고 설명적
var exchangeRateRepositoryModule: @Sendable () -> Module { ... }
var userAuthenticationUseCaseModule: @Sendable () -> Module { ... }

// ❌ 피함 - 불명확한 이름
var repo1Module: @Sendable () -> Module { ... }
var module2: @Sendable () -> Module { ... }
```

### 3. 의존성 문서화

```swift
extension RegisterModule {
    /// 환율 repository 모듈
    /// 통화 환율 데이터 접근 제공
    var exchangeRepositoryModule: @Sendable () -> Module {
        makeDependency(ExchangeRateInterface.self) {
            ExchangeRepositoryImpl()
        }
    }
}
```

## 문제 해결

### 의존성이 등록되지 않음

의존성이 자동으로 등록되지 않는 경우:

1. `registerRepositories()`와 `registerUseCases()` extension이 있는지 확인
2. `bootstrap`이 호출되고 있는지 확인
3. Extension이 앱과 같은 타겟에 있는지 확인

### 디버그 로깅

등록 진행 상황을 보기 위해 디버그 로깅 활성화:

```swift
#if DEBUG
extension WeaveDI.Container {
    static func registerRepositories() async {
        print("📦 Repository 등록 중...")
        // ... 등록 로직
        print("✅ Repository 등록 완료")
    }
}
#endif
```

## 참고

- [@Injected](../api/injected.md) - 모던 의존성 주입
- [모듈 시스템](./modules.md) - 모듈 기반 구성
- [테스트 가이드](./testing.md) - 자동 등록을 사용한 테스트