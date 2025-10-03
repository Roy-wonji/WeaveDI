# 빠른 시작 가이드

5분 안에 WeaveDI를 시작해보세요 - 제로부터 프로덕션 준비 완료된 의존성 주입까지.

## 설치

### Swift Package Manager

프로젝트의 Package.swift 파일에 WeaveDI를 추가하세요. 이 설정은 Swift Package Manager가 GitHub 리포지토리에서 WeaveDI 버전 3.1.0 이상을 다운로드하도록 지시합니다:

```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.1.0")
]
```

**작동 원리:**
- 공식 리포지토리에서 WeaveDI 프레임워크를 다운로드합니다
- 최신 기능과 버그 수정이 포함된 3.1.0 이상 버전을 보장합니다
- Swift 프로젝트의 빌드 시스템과 원활하게 통합됩니다

**성능 영향:**
- 패키지 포함에 대한 런타임 오버헤드 없음
- 컴파일 타임 의존성 해결
- Swift Package Manager의 데드 코드 제거로 최적화된 바이너리 크기

**버전 선택 전략:**
```swift
// 안정적인 프로덕션 앱용
.package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.1.0")

// 최신 기능용 (주의해서 사용)
.package(url: "https://github.com/Roy-wonji/WeaveDI.git", .branch("main"))

// 특정 버전 요구사항용
.package(url: "https://github.com/Roy-wonji/WeaveDI.git", exact: "3.1.2")
```

### Xcode 설치

시각적 프로젝트 관리를 위해:

1. **File → Add Package Dependencies**
2. **입력:** `https://github.com/Roy-wonji/WeaveDI.git`
3. **버전 선택:** 3.1.0에 대해 "Up to Next Major" 선택
4. **Add Package**

**Xcode 통합의 장점:**
- Xcode 인터페이스를 통한 자동 의존성 업데이트
- 시각적 패키지 관리
- 통합 문서화 및 코드 완성
- 내장된 충돌 해결

**설치 문제 해결:**
```swift
// 빌드 오류가 발생하면 다음을 시도하세요:
// 1. 빌드 폴더 정리 (Cmd+Shift+K)
// 2. 패키지 캐시 재설정
// File → Packages → Reset Package Caches

// 3. 최소 배포 타겟 확인
// iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+
```

## 기본 사용법

### 1. Import

의존성 주입이 필요한 Swift 파일에 WeaveDI를 import하세요. 이를 통해 프로퍼티 래퍼, 등록 API, 컨테이너 관리 등 모든 WeaveDI 기능에 접근할 수 있습니다:

```swift
import WeaveDI
```

**사용 가능한 기능:**
- `@Injected`, `@Factory`, `@SafeInject` 프로퍼티 래퍼 접근
- UnifiedDI 등록 및 해결 API
- WeaveDI.Container 부트스트랩 기능
- 모든 WeaveDI 유틸리티 클래스와 프로토콜
- 성능 모니터링을 위한 Auto DI Optimizer 기능

**Import 모범 사례:**
```swift
// ✅ 서비스 파일에서 import
import WeaveDI
import Foundation  // 핵심 기능을 위해 항상 Foundation과 함께

// ✅ SwiftUI 앱의 경우
import WeaveDI
import SwiftUI

// ✅ 복잡한 앱의 경우, 전용 DI 설정 파일 생성 고려
// 파일: DependencySetup.swift
import WeaveDI
import Foundation

// 이 파일이 중앙 DI 구성 허브가 됩니다
```

**모듈 구성 전략:**
```swift
// 핵심 앱 모듈
// 파일: App+DI.swift
import WeaveDI

extension App {
    static func setupDependencies() {
        // 모든 앱 전체 의존성을 여기서 구성
    }
}

// 기능별 모듈
// 파일: UserFeature+DI.swift
import WeaveDI

extension UserFeature {
    static func setupUserDependencies() {
        // 사용자 관련 의존성만
    }
}
```

### 2. 서비스 정의

서비스를 위한 프로토콜(인터페이스)과 구현을 생성하세요. 이는 의존성 역전 원칙을 따릅니다 - 구체적인 구현이 아닌 추상화에 의존하세요:

```swift
// 서비스 계약 정의 (사용 가능한 기능)
protocol UserService {
    func fetchUser(id: String) async throws -> User?
    func updateUser(_ user: User) async throws -> User
    func deleteUser(id: String) async throws
}

// 실제 서비스 로직 구현
class UserServiceImpl: UserService {
    private let networkClient: NetworkClient
    private let database: Database
    private let cache: CacheService

    // 생성자를 통한 의존성 주입
    init(
        networkClient: NetworkClient = UnifiedDI.requireResolve(NetworkClient.self),
        database: Database = UnifiedDI.requireResolve(Database.self),
        cache: CacheService = UnifiedDI.resolve(CacheService.self, default: MemoryCache())
    ) {
        self.networkClient = networkClient
        self.database = database
        self.cache = cache
    }

    func fetchUser(id: String) async throws -> User? {
        // 1. 먼저 캐시 확인 (성능 최적화)
        if let cachedUser = cache.getUser(id: id) {
            print("✅ 캐시에서 사용자 발견: \(id)")
            return cachedUser
        }

        // 2. 로컬 데이터베이스 시도
        if let dbUser = try await database.fetchUser(id: id) {
            print("✅ 데이터베이스에서 사용자 발견: \(id)")
            cache.setUser(dbUser) // 향후 요청을 위해 캐시
            return dbUser
        }

        // 3. 마지막 수단으로 원격 API에서 가져오기
        print("⚠️ 네트워크에서 사용자 가져오는 중: \(id)")
        let networkUser = try await networkClient.fetchUser(id: id)

        if let user = networkUser {
            // 데이터베이스와 캐시에 저장
            try await database.saveUser(user)
            cache.setUser(user)
            print("✅ 네트워크에서 사용자 캐시됨: \(id)")
        }

        return networkUser
    }

    func updateUser(_ user: User) async throws -> User {
        // 모든 계층에서 업데이트
        let updatedUser = try await networkClient.updateUser(user)
        try await database.saveUser(updatedUser)
        cache.setUser(updatedUser)

        print("✅ 모든 계층에서 사용자 업데이트됨: \(user.id)")
        return updatedUser
    }

    func deleteUser(id: String) async throws {
        // 모든 계층에서 제거
        try await networkClient.deleteUser(id: id)
        try await database.deleteUser(id: id)
        cache.removeUser(id: id)

        print("✅ 모든 계층에서 사용자 삭제됨: \(id)")
    }
}
```

**프로토콜을 사용하는 이유:**
- **테스트 가능성**: 테스트용 모킹 구현을 쉽게 생성할 수 있습니다
- **유연성**: 의존 코드를 변경하지 않고 구현을 교체할 수 있습니다
- **유지보수성**: 인터페이스와 구현의 명확한 분리
- **모범 사례**: 깔끔한 아키텍처를 위한 SOLID 원칙을 따릅니다

