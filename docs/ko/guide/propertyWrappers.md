# Property Wrapper 가이드

WeaveDI의 강력한 Property Wrapper를 사용하여 선언적이고 타입 안전한 의존성 주입을 구현하는 완전한 가이드입니다. 이 가이드는 Swift 5/6 호환성, 고급 패턴, 실제 사용 시나리오를 다룹니다.

## 개요

WeaveDI는 Swift의 Property Wrapper 기능을 활용하여 의존성 주입을 더 선언적이고 직관적으로 만듭니다. `@Inject`, `@Factory`, `@SafeInject`와 같은 Property Wrapper를 통해 간단한 어노테이션으로 복잡한 의존성 관리를 해결할 수 있습니다.

### Swift 버전 호환성

| Swift 버전 | Property Wrapper 기능 | WeaveDI 지원 |
|------------|----------------------|-------------|
| **Swift 6.0+** | 완전한 엄격한 동시성, Sendable 준수 | ✅ 액터 안전성을 포함한 완전한 지원 |
| **Swift 5.9+** | 고급 프로퍼티 래퍼, async/await | ✅ 모든 기능 지원 |
| **Swift 5.8+** | 기본 프로퍼티 래퍼 | ✅ 핵심 기능 |
| **Swift 5.7+** | 프로퍼티 래퍼 기본 | ⚠️ 제한적 기능 |

### 주요 장점

- **🔒 타입 안전성**: 컴파일 타임 의존성 검증
- **📝 선언적**: 깔끔하고 읽기 쉬운 주입 문법
- **⚡ 성능**: 지연 로딩을 통한 최적화된 해결
- **🧪 테스트 가능**: 테스트를 위한 쉬운 모킹 주입
- **🔄 스레드 안전**: 액터와 비동기 컨텍스트에서 안전

## @Inject - 범용 의존성 주입

### 기본 사용법

`@Inject`는 가장 일반적으로 사용되는 Property Wrapper로, 타입 기반과 KeyPath 기반 주입을 모두 지원합니다.

#### Swift 6 향상된 안전성

```swift
import WeaveDI

// Swift 6: Sendable을 준수하는 서비스
protocol UserService: Sendable {
    func getUser(id: String) async throws -> User
}

@MainActor
class UserViewController {
    @Inject private var userService: UserService?
    @Inject private var logger: Logger?

    func loadUser() async {
        // 안전한 액터 격리 접근
        guard let service = userService else {
            logger?.error("UserService를 사용할 수 없습니다")
            return
        }

        do {
            let user = try await service.getUser(id: "current")
            // 메인 액터에서 UI 업데이트
            await updateUI(with: user)
        } catch {
            logger?.error("사용자 로드 실패: \(error)")
        }
    }

    @MainActor
    private func updateUI(with user: User) {
        // UI 업데이트가 메인 액터에서 안전하게 수행
    }
}
```

#### 기본 타입 기반 주입

```swift
import WeaveDI

class UserService {
    // 타입 기반 주입 - 옵셔널
    @Inject var repository: UserRepositoryProtocol?
    @Inject var logger: LoggerProtocol?

    // 타입 기반 주입 - 필수 (강제 언래핑)
    @Inject var networkService: NetworkServiceProtocol!

    func getUser(id: String) async throws -> User {
        logger?.info("사용자 조회 시작: \(id)")

        guard let repository = repository else {
            throw ServiceError.repositoryNotAvailable
        }

        let user = try await repository.findUser(by: id)
        logger?.info("사용자 조회 완료: \(user.name)")
        return user
    }
}
```

### KeyPath 기반 주입

```swift
// WeaveDI.Container 확장
extension WeaveDI.Container {
    var userRepository: UserRepositoryProtocol? {
        resolve(UserRepositoryProtocol.self)
    }

    var database: DatabaseServiceProtocol? {
        resolve(DatabaseServiceProtocol.self)
    }

    var logger: LoggerProtocol? {
        resolve(LoggerProtocol.self)
    }
}

// KeyPath 기반 주입 사용
class DatabaseManager {
    @Inject(\.database) var database: DatabaseServiceProtocol?
    @Inject(\.logger) var logger: LoggerProtocol!

    func performMigration() async throws {
        logger.info("데이터베이스 마이그레이션 시작")

        guard let database = database else {
            logger.error("데이터베이스 서비스를 사용할 수 없습니다")
            throw DatabaseError.serviceUnavailable
        }

        try await database.runMigrations()
        logger.info("데이터베이스 마이그레이션 완료")
    }
}
```

## @Factory - 팩토리 인스턴스 주입

### 기본 개념

