# Needle 방식 DI 사용법

WeaveDI에서 Uber Needle 프레임워크와 유사한 방식으로 의존성 주입을 사용하는 방법을 안내합니다.

## 개요

WeaveDI는 Needle의 모든 핵심 기능을 제공하면서도 더 나은 개발자 경험을 제공합니다. Needle에서 WeaveDI로 마이그레이션하거나 Needle 스타일로 WeaveDI를 사용하고 싶은 개발자를 위한 완벽한 가이드입니다.

## 🏆 WeaveDI vs Needle 비교

| 특징 | Needle | WeaveDI | 결과 |
|------|--------|---------|------|
| **컴파일타임 안전성** | ✅ 코드 생성 | ✅ 매크로 기반 | **동등** |
| **런타임 성능** | ✅ 제로 코스트 | ✅ 제로 코스트 + Actor 최적화 | **WeaveDI 우승** |
| **Swift 6 지원** | ⚠️ 제한적 | ✅ 완벽 네이티브 | **WeaveDI 우승** |
| **코드 생성 필요** | ❌ 필수 | ✅ 선택적 | **WeaveDI 우승** |
| **학습 곡선** | ❌ 가파름 | ✅ 점진적 | **WeaveDI 우승** |
| **마이그레이션 용이성** | ❌ All-or-nothing | ✅ 점진적 | **WeaveDI 우승** |

## 🚀 빠른 시작

### 1. Needle 수준 성능 활성화

```swift
import WeaveDI

@main
struct MyApp: App {
    init() {
        // Needle과 동일한 제로 코스트 성능 활성화
        UnifiedDI.enableStaticOptimization()
        setupDependencies()
    }
}
```

**빌드 설정 (최고 성능을 원한다면):**
```bash
# Xcode: Build Settings → Other Swift Flags에 추가
-DUSE_STATIC_FACTORY

# 또는 SPM 명령어
swift build -c release -Xswiftc -DUSE_STATIC_FACTORY
```

### 2. 컴파일타임 의존성 검증

```swift
// Needle의 핵심 장점: 컴파일타임 안전성
@DependencyGraph([
    UserService.self: [NetworkService.self, Logger.self],
    NetworkService.self: [Logger.self, DatabaseService.self],
    DatabaseService.self: [Logger.self]
])
extension WeaveDI {}

// ✅ 정상: 의존성 그래프가 올바름
// ❌ 순환 의존성이 있다면 컴파일 에러 발생!
```

## 📋 Needle 스타일 사용 패턴

### 패턴 1: Component 기반 등록

**Needle 방식:**
```swift
// Needle 코드
import NeedleFoundation

class AppComponent: Component<EmptyDependency> {
    var userService: UserServiceProtocol {
        return UserServiceImpl(networkService: networkService)
    }

    var networkService: NetworkServiceProtocol {
        return NetworkServiceImpl(logger: logger)
    }

    var logger: LoggerProtocol {
        return ConsoleLogger()
    }
}
```

**WeaveDI 대응 방식:**
```swift
// WeaveDI: 더 간단하고 강력함
import WeaveDI

extension UnifiedDI {
    // Component 스타일 의존성 설정
    static func setupAppComponent() {
        // 기본 서비스들
        _ = register(LoggerProtocol.self) { ConsoleLogger() }
        _ = register(NetworkServiceProtocol.self) {
            NetworkServiceImpl(logger: resolve(LoggerProtocol.self)!)
        }
        _ = register(UserServiceProtocol.self) {
            UserServiceImpl(networkService: resolve(NetworkServiceProtocol.self)!)
        }

        // Needle 스타일 검증
        _ = validateNeedleStyle(
            component: AppComponent.self,
            dependencies: [LoggerProtocol.self, NetworkServiceProtocol.self, UserServiceProtocol.self]
        )
    }
}
```

### 패턴 2: 계층적 의존성 구조

**WeaveDI에서 Needle 스타일 계층 구조:**
```swift
// 1. Root Component (앱 전체 공통)
extension UnifiedDI {
    static func setupRootComponent() {
        _ = register(Logger.self) { OSLogger() }
        _ = register(NetworkClient.self) { URLSessionClient() }
        _ = register(DatabaseClient.self) { CoreDataClient() }
    }
}

// 2. Feature Component (기능별)
extension UnifiedDI {
    static func setupUserFeature() {
        _ = register(UserRepository.self) {
            UserRepositoryImpl(
                network: resolve(NetworkClient.self)!,
                database: resolve(DatabaseClient.self)!
            )
        }
        _ = register(UserService.self) {
            UserServiceImpl(repository: resolve(UserRepository.self)!)
        }
    }

    static func setupAuthFeature() {
        _ = register(AuthRepository.self) {
            AuthRepositoryImpl(network: resolve(NetworkClient.self)!)
        }
        _ = register(AuthService.self) {
            AuthServiceImpl(repository: resolve(AuthRepository.self)!)
        }
    }
}

// 3. 컴파일타임 그래프 검증
@DependencyGraph([
    UserService.self: [UserRepository.self],
    UserRepository.self: [NetworkClient.self, DatabaseClient.self],
    AuthService.self: [AuthRepository.self],
    AuthRepository.self: [NetworkClient.self],
    NetworkClient.self: [Logger.self],
    DatabaseClient.self: [Logger.self]
])
extension WeaveDI {}
```