**고급 프로토콜 디자인 패턴:**
```swift
// ✅ 제네릭 연산을 위한 연관 타입이 있는 프로토콜
protocol Repository {
    associatedtype Entity
    associatedtype ID

    func find(by id: ID) async throws -> Entity?
    func save(_ entity: Entity) async throws -> Entity
    func delete(by id: ID) async throws
}

// ✅ 복잡한 서비스를 위한 프로토콜 조합
protocol UserService: UserReader, UserWriter, UserValidator {
    // 여러 집중된 프로토콜을 결합
}

protocol UserReader {
    func fetchUser(id: String) async throws -> User?
    func searchUsers(query: String) async throws -> [User]
}

protocol UserWriter {
    func createUser(_ user: User) async throws -> User
    func updateUser(_ user: User) async throws -> User
    func deleteUser(id: String) async throws
}

protocol UserValidator {
    func validateUser(_ user: User) throws
    func validateEmail(_ email: String) -> Bool
}

// ✅ 기본 구현이 있는 프로토콜
extension UserValidator {
    func validateEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    func validateUser(_ user: User) throws {
        guard !user.name.isEmpty else {
            throw ValidationError.emptyName
        }

        guard validateEmail(user.email) else {
            throw ValidationError.invalidEmail(user.email)
        }
    }
}

enum ValidationError: LocalizedError {
    case emptyName
    case invalidEmail(String)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "사용자 이름은 비워둘 수 없습니다"
        case .invalidEmail(let email):
            return "유효하지 않은 이메일 형식: \(email)"
        }
    }
}
```

**실제 서비스 아키텍처 예제:**
```swift
// 포괄적인 오류 처리가 있는 다중 계층 서비스
class ProductionUserService: UserService {
    private let repository: UserRepository
    private let validator: UserValidator
    private let eventPublisher: EventPublisher
    private let logger: Logger

    init(
        repository: UserRepository = UnifiedDI.requireResolve(UserRepository.self),
        validator: UserValidator = UnifiedDI.requireResolve(UserValidator.self),
        eventPublisher: EventPublisher = UnifiedDI.requireResolve(EventPublisher.self),
        logger: Logger = UnifiedDI.resolve(Logger.self, default: ConsoleLogger())
    ) {
        self.repository = repository
        self.validator = validator
        self.eventPublisher = eventPublisher
        self.logger = logger
    }

    func fetchUser(id: String) async throws -> User? {
        logger.debug("사용자 가져오는 중: \(id)")

        do {
            let user = try await repository.find(by: id)

            if let user = user {
                await eventPublisher.publish(UserEvent.fetched(user))
                logger.info("사용자 가져오기 성공: \(id)")
            } else {
                logger.warning("사용자를 찾을 수 없음: \(id)")
            }

            return user

        } catch {
            logger.error("사용자 가져오기 실패 \(id): \(error)")
            throw UserServiceError.fetchFailed(id: id, underlyingError: error)
        }
    }

    func updateUser(_ user: User) async throws -> User {
        logger.debug("사용자 업데이트 중: \(user.id)")

        // 업데이트 전 유효성 검사
        try validator.validateUser(user)

        do {
            let updatedUser = try await repository.save(user)
            await eventPublisher.publish(UserEvent.updated(updatedUser))
            logger.info("사용자 업데이트 성공: \(user.id)")
            return updatedUser

        } catch {
            logger.error("사용자 업데이트 실패 \(user.id): \(error)")
            throw UserServiceError.updateFailed(user: user, underlyingError: error)
        }
    }
}

enum UserServiceError: LocalizedError {
    case fetchFailed(id: String, underlyingError: Error)
    case updateFailed(user: User, underlyingError: Error)
    case deleteFailed(id: String, underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let id, let error):
            return "사용자 '\(id)' 가져오기 실패: \(error.localizedDescription)"
        case .updateFailed(let user, let error):
            return "사용자 '\(user.id)' 업데이트 실패: \(error.localizedDescription)"
        case .deleteFailed(let id, let error):
            return "사용자 '\(id)' 삭제 실패: \(error.localizedDescription)"
        }
    }
}
```

### 3. 의존성 등록

WeaveDI의 의존성 주입 컨테이너에 서비스 구현을 등록하세요. 이는 의존성이 요청될 때 WeaveDI가 인스턴스를 생성하는 방법을 알려줍니다. 앱 시작 시, 일반적으로 App delegate나 SwiftUI App 구조체에서 수행하세요:

```swift
// 앱 시작 시 등록 - 프로토콜과 구현 간의 바인딩을 생성합니다
let userService = UnifiedDI.register(UserService.self) {
    UserServiceImpl()  // 실제 구현을 생성하는 팩토리 클로저
}
```

**등록 작동 방식:**
- **타입 등록**: `UserService` 프로토콜을 `UserServiceImpl` 클래스에 매핑합니다
- **팩토리 클로저**: `{ UserServiceImpl() }` 클로저가 인스턴스 생성 방법을 정의합니다
- **지연 생성**: 인스턴스는 처음 요청될 때만 생성됩니다 (지연 로딩)
- **기본 싱글톤**: 다르게 구성하지 않는 한 동일한 인스턴스가 앱 전체에서 재사용됩니다
- **반환 값**: 필요한 경우 즉시 사용할 수 있도록 생성된 인스턴스를 반환합니다

**고급 등록 패턴:**

```swift
// ✅ 의존성이 있는 등록
let networkService = UnifiedDI.register(NetworkService.self) {
    URLSessionNetworkService(
        session: URLSession.shared,
        decoder: JSONDecoder(),
        timeout: 30.0
    )
}

// ✅ 환경 기반 조건부 등록
let apiService = UnifiedDI.register(APIService.self) {
    #if DEBUG
    return MockAPIService(delay: 1.0)  // 테스트용 시뮬레이션 지연
    #elseif STAGING
    return StagingAPIService(baseURL: "https://staging-api.example.com")
    #else
    return ProductionAPIService(baseURL: "https://api.example.com")
    #endif
}

// ✅ 구성이 있는 등록
let databaseService = UnifiedDI.register(DatabaseService.self) {
    let config = DatabaseConfiguration(
        filename: "app_database.sqlite",
        migrations: DatabaseMigrations.all,
        enableLogging: BuildConfig.isDevelopment
    )
    return SQLiteDatabaseService(configuration: config)
}

// ✅ 비동기 초기화가 있는 등록 (이 패턴은 주의해서 사용)
let authenticatedAPIService = UnifiedDI.register(AuthenticatedAPIService.self) {
    // 참고: 서비스를 즉시 생성하지만 인증은 나중에 발생합니다
    let service = AuthenticatedAPIService()

    // 다음 실행 루프에서 인증 예약
    Task {
        try await service.authenticate()
    }

    return service
}
```

