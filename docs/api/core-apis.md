# Core APIs

Essential WeaveDI APIs for dependency injection

## Overview

WeaveDI provides a clean, type-safe API for dependency registration and resolution. This guide covers the most important APIs you'll use daily.

## UnifiedDI

The recommended API for most use cases.

### Registration

#### Basic Registration Pattern

```swift
// Basic registration - 가장 기본적인 의존성 등록 방법
let service = UnifiedDI.register(UserService.self) {
    UserServiceImpl()
}
```

**코드 설명:**
- `UnifiedDI.register`: WeaveDI의 통합 등록 API를 호출
- `UserService.self`: 등록할 타입을 지정 (프로토콜 또는 클래스)
- `{ UserServiceImpl() }`: 팩토리 클로저 - 인스턴스 생성 방법 정의
- `let service`: 등록과 동시에 첫 번째 인스턴스 반환받기
- 내부적으로 TypeID 매핑을 통해 O(1) 접근 속도 최적화

#### KeyPath 기반 등록 (타입 안전성 강화)

```swift
// 먼저 DependencyContainer 확장으로 KeyPath 정의
extension DependencyContainer {
    var userRepository: UserRepository? {
        resolve(UserRepository.self)
    }
}

// KeyPath를 사용한 타입 안전한 등록
let repository = UnifiedDI.register(\.userRepository) {
    UserRepositoryImpl()
}
```

**코드 설명:**
- `extension DependencyContainer`: 의존성 KeyPath들을 한 곳에서 관리
- `var userRepository: UserRepository?`: computed property로 KeyPath 정의
- `\.userRepository`: Swift KeyPath 문법으로 컴파일 타임 안전성 보장
- 오타나 잘못된 타입 사용 시 컴파일 에러로 조기 발견
- IDE 자동완성과 리팩토링 지원 향상

#### 조건부 등록 (환경별 구현체 선택)

```swift
let analytics = UnifiedDI.Conditional.registerIf(
    AnalyticsService.self,           // 등록할 서비스 타입
    condition: !isDebugMode,         // 조건식 - false면 fallback 사용
    factory: { FirebaseAnalytics() }, // 조건이 true일 때 생성할 구현체
    fallback: { MockAnalytics() }     // 조건이 false일 때 생성할 구현체
)
```

**코드 설명:**
- `UnifiedDI.Conditional.registerIf`: 조건부 등록 전용 API
- `condition: !isDebugMode`: Bool 표현식으로 런타임 조건 확인
- `factory`: 조건이 참일 때 사용할 실제 구현체 (프로덕션용)
- `fallback`: 조건이 거짓일 때 사용할 대체 구현체 (테스트/디버그용)
- 빌드 환경, 피처 플래그, A/B 테스트 등에서 유용

### Resolution (의존성 해결)

의존성 해결은 등록된 서비스를 실제로 가져와 사용하는 과정입니다.

#### 기본 해결 방식

```swift
// 기본적인 의존성 해결 - 가장 간단한 형태
let service = await UnifiedDI.resolve(UserService.self)
```

**코드 설명:**
- `await UnifiedDI.resolve`: 비동기적으로 의존성을 해결
- Swift Concurrency를 완전 지원하여 Actor 간 안전한 전환
- 내부적으로 TypeID 매핑을 통해 O(1) 접근 속도
- 등록되지 않은 의존성의 경우 nil 반환

#### 안전한 해결 방식 (에러 처리 포함)

```swift
// 에러 핸들링을 포함한 안전한 의존성 해결
do {
    let service: UserService = try await UnifiedDI.resolveSafely(UserService.self)
    // 성공적으로 해결된 서비스 사용
    let userData = await service.fetchUserData()
} catch DIError.dependencyNotFound {
    // 의존성을 찾을 수 없는 경우의 처리
    print("UserService가 등록되지 않았습니다")
    showErrorMessage("서비스를 사용할 수 없습니다")
} catch DIError.circularDependency {
    // 순환 의존성 오류 처리
    print("순환 의존성이 감지되었습니다")
    assertionFailure("의존성 그래프를 확인하세요")
} catch {
    print("Resolution failed: \(error)")
}
```

