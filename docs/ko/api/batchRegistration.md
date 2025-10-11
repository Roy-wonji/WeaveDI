# Batch Registration DSL

## 개요

WeaveDI의 Batch Registration DSL은 Swift의 Result Builder 패턴을 활용하여 여러 의존성을 한 번에 등록할 수 있는 선언적 구문을 제공합니다. `@BatchRegistrationBuilder`를 통해 깔끔하고 읽기 쉬운 코드로 대량 등록을 수행할 수 있습니다.

## 🚀 핵심 장점

- **✅ 선언적 구문**: Swift Result Builder로 깔끔한 등록 코드
- **✅ 타입 안전성**: 컴파일 타임 타입 검증
- **✅ 조건부 등록**: if/else를 지원하는 유연한 등록
- **✅ 다양한 등록 방식**: 팩토리, 기본값, 조건부 등록 지원

## 기본 사용법

### DIAdvanced.Batch.registerMany

```swift
import WeaveDI

// 여러 의존성을 한 번에 등록
DIAdvanced.Batch.registerMany {
    BatchRegistration(UserService.self) {
        UserServiceImpl()
    }

    BatchRegistration(NetworkService.self) {
        NetworkServiceImpl()
    }

    BatchRegistration(CacheService.self, default: CacheServiceImpl())
}
```

## BatchRegistration 종류

### 1. 팩토리 기반 등록

```swift
DIAdvanced.Batch.registerMany {
    // 기본 팩토리 등록
    BatchRegistration(APIClient.self) {
        APIClientImpl(baseURL: "https://api.example.com")
    }

    // 의존성이 있는 팩토리
    BatchRegistration(UserRepository.self) {
        UserRepositoryImpl(
            apiClient: UnifiedDI.resolve(APIClient.self)!,
            cache: UnifiedDI.resolve(CacheService.self)!
        )
    }
}
```

### 2. 기본값 등록

```swift
// 미리 생성된 인스턴스 등록
let sharedLogger = LoggerImpl(level: .debug)
let defaultConfig = AppConfig.default

DIAdvanced.Batch.registerMany {
    BatchRegistration(Logger.self, default: sharedLogger)
    BatchRegistration(AppConfig.self, default: defaultConfig)
}
```

### 3. 조건부 등록

```swift
DIAdvanced.Batch.registerMany {
    // 환경에 따른 조건부 등록
    BatchRegistration(
        AnalyticsService.self,
        condition: Bundle.main.bundleIdentifier?.contains("debug") == true,
        factory: { DebugAnalyticsService() },
        fallback: { ProductionAnalyticsService() }
    )

    // 기능 플래그에 따른 등록
    BatchRegistration(
        PaymentService.self,
        condition: FeatureFlags.newPaymentEnabled,
        factory: { NewPaymentServiceImpl() },
        fallback: { LegacyPaymentServiceImpl() }
    )
}
```

## BatchRegistrationBuilder 고급 기능

### 조건부 블록

```swift
DIAdvanced.Batch.registerMany {
    // 항상 등록되는 기본 서비스
    BatchRegistration(CoreService.self) {
        CoreServiceImpl()
    }

    // 디버그 모드에서만 등록
    #if DEBUG
    BatchRegistration(DebugService.self) {
        DebugServiceImpl()
    }
    #endif

    // 조건부 등록
    if ProcessInfo.processInfo.arguments.contains("--mock-mode") {
        BatchRegistration(DataService.self) {
            MockDataService()
        }
    } else {
        BatchRegistration(DataService.self) {
            RealDataService()
        }
    }
}
```

### 배열 기반 등록

```swift
let services = [
    ("UserService", { UserServiceImpl() as any UserService }),
    ("OrderService", { OrderServiceImpl() as any OrderService }),
    ("NotificationService", { NotificationServiceImpl() as any NotificationService })
]

DIAdvanced.Batch.registerMany {
    for (name, factory) in services {
        // 주의: 현재 구현에서는 직접 타입이 필요
        // 이 패턴은 향후 개선될 예정
    }

    // 현재는 명시적 타입으로 등록
    BatchRegistration(UserService.self) { UserServiceImpl() }
    BatchRegistration(OrderService.self) { OrderServiceImpl() }
    BatchRegistration(NotificationService.self) { NotificationServiceImpl() }
}
```

## 실전 활용 예시

### 앱 모듈 설정

```swift
class AppDependencySetup {
    static func registerCoreServices() {
        DIAdvanced.Batch.registerMany {
            // 네트워킹 레이어
            BatchRegistration(HTTPClient.self) {
                URLSessionHTTPClient(session: .shared)
            }

            BatchRegistration(APIClient.self) {
                APIClientImpl(
                    httpClient: UnifiedDI.resolve(HTTPClient.self)!,
                    baseURL: Configuration.apiBaseURL
                )
            }

            // 데이터 레이어
            BatchRegistration(UserRepository.self) {
                UserRepositoryImpl(
                    apiClient: UnifiedDI.resolve(APIClient.self)!
                )
            }

            BatchRegistration(OrderRepository.self) {
                OrderRepositoryImpl(
                    apiClient: UnifiedDI.resolve(APIClient.self)!
                )
            }

            // 비즈니스 로직 레이어
            BatchRegistration(UserUseCase.self) {
                UserUseCaseImpl(
                    repository: UnifiedDI.resolve(UserRepository.self)!
                )
            }

            BatchRegistration(OrderUseCase.self) {
                OrderUseCaseImpl(
                    repository: UnifiedDI.resolve(OrderRepository.self)!,
                    userUseCase: UnifiedDI.resolve(UserUseCase.self)!
                )
            }
        }
    }
}
```