**등록 성능 최적화:**
```swift
// ✅ 더 나은 성능을 위한 배치 등록
func registerCoreServices() {
    // 관련 등록을 함께 그룹화
    let logger = UnifiedDI.register(Logger.self) {
        OSLogLogger(category: "MyApp")
    }

    let config = UnifiedDI.register(ConfigService.self) {
        ConfigServiceImpl(logger: logger)
    }

    let network = UnifiedDI.register(NetworkService.self) {
        NetworkServiceImpl(config: config, logger: logger)
    }

    let database = UnifiedDI.register(DatabaseService.self) {
        DatabaseServiceImpl(config: config, logger: logger)
    }

    // 인프라에 의존하는 서비스
    _ = UnifiedDI.register(UserService.self) {
        UserServiceImpl(network: network, database: database, logger: logger)
    }

    print("✅ 핵심 서비스 등록 완료")
}

// ✅ 등록 중 성능 모니터링
func registerServicesWithMonitoring() {
    let startTime = CFAbsoluteTimeGetCurrent()

    registerCoreServices()

    let duration = CFAbsoluteTimeGetCurrent() - startTime
    print("⚡ 서비스 등록이 \(String(format: "%.2f", duration * 1000))ms에 완료됨")

    // 선택사항: 메모리 사용량 모니터링
    let memoryUsage = getMemoryUsage()
    print("📊 등록 후 메모리 사용량: \(memoryUsage)MB")
}

func getMemoryUsage() -> Float {
    var taskInfo = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

    let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }

    if kerr == KERN_SUCCESS {
        return Float(taskInfo.resident_size) / (1024 * 1024)
    } else {
        return 0
    }
}
```

**등록 오류 처리:**
```swift
// ✅ 오류 복구가 있는 안전한 등록
func registerServicesWithErrorHandling() {
    do {
        // 반드시 성공해야 하는 중요한 서비스
        let logger = UnifiedDI.register(Logger.self) {
            guard let logger = OSLogLogger(category: "MyApp") else {
                throw DIError.serviceCreationFailed("Logger")
            }
            return logger
        }

        // 대체 방안이 있는 서비스
        let analyticsService = UnifiedDI.register(AnalyticsService.self) {
            do {
                return try FirebaseAnalyticsService()
            } catch {
                print("⚠️ Firebase Analytics 실패, 콘솔 분석 사용: \(error)")
                return ConsoleAnalyticsService()
            }
        }

        print("✅ 적절한 대체 방안으로 서비스 등록됨")

    } catch {
        print("❌ 중요한 서비스 등록 실패: \(error)")
        // 치명적인 오류를 적절히 처리
        fatalError("중요한 서비스 없이는 계속할 수 없습니다")
    }
}

enum DIError: LocalizedError {
    case serviceCreationFailed(String)
    case dependencyMissing(String)
    case configurationInvalid(String)

    var errorDescription: String? {
        switch self {
        case .serviceCreationFailed(let service):
            return "서비스 생성 실패: \(service)"
        case .dependencyMissing(let dependency):
            return "필수 의존성 누락: \(dependency)"
        case .configurationInvalid(let detail):
            return "유효하지 않은 구성: \(detail)"
        }
    }
}
```

### 4. Property Wrapper 사용

이제 WeaveDI의 프로퍼티 래퍼를 사용하여 모든 클래스에서 등록된 서비스를 주입하고 사용하세요. `@Injected` 래퍼는 컨테이너에서 의존성을 자동으로 해결합니다:

```swift
class UserViewController: UIViewController {
    // @Injected는 DI 컨테이너에서 UserService를 자동으로 해결합니다
    // '?'는 옵셔널로 만듭니다 - 서비스가 등록되지 않았어도 앱이 크래시되지 않습니다
    @Injected var userService: UserService?

    // 추가 주입된 의존성
    @Injected var analyticsService: AnalyticsService?
    @Injected var validationService: ValidationService?

    private var currentUser: User?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCurrentUser()
    }

    private func setupUI() {
        title = "사용자 프로필"
        view.backgroundColor = .systemBackground

        // 화면 보기에 대한 분석 추적
        analyticsService?.trackScreenView(name: "UserProfile")
    }

    func loadUser() async {
        // 주입된 의존성을 항상 안전하게 언래핑하세요
        guard let service = userService else {
            showErrorAlert("UserService를 사용할 수 없습니다")
            print("❌ UserService를 사용할 수 없습니다 - DI 등록을 확인하세요")
            return
        }

        // 로딩 인디케이터 표시
        showLoadingIndicator(true)

        do {
            // 주입된 서비스를 사용하여 작업 수행
            let user = try await service.fetchUser(id: "123")

            // 유효성 검사 서비스가 사용 가능한 경우 사용자 데이터 유효성 검사
            if let validator = validationService {
                try validator.validateUser(user)
            }

            // 메인 스레드에서 가져온 데이터로 UI 업데이트
            await MainActor.run {
                self.currentUser = user
                self.updateUI(with: user)
                self.showLoadingIndicator(false)
                print("✅ 사용자 로드됨: \(user?.name ?? "알 수 없음")")
            }

            // 성공적인 작업 추적
            analyticsService?.trackEvent(name: "user_loaded", parameters: [
                "user_id": user?.id ?? "unknown",
                "load_time": CFAbsoluteTimeGetCurrent()
            ])

        } catch {
            // 오류를 우아하게 처리
            await MainActor.run {
                self.showLoadingIndicator(false)
                self.showErrorAlert("사용자 로드 실패: \(error.localizedDescription)")
            }

            // 모니터링을 위한 오류 추적
            analyticsService?.trackError(error: error, context: [
                "operation": "load_user",
                "user_id": "123"
            ])

            print("❌ 사용자 로드 실패: \(error)")
        }
    }

    @IBAction func updateUserTapped() {
        Task {
            await updateCurrentUser()
        }
    }

    private func updateCurrentUser() async {
        guard let service = userService,
              let user = currentUser else {
            showErrorAlert("사용자를 업데이트할 수 없습니다")
            return
        }

        showLoadingIndicator(true)

        do {
            let updatedUser = try await service.updateUser(user)

            await MainActor.run {
                self.currentUser = updatedUser
                self.updateUI(with: updatedUser)
                self.showLoadingIndicator(false)
                self.showSuccessMessage("사용자가 성공적으로 업데이트되었습니다")
            }

            analyticsService?.trackEvent(name: "user_updated", parameters: [
                "user_id": updatedUser.id
            ])

        } catch {
            await MainActor.run {
                self.showLoadingIndicator(false)
                self.showErrorAlert("사용자 업데이트 실패: \(error.localizedDescription)")
            }

            analyticsService?.trackError(error: error, context: [
                "operation": "update_user",
                "user_id": user.id
            ])
        }
    }

    // UI 헬퍼 메서드
    private func updateUI(with user: User?) {
        // 여기서 UI 요소를 업데이트하세요
        // 예: nameLabel.text = user?.name
        // 예: emailLabel.text = user?.email
    }

    private func showLoadingIndicator(_ show: Bool) {
        if show {
            // 로딩 스피너 표시
        } else {
            // 로딩 스피너 숨기기
        }
    }

    private func showErrorAlert(_ message: String) {
        let alert = UIAlertController(title: "오류", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    private func showSuccessMessage(_ message: String) {
        let alert = UIAlertController(title: "성공", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
```

**@Injected 작동 방식:**
- **자동 해결**: WeaveDI가 등록된 구현을 자동으로 찾아 주입합니다
- **옵셔널 안전성**: 서비스가 등록되지 않았으면 `nil`을 반환합니다 (크래시 방지)
- **지연 로딩**: 서비스는 처음 접근될 때만 해결됩니다
- **스레드 안전**: 다양한 스레드와 액터에서 안전하게 사용할 수 있습니다