`@Factory`는 `FactoryValues`에서 관리되는 팩토리 인스턴스를 주입받는 Property Wrapper입니다. 주로 모듈화된 아키텍처에서 사용됩니다.

```swift
// FactoryValues 확장
extension FactoryValues {
    var repositoryFactory: RepositoryModuleFactory {
        get { self[RepositoryModuleFactory.self] ?? RepositoryModuleFactory() }
        set { self[RepositoryModuleFactory.self] = newValue }
    }

    var useCaseFactory: UseCaseModuleFactory {
        get { self[UseCaseModuleFactory.self] ?? UseCaseModuleFactory() }
        set { self[UseCaseModuleFactory.self] = newValue }
    }
}
```

## @RequiredInject - 필수 의존성 주입

### 기본 사용법

`@RequiredInject`는 의존성 해결에 실패하면 `fatalError`를 발생시키는 엄격한 Property Wrapper입니다.

```swift
class CriticalService {
    // 반드시 필요한 의존성들 - 해결 실패 시 앱 종료
    @RequiredInject var database: DatabaseServiceProtocol
    @RequiredInject var securityService: SecurityServiceProtocol

    // KeyPath 기반 필수 의존성
    @RequiredInject(\.logger) var logger: LoggerProtocol

    func performCriticalOperation() async throws {
        // database, securityService는 항상 유효함이 보장됨
        try await securityService.validateAccess()
        let result = try await database.executeCriticalQuery()
        logger.info("중요한 작업 완료: \(result)")
    }
}
```

## 고급 사용 패턴

### Actor와 함께 사용

```swift
@MainActor
class UIService {
    @Inject var userService: UserServiceProtocol?
    @Inject var imageLoader: ImageLoaderProtocol!

    func updateUserProfile(_ user: User) async {
        // MainActor 컨텍스트에서 안전하게 실행
        let profileImage = await imageLoader.loadImage(from: user.profileImageURL)
        // UI 업데이트...
    }
}

actor DataProcessor {
    @Inject var databaseService: DatabaseServiceProtocol?
    @Inject var analyticsService: AnalyticsServiceProtocol!

    func processUserData(_ data: UserData) async throws {
        // Actor 컨텍스트에서 안전하게 실행
        try await databaseService?.store(data)
        await analyticsService.track(event: "data_processed")
    }
}
```

### SwiftUI와 통합

```swift
import SwiftUI
import WeaveDI

struct UserProfileView: View {
    @StateObject private var viewModel = UserProfileViewModel()

    var body: some View {
        VStack {
            AsyncImage(url: viewModel.user?.profileImageURL)
            Text(viewModel.user?.name ?? "Loading...")

            Button("Refresh") {
                Task {
                    await viewModel.loadUserData()
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadUserData()
            }
        }
    }
}

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Inject var userService: UserServiceProtocol?
    @Inject var logger: LoggerProtocol!

    func loadUserData() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let userService = userService else {
                throw ServiceError.serviceUnavailable("UserService")
            }

            let loadedUser = try await userService.getCurrentUser()
            self.user = loadedUser
            logger.info("사용자 데이터 로드 완료")
        } catch {
            self.errorMessage = error.localizedDescription
            logger.error("사용자 데이터 로드 실패: \(error)")
        }

        isLoading = false
    }
}
```

## 테스트에서의 활용

### Mock 주입

```swift
// 테스트용 Mock 서비스
class MockUserService: UserServiceProtocol {
    var mockUser: User?
    var shouldThrowError = false

    func getCurrentUser() async throws -> User {
        if shouldThrowError {
            throw ServiceError.networkError
        }
        return mockUser ?? User.mockUser
    }
}

class UserServiceTests: XCTestCase {
    var mockUserService: MockUserService!

    override func setUp() async throws {
        await super.setUp()

        // Mock 서비스 등록
        mockUserService = MockUserService()
        DI.register(UserServiceProtocol.self, instance: mockUserService)
    }

    func testUserLoading() async throws {
        // Given
        let expectedUser = User(id: "test", name: "Test User")
        mockUserService.mockUser = expectedUser

        // 테스트 대상 클래스 (자동으로 Mock이 주입됨)
        let viewModel = UserProfileViewModel()

        // When
        await viewModel.loadUserData()

        // Then
        XCTAssertEqual(viewModel.user?.id, expectedUser.id)
        XCTAssertEqual(viewModel.user?.name, expectedUser.name)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
}
```

Property Wrapper를 통한 의존성 주입은 WeaveDI의 가장 강력한 기능 중 하나입니다. 선언적이고 타입 안전하며, Swift의 언어 기능과 자연스럽게 통합되어 개발자 경험을 크게 향상시킵니다.
