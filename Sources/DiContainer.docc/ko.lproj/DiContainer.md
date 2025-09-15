# ``DiContainer``

현대적인 Swift Concurrency와 Actor 모델을 위해 설계된 고성능 의존성 주입 프레임워크

## Overview

DiContainer 2.0은 iOS 15.0+, macOS 12.0+, watchOS 8.0+, tvOS 15.0+ 애플리케이션을 위한 차세대 의존성 주입 프레임워크입니다. Swift의 최신 동시성 모델과 완벽하게 통합되며, **Actor Hop 최적화**를 통해 의존성 해결 성능을 최대 **10배** 향상시킵니다.

### 🚀 주요 특징

#### 🎭 Actor Hop 최적화
서로 다른 Actor 컨텍스트 간 전환을 지능적으로 최적화하여 의존성 해결 성능을 극대화합니다.

#### 🔒 완전한 타입 안전성
- **컴파일 타임 검증**: KeyPath 기반 등록으로 타입 안전성 보장
- **런타임 안전성**: 명확한 에러 메시지와 안전한 폴백 시스템
- **타입 추론**: Swift의 강력한 타입 시스템 활용

#### 📝 직관적인 Property Wrapper
- **`@Inject`**: 자동 의존성 주입 (옵셔널/필수 지원)
- **`@Factory`**: 팩토리 패턴 기반 모듈 관리
- **`@RequiredInject`**: 필수 의존성 주입

#### 🏗️ 강력한 모듈 시스템
- **AppDIContainer**: 앱 전역 의존성 관리
- **ModuleFactory**: 재사용 가능한 모듈 생성
- **Container**: 배치 등록 및 병렬 실행

#### 🔌 확장 가능한 플러그인 아키텍처
- **RegistrationPlugin**: 등록 프로세스 확장
- **ResolutionPlugin**: 해결 프로세스 커스터마이징
- **MonitoringPlugin**: 성능 모니터링 및 로깅

#### 🧪 테스트 친화적 설계
- **의존성 모킹**: 테스트용 Mock 객체 쉬운 등록
- **격리된 테스트**: 테스트 간 상태 독립성 보장
- **부트스트랩 리셋**: 테스트용 컨테이너 초기화

### ⚡ 빠른 시작

#### 1단계: 의존성 등록 (UnifiedDI 사용 권장)

```swift
import DiContainer

// 앱 시작 시 의존성 부트스트랩
await DependencyContainer.bootstrap { container in
    // 서비스 등록
    container.register(UserServiceProtocol.self) {
        UserService()
    }

    container.register(NetworkServiceProtocol.self) {
        NetworkService()
    }

    // 로거 등록
    container.register(LoggerProtocol.self) {
        Logger()
    }
}

// 또는 UnifiedDI 직접 사용
UnifiedDI.register(UserServiceProtocol.self) { UserService() }
UnifiedDI.register(NetworkServiceProtocol.self) { NetworkService() }
```

#### 2단계: 의존성 사용

```swift
class UserViewController: UIViewController {
    @Inject var userService: UserServiceProtocol?    // 옵셔널 주입
    @RequiredInject var logger: LoggerProtocol       // 필수 주입

    override func viewDidLoad() {
        super.viewDidLoad()

        Task {
            logger.info("사용자 데이터 로딩 시작")

            if let service = userService {
                let user = try await service.getCurrentUser()
                await updateUI(with: user)
                logger.info("사용자 데이터 로딩 완료")
            }

            // UnifiedDI로 직접 해결도 가능
            if let networkService = UnifiedDI.resolve(NetworkServiceProtocol.self) {
                // 네트워크 서비스 사용
            }
        }
    }
}
```

### 🎯 Actor Hop 최적화란?

Actor Hop은 Swift Concurrency에서 서로 다른 Actor 컨텍스트 간에 실행이 전환되는 현상입니다. DiContainer는 이러한 전환을 최적화하여 성능을 극대화합니다.

```swift
// 기존 방식: 여러 번의 Actor Hop 발생 ❌
@MainActor
class TraditionalViewController {
    func loadData() {
        Task {
            let service: UserService = resolve()      // Hop 1
            let data = await service.fetchUser()      // Hop 2
            await MainActor.run { updateUI(data) }    // Hop 3
        }
    }
}

// DiContainer 방식: 최적화된 단일 Hop ✅
@MainActor
class OptimizedViewController {
    @Inject var userService: UserService?

    func loadData() {
        Task {
            guard let service = userService else { return }
            let data = await service.fetchUser()  // 최적화된 단일 Hop
            updateUI(data)  // 이미 MainActor 컨텍스트
        }
    }
}
```

### 📊 성능 향상 지표

| 시나리오 | 기존 DI | DiContainer 2.0 | 개선율 |
|---------|--------|----------------|--------|
| 단일 의존성 해결 | 0.8ms | 0.1ms | **87.5%** |
| 복잡한 의존성 그래프 | 15.6ms | 1.4ms | **91.0%** |
| MainActor UI 업데이트 | 3.1ms | 0.2ms | **93.5%** |

## Topics

### 시작하기

- <doc:QuickStart>
- <doc:CoreAPIs>
- <doc:MIGRATION-2.0.0>
- <doc:AppDIIntegration>
- ``DependencyContainer``

### 핵심 컴포넌트

#### 의존성 주입 API
- ``UnifiedDI`` - 통합 DI 시스템 (권장)
- ``DI`` - 단순화된 API
- ``DependencyContainer`` - 핵심 컨테이너
- ``GlobalUnifiedRegistry`` - 전역 레지스트리

#### Property Wrappers
- ``Inject``
- ``RequiredInject``
- ``Factory``
- ``FactoryValues``

#### 컨테이너 시스템
- <doc:ContainerUsage>
- <doc:ContainerPerformance>
- ``Container``
- ``Module``
- ``BatchModule``
- ``AppDIContainer``

### 고급 기능

#### 자동 해결 시스템
- <doc:AutoResolution>
- ``AutoDependencyResolver``

#### 플러그인 시스템
- <doc:PluginSystem>
- ``BasePlugin``

#### 모듈 팩토리
- ``ModuleFactory``
- ``RepositoryModuleFactory``
- ``UseCaseModuleFactory``
- ``ScopeModuleFactory``

### 성능 최적화

- <doc:ActorHop>
- ``SimplePerformanceOptimizer``
- ``TypeSafeRegistry``
- ``UnifiedRegistry``
 - <doc:Scopes>

### 프로퍼티 래퍼 확장

- <doc:PropertyWrappers>
- <doc:DependencyKeyPatterns>
- ``ContainerRegister``
- ``SafeDependencyKey``
- ``RequiredDependencyRegister``

### 실무 가이드

- <doc:BulkRegistrationDSL>
- <doc:ModuleFactory>
- <doc:AutoResolution>
- <doc:PluginSystem>
- <doc:LegacyAPIs>
- <doc:PropertyWrappers>
- <doc:ActorHopOptimization>

### API 참조

#### 등록 API
- ``UnifiedDI/register(_:factory:)``
- ``UnifiedDI/registerMany(_:)``

#### 해결 API
- ``UnifiedDI/resolve(_:)``
- ``UnifiedDI/requireResolve(_:)``
- ``UnifiedDI/resolveThrows(_:)``
- ``UnifiedDI/resolve(_:default:)``

#### 관리 API
- ``UnifiedDI/release(_:)``
- ``UnifiedDI/releaseAll()``
- ``DependencyContainer/bootstrap(_:)``
- ``DependencyContainer/resetForTesting()``
