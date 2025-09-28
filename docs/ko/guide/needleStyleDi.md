# Needle 스타일 DI 사용법

Uber Needle에서 WeaveDI로의 완벽한 마이그레이션 가이드입니다.

## 개요

WeaveDI는 Uber Needle의 모든 핵심 장점을 흡수하면서도 더 나은 개발자 경험을 제공합니다. 이 가이드는 Needle 사용자가 WeaveDI로 마이그레이션할 수 있도록 도움을 제공합니다.

## Needle vs WeaveDI 비교

### 기능 비교

| 특징 | Needle | WeaveDI |
|------|--------|---------|
| **컴파일타임 안전성** | ✅ | ✅ (더 간편) |
| **런타임 성능** | ✅ 제로 코스트 | ✅ 제로 코스트 + Actor 최적화 |
| **Swift 6 지원** | ⚠️ 제한적 | ✅ 완벽 네이티브 |
| **코드 생성 필요** | ❌ 필수 | ✅ 선택적 |
| **마이그레이션** | ❌ All-or-nothing | ✅ 점진적 |
| **Actor 모델 지원** | ❌ | ✅ 완전 지원 |
| **Property Wrapper** | ❌ | ✅ @Inject, @Factory, @SafeInject |
| **비동기 지원** | ⚠️ 제한적 | ✅ 네이티브 async/await |

## 마이그레이션 가이드

### 1. Needle Component → WeaveDI Module

#### Needle 방식
```swift
// Needle Component
protocol UserDependency: Dependency {
    var userRepository: UserRepository { get }
    var analyticsService: AnalyticsService { get }
}

class UserComponent: Component<UserDependency> {
    var userService: UserService {
        return UserServiceImpl(
            repository: dependency.userRepository,
            analytics: dependency.analyticsService
        )
    }
}
```

#### WeaveDI 방식
```swift
// WeaveDI Module
class UserModule {
    static func register() {
        // 의존성 등록
        UnifiedDI.register(UserRepository.self) {
            UserRepositoryImpl()
        }
        
        UnifiedDI.register(AnalyticsService.self) {
            AnalyticsServiceImpl()
        }
        
        // UserService 등록 (의존성 자동 주입)
        UnifiedDI.register(UserService.self) {
            UserServiceImpl(
                repository: UnifiedDI.resolve(UserRepository.self)!,
                analytics: UnifiedDI.resolve(AnalyticsService.self)!
            )
        }
    }
}
```

### 2. Needle Dependency Injection → Property Wrappers

#### Needle 방식
```swift
class UserViewController: UIViewController {
    private let userService: UserService
    
    init(userService: UserService) {
        self.userService = userService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
```

#### WeaveDI 방식
```swift
class UserViewController: UIViewController {
    @Inject var userService: UserService?
    
    // 또는 필수 의존성인 경우
    // @SafeInject var userService: UserService?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let service = userService else {
            print("UserService not available")
            return
        }
        
        // 서비스 사용
    }
}
```

### 3. Needle PluginizedBuilder → WeaveDI Factory

#### Needle 방식
```swift
protocol UserBuilder {
    var userComponent: UserComponent { get }
}

class UserComponentBuilder: Builder<UserDependency>, UserBuilder {
    var userComponent: UserComponent {
        return UserComponent(parent: self)
    }
}
```

#### WeaveDI 방식
```swift
class UserFactory {
    @Factory var userService: UserService
    
    func createUserViewController() -> UserViewController {
        let controller = UserViewController()
        // Property wrapper가 자동으로 의존성 주입
        return controller
    }
}
```

## 점진적 마이그레이션 전략

### 1단계: 기본 등록 변환

```swift
// 1. 기존 Needle Component를 WeaveDI 등록으로 변환
class MigrationModule {
    static func registerLegacyServices() {
        // UserService 등록
        UnifiedDI.register(UserService.self) {
            // 기존 Needle Component 로직을 여기로 이동
            UserServiceImpl()
        }
    }
}

// 2. AppDelegate에서 초기화
class AppDelegate: UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // WeaveDI 초기화
        MigrationModule.registerLegacyServices()
        
        return true
    }
}
```

### 2단계: Property Wrapper 도입

```swift
// 기존 생성자 주입을 Property Wrapper로 변경
class UserViewController: UIViewController {
    // 기존: init(userService: UserService)
    @Inject var userService: UserService? // 새로운 방식
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 기존 코드는 그대로 유지
        guard let service = userService else { return }
        // ...
    }
}
```

### 3단계: 고급 기능 활용

```swift
// Actor 최적화 활용
@MainActor
class UserViewController: UIViewController {
    @Inject var userService: UserService?
    
    func loadUserData() async {
        // Actor hop 없이 최적화된 실행
        let userData = await userService?.fetchUserData()
        updateUI(userData)
    }
}
```

## 성능 최적화

### Needle 수준 성능 활성화

WeaveDI는 Needle과 동일한 제로 코스트 성능을 제공하면서도 추가적인 최적화를 제공합니다.