### 패턴 3: 고성능 해결 (Needle 수준)

```swift
class PerformanceCriticalViewModel {
    // 일반적인 사용 (편의성 우선)
    @Inject private var userService: UserService?

    // 고성능이 필요한 곳 (Needle 수준 제로 코스트)
    func performanceHotPath() {
        // 정적 해결: 런타임 오버헤드 완전 제거
        let fastUserService = UnifiedDI.staticResolve(UserService.self)

        // 반복 루프에서 최적화
        for _ in 0..<10000 {
            // 매번 resolve하지 말고 캐시된 인스턴스 사용
            fastUserService?.performQuickOperation()
        }
    }
}
```

## 🔄 Needle 마이그레이션 가이드

### 단계별 마이그레이션

```swift
// 1. 마이그레이션 가이드 확인
func checkMigrationGuide() {
    print(UnifiedDI.migrateFromNeedle())
    // 상세한 단계별 가이드 출력

    print(UnifiedDI.needleMigrationBenefits())
    // 마이그레이션 이점 분석
}

// 2. 점진적 마이그레이션 (Needle의 All-or-nothing과 다름)
class HybridApproach {
    // 기존 Needle 코드는 그대로 유지
    private let legacyService = NeedleContainer.resolve(LegacyService.self)

    // 새 코드만 WeaveDI 사용
    @Inject private var newService: NewService?

    func migrate() {
        // 단계적으로 하나씩 변경 가능
        let mixedResult = legacyService.work() + (newService?.work() ?? "")
    }
}
```

### 자동 변환 도구

```swift
// Needle Component 자동 검증
extension UnifiedDI {
    static func validateNeedleComponent() -> Bool {
        // 기존 Needle 스타일 의존성들 검증
        let dependencies: [Any.Type] = [
            UserService.self,
            NetworkService.self,
            Logger.self
        ]

        return validateNeedleStyle(
            component: AppComponent.self,
            dependencies: dependencies
        )
    }
}
```

## 🎯 실제 프로젝트 적용

### 대규모 앱 구조 예시

```swift
// AppDelegate.swift
class AppDelegate: UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Needle 수준 성능 활성화
        UnifiedDI.enableStaticOptimization()

        // 계층적 의존성 설정
        setupCoreDependencies()
        setupFeatureDependencies()
        setupUIDependencies()

        // 의존성 그래프 검증
        validateDependencyGraph()

        return true
    }

    private func setupCoreDependencies() {
        // Core Layer (Needle의 Root Component와 유사)
        _ = UnifiedDI.register(Logger.self) { OSLogger() }
        _ = UnifiedDI.register(NetworkClient.self) { URLSessionClient() }
        _ = UnifiedDI.register(DatabaseClient.self) { CoreDataClient() }
        _ = UnifiedDI.register(CacheClient.self) { NSCacheClient() }
    }

    private func setupFeatureDependencies() {
        // Business Layer (Needle의 Feature Component와 유사)
        _ = UnifiedDI.register(UserRepository.self) { UserRepositoryImpl() }
        _ = UnifiedDI.register(AuthRepository.self) { AuthRepositoryImpl() }
        _ = UnifiedDI.register(ProductRepository.self) { ProductRepositoryImpl() }

        _ = UnifiedDI.register(UserService.self) { UserServiceImpl() }
        _ = UnifiedDI.register(AuthService.self) { AuthServiceImpl() }
        _ = UnifiedDI.register(ProductService.self) { ProductServiceImpl() }
    }

    private func setupUIDependencies() {
        // Presentation Layer
        _ = UnifiedDI.register(UserViewModel.self) { UserViewModel() }
        _ = UnifiedDI.register(AuthViewModel.self) { AuthViewModel() }
        _ = UnifiedDI.register(ProductViewModel.self) { ProductViewModel() }
    }

    private func validateDependencyGraph() {
        // Needle 스타일 검증
        _ = UnifiedDI.validateNeedleStyle(
            component: AppComponent.self,
            dependencies: [
                Logger.self, NetworkClient.self, DatabaseClient.self,
                UserService.self, AuthService.self, ProductService.self
            ]
        )

        print("✅ All Needle-style dependencies validated")
    }
}

// DependencyGraph.swift - 컴파일타임 검증
@DependencyGraph([
    // UI Layer
    UserViewModel.self: [UserService.self],
    AuthViewModel.self: [AuthService.self],
    ProductViewModel.self: [ProductService.self],

    // Business Layer
    UserService.self: [UserRepository.self, Logger.self],
    AuthService.self: [AuthRepository.self, Logger.self],
    ProductService.self: [ProductRepository.self, CacheClient.self, Logger.self],

    // Data Layer
    UserRepository.self: [NetworkClient.self, DatabaseClient.self],
    AuthRepository.self: [NetworkClient.self],
    ProductRepository.self: [NetworkClient.self, DatabaseClient.self],

    // Core Layer
    NetworkClient.self: [Logger.self],
    DatabaseClient.self: [Logger.self],
    CacheClient.self: [Logger.self]
])
extension WeaveDI {}
```