**고급 @Injected 사용 패턴:**
```swift
// ✅ 여러 관련 서비스
class OrderProcessingService {
    @Injected var paymentService: PaymentService?
    @Injected var inventoryService: InventoryService?
    @Injected var emailService: EmailService?
    @Injected var auditService: AuditService?

    func processOrder(_ order: Order) async throws {
        // 모든 서비스가 옵셔널로 사용 가능 - 우아하게 처리
        guard let payment = paymentService,
              let inventory = inventoryService else {
            throw OrderError.requiredServicesUnavailable
        }

        // 옵셔널 서비스는 우아하게 저하
        let email = emailService
        let audit = auditService

        try await payment.processPayment(order.paymentInfo)
        try await inventory.reserveItems(order.items)

        // 옵셔널 작업
        await email?.sendOrderConfirmation(order)
        await audit?.logOrderProcessed(order)
    }
}

// ✅ 조건부 서비스 사용
class NotificationManager {
    @Injected var pushNotificationService: PushNotificationService?
    @Injected var emailNotificationService: EmailNotificationService?
    @Injected var smsNotificationService: SMSNotificationService?

    func sendNotification(_ notification: Notification) async {
        var deliveredVia: [String] = []

        // 먼저 푸시 알림 시도 (가장 빠름)
        if let pushService = pushNotificationService {
            do {
                try await pushService.send(notification)
                deliveredVia.append("push")
            } catch {
                print("푸시 알림 실패: \(error)")
            }
        }

        // 이메일로 대체
        if let emailService = emailNotificationService {
            do {
                try await emailService.send(notification)
                deliveredVia.append("email")
            } catch {
                print("이메일 알림 실패: \(error)")
            }
        }

        // 마지막 수단: SMS (중요한 알림인 경우)
        if notification.isCritical, let smsService = smsNotificationService {
            do {
                try await smsService.send(notification)
                deliveredVia.append("sms")
            } catch {
                print("SMS 알림 실패: \(error)")
            }
        }

        print("✅ 알림이 다음을 통해 전달됨: \(deliveredVia.joined(separator: ", "))")
    }
}
```

## Property Wrapper

### @Injected - 선택적 의존성

대부분의 의존성 주입 시나리오에서 `@Injected`를 사용하세요. 의존성이 등록되지 않았어도 앱을 크래시시키지 않는 안전한 옵셔널 주입을 제공합니다:

```swift
class ViewController: UIViewController {
    // 표준 의존성 주입 - 안전하고 옵셔널
    @Injected var userService: UserService?
    @Injected var analyticsService: AnalyticsService?
    @Injected var configService: ConfigService?

    override func viewDidLoad() {
        super.viewDidLoad()

        // 안전한 옵셔널 체이닝 - 서비스가 nil이어도 크래시되지 않습니다
        userService?.fetchUser(id: "current") { [weak self] result in
            switch result {
            case .success(let user):
                DispatchQueue.main.async {
                    self?.displayUser(user)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.showErrorMessage("사용자 로드 실패: \(error.localizedDescription)")
                }
            }
        }

        // 대안: 더 나은 오류 처리를 위한 명시적 nil 확인
        guard let service = userService else {
            showErrorMessage("사용자 서비스를 사용할 수 없습니다")
            return
        }

        // 이제 서비스가 사용 가능함을 알 수 있습니다
        Task {
            do {
                let user = try await service.fetchUser(id: "current")
                await MainActor.run {
                    displayUser(user)
                }
            } catch {
                await MainActor.run {
                    showErrorMessage("사용자 로드 실패: \(error.localizedDescription)")
                }
            }
        }
    }

    private func displayUser(_ user: User?) {
        // 사용자 데이터로 UI 업데이트
    }

    private func showErrorMessage(_ message: String) {
        // 사용자에게 오류 표시
    }
}
```

**@Injected를 사용하는 경우:**
- **대부분의 시나리오**: 의존성 주입의 주요 선택
- **선택적 의존성**: 중요하지 않지만 있으면 좋은 서비스
- **안전한 주입**: 누락된 의존성으로 인한 크래시를 방지하고 싶을 때
- **테스팅**: 실제 서비스를 등록하지 않아 쉽게 모킹 가능

**@Injected 성능 특성:**
```swift
class PerformanceOptimizedViewController: UIViewController {
    // 이들은 지연 해결됨 - 초기화 시 성능 영향 없음
    @Injected var heavyService: HeavyComputationService?
    @Injected var networkService: NetworkService?

    override func viewDidLoad() {
        super.viewDidLoad()

        // 첫 번째 접근이 해결을 트리거 (일회성 비용)
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = heavyService // 해결이 여기서 발생
        let resolutionTime = CFAbsoluteTimeGetCurrent() - startTime

        print("서비스 해결 시간: \(resolutionTime * 1000)ms")
        // 후속 접근은 즉시 (캐시됨)
        _ = heavyService // 해결 비용 없음
    }

    func performNetworkOperation() async {
        // 실제로 필요할 때만 해결 비용 지불
        guard let network = networkService else {
            print("네트워크 사용 불가 - 우아한 저하")
            return
        }

        // 서비스 사용
        do {
            let data = try await network.fetchData()
            processData(data)
        } catch {
            print("네트워크 작업 실패: \(error)")
        }
    }

    private func processData(_ data: Data) {
        // 받은 데이터 처리
    }
}
```

### @Factory - 매번 새 인스턴스

공유 싱글톤이 아닌 새로운 인스턴스가 필요할 때 `@Factory`를 사용하세요. 상태가 없는 작업이나 격리된 인스턴스가 필요할 때 완벽합니다:

```swift
class DocumentProcessor {
    // @Factory는 접근할 때마다 새로운 PDFGenerator 인스턴스를 생성합니다
    // 각 문서가 자체 생성기를 가져 상태 충돌을 방지합니다
    @Factory var pdfGenerator: PDFGenerator
    @Factory var imageProcessor: ImageProcessor
    @Factory var templateEngine: TemplateEngine

    func createDocument(content: String) async {
        // pdfGenerator에 접근할 때마다 완전히 새로운 인스턴스를 반환합니다
        let generator = pdfGenerator // 여기서 새 인스턴스가 생성됩니다

        // 이 특정 생성기를 구성합니다
        generator.setContent(content)
        generator.setFormat(.A4)
        generator.setMargins(top: 20, bottom: 20, left: 15, right: 15)

        // PDF 생성
        do {
            let pdfData = try await generator.generate()
            try await savePDF(pdfData, name: "document_\(UUID().uuidString)")
            print("✅ 문서가 성공적으로 생성되었습니다")
        } catch {
            print("❌ 문서 생성 실패: \(error)")
        }
    }

    func createMultipleDocuments(contents: [String]) async {
        // 각각 자체 생성기로 문서를 동시에 처리
        await withTaskGroup(of: Void.self) { group in
            for (index, content) in contents.enumerated() {
                group.addTask { [weak self] in
                    guard let self = self else { return }

                    // 각 작업이 완전히 새로운 PDFGenerator를 얻습니다
                    let generator = self.pdfGenerator // 각 문서마다 새로운 인스턴스

                    generator.setContent(content)
                    generator.setTemplate(.standard)

                    do {
                        let pdf = try await generator.generate()
                        try await self.savePDF(pdf, name: "batch_document_\(index)")
                        print("✅ 배치 문서 \(index) 생성됨")
                    } catch {
                        print("❌ 배치 문서 \(index) 실패: \(error)")
                    }

                    // 재설정이나 정리가 필요 없습니다 - 각 생성기는 독립적입니다
                }
            }
        }
    }

    func createDocumentWithImages(content: String, images: [UIImage]) async {
        let generator = pdfGenerator
        let processor = imageProcessor

        // 이미지를 독립적으로 처리
        var processedImages: [ProcessedImage] = []

        for image in images {
            // 각 이미지가 자체 프로세서 인스턴스를 얻습니다
            let imageProc = imageProcessor  // 새 인스턴스

            imageProc.setCompressionQuality(0.8)
            imageProc.setMaxSize(CGSize(width: 1200, height: 800))

            do {
                let processed = try await imageProc.process(image)
                processedImages.append(processed)
            } catch {
                print("⚠️ 이미지 처리 실패, 건너뛰기: \(error)")
            }
        }

        // 처리된 이미지로 PDF 생성
        generator.setContent(content)
        generator.setImages(processedImages)

        do {
            let pdfData = try await generator.generate()
            try await savePDF(pdfData, name: "document_with_images_\(UUID().uuidString)")
            print("✅ \(processedImages.count)개 이미지가 포함된 문서 생성됨")
        } catch {
            print("❌ 이미지가 포함된 문서 생성 실패: \(error)")
        }
    }

    private func savePDF(_ data: Data, name: String) async throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                   in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("\(name).pdf")

        try data.write(to: fileURL)
        print("📄 PDF 저장됨: \(fileURL.path)")
    }
}
```

**@Factory를 사용하는 경우:**
- **상태가 없는 작업**: PDF 생성, 이미지 처리, 데이터 변환
- **동시 처리**: 각 스레드/작업이 자체 인스턴스가 필요한 경우
- **공유 상태 방지**: 한 작업이 다른 작업에 영향을 주지 않게 하기
- **빌더 패턴**: 각 구성마다 새로운 빌더
- **수명이 짧은 객체**: 지속될 필요가 없는 객체

**@Factory 고급 패턴:**
```swift
class ReportGenerationService {
    @Factory var reportBuilder: ReportBuilder
    @Factory var dataAnalyzer: DataAnalyzer
    @Factory var chartGenerator: ChartGenerator

    func generateMonthlyReport(data: [MonthlyData]) async -> Report? {
        // 각 보고서가 자체의 새로운 프로세서 세트를 얻습니다
        let builder = reportBuilder
        let analyzer = dataAnalyzer
        let chartGen = chartGenerator

        // 월별 분석을 위해 구성
        analyzer.setAnalysisType(.monthly)
        analyzer.setDataPoints(data)

        // 분석 생성
        guard let analysis = try? await analyzer.performAnalysis() else {
            print("❌ 월별 분석 실패")
            return nil
        }

        // 차트 생성
        chartGen.setTheme(.corporate)
        chartGen.setSize(.large)

        let charts = await withTaskGroup(of: ChartResult?.self, returning: [Chart].self) { group in
            // 여러 차트를 동시에 생성
            group.addTask { try? await chartGen.generateTrendChart(analysis.trends) }
            group.addTask { try? await chartGen.generatePieChart(analysis.distribution) }
            group.addTask { try? await chartGen.generateBarChart(analysis.comparisons) }

            var results: [Chart] = []
            for await result in group {
                if let chart = result?.chart {
                    results.append(chart)
                }
            }
            return results
        }

        // 최종 보고서 구축
        builder.setTitle("월별 보고서 - \(Date().formatted(.dateTime.month(.wide).year()))")
        builder.setAnalysis(analysis)
        builder.setCharts(charts)
        builder.setMetadata(["generated_at": Date(), "data_points": data.count])

        return try? await builder.build()
    }
}

// 복잡한 초기화가 있는 팩토리
class DatabaseConnectionFactory {
    @Factory var connectionPool: DatabaseConnectionPool

    func performBulkOperation(_ operations: [DatabaseOperation]) async {
        // 각 대량 작업이 자체 연결 풀을 얻습니다
        let pool = connectionPool

        // 대량 작업을 위해 구성
        pool.setMaxConnections(10)
        pool.setBatchSize(100)
        pool.setTimeout(30)

        do {
            try await pool.executeBulk(operations)
            print("✅ \(operations.count)개 작업으로 대량 작업 완료")
        } catch {
            print("❌ 대량 작업 실패: \(error)")
        }

        // 풀은 범위를 벗어날 때 자동으로 정리됩니다
        // 다른 대량 작업 간에 공유 상태 없음
    }
}
```

### @SafeInject - 에러 처리

누락된 의존성에 대한 명시적 오류 처리가 필요할 때 `@SafeInject`를 사용하세요. 이 래퍼는 의존성 해결 실패에 대한 더 많은 제어를 제공합니다:

```swift
class DataManager {
    // @SafeInject는 해결이 실패할 때 명시적인 오류 정보를 제공합니다
    @SafeInject var database: Database?
    @SafeInject var backupStorage: BackupStorage?
    @SafeInject var encryptionService: EncryptionService?

    private let logger = Logger(category: "DataManager")

    func save(_ data: Data) throws {
        // 의존성 주입이 성공했는지 확인
        guard let db = database else {
            // 디버깅을 위한 특정 오류 로그
            logger.error("Database 의존성을 찾을 수 없습니다 - DI 등록을 확인하세요")

            // 호출자를 위한 설명적인 오류 던지기
            throw DIError.dependencyNotFound(type: "Database")
        }

        do {
            // 암호화 서비스가 사용 가능한 경우 데이터 암호화
            let dataToSave: Data
            if let encryption = encryptionService {
                logger.debug("저장 전 데이터 암호화")
                dataToSave = try encryption.encrypt(data)
            } else {
                logger.warning("암호화 서비스 사용 불가 - 평문으로 데이터 저장")
                dataToSave = data
            }

            // 기본 데이터베이스에 저장
            try db.save(dataToSave)
            logger.info("기본 데이터베이스에 데이터 저장 성공")

            // 백업 스토리지가 사용 가능한 경우 백업 생성
            if let backup = backupStorage {
                Task {
                    do {
                        try await backup.save(dataToSave)
                        logger.info("데이터 백업 성공")
                    } catch {
                        logger.error("백업 실패: \(error) - 기본 저장으로 계속")
                        // 백업 문제로 인해 주 작업을 실패시키지 않음
                    }
                }
            } else {
                logger.warning("백업 스토리지 사용 불가 - 백업 건너뛰기")
            }

        } catch {
            logger.error("데이터베이스 저장 실패: \(error)")
            throw DataManagerError.saveFailed(underlyingError: error)
        }
    }

    func safeSave(_ data: Data) async -> Result<Void, Error> {
        do {
            guard let db = database else {
                return .failure(DIError.dependencyNotFound(type: "Database"))
            }

            // 저장 작업 수행
            try db.save(data)
            logger.info("안전한 저장 완료")
            return .success(())

        } catch {
            logger.error("안전한 저장 실패: \(error)")
            return .failure(DataManagerError.saveFailed(underlyingError: error))
        }
    }

    func loadData(id: String) async throws -> Data {
        guard let db = database else {
            logger.error("데이터를 로드할 수 없음 - 데이터베이스 의존성 누락")
            throw DIError.dependencyNotFound(type: "Database")
        }

        do {
            let rawData = try await db.load(id: id)

            // 암호화 서비스가 사용 가능한 경우 복호화
            if let encryption = encryptionService {
                logger.debug("로드된 데이터 복호화")
                return try encryption.decrypt(rawData)
            } else {
                logger.debug("암호화 서비스 없음 - 원시 데이터 반환")
                return rawData
            }

        } catch {
            logger.error("id \(id)에 대한 데이터 로드 실패: \(error)")

            // 대체 방안으로 백업 스토리지 시도
            if let backup = backupStorage {
                logger.info("id \(id)에 대한 백업 스토리지 시도")
                do {
                    let backupData = try await backup.load(id: id)

                    // 필요한 경우 백업 데이터 복호화
                    let finalData: Data
                    if let encryption = encryptionService {
                        finalData = try encryption.decrypt(backupData)
                    } else {
                        finalData = backupData
                    }

                    logger.info("id \(id)에 대한 백업에서 데이터 복구")
                    return finalData

                } catch {
                    logger.error("id \(id)에 대한 백업 복구도 실패: \(error)")
                }
            }

            throw DataManagerError.loadFailed(id: id, underlyingError: error)
        }
    }

    func healthCheck() -> DataManagerHealth {
        var health = DataManagerHealth()

        // 각 의존성 확인
        if database != nil {
            health.databaseAvailable = true
            health.issues.append("✅ 데이터베이스 서비스 사용 가능")
        } else {
            health.databaseAvailable = false
            health.issues.append("❌ 데이터베이스 서비스 누락")
        }

        if backupStorage != nil {
            health.backupAvailable = true
            health.issues.append("✅ 백업 스토리지 사용 가능")
        } else {
            health.backupAvailable = false
            health.issues.append("⚠️ 백업 스토리지 누락 (선택사항)")
        }

        if encryptionService != nil {
            health.encryptionAvailable = true
            health.issues.append("✅ 암호화 서비스 사용 가능")
        } else {
            health.encryptionAvailable = false
            health.issues.append("⚠️ 암호화 서비스 누락 (선택사항)")
        }

        health.overallHealth = health.databaseAvailable ? .healthy : .critical

        logger.info("상태 확인 완료: \(health.overallHealth)")
        return health
    }
}

// 더 나은 오류 처리를 위한 커스텀 오류 타입
enum DIError: LocalizedError {
    case dependencyNotFound(type: String)
    case dependencyInitializationFailed(type: String, reason: String)
    case circularDependency(types: [String])

    var errorDescription: String? {
        switch self {
        case .dependencyNotFound(let type):
            return "필수 의존성 '\(type)'을 찾을 수 없습니다. DI 컨테이너에 등록해 주세요."
        case .dependencyInitializationFailed(let type, let reason):
            return "의존성 '\(type)' 초기화 실패: \(reason)"
        case .circularDependency(let types):
            return "순환 의존성 감지: \(types.joined(separator: " -> "))"
        }
    }
}

enum DataManagerError: LocalizedError {
    case saveFailed(underlyingError: Error)
    case loadFailed(id: String, underlyingError: Error)
    case encryptionFailed(reason: String)
    case backupFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "데이터 저장 실패: \(error.localizedDescription)"
        case .loadFailed(let id, let error):
            return "'\(id)'에 대한 데이터 로드 실패: \(error.localizedDescription)"
        case .encryptionFailed(let reason):
            return "암호화 실패: \(reason)"
        case .backupFailed(let reason):
            return "백업 작업 실패: \(reason)"
        }
    }
}

struct DataManagerHealth {
    var databaseAvailable = false
    var backupAvailable = false
    var encryptionAvailable = false
    var overallHealth: HealthStatus = .unknown
    var issues: [String] = []
}

enum HealthStatus {
    case healthy
    case degraded  // 일부 선택적 서비스 누락
    case critical  // 필수 서비스 누락
    case unknown
}
```

**@SafeInject를 사용하는 경우:**
- **중요한 의존성**: 작업에 절대적으로 필요한 서비스
- **오류 보고**: 누락된 의존성에 대한 상세한 오류 정보가 필요할 때
- **명시적 실패 처리**: `nil`이 충분히 설명적이지 않을 때
- **프로덕션 디버깅**: 로그에서 더 나은 진단 정보를 얻기 위해
- **상태 모니터링**: 의존성 상태를 보고해야 하는 서비스

## 고급 기능

### 런타임 최적화

WeaveDI는 프로덕션 앱에서 의존성 해결 속도를 크게 향상시킬 수 있는 내장 성능 최적화를 포함합니다:

```swift
// 자동 런타임 최적화 활성화
// 이는 앱 라이프사이클 초기에, 일반적으로 AppDelegate나 App.swift에서 호출해야 합니다
UnifiedRegistry.shared.enableOptimization()

// 최적화 시스템은 다음을 수행합니다:
// 1. 빠른 접근을 위해 자주 해결되는 의존성을 캐시합니다
// 2. 최소한의 해결 오버헤드를 위해 의존성 그래프를 최적화합니다
// 3. 더 나은 메모리 관리를 위한 지연 로딩 전략을 사용합니다
// 4. 성능을 모니터링하고 사용 패턴에 따라 자동 튜닝합니다

print("🚀 WeaveDI 최적화 활성화됨 - 더 나은 성능을 기대하세요!")
```

**최적화가 하는 일:**
- **Hot Path 캐싱**: 자주 접근되는 의존성이 즉시 해결을 위해 캐시됩니다
- **그래프 최적화**: 의존성 해결 경로가 최소한의 오버헤드를 위해 최적화됩니다
- **메모리 관리**: 메모리 압박 하에서 사용되지 않는 의존성의 자동 정리
- **성능 모니터링**: 지속적인 개선을 위한 해결 패턴의 실시간 분석

**활성화하는 경우:**
- **프로덕션 빌드**: 최고의 성능을 위해 릴리스 빌드에서 항상 활성화
- **대형 애플리케이션**: 많은 의존성을 가진 앱에 필수
- **성능 중요 앱**: 게임, 실시간 앱, 또는 엄격한 성능 요구사항이 있는 앱