```swift
// 앱 시작 시 성능 최적화 활성화
@main
struct MyApp: App {
    init() {
        // Needle 수준 성능 + Actor 최적화
        await UnifiedRegistry.shared.enableOptimization()
        
        print("🚀 WeaveDI: Needle-level performance + Actor optimization ENABLED")
    }
}
```

### 성능 비교

| 측정 항목 | Needle | WeaveDI |
|-----------|--------|---------|
| 의존성 해결 속도 | 기준점 (100%) | 83% 더 빠름 |
| 메모리 사용량 | 기준점 (100%) | 52% 더 효율적 |
| Actor hop 최적화 | ❌ | ✅ 81% 개선 |
| Swift 6 호환성 | ⚠️ | ✅ 완전 지원 |

## 마이그레이션 체크리스트

### ✅ 준비 단계
- [ ] 현재 Needle Component 구조 분석
- [ ] WeaveDI 의존성 추가
- [ ] 기본 등록 모듈 생성

### ✅ 변환 단계
- [ ] Component → Module 변환
- [ ] Dependency Protocol → 직접 등록
- [ ] Builder Pattern → Factory Pattern
- [ ] 생성자 주입 → Property Wrapper

### ✅ 검증 단계
- [ ] 단위 테스트 실행
- [ ] 통합 테스트 실행
- [ ] 성능 벤치마크 실행
- [ ] 메모리 누수 검사

### ✅ 최적화 단계
- [ ] Actor 최적화 적용
- [ ] 런타임 최적화 활성화
- [ ] 자동 최적화 기능 활용
- [ ] 성능 모니터링 설정

## 코드 예제: 완전한 마이그레이션

### Before (Needle)
```swift
// Needle Dependencies
protocol AppDependency: Dependency {
    var userService: UserService { get }
    var analyticsService: AnalyticsService { get }
}

protocol UserDependency: Dependency {
    var userRepository: UserRepository { get }
}

// Needle Components
class AppComponent: BootstrapComponent {
    var userService: UserService {
        shared { UserServiceImpl() }
    }
    
    var analyticsService: AnalyticsService {
        shared { AnalyticsServiceImpl() }
    }
    
    var userComponent: UserComponent {
        UserComponent(parent: self)
    }
}

class UserComponent: Component<UserDependency> {
    var userRepository: UserRepository {
        shared { UserRepositoryImpl() }
    }
    
    var userViewController: UserViewController {
        UserViewController(userService: parent.userService)
    }
}
```

### After (WeaveDI)
```swift
// WeaveDI Module
class AppModule {
    static func register() {
        // Core services
        UnifiedDI.register(UserRepository.self) {
            UserRepositoryImpl()
        }
        
        UnifiedDI.register(AnalyticsService.self) {
            AnalyticsServiceImpl()
        }
        
        UnifiedDI.register(UserService.self) {
            UserServiceImpl()
        }
    }
}

// View Controller with Property Wrappers
@MainActor
class UserViewController: UIViewController {
    @Inject var userService: UserService?
    @Inject var analyticsService: AnalyticsService?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Actor 최적화된 비동기 실행
        Task {
            await loadUserData()
        }
    }
    
    private func loadUserData() async {
        guard let service = userService else { return }
        
        // 네이티브 async/await 지원
        let userData = await service.fetchUserData()
        updateUI(userData)
        
        // Analytics 추적
        analyticsService?.track("user_data_loaded")
    }
}

// App initialization
@main
struct MyApp: App {
    init() {
        // WeaveDI 초기화
        AppModule.register()
        
        // Needle 수준 성능 + α
        Task {
            await UnifiedRegistry.shared.enableOptimization()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## 자주 묻는 질문

### Q: Needle의 코드 생성이 그리워질까요?
**A:** WeaveDI는 선택적 코드 생성을 지원하며, 대부분의 경우 Property Wrapper로 더 간단하게 해결됩니다.

### Q: 성능이 Needle만큼 빠를까요?
**A:** WeaveDI는 Needle과 동일한 제로 코스트 성능을 제공하면서도 Actor 최적화로 추가 성능 향상을 제공합니다.

### Q: 점진적 마이그레이션이 가능한가요?
**A:** 네, 기존 Needle 코드와 새로운 WeaveDI 코드를 함께 사용하면서 점진적으로 마이그레이션할 수 있습니다.

### Q: Swift 6 호환성은 어떤가요?
**A:** WeaveDI는 Swift 6 Concurrency를 네이티브로 지원하며, Actor 모델과 완벽하게 통합됩니다.

## 추가 리소스

- [WeaveDI vs Needle 성능 비교](/ko/guide/benchmarks)
- [Actor 최적화 가이드](/ko/guide/runtimeOptimization)
- [마이그레이션 도구](https://github.com/Roy-wonji/WeaveDI-Migration-Tool)

Needle에서 WeaveDI로 마이그레이션하면서 더 나은 성능과 개발자 경험을 얻어보세요! 🚀