## 📊 성능 모니터링

```swift
// Needle과 달리 실시간 성능 분석 제공
class PerformanceAnalyzer {
    func analyzeDIPerformance() {
        // WeaveDI vs Needle 성능 비교
        print(UnifiedDI.performanceComparison())
        /*
        출력:
        🏆 WeaveDI vs Needle Performance:
        ✅ Compile-time safety: EQUAL
        ✅ Runtime performance: EQUAL (zero-cost)
        🚀 Developer experience: WeaveDI BETTER
        🎯 Swift 6 support: WeaveDI EXCLUSIVE
        */

        // 실시간 성능 통계
        let stats = UnifiedDI.stats()
        print("📊 DI Usage Stats: \(stats)")

        // Actor hop 최적화 분석 (Needle에 없는 기능)
        Task {
            let hopStats = await UnifiedDI.actorHopStats
            let optimizations = await UnifiedDI.actorOptimizations

            print("⚡ Actor Hop Stats: \(hopStats)")
            print("🤖 Optimization Suggestions: \(optimizations)")
        }
    }
}
```

## 🎨 고급 사용법

### Swift 6 Concurrency와 함께

```swift
// Needle은 Swift 6 지원이 제한적이지만, WeaveDI는 완벽 지원
actor DataManager {
    @Inject private var networkService: NetworkService?
    @Inject private var databaseService: DatabaseService?

    func syncData() async {
        // Actor 내에서도 안전한 DI 사용
        let networkData = await networkService?.fetchData()
        await databaseService?.save(networkData)
    }
}

// MainActor에서도 안전
@MainActor
class UIViewModel: ObservableObject {
    @Inject private var userService: UserService?

    func updateUI() {
        // MainActor 컨텍스트에서 안전한 DI 해결
        userService?.updateUserData()
    }
}
```

### 모듈별 의존성 관리

```swift
// 대규모 프로젝트를 위한 모듈별 관리
enum DIModule {
    case core
    case user
    case auth
    case product
}

extension UnifiedDI {
    static func setup(module: DIModule) {
        switch module {
        case .core:
            setupCoreModule()
        case .user:
            setupUserModule()
        case .auth:
            setupAuthModule()
        case .product:
            setupProductModule()
        }
    }

    private static func setupCoreModule() {
        // Core 모듈 의존성
        _ = register(Logger.self) { OSLogger() }
        _ = register(NetworkClient.self) { URLSessionClient() }
    }

    // ... 다른 모듈들
}
```

## 📝 체크리스트

### ✅ Needle에서 WeaveDI로 마이그레이션
- [ ] `import WeaveDI` 추가
- [ ] `UnifiedDI.enableStaticOptimization()` 호출
- [ ] 빌드 플래그에 `-DUSE_STATIC_FACTORY` 추가 (최고 성능)
- [ ] `@DependencyGraph`로 컴파일타임 검증 설정
- [ ] `validateNeedleStyle()`로 호환성 확인
- [ ] 점진적으로 기존 Component를 WeaveDI 방식으로 변환

### ✅ 새 프로젝트에서 Needle 스타일 WeaveDI 사용
- [ ] 계층적 의존성 구조 설계
- [ ] Component 스타일 의존성 등록
- [ ] 컴파일타임 의존성 그래프 정의
- [ ] 성능 크리티컬 부분에 `staticResolve()` 적용
- [ ] 실시간 성능 모니터링 설정

## 🚀 결론

WeaveDI는 Needle의 모든 핵심 장점을 제공하면서도:

- **더 쉬운 사용법**: 코드 생성 도구 불필요
- **더 나은 성능**: Actor hop 최적화 + 실시간 분석
- **더 안전한 마이그레이션**: 점진적 변환 가능
- **더 현대적**: Swift 6 완벽 지원

**Needle 사용자라면 WeaveDI로 마이그레이션을 적극 추천합니다!** 🏆