**코드 설명:**
- `try await UnifiedDI.resolveSafely`: 실패 시 에러를 던지는 안전한 해결
- `DIError.dependencyNotFound`: 등록되지 않은 의존성 오류
- `DIError.circularDependency`: A→B→A 형태의 순환 의존성 감지
- 개발 단계에서 의존성 문제를 명확하게 파악 가능
- 프로덕션에서 graceful failure 처리 지원

#### KeyPath 기반 해결 (타입 안전성 최대화)

```swift
// KeyPath를 사용한 타입 안전한 의존성 해결
let repository = await UnifiedDI.resolve(\.userRepository)
```

**코드 설명:**
- `\.userRepository`: Swift KeyPath 문법으로 컴파일 타임 검증
- 오타나 잘못된 프로퍼티명 사용 시 컴파일 에러 발생
- IDE에서 자동완성과 go-to-definition 지원
- 리팩토링 시 모든 사용처가 자동으로 업데이트

## Property Wrappers (프로퍼티 래퍼)

WeaveDI의 프로퍼티 래퍼는 의존성 주입을 선언적이고 직관적으로 만들어주는 핵심 기능입니다.

### @Inject - 기본 의존성 주입

선택적 의존성을 위한 가장 기본적인 프로퍼티 래퍼입니다.

```swift
class ViewController {
    // @Inject 프로퍼티 래퍼로 의존성 자동 주입
    @Inject var userService: UserService?
    @Inject var analyticsService: AnalyticsService?

    func loadData() async {
        // 의존성이 등록되어 있는지 안전하게 확인
        guard let service = userService else {
            print("UserService가 등록되지 않았습니다")
            showErrorState()
            return
        }

        // 비동기적으로 사용자 데이터 가져오기
        let user = await service.fetchUser()

        // 선택적 의존성 사용 (등록되지 않았어도 앱이 동작)
        analyticsService?.trackUserDataLoaded(user.id)

        // UI 업데이트 (MainActor에서 자동 실행)
        updateUI(with: user)
    }
}
```

**@Inject 동작 원리:**
- **Lazy Resolution**: 프로퍼티에 최초 접근 시에만 의존성 해결
- **Caching**: 한 번 해결된 의존성은 인스턴스 생명주기 동안 캐시
- **Thread Safety**: Actor isolation을 준수하여 스레드 안전 보장
- **Optional Return**: 등록되지 않은 의존성의 경우 nil 반환으로 안전성 확보
- **Memory Efficiency**: Weak reference를 사용하여 메모리 누수 방지

### @Factory - 팩토리 패턴 주입

매번 새로운 인스턴스가 필요한 의존성을 위한 프로퍼티 래퍼입니다.

```swift
class DocumentProcessor {
    // @Factory는 매번 새로운 인스턴스를 생성
    @Factory var pdfGenerator: PDFGenerator
    @Factory var imageProcessor: ImageProcessor

    func createDocument() async {
        // 새로운 PDFGenerator 인스턴스 생성
        let generator = pdfGenerator

        // 문서별로 독립적인 설정 적용
        generator.setQuality(.high)
        generator.setEncryption(enabled: true)

        // 비동기 PDF 생성
        let pdfData = await generator.generate()

        // 이미지 처리도 별도 인스턴스로
        let processor = imageProcessor
        processor.optimizeForPDF()

        // 처리 완료 후 자동으로 메모리 해제
        saveDocument(pdfData)
    }

    func createMultipleDocuments() async {
        // 각 문서마다 독립적인 generator 사용
        for document in documents {
            let generator = pdfGenerator // 매번 새 인스턴스
            await generator.process(document)
        }
    }
}
```

**@Factory 동작 원리:**
- **Fresh Instance**: 프로퍼티 접근 시마다 팩토리 함수 호출하여 새 인스턴스 생성
- **Stateless Design**: 인스턴스 간 상태 공유 없이 독립적으로 동작
- **Resource Management**: 각 인스턴스는 사용 후 자동으로 메모리에서 해제
- **Concurrent Safe**: 동시 접근 시에도 각각 별도 인스턴스로 안전성 보장
- **Configuration Flexibility**: 각 인스턴스마다 다른 설정 적용 가능

### @SafeInject - 안전한 의존성 주입

필수 의존성을 위한 에러 처리가 포함된 프로퍼티 래퍼입니다.