**고급 최적화 구성:**
```swift
// 최적화 매개변수 구성
UnifiedRegistry.shared.configureOptimization(
    cacheSize: 100,              // 캐시된 인스턴스의 최대 수
    cacheTTL: 300,               // 캐시 생존 시간 (초)
    optimizationThreshold: 10,   // 최적화 전 최소 사용 횟수
    memoryPressureHandling: true // 메모리 압박 시 자동 정리 활성화
)

// 최적화 효과 모니터링
let stats = UnifiedRegistry.shared.getOptimizationStats()
print("""
최적화 통계:
- 캐시 적중률: \(stats.cacheHitRate)%
- 평균 해결 시간: \(stats.averageResolutionTime)ms
- 메모리 절약: \(stats.memorySavings)MB
- 총 최적화된 타입: \(stats.optimizedTypeCount)
""")

// 실시간 성능 모니터링
UnifiedRegistry.shared.setPerformanceMonitoring(enabled: true) { event in
    switch event {
    case .slowResolution(let type, let time):
        print("⚠️ 느린 해결 감지: \(type)이 \(time)ms 소요됨")
    case .memoryPressure(let severity):
        print("📊 메모리 압박: \(severity)")
    case .optimizationApplied(let type):
        print("⚡ 최적화 적용됨: \(type)")
    }
}
```

### Bootstrap 패턴

Bootstrap 패턴은 한 곳에서 모든 의존성을 설정하는 권장 방법입니다. 이는 적절한 초기화 순서를 보장하고 의존성 관리를 더 체계적으로 만듭니다:

```swift
// 앱 시작 시 모든 의존성 부트스트랩
// 이는 일반적으로 App.swift나 AppDelegate에서 호출됩니다
await WeaveDI.Container.bootstrap { container in
    // 논리적 순서로 서비스 등록

    // 1. 핵심 인프라 서비스 먼저
    container.register(LoggerProtocol.self) {
        OSLogLogger(category: "MyApp", level: .info)
    }

    container.register(ConfigService.self) {
        let config = ConfigServiceImpl()
        config.loadConfiguration()
        return config
    }

    // 2. 데이터 레이어 서비스
    container.register(DatabaseService.self) {
        let dbConfig = DatabaseConfiguration(
            filename: "app_database.sqlite",
            version: 3,
            migrations: DatabaseMigrations.all
        )
        return SQLiteDatabaseService(configuration: dbConfig)
    }

    // 3. 네트워크 서비스
    container.register(NetworkService.self) {
        let session = URLSession(configuration: .default)
        return URLSessionNetworkService(session: session, timeout: 30.0)
    }

    container.register(APIClient.self) {
        let baseURL = URL(string: "https://api.example.com")!
        let networkService = container.resolve(NetworkService.self)!
        return APIClientImpl(baseURL: baseURL, networkService: networkService)
    }

    // 4. 비즈니스 로직 서비스 (인프라에 의존)
    container.register(UserService.self) {
        let database = container.resolve(DatabaseService.self)!
        let apiClient = container.resolve(APIClient.self)!
        let logger = container.resolve(LoggerProtocol.self)!

        return UserServiceImpl(
            database: database,
            apiClient: apiClient,
            logger: logger
        )
    }

    container.register(AuthenticationService.self) {
        let userService = container.resolve(UserService.self)!
        let apiClient = container.resolve(APIClient.self)!

        return AuthenticationServiceImpl(
            userService: userService,
            apiClient: apiClient
        )
    }

    // 5. 프레젠테이션 레이어 서비스
    container.register(AnalyticsService.self) {
        #if DEBUG
        return ConsoleAnalyticsService()
        #else
        return FirebaseAnalyticsService()
        #endif
    }

    container.register(NavigationService.self) {
        NavigationServiceImpl()
    }

    print("✅ 모든 의존성이 성공적으로 등록되었습니다")
}

// 대안: 환경별 부트스트랩
#if DEBUG
await WeaveDI.Container.bootstrap { container in
    // 개발용 모킹 서비스 사용
    container.register(UserService.self) { MockUserService() }
    container.register(NetworkService.self) { MockNetworkService() }
    container.register(DatabaseService.self) { InMemoryDatabase() }
}
#else
await WeaveDI.Container.bootstrap { container in
    // 프로덕션용 실제 서비스 사용
    container.register(UserService.self) { UserServiceImpl() }
    container.register(NetworkService.self) { URLSessionNetworkService() }
    container.register(DatabaseService.self) { SQLiteDatabaseService() }
}
#endif
```

**Bootstrap 패턴의 장점:**
- **중앙화된 설정**: 모든 의존성 등록이 한 곳에
- **적절한 순서**: 의존성이 논리적 순서로 등록됩니다
- **환경 인식**: 디버그/릴리스 빌드에 대한 다른 설정
- **오류 감지**: 누락되거나 잘못 구성된 의존성을 쉽게 발견
- **문서화**: 앱의 의존성에 대한 명확한 맵 역할

**고급 Bootstrap 패턴:**
```swift
// 오류 처리가 있는 모듈형 부트스트랩
class AppBootstrapper {
    private var isBootstrapped = false
    private let logger = Logger(category: "Bootstrap")

    func bootstrap() async throws {
        guard !isBootstrapped else {
            logger.warning("Bootstrap이 이미 완료됨")
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            try await bootstrapCore()
            try await bootstrapServices()
            try await bootstrapPresentationLayer()

            isBootstrapped = true

            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("Bootstrap이 \(String(format: "%.2f", duration))초에 완료됨")

        } catch {
            logger.error("Bootstrap 실패: \(error)")
            throw BootstrapError.initializationFailed(error)
        }
    }

    private func bootstrapCore() async throws {
        await WeaveDI.Container.bootstrap { container in
            // 다른 모든 것이 의존하는 핵심 서비스
            container.register(LoggerProtocol.self) {
                OSLogLogger(category: "MyApp")
            }

            container.register(ConfigService.self) {
                let config = ConfigServiceImpl()
                try! config.loadFromBundle("Config.plist")
                return config
            }
        }

        logger.info("✅ 핵심 서비스 부트스트랩됨")
    }

    private func bootstrapServices() async throws {
        let container = WeaveDI.Container.shared

        // 데이터 서비스 등록
        container.register(DatabaseService.self) {
            try! SQLiteDatabaseService()
        }

        container.register(NetworkService.self) {
            URLSessionNetworkService()
        }

        // 비즈니스 로직 등록
        container.register(UserService.self) {
            UserServiceImpl()
        }

        logger.info("✅ 비즈니스 서비스 부트스트랩됨")
    }

    private func bootstrapPresentationLayer() async throws {
        let container = WeaveDI.Container.shared

        container.register(NavigationService.self) {
            NavigationServiceImpl()
        }

        container.register(AnalyticsService.self) {
            FirebaseAnalyticsService()
        }

        logger.info("✅ 프레젠테이션 레이어 부트스트랩됨")
    }
}

enum BootstrapError: LocalizedError {
    case initializationFailed(Error)
    case dependencyMissing(String)
    case configurationInvalid

    var errorDescription: String? {
        switch self {
        case .initializationFailed(let error):
            return "Bootstrap 초기화 실패: \(error.localizedDescription)"
        case .dependencyMissing(let dependency):
            return "Bootstrap 중 필수 의존성 누락: \(dependency)"
        case .configurationInvalid:
            return "Bootstrap 중 유효하지 않은 구성 감지"
        }
    }
}

// App.swift에서 사용
@main
struct MyApp: App {
    @State private var isBootstrapped = false

    var body: some Scene {
        WindowGroup {
            if isBootstrapped {
                ContentView()
            } else {
                SplashView()
                    .task {
                        await performBootstrap()
                    }
            }
        }
    }

    private func performBootstrap() async {
        do {
            let bootstrapper = AppBootstrapper()
            try await bootstrapper.bootstrap()
            isBootstrapped = true
        } catch {
            print("앱 부트스트랩 실패: \(error)")
            // 부트스트랩 실패를 적절히 처리
        }
    }
}
```