### 테스트 환경 설정

```swift
class TestDependencySetup {
    static func registerMockServices() {
        DIAdvanced.Batch.registerMany {
            // Mock 서비스들
            BatchRegistration(APIClient.self) {
                MockAPIClient()
            }

            BatchRegistration(UserRepository.self) {
                MockUserRepository()
            }

            BatchRegistration(OrderRepository.self) {
                MockOrderRepository()
            }

            // 테스트 전용 서비스
            BatchRegistration(TestDataGenerator.self) {
                TestDataGeneratorImpl()
            }

            // 조건부 Mock (특정 테스트에서만)
            BatchRegistration(
                NetworkService.self,
                condition: TestContext.shouldMockNetwork,
                factory: { MockNetworkService() },
                fallback: { RealNetworkService() }
            )
        }
    }
}
```

### 환경별 설정

```swift
class EnvironmentDependencySetup {
    static func registerEnvironmentServices() {
        DIAdvanced.Batch.registerMany {
            // 환경별 API 서비스
            BatchRegistration(
                APIService.self,
                condition: Environment.current == .development,
                factory: { DevelopmentAPIService() },
                fallback: { ProductionAPIService() }
            )

            // 환경별 로깅
            BatchRegistration(
                Logger.self,
                condition: Environment.current == .debug,
                factory: { VerboseLoggerImpl() },
                fallback: { ProductionLoggerImpl() }
            )

            // 환경별 분석 도구
            BatchRegistration(
                AnalyticsService.self,
                condition: Environment.current == .production,
                factory: { FirebaseAnalyticsService() },
                fallback: { NoOpAnalyticsService() }
            )
        }
    }
}
```

## SwiftUI 통합

### 앱 시작 시 등록

```swift
import SwiftUI
import ComposableArchitecture

@main
struct MyApp: App {
    init() {
        setupDependencies()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupDependencies() {
        DIAdvanced.Batch.registerMany {
            // Core 서비스
            BatchRegistration(AppState.self, default: AppState())

            BatchRegistration(UserDefaults.self, default: .standard)

            // 환경별 서비스
            #if DEBUG
            BatchRegistration(APIClient.self) {
                MockAPIClient()
            }
            #else
            BatchRegistration(APIClient.self) {
                ProductionAPIClient()
            }
            #endif
        }
    }
}
```

## 성능 특성

### 등록 성능
- **일괄 처리**: 개별 등록 대비 ~20% 빠른 성능
- **메모리 효율성**: Result Builder로 최적화된 메모리 사용
- **지연 실행**: 팩토리는 실제 해결 시점에만 실행

### 권장사항
1. **관련 의존성 그룹화**: 모듈별로 배치 등록 사용
2. **조건부 등록 활용**: 환경별 다른 구현 등록
3. **팩토리 최적화**: 무거운 초기화는 지연 로딩 사용
4. **테스트 분리**: 프로덕션과 테스트 등록 분리

## 문제 해결

### Q: BatchRegistration에서 제네릭 타입을 사용할 수 없나요?
**A:** 현재는 구체적인 타입만 지원합니다. 제네릭 지원은 향후 업데이트에서 추가될 예정입니다.

### Q: 순환 의존성이 있을 때는 어떻게 하나요?
**A:** BatchRegistration은 등록 순서와 관계없이 지연 해결되므로, 팩토리 내에서 `UnifiedDI.resolve()`를 사용하여 해결할 수 있습니다.

### Q: 등록 실패 시 어떻게 디버깅하나요?
**A:** 각 BatchRegistration을 개별적으로 테스트하거나, 디버그 모드에서 로깅을 활성화하여 확인할 수 있습니다.

## 마이그레이션 가이드

### 기존 개별 등록에서 배치 등록으로

```swift
// Before: 개별 등록
DI.register(UserService.self) { UserServiceImpl() }
DI.register(OrderService.self) { OrderServiceImpl() }
DI.register(PaymentService.self) { PaymentServiceImpl() }

// After: 배치 등록
DIAdvanced.Batch.registerMany {
    BatchRegistration(UserService.self) { UserServiceImpl() }
    BatchRegistration(OrderService.self) { OrderServiceImpl() }
    BatchRegistration(PaymentService.self) { PaymentServiceImpl() }
}
```

## 관련 API

- [`DIAdvanced`](./diAdvanced.md) - 고급 DI 기능
- [`UnifiedDI`](./unifiedDI.md) - 통합 DI API
- [`@Component`](./componentMacro.md) - 컴포넌트 기반 등록

---

*이 기능은 WeaveDI v3.2.1에서 개선되었습니다. Swift의 Result Builder 패턴을 활용한 현대적인 배치 등록 시스템입니다.*