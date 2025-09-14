# 통합 DI 시스템 - UnifiedDI vs DI

DiContainer 2.0은 두 가지 주요 API 진입점을 제공합니다: `UnifiedDI`와 `DI`. 각각의 역할과 사용 시나리오를 이해하여 프로젝트에 최적한 선택을 하세요.

## 🎯 API 선택 가이드

### UnifiedDI (권장)
**"모든 기능을 담은 포괄적 API"**

```swift
// 모든 등록 방식 지원
UnifiedDI.register(Service.self) { ServiceImpl() }
UnifiedDI.registerIf(Service.self, condition: isProduction,
                     factory: { ProdService() },
                     fallback: { MockService() })

// 다양한 해결 전략
let service = UnifiedDI.resolve(Service.self)                    // 옵셔널
let required = UnifiedDI.requireResolve(Service.self)           // 필수
let safe = try UnifiedDI.resolveThrows(Service.self)           // Throws
let withDefault = UnifiedDI.resolve(Service.self, default: MockService())

// 성능 추적
let tracked = UnifiedDI.resolveWithTracking(Service.self)

// 배치 등록
UnifiedDI.registerMany {
    Registration(NetworkService.self) { NetworkServiceImpl() }
    Registration(UserService.self, singleton: sharedUserService)
    Registration(AnalyticsService.self, condition: analytics) {
        GoogleAnalytics()
    } fallback: {
        NoOpAnalytics()
    }
}
```

**사용 시나리오:**
- 복잡한 앱 아키텍처
- 고급 DI 기능이 필요한 경우
- 성능 최적화가 중요한 경우
- A/B 테스트나 조건부 등록이 필요한 경우
- 대규모 팀 개발

### DI (단순화)
**"핵심만 담은 간결한 API"**

```swift
// 기본 3가지 패턴만 제공
DI.register(Service.self) { ServiceImpl() }  // 등록
@Inject var service: Service?                 // 주입
let service = DI.resolve(Service.self)        // 해결
```

**사용 시나리오:**
- 간단한 프로젝트
- DI 학습 목적
- 최소한의 설정을 원하는 경우
- 프로토타입 개발
- 소규모 팀 개발

## 🔄 마이그레이션 전략

### Legacy DI → UnifiedDI
```swift
// Before (Legacy)
DI.register(Service.self) { ServiceImpl() }
let service = DI.resolve(Service.self)

// After (UnifiedDI)
UnifiedDI.register(Service.self) { ServiceImpl() }
let service = UnifiedDI.resolve(Service.self)
```

### 점진적 마이그레이션
```swift
// 1단계: 기존 코드 유지하면서 새로운 코드는 UnifiedDI 사용
class LegacyViewController {
    @Inject var service: OldService?  // 기존 코드 유지
}

class NewViewController {
    private let newService = UnifiedDI.resolve(NewService.self, default: DefaultNewService())
}

// 2단계: 배치 등록으로 통합
await DependencyContainer.bootstrap { container in
    // 기존 서비스들
    container.register(OldService.self) { OldServiceImpl() }

    // 새로운 서비스들 - UnifiedDI 스타일로 등록
    UnifiedDI.register(NewService.self) { NewServiceImpl() }
}

// 3단계: 완전히 UnifiedDI로 통합
UnifiedDI.registerMany {
    Registration(OldService.self) { OldServiceImpl() }
    Registration(NewService.self) { NewServiceImpl() }
}
```

## 🏗️ 실무 패턴

### 환경별 구성
```swift
#if DEBUG
UnifiedDI.registerMany {
    Registration(APIService.self) { MockAPIService() }
    Registration(AnalyticsService.self) { DebugAnalytics() }
    Registration(LoggerService.self, default: ConsoleLogger(level: .debug))
}
#else
UnifiedDI.registerMany {
    Registration(APIService.self) { ProductionAPIService() }
    Registration(AnalyticsService.self) { FirebaseAnalytics() }
    Registration(LoggerService.self, default: CloudLogger(level: .info))
}
#endif
```

### 모듈별 분리
```swift
enum NetworkModule {
    static func register() {
        UnifiedDI.registerMany {
            Registration(HTTPClient.self) { URLSessionHTTPClient() }
            Registration(APIService.self) { APIServiceImpl() }
            Registration(NetworkReachability.self, singleton: NetworkReachability.shared)
        }
    }
}

enum DataModule {
    static func register() {
        UnifiedDI.registerMany {
            Registration(DatabaseService.self) { CoreDataService() }
            Registration(CacheService.self) { NSCacheService() }
            Registration(KeychainService.self, singleton: KeychainService.shared)
        }
    }
}

// 앱 초기화에서
await DependencyContainer.bootstrap { container in
    NetworkModule.register()
    DataModule.register()
}
```

## 📊 성능 특성 비교

| 기능 | UnifiedDI | DI (단순화) |
|------|-----------|------------|
| 기본 등록/해결 | ✅ 최적화됨 | ✅ 최적화됨 |
| 조건부 등록 | ✅ 지원 | ❌ 미지원 |
| 성능 추적 | ✅ 내장 | ❌ 미지원 |
| 배치 등록 | ✅ Result Builder DSL | ❌ 미지원 |
| KeyPath 등록 | ✅ 지원 | ❌ 미지원 |
| 에러 전략 | ✅ 다양함 (throws, default 등) | ✅ 기본만 |
| 학습 곡선 | 보통 | 낮음 |
| 메모리 오버헤드 | 낮음 | 매우 낮음 |

## 🎯 결론 및 권장사항

### ✅ UnifiedDI를 선택하세요
- 프로덕션 앱 개발 시
- 팀 개발 환경
- 복잡한 의존성 그래프
- 성능 최적화가 중요한 경우
- 테스트 친화적 아키텍처 필요 시

### ✅ DI(단순화)를 선택하세요
- 프로토타입 개발
- 학습 목적
- 매우 간단한 프로젝트
- 최소한의 의존성 관리만 필요한 경우

### 💡 Best Practice
대부분의 경우 **UnifiedDI**를 사용하는 것을 권장합니다. 더 많은 기능을 제공하면서도 필요한 만큼만 사용할 수 있어 확장성이 뛰어나기 때문입니다.

```swift
// 권장 패턴: UnifiedDI로 시작하여 필요에 따라 기능 확장
@main
struct MyApp: App {
    init() {
        Task {
            await setupDependencies()
        }
    }

    private func setupDependencies() async {
        // UnifiedDI의 강력한 배치 등록 사용
        UnifiedDI.registerMany {
            // 기본 서비스들
            Registration(NetworkService.self) { NetworkServiceImpl() }
            Registration(UserService.self) { UserServiceImpl() }

            // 환경별 조건부 등록
            Registration(AnalyticsService.self,
                        condition: !isDebug,
                        factory: { GoogleAnalytics() },
                        fallback: { NoOpAnalytics() })
        }

        // 성능 최적화 활성화
        await UnifiedDI.enablePerformanceOptimization()
    }
}
```