```swift
class DataManager {
    // @SafeInject로 필수 의존성 안전하게 주입
    @SafeInject var database: Database?
    @SafeInject var cacheManager: CacheManager?

    func save(_ data: Data) throws {
        // 의존성 안전 검증 및 에러 처리
        guard let db = try database?.getValue() else {
            // 구체적인 에러 정보와 함께 실패 처리
            throw DIError.dependencyNotFound(
                type: Database.self,
                reason: "Database service is not registered"
            )
        }

        // 캐시 매니저도 안전하게 검증
        guard let cache = try cacheManager?.getValue() else {
            throw DIError.dependencyNotFound(
                type: CacheManager.self,
                reason: "Cache manager is not available"
            )
        }

        // 트랜잭션으로 안전하게 저장
        try db.transaction { transaction in
            try transaction.save(data)
            try cache.invalidate(key: data.id)
        }
    }

    func safeInitialization() throws {
        // 앱 시작 시 필수 의존성들이 모두 준비되었는지 검증
        _ = try database?.getValue()
        _ = try cacheManager?.getValue()

        print("모든 필수 의존성이 성공적으로 주입되었습니다")
    }
}
```

**@SafeInject 동작 원리:**
- **Explicit Error Handling**: getValue() 메서드로 명시적 에러 처리
- **Early Validation**: 앱 시작 시 필수 의존성 검증 가능
- **Detailed Error Info**: 구체적인 에러 정보와 해결 방안 제공
- **Fail-Fast Pattern**: 의존성 누락을 조기에 발견하여 런타임 오류 방지
- **Production Safety**: 개발/테스트 환경에서 의존성 문제를 사전 발견

## DIContainer

Low-level container for advanced scenarios.

### Registration

```swift
DIContainer.shared.register(UserService.self) {
    UserServiceImpl()
}
```

### Resolution

```swift
let service = DIContainer.shared.resolve(UserService.self)
```

## Runtime Optimization (런타임 최적화)

WeaveDI 3.1의 핵심 기능인 런타임 핫패스 최적화는 의존성 해결 성능을 50-80% 향상시킵니다.

### 최적화 활성화

```swift
// 고성능 최적화 모드 활성화
UnifiedRegistry.shared.enableOptimization()

// 최적화 상태 확인
let isEnabled = UnifiedRegistry.shared.isOptimizationEnabled

// 최적화가 활성화된 후 기존 코드가 자동으로 빨라짐
let service = await UnifiedDI.resolve(UserService.self)
```

**최적화 동작 원리:**
- **TypeID Mapping**: 타입을 고유 ID로 변환하여 해시 충돌 제거
- **Array Slot Access**: Dictionary → Array 접근으로 O(1) 성능 보장
- **Lock-Free Reads**: 스냅샷 기반 접근으로 읽기 경합 제거
- **Memory Layout**: 캐시 친화적 메모리 배치로 CPU 캐시 미스 감소

### 성능 개선 세부사항

| 최적화 기법 | 이전 성능 | 최적화 후 | 개선율 |
|-------------|----------|-----------|--------|
| 단일 스레드 해결 | 1.2ms | 0.2ms | **83%** |
| 멀티 스레드 읽기 | 경합 발생 | 락프리 | **300%** |
| 복잡한 의존성 | 25.6ms | 3.1ms | **87%** |

### 고급 최적화 옵션

```swift
// 세밀한 최적화 제어
UnifiedRegistry.shared.configure { config in
    // TypeID 최적화 활성화 (기본값: true)
    config.enableTypeIDOptimization = true

    // 인라인 캐싱 활성화 (기본값: true)
    config.enableInlineCache = true

    // 스냅샷 업데이트 주기 설정 (기본값: 100ms)
    config.snapshotUpdateInterval = 0.1

    // 메모리 압축 레벨 (기본값: .balanced)
    config.memoryCompressionLevel = .aggressive
}

// 런타임 통계 수집
let stats = UnifiedRegistry.shared.getPerformanceStats()
print("평균 해결 시간: \(stats.averageResolutionTime)ms")
print("캐시 히트율: \(stats.cacheHitRatio)%")
```

## Error Handling

```swift
enum DIError: Error {
    case dependencyNotFound
    case circularDependency
    case registrationFailed
}
```