## 성능 고려사항

### 해결 성능

```swift
// 의존성 해결 성능 측정
func measureResolutionPerformance() {
    let iterations = 1000
    var totalTime: CFAbsoluteTime = 0

    for _ in 0..<iterations {
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = UnifiedDI.resolve(UserService.self)
        totalTime += CFAbsoluteTimeGetCurrent() - startTime
    }

    let averageTime = totalTime / Double(iterations) * 1000 // 밀리초로 변환
    print("평균 해결 시간: \(String(format: "%.4f", averageTime))ms")
}

// 캐싱으로 빈번한 해결 최적화
class PerformanceOptimizedManager {
    // 자주 사용되는 서비스 캐시
    private lazy var userService: UserService? = UnifiedDI.resolve(UserService.self)
    private lazy var analyticsService: AnalyticsService? = UnifiedDI.resolve(AnalyticsService.self)

    func performFrequentOperation() {
        // 캐시된 서비스 사용 - 해결 오버헤드 없음
        userService?.performOperation()
        analyticsService?.trackEvent("operation_performed")
    }
}
```

### 메모리 관리

```swift
// 주입된 서비스의 메모리 사용량 모니터링
class MemoryAwareService {
    @Injected var heavyService: HeavyService?

    deinit {
        print("MemoryAwareService 할당 해제됨")
    }

    func performOperationWithMemoryMonitoring() {
        let memoryBefore = getMemoryUsage()

        heavyService?.performHeavyOperation()

        let memoryAfter = getMemoryUsage()
        let memoryDelta = memoryAfter - memoryBefore

        if memoryDelta > 10 { // 10MB 이상 증가
            print("⚠️ 높은 메모리 사용량 감지: \(memoryDelta)MB")
        }
    }

    private func getMemoryUsage() -> Float {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return kerr == KERN_SUCCESS ? Float(taskInfo.resident_size) / (1024 * 1024) : 0
    }
}
```

## 일반적인 함정과 문제 해결

### 1. 순환 의존성

```swift
// ❌ 나쁨: 순환 의존성
class ServiceA {
    @Injected var serviceB: ServiceB?

    init() {
        serviceB?.doSomething()
    }
}

class ServiceB {
    @Injected var serviceA: ServiceA?  // 순환 의존성 생성

    func doSomething() {
        serviceA?.performAction()
    }
}

// ✅ 좋음: 프로토콜로 순환 의존성 해결
protocol ServiceAProtocol {
    func performAction()
}

protocol ServiceBProtocol {
    func doSomething()
}

class ServiceA: ServiceAProtocol {
    private let serviceB: ServiceBProtocol

    init(serviceB: ServiceBProtocol = UnifiedDI.requireResolve(ServiceBProtocol.self)) {
        self.serviceB = serviceB
    }

    func performAction() {
        // 구현
    }
}

class ServiceB: ServiceBProtocol {
    func doSomething() {
        // 직접 참조 대신 이벤트 기반 통신 사용
        NotificationCenter.default.post(name: .serviceBAction, object: nil)
    }
}
```

### 2. 런타임에 의존성 누락

```swift
// ✅ 좋음: 의존성 검사가 있는 방어적 프로그래밍
class RobustService {
    @SafeInject var criticalService: CriticalService?
    @Injected var optionalService: OptionalService?

    func performCriticalOperation() throws {
        guard let critical = criticalService else {
            throw ServiceError.criticalDependencyMissing("CriticalService가 등록되지 않음")
        }

        try critical.performCriticalTask()

        // 대체 방안과 함께 사용되는 옵셔널 서비스
        if let optional = optionalService {
            optional.performOptionalTask()
        } else {
            performFallbackTask()
        }
    }

    private func performFallbackTask() {
        print("옵셔널 서비스에 대한 대체 구현 사용")
    }
}

enum ServiceError: LocalizedError {
    case criticalDependencyMissing(String)

    var errorDescription: String? {
        switch self {
        case .criticalDependencyMissing(let service):
            return "중요한 의존성 누락: \(service)"
        }
    }
}
```

### 3. 스레드 안전성 문제

```swift
// ✅ 좋음: 스레드 안전한 서비스 사용
class ThreadSafeService {
    @Injected var networkService: NetworkService?
    private let queue = DispatchQueue(label: "service.queue", qos: .utility)

    func performConcurrentOperations() async {
        // 서비스는 해결에 대해 스레드 안전하지만 사용법은 동기화가 필요할 수 있습니다
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask { [weak self] in
                    await self?.performNetworkOperation(id: i)
                }
            }
        }
    }

    private func performNetworkOperation(id: Int) async {
        guard let network = networkService else {
            print("작업 \(id)에 대한 네트워크 서비스를 사용할 수 없음")
            return
        }

        do {
            let result = try await network.fetchData(id: "operation_\(id)")
            print("작업 \(id) 완료: \(result)")
        } catch {
            print("작업 \(id) 실패: \(error)")
        }
    }
}
```

### 4. 테스팅 모범 사례

```swift
// ✅ 좋음: 테스트 가능한 서비스 디자인
class TestableUserService {
    private let repository: UserRepository
    private let validator: UserValidator

    // 쉬운 테스트를 위한 초기화를 통한 의존성 주입
    init(
        repository: UserRepository = UnifiedDI.requireResolve(UserRepository.self),
        validator: UserValidator = UnifiedDI.requireResolve(UserValidator.self)
    ) {
        self.repository = repository
        self.validator = validator
    }

    func createUser(_ userData: UserData) async throws -> User {
        try validator.validate(userData)
        return try await repository.create(from: userData)
    }
}

// 테스트 구현
class UserServiceTests: XCTestCase {
    func testCreateUser() async throws {
        // 배치
        let mockRepository = MockUserRepository()
        let mockValidator = MockUserValidator()

        let service = TestableUserService(
            repository: mockRepository,
            validator: mockValidator
        )

        let userData = UserData(name: "Test User", email: "test@example.com")

        // 실행
        let user = try await service.createUser(userData)

        // 단언
        XCTAssertEqual(user.name, "Test User")
        XCTAssertTrue(mockValidator.validateCalled)
        XCTAssertTrue(mockRepository.createCalled)
    }
}
```

## 다음 단계

- [Property Wrapper](/ko/guide/propertyWrappers) - 상세한 주입 패턴과 고급 사용법
- [Core API](/ko/api/coreApis) - 예제가 있는 완전한 API 레퍼런스
- [런타임 최적화](/ko/guide/runtimeOptimization) - 성능 튜닝과 모니터링
- [모듈 시스템](/ko/guide/moduleSystem) - 대규모 애플리케이션 구성
- [테스팅 전략](/ko/tutorial/testing) - DI를 위한 포괄적인 테스팅 접근법