## Best Practices (모범 사례)

실제 앱에서 WeaveDI를 효과적으로 사용하는 완전한 예제를 제공합니다.

### 전체 앱 구조 예제

#### 1. 서비스 프로토콜 정의

```swift
// Services/Protocols/UserServiceProtocol.swift
import Foundation

protocol UserServiceProtocol {
    func fetchUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws
    func deleteUser(id: String) async throws
}

protocol NetworkServiceProtocol {
    func request<T: Codable>(_ endpoint: Endpoint) async throws -> T
    func upload(data: Data, to endpoint: Endpoint) async throws
}

protocol CacheServiceProtocol {
    func get<T: Codable>(_ key: String, type: T.Type) async -> T?
    func set<T: Codable>(_ value: T, key: String) async
    func invalidate(key: String) async
}

protocol AnalyticsServiceProtocol {
    func track(event: AnalyticsEvent)
    func setUserProperty(key: String, value: String)
    func flush() async
}
```

#### 2. 구현체 클래스

```swift
// Services/Implementations/UserService.swift
import WeaveDI

class UserService: UserServiceProtocol {
    @Inject private var networkService: NetworkServiceProtocol?
    @Inject private var cacheService: CacheServiceProtocol?
    @Inject private var analyticsService: AnalyticsServiceProtocol?

    func fetchUser(id: String) async throws -> User {
        // 캐시에서 먼저 확인
        if let cachedUser = await cacheService?.get("user_\(id)", type: User.self) {
            analyticsService?.track(event: .userLoadedFromCache(id: id))
            return cachedUser
        }

        // 네트워크에서 가져오기
        guard let network = networkService else {
            throw ServiceError.networkServiceUnavailable
        }

        let user: User = try await network.request(.user(id: id))

        // 캐시에 저장
        await cacheService?.set(user, key: "user_\(id)")

        // 분석 이벤트 전송
        analyticsService?.track(event: .userLoadedFromNetwork(id: id))

        return user
    }

    func updateUser(_ user: User) async throws {
        guard let network = networkService else {
            throw ServiceError.networkServiceUnavailable
        }

        // 서버에 업데이트
        try await network.request(.updateUser(user))

        // 캐시 무효화
        await cacheService?.invalidate(key: "user_\(user.id)")

        // 분석 이벤트
        analyticsService?.track(event: .userUpdated(id: user.id))
    }

    func deleteUser(id: String) async throws {
        guard let network = networkService else {
            throw ServiceError.networkServiceUnavailable
        }

        try await network.request(.deleteUser(id: id))
        await cacheService?.invalidate(key: "user_\(id)")
        analyticsService?.track(event: .userDeleted(id: id))
    }
}
```

#### 3. 앱 부트스트랩 및 의존성 등록

```swift
// App/AppDelegate.swift 또는 App.swift
import WeaveDI
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // 의존성 부트스트랩을 비동기로 수행
        Task {
            await bootstrapDependencies()
        }

        return true
    }

    private func bootstrapDependencies() async {
        await DependencyContainer.bootstrap { container in
            // 1. 핵심 서비스 등록
            container.register(NetworkServiceProtocol.self) {
                NetworkService(baseURL: Configuration.apiBaseURL)
            }

            container.register(CacheServiceProtocol.self) {
                CacheService(memoryLimit: 50_000_000) // 50MB
            }

            // 2. 환경별 조건부 등록
            if Configuration.isProduction {
                container.register(AnalyticsServiceProtocol.self) {
                    FirebaseAnalyticsService()
                }
            } else {
                container.register(AnalyticsServiceProtocol.self) {
                    MockAnalyticsService()
                }
            }

            // 3. 비즈니스 로직 서비스 등록
            container.register(UserServiceProtocol.self) {
                UserService()
            }

            // 4. KeyPath 기반 등록
            container.register(\.userRepository) {
                UserRepository()
            }

            container.register(\.authenticationManager) {
                AuthenticationManager()
            }
        }

        // 5. 런타임 최적화 활성화
        UnifiedRegistry.shared.enableOptimization()

        // 6. 필수 의존성 검증
        await validateCriticalDependencies()
    }

    private func validateCriticalDependencies() async {
        do {
            _ = try await UnifiedDI.resolveSafely(NetworkServiceProtocol.self)
            _ = try await UnifiedDI.resolveSafely(UserServiceProtocol.self)
            print("✅ 모든 필수 의존성이 성공적으로 등록되었습니다")
        } catch {
            fatalError("❌ 필수 의존성 등록 실패: \(error)")
        }
    }
}
```

#### 4. ViewController에서 의존성 사용

```swift
// ViewControllers/UserProfileViewController.swift
import UIKit
import WeaveDI

@MainActor
class UserProfileViewController: UIViewController {

    // 의존성 주입
    @Inject private var userService: UserServiceProtocol?
    @SafeInject private var analyticsService: AnalyticsServiceProtocol?
    @Factory private var imageProcessor: ImageProcessor

    // UI 컴포넌트
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!

    private var currentUser: User?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()

        Task {
            await loadUserProfile()
        }
    }

    private func setupUI() {
        loadingIndicator.startAnimating()

        // 분석 이벤트 전송
        do {
            let analytics = try analyticsService?.getValue()
            analytics?.track(event: .screenViewed(screen: "UserProfile"))
        } catch {
            print("Analytics service unavailable: \(error)")
        }
    }

    private func loadUserProfile() async {
        guard let service = userService else {
            showError("사용자 서비스를 사용할 수 없습니다")
            return
        }

        do {
            // 사용자 데이터 로드
            let user = try await service.fetchUser(id: "current_user")
            currentUser = user

            // UI 업데이트 (이미 MainActor에서 실행 중)
            updateUI(with: user)

            // 프로필 이미지 처리
            if let imageData = user.profileImageData {
                let processor = imageProcessor
                let optimizedImage = await processor.optimizeForDisplay(imageData)
                profileImageView.image = optimizedImage
            }

        } catch {
            showError("사용자 정보를 불러올 수 없습니다: \(error.localizedDescription)")
        }

        loadingIndicator.stopAnimating()
    }

    private func updateUI(with user: User) {
        nameLabel.text = user.name
        emailLabel.text = user.email

        // 분석 이벤트 전송
        do {
            let analytics = try analyticsService?.getValue()
            analytics?.track(event: .userProfileLoaded(userId: user.id))
        } catch {
            print("Analytics service unavailable")
        }
    }

    @IBAction func editProfileTapped(_ sender: UIButton) {
        guard let user = currentUser else { return }

        // 편집 화면으로 이동
        let editVC = UserEditViewController()
        editVC.user = user
        navigationController?.pushViewController(editVC, animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "오류", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
```

#### 5. KeyPath 확장 정의

```swift
// Extensions/DependencyContainer+KeyPaths.swift
import WeaveDI

extension DependencyContainer {
    // 사용자 관련 의존성
    var userRepository: UserRepositoryProtocol? {
        resolve(UserRepositoryProtocol.self)
    }

    var authenticationManager: AuthenticationManagerProtocol? {
        resolve(AuthenticationManagerProtocol.self)
    }

    // 네트워크 관련 의존성
    var apiClient: APIClientProtocol? {
        resolve(APIClientProtocol.self)
    }

    // 저장소 관련 의존성
    var localDatabase: LocalDatabaseProtocol? {
        resolve(LocalDatabaseProtocol.self)
    }

    var keychain: KeychainServiceProtocol? {
        resolve(KeychainServiceProtocol.self)
    }
}
```

### 모범 사례 요약

1. **프로토콜 기반 설계**: 구체적인 구현이 아닌 프로토콜에 의존
2. **계층적 의존성**: UI → Service → Repository → Network 순서로 구성
3. **환경별 구현체**: 프로덕션/테스트/개발 환경에 맞는 구현체 등록
4. **에러 처리**: SafeInject와 try-catch를 활용한 안전한 의존성 해결
5. **성능 최적화**: enableOptimization()으로 런타임 성능 향상
6. **타입 안전성**: KeyPath를 활용한 컴파일 타임 검증

## See Also

- [Property Wrappers](/guide/property-wrappers) - Detailed property wrapper guide
- [Runtime Optimization](/guide/runtime-optimization) - Performance optimization
- [UnifiedDI](/guide/unified-di) - Advanced UnifiedDI features